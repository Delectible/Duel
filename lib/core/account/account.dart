import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';

import '../avatars/faces.dart';
import 'achievements.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/poker/reads.dart';
import '../sound/sound.dart';
import '../store/cosmetics.dart';
import '../store/daily.dart';
import '../store/shop.dart';
import '../theme/toon.dart';

/// How money is shown. One pip is one of anything: it's display only.
enum CurrencyChoice {
  pips('Pips', 'Duel’s own'),
  usd('US dollar', r'$'),
  eur('Euro', '€'),
  gbp('British pound', '£'),
  jpy('Japanese yen', '¥'),
  aud('Australian dollar', r'A$');

  const CurrencyChoice(this.label, this.symbol);

  final String label;
  final String symbol;

  /// What your balance is called in a sentence: "pips", or "money" for a
  /// real currency ("Not enough money to sit here").
  String get noun => this == pips ? 'pips' : 'money';

  /// 1240 -> "1,240 pips", "$1,240"; negatives with a minus.
  String format(int amount) {
    final n = chips(amount.abs());
    final sign = amount < 0 ? '−' : '';
    if (this == pips) return '$sign$n ${amount.abs() == 1 ? 'pip' : 'pips'}';
    return '$sign$symbol$n';
  }
}

enum ThemeChoice {
  system('Match phone'),
  light('Light'),
  dark('Dark');

  const ThemeChoice(this.label);

  final String label;
}

enum Outcome { win, loss, tie }

/// How one game has gone for you over time.
class GameStats {
  int played = 0;
  int won = 0;
  int lost = 0;
  int tied = 0;

  /// Money won minus money lost, staked games only.
  int net = 0;

  Map<String, int> toJson() => {'p': played, 'w': won, 'l': lost, 't': tied, 'n': net};

  static GameStats fromJson(Map<String, dynamic> j) => GameStats()
    ..played = j['p'] as int? ?? 0
    ..won = j['w'] as int? ?? 0
    ..lost = j['l'] as int? ?? 0
    ..tied = j['t'] as int? ?? 0
    ..net = j['n'] as int? ?? 0;
}

/// Where the account is kept (shared preferences on the phone; memory in
/// tests).
abstract class AccountStore {
  String? load();
  void save(String json);
}

class MemoryStore implements AccountStore {
  String? data;

  @override
  String? load() => data;

  @override
  void save(String json) => data = json;
}

/// You: name, face, wallet, per-game stats and settings.
///
/// Money: playing free wins nothing. A staked game takes the stake when it
/// starts; a win gives it back plus stake x opponents x the difficulty's
/// rate; a tie gives it back; a loss (or leaving early) keeps it. At zero
/// or below you can still stake 1, which goes on your debt (a negative
/// balance); winnings pay it off, no time limit.
class Account extends ChangeNotifier {
  Account({AccountStore? store}) : _store = store ?? MemoryStore() {
    _read();
    CardBack.chosen = _back;
    TableFelt.chosen = _felt;
    // The app closed at a cash table: those chips come back now.
    if (_cashChips case final chips?) cashOut(chips);
  }

  static const startingBalance = 100;

  final AccountStore _store;

  String _name = 'You';
  Avatar _avatar = const Avatar();

  /// The server's balance as last heard (never synced: the phone's own).
  int _base = startingBalance;

  /// Pips won or lost here (bot games) since, not yet sent to the server.
  int _unsynced = 0;

  /// The report on its way to the server (sent again until it's heard).
  ({String id, int delta})? _sending;

  /// The server keeps this account's pips (they were carried over).
  bool _synced = false;
  CurrencyChoice _currency = CurrencyChoice.pips;
  ThemeChoice _theme = ThemeChoice.system;
  bool _pokerOdds = true;
  bool _sound = true;
  double _volume = 0.8;
  Track? _music = Track.lounge;
  double _musicVolume = 0.5;
  final Map<String, GameStats> _stats = {};
  String? _partyId;

