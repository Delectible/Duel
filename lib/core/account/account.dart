import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../avatars/faces.dart';
import 'package:duel_engine/difficulty.dart';
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
  }

  static const startingBalance = 100;

  final AccountStore _store;

  String _name = 'You';
  Avatar _avatar = const Avatar();
  int _balance = startingBalance;
  CurrencyChoice _currency = CurrencyChoice.pips;
  ThemeChoice _theme = ThemeChoice.system;
  bool _pokerOdds = true;
  bool _sound = true;
  double _volume = 0.8;
  final Map<String, GameStats> _stats = {};
  String? _partyId;

  String get name => _name;
  Avatar get avatar => _avatar;
  int get balance => _balance;
  CurrencyChoice get currency => _currency;
  ThemeChoice get theme => _theme;

  /// Hold'em: pot odds and outs under your buttons.
  bool get pokerOdds => _pokerOdds;

  /// Sound effects on, and how loud (0..1).
  bool get sound => _sound;
  double get volume => _volume;
  set sound(bool v) => _change(() => _sound = v);
  set volume(double v) => _change(() => _volume = v.clamp(0.0, 1.0));

  /// The online party you're in, so reopening the app takes you back.
  String? get partyId => _partyId;

  /// Online games you left (match id -> the stake that went with it), so
  /// coming back ([takeBack]) returns it: leaving and rejoining costs
  /// nothing; leaving for good loses the stake.
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
    if (st.played > 0) st.played--;
    if (st.lost > 0) st.lost--;
    st.net += left.stake;
    _change(() => _balance += left.stake);
  }

  set partyId(String? v) {
    if (v != _partyId) _change(() => _partyId = v);
  }

  bool get inDebt => _balance < 0;

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
  int get maxStake => _balance > 0 ? _balance : 1;

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
    if (s > 0) _change(() => _balance -= s);
    return s;
  }

  /// Settles a finished game. Returns what changed your balance compared
  /// to before the stake: +winnings, 0 (tie / free), or -stake.
  int settle({
    required String gameId,
    required int stake,
    required Outcome outcome,
    required int opponents,
    required Difficulty difficulty,
  }) {
    final st = stats(gameId);
    st.played++;
    var delta = 0;
    switch (outcome) {
      case Outcome.win:
        st.won++;
        delta = winnings(stake, opponents, difficulty);
        _balance += stake + delta;
      case Outcome.tie:
        st.tied++;
        _balance += stake;
      case Outcome.loss:
        st.lost++;
        delta = -stake;
    }
    st.net += delta;
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
      _balance = j['balance'] as int? ?? startingBalance;
      _currency = CurrencyChoice.values.asNameMap()[j['currency']] ?? CurrencyChoice.pips;
      _theme = ThemeChoice.values.asNameMap()[j['theme']] ?? ThemeChoice.system;
      _partyId = j['party'] as String?;
      _pokerOdds = j['odds'] as bool? ?? true;
      _sound = j['sound'] as bool? ?? true;
      _volume = (j['volume'] as num?)?.toDouble() ?? 0.8;
      final left = j['left'] as Map<String, dynamic>? ?? {};
      left.forEach((k, v) {
        if (v is Map && v['g'] is String && v['s'] is int) {
          _leftGames[k] = (game: v['g'] as String, stake: v['s'] as int);
        }
      });
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
      'balance': _balance,
      'currency': _currency.name,
      'theme': _theme.name,
      'stats': {for (final e in _stats.entries) e.key: e.value.toJson()},
      'party': ?_partyId,
      if (!_pokerOdds) 'odds': false,
      if (!_sound) 'sound': false,
      'volume': _volume,
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
