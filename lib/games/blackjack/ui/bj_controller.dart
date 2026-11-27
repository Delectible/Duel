import 'dart:async';
import 'dart:math';

import 'package:duel_engine/blackjack/bj_bot.dart';
import 'package:duel_engine/blackjack/blackjack.dart';
import 'package:duel_engine/cards.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:flutter/foundation.dart';

import '../../../core/account/account.dart';
import '../../../core/avatars/faces.dart';
import '../../../core/online/bj_service.dart';
import '../../../core/online/party.dart';
import '../../../core/sound/sound.dart';
import 'bj_tables.dart';
import 'bj_talk.dart';

part 'bj_online.dart';

enum BjPhase { betting, dealing, insurance, playing, dealer, paid }

/// A bot at the table: who, how it plays, its chips.
class BjSeat {
  BjSeat(this.persona, this.bot, this.chips) : open = false;

  /// An empty seat.
  BjSeat.empty() : persona = BjController.dealer, bot = null, chips = 0, open = true;

  final bool open;

  final Persona persona;

  /// Null = you.
  final BjBot? bot;
  int chips;

  /// Its bet this round (null = sitting this one out).
  int? bet;
}

/// Runs a blackjack table: five seats, you in the middle and bots coming
/// and going in the others against the dealer.
/// Your bets come straight off your balance. Cards are played back from
/// the round's events one at a time, with pauses where it matters.
class BjController extends ChangeNotifier {
  BjController({
    required this.table,
    required this.account,
    int bots = 2,
    Difficulty? difficulty,
    List<BjSitter?>? seated,
    this.rules = const BjRules(),
    Random? rng,
    this.pace = 1,
  }) : _rng = rng ?? Random(),
       difficulty = difficulty ?? table.difficulty,
       shoe = Shoe(rng ?? Random(), decks: rules.decks) {
    if (seated != null) {
      // The lobby's crowd: whoever's in the middle seat slides over for you.
      final at = [...seated];
      if (at[youSeat] != null) {
        final open = at.indexWhere((s) => s == null);
        if (open >= 0) at[open] = at[youSeat];
        at[youSeat] = null;
      }
      for (var i = 0; i < seatCount; i++) {
        seats.add(
          i == youSeat
              ? BjSeat(account.persona, null, 0)
              : at[i] == null
              ? BjSeat.empty()
              : _newBot(at[i]!.persona),
        );
      }
    } else {
      final names = Persona.bots(seatCount - 1, _rng);
      final others = [0, 1, 3, 4]..shuffle(_rng);
      final taken = others.take(min(bots, seatCount - 1)).toSet();
      for (var i = 0, b = 0; i < seatCount; i++) {
        seats.add(
          i == youSeat
              ? BjSeat(account.persona, null, 0)
              : taken.contains(i)
              ? _newBot(names[b++])
              : BjSeat.empty(),
        );
      }
    }
    bet = table.min;
    _say(-1, dealerLine(BjTalk.hello, _rng));
  }

  final BjTable table;
  final Difficulty difficulty;

  /// Your house rules.
  final BjRules rules;
  final Account account;
  final double pace;
  final Random _rng;
  final Shoe shoe;

  static final dealer = Persona.bot('Dot', Look.shades);

  /// Seats at the table: you always in the middle one.
  static const seatCount = 5;
  final List<BjSeat> seats = [];

  /// Your seat (the middle one at a table here; online, wherever you sat:
  /// the screen turns the table so you're in the middle).
  int get youSeat => 2;

  /// Bets come off your balance here; online the referee moves the pips.
  bool get _local => true;

  /// The shoe as shown.
  int get shoeLeft => shoe.left;
  int get shoeDecks => shoe.decks;
  double get decksLeft => shoe.decksLeft;

  /// Fresh shoes so far (the screen flashes "New shoe").
  int shuffles = 0;

  BjPhase phase = BjPhase.betting;

  /// Your bet for the next deal (starts as the last one).
  int bet = 0;

  BjRound? round;