  String get name => _name;
  Avatar get avatar => _avatar;
  int get balance => _base + (_sending?.delta ?? 0) + _unsynced;
  CurrencyChoice get currency => _currency;
  ThemeChoice get theme => _theme;

  /// Hold'em: pot odds and outs under your buttons.
  bool get pokerOdds => _pokerOdds;

  /// Sound effects on, and how loud (0..1).
  bool get sound => _sound;
  double get volume => _volume;
  set sound(bool v) => _change(() => _sound = v);
  set volume(double v) => _change(() => _volume = v.clamp(0.0, 1.0));

  /// Background music (null: off) and its own volume.
  Track? get music => _music;
  double get musicVolume => _musicVolume;
  set music(Track? t) => _change(() => _music = t);
  set musicVolume(double v) => _change(() => _musicVolume = v.clamp(0.0, 1.0));

  /// The online party you're in, so reopening the app takes you back.
  String? get partyId => _partyId;

  /// Online games you left (match id -> the stake that went with it), so
  /// coming back ([takeBack]) undoes the loss in your stats (the pips
  /// themselves are the server's: it pays out when the game ends).
  final Map<String, ({String game, int stake})> _leftGames = {};

  /// You left online match [matchId] of [game], losing [stake].
  void leftGame(String matchId, String game, int stake) {
    _leftGames.remove(matchId);
    _leftGames[matchId] = (game: game, stake: stake);
    // Only the latest few matter.
    while (_leftGames.length > 8) {
      _leftGames.remove(_leftGames.keys.first);
    }
    _save();
  }

  /// You're back in [matchId]: the loss you took for leaving is undone.
  void takeBack(String matchId) {
    final left = _leftGames.remove(matchId);
    if (left == null) return;
    final st = stats(left.game);
    _change(() {
      if (st.played > 0) st.played--;
      if (st.lost > 0) st.lost--;
      st.net += left.stake;
    });
  }

  // --- The wallet on the server ----------------------------------------------

  /// Something the server hasn't heard yet: the first carry-over, or bot
  /// games since the last report.
  bool get walletDue => !_synced || _sending != null || _unsynced != 0;

  /// The next report for the server's wallet: {carry (the phone's balance,
  /// used only the first time), id, delta (bot games since)}. The same one
  /// is sent again until [walletHeard] says it landed.
  Map<String, Object> walletReport() {
    if (_sending == null) {
      _sending = (
        id: '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}',
        delta: _unsynced,
      );
      _unsynced = 0;
      _save();
    }
    final s = _sending!;
    return {'carry': _base + s.delta, 'id': s.id, 'delta': s.delta};
  }

  /// The server's wallet ({balance, applied}): its balance is yours now.
  void walletHeard(Map<String, Object?> wallet) {
    final balance = wallet['balance'];
    if (balance is! int) return;
    final applied = (wallet['applied'] as List?) ?? const [];
    _change(() {
      if (_sending != null && applied.contains(_sending!.id)) _sending = null;
      _base = balance;
      _synced = true;
    });
  }

  set partyId(String? v) {
    if (v != _partyId) _change(() => _partyId = v);
  }

  bool get inDebt => balance < 0;

  // --- Achievements and rivals (Hold'em against bots) -------------------------

  final Map<Achievement, int> _earned = {};

  /// When each achievement was earned (ms since epoch).
  Map<Achievement, int> get earned => Map.unmodifiable(_earned);

  /// Earns [a]; true the first time (show it off), false after.
  bool earn(Achievement a) {
    if (_earned.containsKey(a)) return false;
    _change(() => _earned[a] = DateTime.now().millisecondsSinceEpoch);
    return true;
  }

  final Map<String, ({int wins, int losses})> _rivals = {};

