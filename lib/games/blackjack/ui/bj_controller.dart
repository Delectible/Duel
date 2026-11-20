import 'dart:async';
import 'dart:math';

import 'package:duel_engine/blackjack/bj_bot.dart';
import 'package:duel_engine/blackjack/blackjack.dart';
import 'package:duel_engine/cards.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:flutter/foundation.dart';

import '../../../core/account/account.dart';
import '../../../core/avatars/faces.dart';
import '../../../core/sound/sound.dart';
import 'bj_tables.dart';
import 'bj_talk.dart';

enum BjPhase { betting, dealing, playing, dealer, paid }

/// A bot at the table: who, how it plays, its chips.
class BjSeat {
  BjSeat(this.persona, this.bot, this.chips);

  final Persona persona;

  /// Null = you.
  final BjBot? bot;
  int chips;

  /// Its bet this round (null = sitting this one out).
  int? bet;
}

/// Runs a blackjack table: you and up to five bots against the dealer.
/// Your bets come straight off your balance. Cards are played back from
/// the round's events one at a time, with pauses where it matters.
class BjController extends ChangeNotifier {
  BjController({
    required this.table,
    required int bots,
    required this.difficulty,
    required this.account,
    Random? rng,
    this.pace = 1,
  }) : _rng = rng ?? Random(),
       shoe = Shoe(rng ?? Random()) {
    final names = Persona.bots(bots, _rng);
    final you = (bots + 1) ~/ 2;
    for (var i = 0, b = 0; i <= bots; i++) {
      seats.add(i == you ? BjSeat(account.persona, null, 0) : _newBot(names[b++]));
    }
    youSeat = you;
    bet = table.min;
    _say(-1, dealerLine(BjTalk.hello, _rng));
  }

  final BjTable table;
  final Difficulty difficulty;
  final Account account;
  final double pace;
  final Random _rng;
  final Shoe shoe;

  static final dealer = Persona.bot('Dot', Look.shades);

  final List<BjSeat> seats = [];
  late final int youSeat;

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
    _timer = Timer(Duration(milliseconds: (ms * pace).round()), () {
      if (!_disposed) f();
    });
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
        if (i != youSeat) i,
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
    if (shoe.due) {
      shoe.shuffle();
      Sound.play(Sfx.shuffle);
      _say(-1, dealerLine(BjTalk.shuffle, _rng));
    }
    account.wager(bet);
    you.bet = bet;
    for (final (i, s) in seats.indexed) {
      if (i == youSeat) continue;
      final b = s.bot!.bet(min: table.min, max: table.max, chips: s.chips, trueCount: shoe.trueCount);
      s.bet = b >= table.min ? b : null;
      if (s.bet != null) s.chips -= s.bet!;
    }
    Sound.play(Sfx.chips);
    round = BjRound(shoe: shoe, bets: [for (final s in seats) s.bet]);
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
            account.wager(r.hands[seat][hand].bet);
            _botSays(BjTalk.youSplit, chance: 0.5);
          } else {
            seats[seat].chips -= r.hands[seat][hand].bet;
          }
        } else if (move == BjMove.double) {
          Sound.play(Sfx.chips);
          final extra = r.hands[seat][hand].bet ~/ 2;
          if (seat == youSeat) {
            account.wager(extra);
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

  /// Your move.
  void act(BjMove m) {
    if (!moves.contains(m)) return;
    round!.act(m);
    _notify();
    _playBack();
  }

  void _settle() {
    final r = round!;
    resultsUp = true;
    phase = BjPhase.paid;
    final staked = r.staked(youSeat);
    final net = r.net(youSeat);
    account.payout('blackjack', staked: staked, back: staked + net);
    lastNet = net;
    lastBlackjack = r.hands[youSeat].any((h) => h.result == BjResult.blackjack);
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
    _after(2600, _nextRound);
  }

  /// Back to betting; broke bots leave and someone new sits down.
  void _nextRound() {
    phase = BjPhase.betting;
    for (final s in seats) {
      s.bet = null;
    }
    for (var i = 0; i < seats.length; i++) {
      if (i == youSeat || seats[i].chips >= table.min) continue;
      final gone = seats[i].persona.name;
      final taken = {for (final s in seats) s.persona.name};
      final fresh = Persona.bots(6, _rng).firstWhere((p) => !taken.contains(p.name));
      seats[i] = _newBot(fresh);
      news = '$gone is out of chips and leaves. ${fresh.name} sits down.';
      _say(i, botLine(BjTalk.hello, _rng));
    }
    bet = min(bet, maxBet);
    if (bet < table.min) bet = min(table.min, maxBet);
    _notify();
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