  /// Cards shown so far, per seat per hand (the round's events are played
  /// back one at a time).
  List<List<int>> shown = [];
  int dealerShown = 0;
  bool holeUp = false;
  bool resultsUp = false;

  /// Rounds dealt (animation keys).
  int rounds = 0;

  /// What each seat (and the dealer, -1) is saying.
  final Map<int, String> speech = {};
  int speechId = 0;

  /// Your last round's change, for the pop.
  int? lastNet;
  bool lastBlackjack = false;

  /// A bot that left / joined (the commentary says so).
  String? news;

  var _cursor = 0;
  Timer? _timer;
  var _disposed = false;

  BjSeat get you => seats[youSeat];

  bool get yourTurn => phase == BjPhase.playing && round?.turn?.$1 == youSeat && _caughtUp;

  bool get _caughtUp => round == null || _cursor >= round!.events.length;

  int get balance => account.balance;

  /// The lowest table lets you bet on credit; the others need the pips.
  bool get credit => table == bjTables.first;

  int get maxBet => credit ? max(table.min, min(table.max, balance)) : min(table.max, balance);

  bool get canDeal => phase == BjPhase.betting && bet >= table.min && bet <= maxBet;

  List<BjMove> get moves =>
      yourTurn ? round!.moves(balance: credit ? max(balance, round!.current.bet) : balance) : const [];

  BjSeat _newBot(Persona p) {
    final style = BjStyle.values[_rng.nextInt(BjStyle.values.length)];
    return BjSeat(
      p,
      BjBot(style: style, difficulty: difficulty, rng: _rng),
      table.min * (20 + _rng.nextInt(40)),
    );
  }

  void _after(int ms, VoidCallback f) {
    _timer?.cancel();
    _next = f;
    // Skip: everything goes quickly until it's your move (or the round's
    // over).
    final wait = hurrying ? min(ms, 120) : ms;
    _timer = Timer(Duration(milliseconds: (wait * pace).round()), () {
      if (!_disposed) f();
    });
  }

  VoidCallback? _next;

  /// The skip button: the bots and the dealer play quickly until it's your
  /// move again or the round's over.
  bool hurrying = false;

  /// Others are playing (or the dealer is) and can be hurried along.
  bool get canHurry =>
      !hurrying && !yourTurn && (phase == BjPhase.playing || phase == BjPhase.dealer) && _next != null;