  /// Your record against each rival bot (by name): games you finished
  /// ahead of them / behind them.
  ({int wins, int losses}) rivalRecord(String name) => _rivals[name] ?? (wins: 0, losses: 0);

  Map<String, ({int wins, int losses})> get rivals => Map.unmodifiable(_rivals);

  void rivalResult(String name, {required bool won}) {
    final r = rivalRecord(name);
    _change(
      () => _rivals[name] = won ? (wins: r.wins + 1, losses: r.losses) : (wins: r.wins, losses: r.losses + 1),
    );
  }

  // --- What rivals and bosses remember of you ---------------------------------

  final Map<String, ReadMemory> _memory = {};

  /// How [name] (a rival or boss) remembers you playing.
  ReadMemory memoryOf(String name) => _memory[name] ?? ReadMemory();

  /// After a game with [name]: what it saw you do this game joins what it
  /// remembers (older games fading).
  void remember(String name, PlayerReads game) {
    if (game.hands == 0) return;
    _change(() => _memory[name] = memoryOf(name).remember(game));
  }

  // --- The lounge: Boss Tables and tournaments --------------------------------

  /// A boss or tournament game in progress (saved after every hand), so
  /// closing the app doesn't lose it.
  Map<String, Object?>? _loungeGame;

  Map<String, Object?>? get loungeGame => _loungeGame;

  /// Saves (or with null clears) the lounge game in progress.
  void saveLoungeGame(Map<String, Object?>? game) {
    _loungeGame = game;
    _save();
  }

  /// Bosses beaten on the ladder so far (the next one is unlocked).
  int _bosses = 0;
  int get bossesBeaten => _bosses;

  /// You beat boss [rung] (0 = the first): the next one unlocks.
  void bossBeaten(int rung) {
    if (rung + 1 > _bosses) _change(() => _bosses = rung + 1);
  }

  final Map<String, ({int played, int cashes, int wins, int best})> _tourneys = {};

  /// Your record in the tournament [tier]: entries, top-three finishes,
  /// wins and best place (0: none yet).
  ({int played, int cashes, int wins, int best}) tourneyRecord(String tier) =>
      _tourneys[tier] ?? (played: 0, cashes: 0, wins: 0, best: 0);

  void tourneyResult(String tier, int place) {
    final r = tourneyRecord(tier);
    _change(
      () => _tourneys[tier] = (
        played: r.played + 1,
        cashes: r.cashes + (place <= 3 ? 1 : 0),
        wins: r.wins + (place == 1 ? 1 : 0),
        best: r.best == 0 ? place : min(r.best, place),
      ),
    );
  }

  /// The day (yyyy-mm-dd) you last entered the Daily Freeroll.
  String? _freeroll;

  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// You've had today's Daily Freeroll.
  bool get freerollPlayed => _freeroll == _today();

  void enterFreeroll() => _change(() => _freeroll = _today());

  /// Settles a game whose payout is a prize (tournaments, bosses): [prize]
  /// (all of it, the stake included) goes to your balance. Returns the
  /// change compared to before the stake.
  int settlePrize({required String gameId, required int stake, required int prize}) {
    final st = stats(gameId);
    _change(() {
      st.played++;
      if (prize > stake || (stake == 0 && prize > 0)) {
        st.won++;
      } else if (prize < stake) {
        st.lost++;
      } else {
        st.tied++;
      }
      st.net += prize - stake;
      _unsynced += prize;
      _dailyGame(gameId, won: prize > stake, stake: stake);
    });
    return prize - stake;
  }

  // --- The store -------------------------------------------------------------

  /// Items bought (or worn before the store opened). Free ones are owned
  /// by everyone.
  final Set<String> _owned = {};
  CardBack _back = CardBack.classic;
  TableFelt _felt = TableFelt.classic;
  final Set<String> _setsDone = {};

  bool owns(ShopItem item) => item.free || _owned.contains(item.id);
  bool ownsId(String id) {
    final item = Shop.byId[id];
    return item != null && owns(item);
  }