  void hurry() {
    if (!canHurry) return;
    hurrying = true;
    _after(80, _next!);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _say(int seat, String? text) {
    if (text == null) return;
    speech[seat] = text;
    speechId++;
  }

  /// A random bot (not you) says something about [t], now and then.
  void _botSays(BjTalk t, {double chance = 0.6, int? who}) {
    if (_rng.nextDouble() > chance) return;
    final bots = [
      for (var i = 0; i < seats.length; i++)
        if (i != youSeat && !seats[i].open) i,
    ];
    if (bots.isEmpty) return;
    _say(who ?? bots[_rng.nextInt(bots.length)], botLine(t, _rng));
  }

  // --- Betting ----------------------------------------------------------------

  void addChip(int v) {
    if (phase != BjPhase.betting) return;
    bet = min(bet + v, maxBet);
    Sound.play(Sfx.chips);
    _notify();
  }

  /// Held +/− presses in a row (they speed up), and when the last was.
  int _nudges = 0;
  DateTime _lastNudge = DateTime(0);

  /// One more (or less, [dir] −1) on the bet: ones at first; held down, the
  /// step grows (5, 10, 50, …, up to a tenth of the table's max) so big
  /// amounts come quickly, landing on round numbers.
  void nudge(int dir) {
    if (phase != BjPhase.betting) return;
    final now = DateTime.now();
    _nudges = now.difference(_lastNudge).inMilliseconds < 420 ? _nudges + 1 : 0;
    _lastNudge = now;
    final steps = [
      1,
      5,
      10,
      50,
      100,
      500,
      1000,
      5000,
      10000,
    ].where((s) => s == 1 || s * 10 <= table.max).toList();
    final step = steps[min(steps.length - 1, _nudges ~/ 5)];
    var next = bet + dir * step;
    if (step > 1) next = dir > 0 ? (next ~/ step) * step : ((next + step - 1) ~/ step) * step;
    next = next.clamp(0, maxBet);
    if (next == bet) return;
    bet = next;
    if (_nudges % 3 == 0) Sound.play(Sfx.chips, gain: 0.5);
    _notify();
  }

  void clearBet() {
    if (phase != BjPhase.betting) return;
    bet = 0;
    _notify();
  }

  void maxOut() {
    if (phase != BjPhase.betting) return;
    bet = maxBet;
    Sound.play(Sfx.chips);
    _notify();
  }

  /// Bets down, cards out.
  void deal() {
    if (!canDeal) return;
    news = null;
    if (shoe.due) _freshShoe();
    account.wager(bet);
    you.bet = bet;
    for (final (i, s) in seats.indexed) {
      if (i == youSeat || s.open) continue;
      final b = s.bot!.bet(min: table.min, max: table.max, chips: s.chips, trueCount: shoe.trueCount);
      s.bet = b >= table.min ? b : null;
      if (s.bet != null) s.chips -= s.bet!;
    }
    Sound.play(Sfx.chips);
    round = BjRound(shoe: shoe, bets: [for (final s in seats) s.bet], rules: rules);
    shown = [for (final h in round!.hands) List.filled(h.length, 0, growable: true)];
    dealerShown = 0;
    holeUp = false;
    resultsUp = false;
    lastNet = null;
    lastBlackjack = false;
    _cursor = 0;
    rounds++;
    phase = BjPhase.dealing;
    speech.clear();
    _notify();
    _after(300, _playBack);
  }

  // --- Playback -----------------------------------------------------------------

  /// Shows the next event, then waits a beat that suits it.
  void _playBack() {
    final r = round!;
    if (_cursor >= r.events.length) return _decide();
    final e = r.events[_cursor++];
    var wait = 0;
    switch (e) {
      case BjDealt(:final seat, :final hand):
        if (seat < 0) {
          dealerShown++;
          // Dealer draws after the hole card: slow, more so when it's close.
          wait = phase == BjPhase.dealer
              ? (r.dealerTotal >= 17 && dealerShown == r.dealer.length ? 1000 : 950)
              : 380;
          if (phase == BjPhase.dealer && bjTotal(r.dealer.take(dealerShown).toList()).total >= 12) {
            wait += 250;
          }
        } else {
          shown[seat][hand]++;
          wait = phase == BjPhase.dealing ? 380 : 600;
        }
        Sound.play(Sfx.deal);
      case BjMoved(:final seat, :final hand, :final move):
        if (move == BjMove.split) {
          shown[seat]
            ..[hand] = 1
            ..insert(hand + 1, 1);
          Sound.play(Sfx.chips);
          if (seat == youSeat) {
            if (_local) account.wager(r.hands[seat][hand].bet);
            _botSays(BjTalk.youSplit, chance: 0.5);
          } else {
            seats[seat].chips -= r.hands[seat][hand].bet;
          }
        } else if (move == BjMove.surrender) {
          Sound.play(Sfx.fall);
          if (seat == youSeat) {
            _say(-1, 'Half back to you. Wise, maybe.');
          } else {
            _botSays(BjTalk.bust, chance: 0.5, who: seat);
          }
        } else if (move == BjMove.double) {
          Sound.play(Sfx.chips);
          final extra = r.hands[seat][hand].bet ~/ 2;
          if (seat == youSeat) {
            if (_local) account.wager(extra);
            Sound.play(Sfx.tension);
            _botSays(BjTalk.youDouble, chance: 0.6);
          } else {
            seats[seat].chips -= extra;
          }
        }
        wait = 250;
      case BjBusted(:final seat):
        if (seat < 0) {
          _say(-1, dealerLine(BjTalk.dealerBust, _rng));
          _botSays(BjTalk.dealerBust, chance: 0.8);
          Sound.play(Sfx.clash);
        } else {
          Sound.play(seat == youSeat ? Sfx.loseSmall : Sfx.fall);
          if (seat != youSeat) _botSays(BjTalk.bust, chance: 0.7, who: seat);
        }
        wait = 650;
      case BjBlackjack(:final seat):
        if (seat < 0) {
          dealerShown = 2;
          holeUp = true;
          _say(-1, dealerLine(BjTalk.dealerBlackjack, _rng));
          _botSays(BjTalk.dealerBlackjack, chance: 0.8);
          Sound.play(Sfx.loseMedium);
          wait = 1300;
        } else if (seat == youSeat) {
          Sound.play(Sfx.winMedium);
          _say(-1, dealerLine(BjTalk.youBlackjack, _rng));
          _botSays(BjTalk.youBlackjack, chance: 0.6);
          wait = 900;
        } else {
          _botSays(BjTalk.blackjack, chance: 0.9, who: seat);
          wait = 600;
        }
      case BjInsuranceOffered():
        phase = BjPhase.insurance;
        _say(-1, 'Ace showing. Insurance, anyone?');
        Sound.play(Sfx.tension, gain: 0.6);
        _notify();
        _insuranceOffered();
        return;
      case BjInsured(:final seat, :final amount):
        Sound.play(Sfx.chips);
        if (seat == youSeat) {
          if (_local) account.wager(amount);
        } else {
          seats[seat].chips -= amount;
        }
        wait = 300;
      case BjHoleShown():
        if (!holeUp) {
          // The moment of truth: a pause, then the hole card turns.
          phase = BjPhase.dealer;
          _notify();
          final big = r.staked(youSeat) >= table.min * 4 || r.hands[youSeat].any((h) => h.doubled);
          _after(big ? 1100 : 700, () {
            holeUp = true;
            Sound.play(Sfx.place);
            if (big) Sound.play(Sfx.tension);
            _notify();
            _after(900, _playBack);
          });
          return;
        }
        wait = 200;
      case BjSettled():
        _settle();
        return;
    }
    // Online the bots have already played: their cards go by quicker.
    final who = _seatOf(e);
    if (!_local && phase != BjPhase.dealing && who != null && who >= 0 && who != youSeat) {
      wait = (wait * 0.45).round();
    }
    _notify();
    _after(wait, _playBack);
  }

  /// Caught up with the round: whose move is it?
  void _decide() {
    final r = round!;
    final t = r.turn;
    if (t == null) return; // the dealer's events follow
    phase = BjPhase.playing;
    if (t.$1 == youSeat) {
      hurrying = false;
      Sound.play(Sfx.yourTurn, gain: 0.7);
      _notify();
      return;
    }
    _notify();
    final s = seats[t.$1];
    final h = r.current;
    _after(650 + _rng.nextInt(700), () {
      final allowed = r.moves(balance: s.chips);
      r.act(s.bot!.decide(h, r.upCard, allowed));
      _playBack();
    });
  }

  /// Insurance on offer and you're in the round.
  bool get canInsure => phase == BjPhase.insurance && you.bet != null && round!.insuring;

  /// What insurance costs you (half your bet).
  int get insuranceCost => (you.bet ?? 0) ~/ 2;

  /// Can you cover insurance (the lowest table lends you the pips).
  bool get canAffordInsurance => credit || balance >= insuranceCost;

  /// Your answer to insurance (the bots answer for themselves), then the
  /// dealer peeks.
  void insure(bool yes) {
    final r = round;
    if (r == null || !r.insuring || phase != BjPhase.insurance) return;
    final buyers = <int>{
      if (yes && you.bet != null && canAffordInsurance && insuranceCost > 0) youSeat,
      for (final (i, s) in seats.indexed)
        if (i != youSeat && s.bet != null && s.chips >= s.bet! ~/ 2 && s.bot!.insure(shoe.trueCount)) i,
    };
    r.insure(buyers);
    phase = BjPhase.dealing;
    speech.remove(-1);
    _notify();
    _after(250, _playBack);
  }

  /// Your move.
  void act(BjMove m) {
    if (!moves.contains(m)) return;
    round!.act(m);
    _notify();
    _playBack();
  }

  void _settle() {
    hurrying = false;
    final r = round!;
    resultsUp = true;
    phase = BjPhase.paid;
    final staked = r.staked(youSeat);
    final net = r.net(youSeat);
    _paid(staked, net);
    lastNet = net;
    lastBlackjack = r.hands[youSeat].any((h) => h.result == BjResult.blackjack);
    if (r.hands[youSeat].isNotEmpty) account.bjRound(blackjack: lastBlackjack, net: net);
    for (final (i, s) in seats.indexed) {
      if (i == youSeat || s.bet == null) continue;
      s.chips += r.staked(i) + r.net(i);
    }
    final big = table.min * 4;
    if (net >= big || lastBlackjack && net > 0) {
      Sound.play(Sfx.winBig);
      _botSays(BjTalk.bigWin, chance: 0.7);
    } else if (net > 0) {
      Sound.play(Sfx.winSmall);
    } else if (net <= -big) {
      Sound.play(Sfx.loseBig);
      _botSays(BjTalk.bigLoss, chance: 0.6);
    } else if (net < 0) {
      Sound.play(Sfx.loseSmall);
    } else if (r.hands[youSeat].isNotEmpty) {
      _say(-1, dealerLine(BjTalk.push, _rng));
    }
    // A bot winning without anything said yet.
    if (speech.isEmpty) {
      for (final (i, _) in seats.indexed) {
        if (i != youSeat && r.hands[i].isNotEmpty && r.net(i) > 0) {
          _botSays(BjTalk.win, chance: 0.4, who: i);
          break;
        }
      }
    }
    _notify();
    _afterRound();
  }

  static int? _seatOf(BjEvent e) => switch (e) {
    BjDealt(:final seat) || BjMoved(:final seat) || BjBusted(:final seat) => seat,
    _ => null,
  };

  /// Insurance is on offer: you decide (Insurance / No); sitting out, the
  /// bots just do.
  void _insuranceOffered() {
    if (you.bet == null) _after(900, () => insure(false));
  }

  /// Your round's result: the pips (here; online only the stats).
  void _paid(int staked, int net) => account.payout('blackjack', staked: staked, back: staked + net);

  /// After the round's shown: the next one (online: the referee's).
  void _afterRound() => _after(2600, _nextRound);

  /// Standing up from the table (online: tells the referee).
  Future<void> leaveTable() async {}

  /// Back to betting; broke bots leave and someone new sits down.
  void _nextRound() {
    phase = BjPhase.betting;
    speech.clear();
    for (final s in seats) {
      s.bet = null;
    }
    final told = <String>[];
    // The broke leave; now and then someone cashes out.
    for (var i = 0; i < seats.length; i++) {
      final s = seats[i];
      if (i == youSeat || s.open) continue;
      final broke = s.chips < table.min;
      if (!broke && _rng.nextDouble() > 0.07) continue;
      told.add(broke ? '${s.persona.name} is out of chips and leaves.' : '${s.persona.name} cashes out.');
      _say(i, botLine(BjTalk.leaving, _rng));
      seats[i] = BjSeat.empty();
      // One goes at a time.
      if (!broke) break;
    }
    // Someone new sits down in an empty seat.
    final open = [
      for (var i = 0; i < seats.length; i++)
        if (seats[i].open && !speech.containsKey(i)) i,
    ];
    final seated = seats.where((s) => !s.open).length - 1;
    if (open.isNotEmpty && _rng.nextDouble() < (seated == 0 ? 0.5 : 0.18)) {
      final i = open[_rng.nextInt(open.length)];
      final taken = {for (final s in seats) s.persona.name};
      final fresh = Persona.bots(
        8,
        _rng,
      ).firstWhere((p) => !taken.contains(p.name), orElse: () => Persona.bots(1, _rng).first);
      seats[i] = _newBot(fresh);
      told.add('${fresh.name} sits down.');
      _say(i, botLine(BjTalk.hello, _rng));
    }
    // The cut card came out: shuffle now, before the bets.
    if (shoe.due) {
      _freshShoe();
      told.add(
        'Cut card\'s out: a fresh shoe of ${shoe.decks} ${shoe.decks == 1 ? 'deck' : 'decks'}. The count starts again.',
      );
    }
    news = told.isEmpty ? null : told.join(' ');
    bet = min(bet, maxBet);
    if (bet < table.min) bet = min(table.min, maxBet);
    _notify();
  }

  void _freshShoe() {
    shoe.shuffle();
    shuffles++;
    Sound.play(Sfx.shuffle);
    _say(-1, dealerLine(BjTalk.shuffle, _rng));
  }

  /// Leaving mid-hand loses what's on the table.
  bool get midHand => phase != BjPhase.betting && phase != BjPhase.paid;

  // --- What it looks like -------------------------------------------------------

  List<PlayingCard> cardsShown(int seat, int hand) {
    final h = round!.hands[seat][hand];
    return h.cards.take(shown[seat][hand]).toList();
  }

  List<PlayingCard> get dealerCards => round == null ? const [] : round!.dealer.take(dealerShown).toList();

  /// "17", "soft 18", "Bust", "BJ".
  String totalLabel(List<PlayingCard> cards, {bool fromSplit = false}) {
    if (cards.isEmpty) return '';
    final t = bjTotal(cards);
    if (cards.length == 2 && t.total == 21 && !fromSplit) return 'Blackjack';
    if (t.total > 21) return 'Bust ${t.total}';
    return t.soft && t.total < 21 ? 'Soft ${t.total}' : '${t.total}';
  }

  String _name(int i) => i == youSeat ? 'You' : seats[i].persona.name;

  String commentary() {
    final r = round;
    switch (phase) {
      case BjPhase.betting:
        final n = news;
        final base = bet < table.min
            ? 'Place a bet: ${account.money(table.min)} to ${account.money(table.max)}.'
            : 'Betting ${account.money(bet)}. Tap Deal, or change it with the chips.';
        return n == null ? base : '$n $base';
      case BjPhase.dealing:
        return 'Dealing…';
      case BjPhase.insurance:
        return canInsure
            ? 'The dealer shows an Ace. Insurance costs ${account.money(insuranceCost)} and pays 2 to 1 if the '
                  'dealer has blackjack.'
            : 'Insurance?';
      case BjPhase.playing:
        final t = r!.turn;
        if (t == null) return 'Dealer\'s turn…';
        if (t.$1 == youSeat) {
          final h = r.current;
          final split = r.hands[youSeat].length > 1
              ? ' (hand ${t.$2 + 1} of ${r.hands[youSeat].length})'
              : '';
          return 'Your move$split: ${totalLabel(h.cards, fromSplit: h.fromSplit)} against the dealer\'s '
              '${bjValue(r.upCard) == 11 ? 'Ace' : bjValue(r.upCard)}. Hit or stand?';
        }
        return '${_name(t.$1)} is thinking…';
      case BjPhase.dealer:
        if (!holeUp) return 'The dealer turns over the hole card…';
        final d = bjTotal(dealerCards).total;
        return d < 17
            ? 'Dealer has $d: drawing to 17…'
            : (d > 21 ? 'Dealer busts with $d!' : 'Dealer stands on $d.');
      case BjPhase.paid:
        final net = lastNet ?? 0;
        if (r!.hands[youSeat].isEmpty) return 'Round over.';
        if (lastBlackjack && net > 0) return 'Blackjack! You win ${account.money(net)}.';
        if (net > 0) return 'You win ${account.money(net)}!';
        if (net < 0) return 'You lose ${account.money(-net)}.';
        return 'Push: your bet comes back.';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