  /// Enough pips (no buying on credit).
  bool canAfford(ShopItem item) => balance >= item.price;

  CardBack get cardBack => _back;
  TableFelt get felt => _felt;

  set cardBack(CardBack b) => _change(() => CardBack.chosen = _back = b);
  set felt(TableFelt f) => _change(() => TableFelt.chosen = _felt = f);

  /// Sets you've finished (their badges).
  List<Collection> get collectionsDone => [
    for (final c in Shop.collections)
      if (_setsDone.contains(c.id)) c,
  ];

  /// How many of [c]'s items you own.
  int ownedIn(Collection c) => c.items.where(ownsId).length;

  /// Buys [item] (and puts it on). Returns the sets it finished (their
  /// prizes paid), or null if it can't be bought.
  List<Collection>? buy(ShopItem item) {
    if (owns(item) || !canAfford(item)) return null;
    final done = <Collection>[];
    _change(() {
      _unsynced -= item.price;
      _owned.add(item.id);
      for (final c in Shop.collections) {
        if (!_setsDone.contains(c.id) && c.items.every(ownsId)) {
          _setsDone.add(c.id);
          _unsynced += c.prize;
          done.add(c);
        }
      }
    });
    wear(item);
    return done;
  }

  /// Puts on an item you own.
  void wear(ShopItem item) {
    if (!owns(item)) return;
    switch (item.kind) {
      case ItemKind.face:
        avatar = _avatar.withPart(item.part!, item.value!);
      case ItemKind.back:
        cardBack = item.back!;
      case ItemKind.felt:
        felt = item.felt!;
    }
  }

  /// Wearing [item] now.
  bool wearing(ShopItem item) => switch (item.kind) {
    ItemKind.face => _avatar.partValue(item.part!) == item.value,
    ItemKind.back => _back == item.back,
    ItemKind.felt => _felt == item.felt,
  };

  // --- Daily challenges --------------------------------------------------------

  String? _day;
  List<int> _dailyProgress = [0, 0, 0];
  final Set<int> _dailyClaimed = {};
  final Set<String> _dailyPlayed = {};

  void _rollDay() {
    final today = _today();
    if (_day == today) return;
    _day = today;
    _dailyProgress = [0, 0, 0];
    _dailyClaimed.clear();
    _dailyPlayed.clear();
  }

  /// Today's three challenges.
  List<Challenge> get daily => Challenge.forDay(_today());

  /// How far along challenge [i] is (capped at its goal).
  int dailyProgress(int i) {
    _rollDay();
    return min(_dailyProgress[i], daily[i].goal);
  }

  bool dailyDone(int i) => dailyProgress(i) >= daily[i].goal;
  bool dailyClaimed(int i) {
    _rollDay();
    return _dailyClaimed.contains(i);
  }

  /// Challenges finished and waiting to be collected.
  int get dailyReady => [0, 1, 2].where((i) => dailyDone(i) && !dailyClaimed(i)).length;

  /// Collects a finished challenge's reward.
  bool claimDaily(int i) {
    if (!dailyDone(i) || dailyClaimed(i)) return false;
    _change(() {
      _dailyClaimed.add(i);
      _unsynced += daily[i].reward;
    });
    return true;
  }

  void _dailyGame(String gameId, {required bool won, required int stake, Difficulty? difficulty}) {
    _rollDay();
    if (gameId != 'blackjack') _dailyPlayed.add(gameId);
    final today = daily;
    for (var i = 0; i < 3; i++) {
      final c = today[i];
      if (c.kind == ChallengeKind.variety) {
        _dailyProgress[i] = _dailyPlayed.length;
      } else {
        _dailyProgress[i] += c.progress(gameId: gameId, won: won, stake: stake, difficulty: difficulty);
      }
    }
  }

  // --- Cash tables (local) ----------------------------------------------------

  /// At a local cash table: the chips in front of you and what you've put
  /// in so far. Kept on every change, so closing the app mid-session
  /// still cashes you out next time.
  int? _cashChips;
  int _cashIn = 0;

  /// At a local cash table now.
  bool get atCashTable => _cashChips != null;

  /// Sits down or tops up with [pips] from your balance.
  void cashIn(int pips) {
    if (pips <= 0) return;
    _change(() {
      _unsynced -= pips;
      _cashIn += pips;
      _cashChips = (_cashChips ?? 0) + pips;
    });
  }

  /// Your chips at the table after a hand.
  void cashChips(int stack) {
    if (_cashChips == null || _cashChips == stack) return;
    _cashChips = stack;
    _save();
  }

  /// Stands up with [stack]: it goes back to your balance. Returns what
  /// the session won (or lost).
  int cashOut(int stack) {
    if (_cashChips == null) return 0;
    final net = stack - _cashIn;
    _change(() {
      _unsynced += stack;
      stats('cash').net += net;
      stats('cash').played++;
      if (net > 0) stats('cash').won++;
      _cashChips = null;
      _cashIn = 0;
    });
    return net;
  }

  // --- Table games bet straight from the balance (Blackjack) ---------------

  /// Puts [pips] on the table from your balance (a bet, a double, a split).
  void wager(int pips) {
    if (pips <= 0) return;
    _change(() => _unsynced -= pips);
  }

  /// A round's over: [back] of the [staked] pips come back (0 = lost,
  /// staked = push, more = won). Counts in [gameId]'s stats.
  void payout(String gameId, {required int staked, required int back}) {
    _change(() {
      _unsynced += back;
      final st = stats(gameId);
      st.played++;
      if (back > staked) {
        st.won++;
      } else if (back < staked) {
        st.lost++;
      } else {
        st.tied++;
      }
      st.net += back - staked;
      _dailyGame(gameId, won: back > staked, stake: staked);
    });
  }

  /// Debug menu: your balance becomes [amount] (sent to the server like a
  /// bot game's result, so it sticks online too).
  void setBalance(int amount) => _change(() => _unsynced += amount - balance);

  /// Extra pips won in a game (a bounty), on top of the stake's result.
  void bonus(String gameId, int pips) {
    if (pips <= 0) return;
    _change(() {
      _unsynced += pips;
      stats(gameId).net += pips;
    });
  }

  GameStats stats(String gameId) => _stats.putIfAbsent(gameId, GameStats.new);

  /// Your face at the tables.
  Persona get persona => Persona.you(name: _name, avatar: _avatar);

  set name(String v) => _change(() => _name = v.trim().isEmpty ? 'You' : v.trim());
  set avatar(Avatar v) => _change(() => _avatar = v);
  set currency(CurrencyChoice v) => _change(() => _currency = v);
  set theme(ThemeChoice v) => _change(() => _theme = v);
  set pokerOdds(bool v) => _change(() => _pokerOdds = v);

  String money(int amount) => _currency.format(amount);

  /// Most you can stake now: your balance, or 1 on credit when you're out.
  int get maxStake => balance > 0 ? balance : 1;

  /// Win for [stake] against [opponents] at [difficulty] (the profit; the
  /// stake comes back on top).
  static int winnings(int stake, int opponents, Difficulty difficulty) {
    if (stake <= 0) return 0;
    final rate = switch (difficulty) {
      Difficulty.easy => 0.5,
      Difficulty.normal => 1.0,
      Difficulty.hard => 1.5,
    };
    return (stake * opponents * rate).floor().clamp(1, 1 << 40);
  }

  /// Takes the stake as a game starts. Returns the stake actually taken
  /// (capped at [maxStake]).
  int placeStake(int stake) {
    final s = stake.clamp(0, maxStake);
    if (s > 0) _change(() => _unsynced -= s);
    return s;
  }

  /// Settles a finished game. Returns what changed your balance compared
  /// to before the stake: +winnings, 0 (tie / free), or -stake. Online,
  /// [paid] is that change as the server made it (it moves the pips; this
  /// only keeps the stats).
  int settle({
    required String gameId,
    required int stake,
    required Outcome outcome,
    required int opponents,
    required Difficulty difficulty,
    int? paid,
  }) {
    final st = stats(gameId);
    st.played++;
    var delta = 0;
    switch (outcome) {
      case Outcome.win:
        st.won++;
        delta = paid ?? winnings(stake, opponents, difficulty);
        if (paid == null) _unsynced += stake + delta;
      case Outcome.tie:
        st.tied++;
        delta = paid ?? 0;
        if (paid == null) _unsynced += stake;
      case Outcome.loss:
        st.lost++;
        delta = paid ?? -stake;
    }
    st.net += delta;
    _dailyGame(gameId, won: outcome == Outcome.win, stake: stake, difficulty: difficulty);
    _save();
    notifyListeners();
    return delta;
  }

  void _change(VoidCallback f) {
    f();
    _save();
    notifyListeners();
  }

  void _read() {
    final raw = _store.load();
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _name = j['name'] as String? ?? _name;
      final face = j['face'];
      if (face is Map<String, dynamic>) _avatar = Avatar.fromJson(face);
      // Whatever you wore before the store opened is yours.
      final owned = j['owned'];
      if (owned is List) {
        _owned.addAll(owned.whereType<String>());
      } else {
        _owned.addAll(Shop.idsOf(_avatar));
      }
      _back = CardBack.values.asNameMap()[j['back']] ?? CardBack.classic;
      _felt = TableFelt.values.asNameMap()[j['felt']] ?? TableFelt.classic;
      final sets = j['sets'];
      if (sets is List) _setsDone.addAll(sets.whereType<String>());
      final day = j['daily'];
      if (day is Map && day['d'] is String) {
        _day = day['d'] as String;
        final p = day['p'];
        if (p is List && p.length == 3 && p.every((x) => x is int)) _dailyProgress = p.cast<int>().toList();
        _dailyClaimed.addAll((day['c'] as List? ?? const []).whereType<int>());
        _dailyPlayed.addAll((day['g'] as List? ?? const []).whereType<String>());
      }
      _base = j['balance'] as int? ?? startingBalance;
      _unsynced = j['unsynced'] as int? ?? 0;
      _synced = j['wallet'] as bool? ?? false;
      final sending = j['sending'];
      if (sending is Map && sending['id'] is String && sending['d'] is int) {
        _sending = (id: sending['id'] as String, delta: sending['d'] as int);
      }
      _currency = CurrencyChoice.values.asNameMap()[j['currency']] ?? CurrencyChoice.pips;
      _theme = ThemeChoice.values.asNameMap()[j['theme']] ?? ThemeChoice.system;
      _partyId = j['party'] as String?;
      _pokerOdds = j['odds'] as bool? ?? true;
      _sound = j['sound'] as bool? ?? true;
      _volume = (j['volume'] as num?)?.toDouble() ?? 0.8;
      _music = j['music'] == 'off' ? null : Track.values.asNameMap()[j['music']] ?? Track.lounge;
      _musicVolume = (j['musicVolume'] as num?)?.toDouble() ?? 0.5;
      final left = j['left'] as Map<String, dynamic>? ?? {};
      left.forEach((k, v) {
        if (v is Map && v['g'] is String && v['s'] is int) {
          _leftGames[k] = (game: v['g'] as String, stake: v['s'] as int);
        }
      });
      final earned = j['ach'] as Map<String, dynamic>? ?? {};
      final byName = Achievement.values.asNameMap();
      earned.forEach((k, v) {
        if (byName[k] case final a? when v is int) _earned[a] = v;
      });
      final rivals = j['rivals'] as Map<String, dynamic>? ?? {};
      rivals.forEach((k, v) {
        if (v is List && v.length == 2 && v[0] is int && v[1] is int) {
          _rivals[k] = (wins: v[0] as int, losses: v[1] as int);
        }
      });
      final memory = j['memory'] as Map<String, dynamic>? ?? {};
      memory.forEach((k, v) => _memory[k] = ReadMemory.fromJson(v));
      final lounge = j['lounge'];
      if (lounge is Map<String, dynamic>) _loungeGame = lounge;
      _bosses = j['bosses'] as int? ?? 0;
      final tourneys = j['tourneys'] as Map<String, dynamic>? ?? {};
      tourneys.forEach((k, v) {
        if (v is List && v.length == 4 && v.every((x) => x is int)) {
          _tourneys[k] = (played: v[0] as int, cashes: v[1] as int, wins: v[2] as int, best: v[3] as int);
        }
      });
      _freeroll = j['freeroll'] as String?;
      _cashChips = j['cashChips'] as int?;
      _cashIn = j['cashIn'] as int? ?? 0;
      final stats = j['stats'] as Map<String, dynamic>? ?? {};
      stats.forEach((k, v) => _stats[k] = GameStats.fromJson(v as Map<String, dynamic>));
    } on Object {
      // A damaged save starts fresh rather than crashing.
    }
  }

  void _save() => _store.save(
    jsonEncode({
      'name': _name,
      'face': _avatar.toJson(),
      'owned': [..._owned],
      if (_back != CardBack.classic) 'back': _back.name,
      if (_felt != TableFelt.classic) 'felt': _felt.name,
      if (_setsDone.isNotEmpty) 'sets': [..._setsDone],
      if (_day != null)
        'daily': {
          'd': _day,
          'p': _dailyProgress,
          'c': [..._dailyClaimed],
          'g': [..._dailyPlayed],
        },
      'balance': _base,
      if (_unsynced != 0) 'unsynced': _unsynced,
      if (_synced) 'wallet': true,
      if (_sending case final s?) 'sending': {'id': s.id, 'd': s.delta},
      'currency': _currency.name,
      'theme': _theme.name,
      'stats': {for (final e in _stats.entries) e.key: e.value.toJson()},
      'party': ?_partyId,
      if (!_pokerOdds) 'odds': false,
      if (!_sound) 'sound': false,
      'volume': _volume,
      'music': _music?.name ?? 'off',
      'musicVolume': _musicVolume,
      if (_earned.isNotEmpty) 'ach': {for (final e in _earned.entries) e.key.name: e.value},
      if (_rivals.isNotEmpty)
        'rivals': {
          for (final e in _rivals.entries) e.key: [e.value.wins, e.value.losses],
        },
      if (_memory.isNotEmpty) 'memory': {for (final e in _memory.entries) e.key: e.value.toJson()},
      'lounge': ?_loungeGame,
      if (_bosses > 0) 'bosses': _bosses,
      if (_tourneys.isNotEmpty)
        'tourneys': {
          for (final e in _tourneys.entries)
            e.key: [e.value.played, e.value.cashes, e.value.wins, e.value.best],
        },
      'freeroll': ?_freeroll,
      'cashChips': ?_cashChips,
      if (_cashChips != null) 'cashIn': _cashIn,
      'left': {
        for (final e in _leftGames.entries) e.key: {'g': e.value.game, 's': e.value.stake},
      },
    }),
  );
}

class AccountScope extends InheritedNotifier<Account> {
  const AccountScope({super.key, required Account account, required super.child}) : super(notifier: account);

  /// The account, rebuilding [context] when it changes.
  static Account of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccountScope>()!.notifier!;

  /// The account without listening (for callbacks and game start / end).
  static Account read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AccountScope>()!.notifier!;

  /// Like [read], or null outside the app (screens tested on their own).
  static Account? maybeRead(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AccountScope>()?.notifier;
}
