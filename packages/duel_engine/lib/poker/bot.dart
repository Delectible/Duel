import 'dart:math';

import '../cards.dart';
import '../difficulty.dart';
import 'hand_eval.dart';
import 'poker_hand.dart';
import 'reads.dart';

extension on Difficulty {
  /// Monte Carlo deals per decision: more = a sharper read of its hand.
  int get simulations => const [80, 220, 450][index];

  /// How far off its read of its own hand can be (equity points).
  double get misread => const [0.14, 0.05, 0.0][index];

  /// How much it reads opponents' bets (narrowing their likely hands) and
  /// learns from what it has seen this game: 0 not at all, 1 fully.
  double get reading => const [0.0, 0.6, 1.0][index];

  /// Leaks on top of the style: plays too many hands, calls too much.
  double get leak => const [0.10, 0.03, 0.0][index];
}

/// How a bot bets: sizes as fractions of the pot. "Honest" players bet big
/// with good hands and small with bluffs (a tell you can learn); balanced
/// ones size the same either way.
enum Sizing { honest, balanced, wild, tiny, trappy, big }

/// What a bot's thinking time gives away.
enum Tell {
  /// Snaps strong hands, agonises over bluffs.
  classic,

  /// Same pace whatever it holds.
  steady,

  /// No pattern.
  random,

  /// Always quick.
  fast,

  /// Hollywood: tanks with monsters, snaps bluffs.
  reverse,
}

/// How a bot plays.
enum BotStyle {
  /// Plays too many hands, calls too much, bets big when it's strong.
  rookie(
    'Rookie',
    loose: 0.10,
    aggression: 0.30,
    bluff: 0.05,
    sticky: 0.30,
    cbet: 0.35,
    barrel: 0.20,
    checkRaise: 0.05,
    slowplay: 0.10,
    tiltProne: 0.6,
    adapt: 0.2,
    suspicion: 0.0,
    bullying: 0.0,
    limps: 0.45,
    sizing: Sizing.honest,
    tell: Tell.classic,
  ),

  /// Tight: few hands, bets them hard, rarely bluffs.
  rock(
    'Rock',
    loose: -0.18,
    aggression: 0.55,
    bluff: 0.03,
    sticky: 0.0,
    cbet: 0.50,
    barrel: 0.25,
    checkRaise: 0.10,
    slowplay: 0.10,
    tiltProne: 0.2,
    adapt: 0.5,
    suspicion: -0.05,
    bullying: 0.0,
    limps: 0.0,
    sizing: Sizing.honest,
    tell: Tell.steady,
  ),

  /// Solid and aggressive, balanced, adapts to you.
  shark(
    'Shark',
    loose: 0.02,
    aggression: 0.70,
    bluff: 0.14,
    sticky: 0.0,
    cbet: 0.70,
    barrel: 0.45,
    checkRaise: 0.20,
    slowplay: 0.15,
    tiltProne: 0.1,
    adapt: 1.0,
    suspicion: 0.05,
    bullying: 0.3,
    limps: 0.0,
    sizing: Sizing.balanced,
    tell: Tell.random,
  ),

  /// Raises and bluffs a lot, overbets, tilts easily.
  maniac(
    'Maniac',
    loose: 0.22,
    aggression: 0.90,
    bluff: 0.30,
    sticky: 0.10,
    cbet: 0.90,
    barrel: 0.60,
    checkRaise: 0.25,
    slowplay: 0.02,
    tiltProne: 0.8,
    adapt: 0.3,
    suspicion: 0.10,
    bullying: 0.4,
    limps: 0.0,
    sizing: Sizing.wild,
    tell: Tell.fast,
  ),

  /// By the book: solid, balanced, never tilts.
  grinder(
    'Grinder',
    loose: 0.0,
    aggression: 0.60,
    bluff: 0.10,
    sticky: 0.0,
    cbet: 0.65,
    barrel: 0.40,
    checkRaise: 0.15,
    slowplay: 0.10,
    tiltProne: 0.0,
    adapt: 0.9,
    suspicion: 0.0,
    bullying: 0.1,
    limps: 0.0,
    sizing: Sizing.balanced,
    tell: Tell.steady,
  ),

  /// Limps, calls, chases every draw, rarely raises.
  fish(
    'Fish',
    loose: 0.30,
    aggression: 0.15,
    bluff: 0.04,
    sticky: 0.55,
    cbet: 0.25,
    barrel: 0.10,
    checkRaise: 0.02,
    slowplay: 0.05,
    tiltProne: 0.5,
    adapt: 0.1,
    suspicion: 0.10,
    bullying: 0.0,
    limps: 0.80,
    sizing: Sizing.tiny,
    tell: Tell.random,
  ),

  /// Slow-plays big hands and loves the check-raise.
  trapper(
    'Trapper',
    loose: -0.02,
    aggression: 0.40,
    bluff: 0.08,
    sticky: 0.05,
    cbet: 0.45,
    barrel: 0.30,
    checkRaise: 0.50,
    slowplay: 0.55,
    tiltProne: 0.3,
    adapt: 0.6,
    suspicion: 0.0,
    bullying: 0.1,
    limps: 0.0,
    sizing: Sizing.trappy,
    tell: Tell.reverse,
  ),

  /// Leans on short stacks and timid players with big bets.
  bully(
    'Bully',
    loose: 0.12,
    aggression: 0.80,
    bluff: 0.20,
    sticky: 0.0,
    cbet: 0.80,
    barrel: 0.55,
    checkRaise: 0.20,
    slowplay: 0.05,
    tiltProne: 0.4,
    adapt: 0.6,
    suspicion: 0.0,
    bullying: 1.0,
    limps: 0.0,
    sizing: Sizing.big,
    tell: Tell.fast,
  ),

  /// Thinks everyone's bluffing: calls you down light.
  sheriff(
    'Sheriff',
    loose: 0.08,
    aggression: 0.35,
    bluff: 0.06,
    sticky: 0.20,
    cbet: 0.50,
    barrel: 0.25,
    checkRaise: 0.10,
    slowplay: 0.10,
    tiltProne: 0.5,
    adapt: 0.5,
    suspicion: 0.30,
    bullying: 0.0,
    limps: 0.10,
    sizing: Sizing.honest,
    tell: Tell.classic,
  );

  const BotStyle(
    this.label, {
    required this.loose,
    required this.aggression,
    required this.bluff,
    required this.sticky,
    required this.cbet,
    required this.barrel,
    required this.checkRaise,
    required this.slowplay,
    required this.tiltProne,
    required this.adapt,
    required this.suspicion,
    required this.bullying,
    required this.limps,
    required this.sizing,
    required this.tell,
  });

  final String label;

  /// Plays weaker hands (> 0) or only strong ones (< 0).
  final double loose;

  /// Chance to bet / raise a good hand rather than check / call it.
  final double aggression;

  /// Appetite for bets with nothing.
  final double bluff;

  /// Chance to call a bet it should fold ("I have to see it").
  final double sticky;

  /// As the pre-flop raiser: chance to bet the flop.
  final double cbet;

  /// Chance to keep betting the next street.
  final double barrel;

  /// Chance to check-raise a strong hand or a draw.
  final double checkRaise;

  /// Chance to check / call a monster to trap.
  final double slowplay;

  /// How much losing a big pot gets to it (0 never).
  final double tiltProne;

  /// How much it learns from what it sees you (and others) do.
  final double adapt;

  /// Extra willingness to call bets it suspects are bluffs.
  final double suspicion;

  /// Pressure on short stacks and timid players.
  final double bullying;

  /// Chance to just call the big blind instead of raising.
  final double limps;

  final Sizing sizing;
  final Tell tell;
}

/// A bot's move, and how long it seems to think about it: [tempo] 0 snap,
/// 1 tank (the table turns it into seconds; it may give the hand away).
class Decision {
  const Decision(this.move, this.tempo);
  final Move move;
  final double tempo;
}

/// A Hold'em bot. It weighs its hand against what each opponent likely
/// holds (narrowed by how they've played this hand and what the table has
/// seen them do), plays its position, follows through on plans (c-bets,
/// barrels, check-raises, slow-plays), sizes bets its own way, gets on
/// tilt after a bad loss and tightens up when stacks are short.
class PokerBot {
  PokerBot({required this.style, required this.difficulty, required this.rng});

  final BotStyle style;
  final Difficulty difficulty;
  final Random rng;

  Move decide(PokerHand hand, {TableReads? reads, List<int>? seats}) =>
      think(hand, reads: reads, seats: seats).move;

  /// The move for whoever is to act. [reads] is the table's memory and
  /// [seats] maps hand index -> table seat (both optional: without them
  /// the bot plays on what it sees in this hand alone).
  Decision think(PokerHand hand, {TableReads? reads, List<int>? seats}) {
    final c = _Spot(this, hand, reads, seats ?? [for (var i = 0; i < hand.players.length; i++) i]);
    final move = hand.street == Street.preflop ? c.preflop() : c.postflop();
    return Decision(move, c.tempo(move));
  }
}

/// One decision's working-out.
class _Spot {
  _Spot(this.bot, this.h, this.reads, this.seats)
    : i = h.toAct!,
      legal = h.legalMoves(),
      roll = bot.rng.nextDouble() {
    me = h.players[i];
    final mood = (reads?.players[seats[i]].tilt ?? 0) * style.tiltProne;
    tilt = mood;
    loose = style.loose + mood * 0.12 + bot.difficulty.leak;
    aggression = (style.aggression + mood * 0.25).clamp(0.0, 1.0);
    bluff = style.bluff + mood * 0.12;
    opponents = [
      for (var k = 0; k < h.players.length; k++)
        if (k != i && !h.players[k].folded) k,
    ];
    reading = bot.difficulty.reading;
  }

  final PokerBot bot;
  final PokerHand h;
  final TableReads? reads;
  final List<int> seats;
  final int i;
  final LegalMoves legal;
  final double roll;
  late final HandPlayer me;
  late final double tilt, loose, aggression, bluff, reading;
  late final List<int> opponents;

  /// Set by the decision for [tempo]: how good it felt about its hand
  /// (0 nothing .. 1 the nuts) and whether the move was a bluff.
  double strength = 0.5;
  bool bluffing = false;

  BotStyle get style => bot.style;
  Random get rng => bot.rng;
  int get bb => h.bigBlind;
  double get stackBB => (me.stack + me.bet) / bb;
  int get pot => h.pot;

  // --- Before the flop -------------------------------------------------------

  Move preflop() {
    final rank = preflopRank(me.hole);
    strength = 1 - rank;
    final n = h.players.length;
    final behind = _playersBehind();
    final facingRaise = h.currentBet > bb;
    final open = _openWidth(behind, n) * (1 + loose * 2.5);

    // Short: push or fold (bullies and maniacs shove wider and earlier).
    final shortAt = style.bullying > 0.5 || style == BotStyle.maniac ? 14 : 10;
    if (stackBB <= shortAt) {
      if (!facingRaise) {
        final push = min(0.75, open * 1.7 + 0.05);
        if (rank <= push || (behind <= 2 && roll < bluff)) return _shove(bluffed: rank > push);
        return legal.canCheck ? const Move.check() : const Move.fold();
      }
      final eq = _equity(sims: 140);
      strength = eq;
      final price = legal.callAmount / (pot + legal.callAmount);
      return eq >= price + _icmTax(legal.callAmount) - loose * 0.15 ? _shove() : _foldOrCheck();
    }

    if (!facingRaise) {
      final limpers = h.players.where((p) => p.bet == bb && p != me && !p.folded).length - 1;
      // Steal from tight blinds in late position.
      final steal = behind <= 2 ? _foldiness(_blindSeats()) * 0.15 * style.adapt * reading : 0.0;
      if (rank <= open + steal) {
        if (legal.callAmount > 0 && roll < style.limps) return const Move.call();
        final size = switch (style.sizing) {
          Sizing.wild => 2.0 + rng.nextDouble() * 3,
          Sizing.big => 3.5,
          Sizing.tiny => 2.0,
          Sizing.honest => 3.0,
          _ => 2.5,
        };
        return _raiseTo(((size + max(0, limpers)) * bb).round());
      }
      if (legal.canCheck) return const Move.check();
      // Limp along with something playable for a small price.
      if (legal.callAmount <= bb && rank <= open * 1.6 && roll < style.limps + loose) {
        return const Move.call();
      }
      if (behind <= 2 && roll < bluff * 0.8) {
        bluffing = true;
        return _raiseTo((2.5 * bb).round());
      }
      return const Move.fold();
    }

    // Facing a raise: what did the raiser open with?
    final raiser = _lastRaiser();
    final width = raiser == null ? 0.2 : _preflopWidth(raiser);
    final eq = _equity(sims: 160);
    strength = eq;
    final call = legal.callAmount;
    final price = call / (pot + call);
    final threeBetTo = h.currentBet * 3 + (pot - h.currentBet) ~/ 2;
    if (rank <= width * 0.3 && roll < aggression + 0.2) return _raiseTo(threeBetTo);
    if (rank > width * 0.3 && rank <= width * 1.2 && behind <= 3 && roll < bluff * 0.5) {
      bluffing = true;
      return _raiseTo(threeBetTo);
    }
    // Equity on paper overstates a call: out of position, dominated, more
    // to pay later. Closing the action from the big blind is cheapest.
    final realize = i == h.bigBlindIndex ? 0.05 : (behind > 0 ? 0.16 : 0.11);
    final needed =
        price + realize + _icmTax(call) - loose * 0.15 - style.sticky * 0.08 - _suspicion(raiser) * 0.05;
    if (eq >= needed) return const Move.call();
    return const Move.fold();
  }

  // --- After the flop --------------------------------------------------------

  Move postflop() {
    final read = classify(me.hole, h.board);
    final eq =
        (_equity(sims: bot.difficulty.simulations) + (rng.nextDouble() * 2 - 1) * bot.difficulty.misread)
            .clamp(0.0, 1.0);
    strength = eq;
    final multi = opponents.length;
    final valueEq = 0.52 + 0.07 * (multi - 1);
    final mySeat = seats[i];
    final cbetSpot = h.street == Street.flop && reads?.preflopAggressor == mySeat;
    final barrelSpot = reads != null && reads!.aggressor == mySeat && _previous(reads!.aggressorStreet);
    final foldEq = _foldiness(opponents.map((k) => seats[k]));
    final pressure = _pressure();
    final aggr = (aggression + pressure * 0.2).clamp(0.0, 1.0);
    final bluffy = bluff + pressure * 0.15;
    final checkedHere = me.lastAction?.label == ActionLabel.check;

    if (legal.canCheck) {
      if (eq >= valueEq + 0.12 && read.index >= Made.goodPair.index) {
        // A monster: sometimes trap (not on the river).
        if (h.street != Street.river && read.index >= Made.strong.index && roll < style.slowplay) {
          return const Move.check();
        }
        return _bet(value: true);
      }
      if (cbetSpot && multi <= 2 && roll < style.cbet + (_dry() ? 0.1 : 0)) {
        bluffing = eq < 0.4;
        return _bet(value: !bluffing, small: true);
      }
      if (barrelSpot &&
          (eq >= valueEq || read == Made.draw) &&
          roll < style.barrel + (read == Made.draw ? 0.2 : 0)) {
        bluffing = eq < 0.4;
        return _bet(value: !bluffing);
      }
      if (barrelSpot && eq < 0.3 && multi <= 2 && roll < style.barrel * (0.5 + foldEq)) {
        bluffing = true;
        return _bet(value: false);
      }
      if (multi <= 2 && eq < 0.35 && roll < bluffy * (0.5 + foldEq)) {
        bluffing = true;
        return _bet(value: false);
      }
      if (read == Made.draw && h.street != Street.river && roll < aggr * 0.35) {
        bluffing = true;
        return _bet(value: false, small: true);
      }
      if (eq >= valueEq && roll < aggr) return _bet(value: true, small: true);
      return const Move.check();
    }

    // Facing a bet.
    final call = legal.callAmount;
    final price = call / (pot + call);
    final bettor = _lastRaiser();
    // Before the river there's more to pay later.
    var needed =
        price -
        _suspicion(bettor) * 0.15 -
        loose * 0.1 +
        _icmTax(call) +
        (h.street == Street.river ? 0 : 0.06);
    if (read == Made.draw && h.street != Street.river && me.stack > call * 3) needed -= 0.06;
    if (eq >= 0.7 || (read.index >= Made.strong.index && eq >= 0.6)) {
      // Strong: raise it up (a trapper sometimes just calls to spring it later).
      if (h.street != Street.river && roll < style.slowplay * 0.6) return const Move.call();
      if (roll < aggr + (checkedHere ? style.checkRaise : 0)) return _raise(value: true);
      return const Move.call();
    }
    if (checkedHere && read == Made.draw && h.street != Street.river && roll < style.checkRaise * 0.6) {
      bluffing = true;
      return _raise(value: false);
    }
    if (multi == 1 && h.street != Street.river && eq < 0.3 && roll < bluffy * 0.25 * (0.5 + foldEq)) {
      bluffing = true;
      return _raise(value: false);
    }
    if (eq >= needed) return const Move.call();
    if (roll < style.sticky + bot.difficulty.leak * 2 &&
        call <= me.stack * 0.3 &&
        read.index >= Made.draw.index) {
      return const Move.call();
    }
    return const Move.fold();
  }

  // --- Sizes -----------------------------------------------------------------

  Move _bet({required bool value, bool small = false}) {
    final f = _fraction(value: value, small: small);
    final size = max(bb, (pot * f).round());
    return _raiseTo(legal.isBet ? size : h.currentBet + max(h.minRaise, size));
  }

  Move _raise({required bool value}) {
    final f = _fraction(value: value, small: false);
    return _raiseTo(h.currentBet * 2 + (pot * f * 0.6).round());
  }

  /// The bet as a fraction of the pot, the style's way.
  double _fraction({required bool value, required bool small}) {
    double between(double a, double b) => a + rng.nextDouble() * (b - a);
    final f = switch (style.sizing) {
      Sizing.honest => value ? between(0.7, 1.0) : between(0.3, 0.5),
      Sizing.balanced => between(0.5, 0.75),
      Sizing.wild => between(0.5, 1.6),
      Sizing.tiny => between(0.2, 0.4),
      Sizing.trappy => value ? between(0.3, 0.5) : between(0.65, 0.85),
      Sizing.big => between(0.8, 1.25),
    };
    return small && style.sizing != Sizing.wild ? f * 0.65 : f;
  }

  Move _raiseTo(int target) {
    if (!legal.canRaise) return legal.canCheck ? const Move.check() : const Move.call();
    // Round to the small blind, like a person stacking chips.
    final unit = h.smallBlind;
    var to = ((target / unit).round() * unit).clamp(legal.minRaiseTo, legal.maxRaiseTo);
    // Most of the stack in means all of it.
    if (to - me.bet > me.stack * 0.6) to = legal.maxRaiseTo;
    return Move.raiseTo(to);
  }

  Move _shove({bool bluffed = false}) {
    bluffing = bluffed;
    return legal.canRaise ? Move.raiseTo(legal.maxRaiseTo) : const Move.call();
  }

  Move _foldOrCheck() => legal.canCheck ? const Move.check() : const Move.fold();

  // --- Thinking time ---------------------------------------------------------

  double tempo(Move move) {
    final easy = move.kind == MoveKind.check && strength < 0.5;
    final big = !legal.canCheck && legal.callAmount >= (me.stack + legal.callAmount) * 0.5;
    var t = switch (style.tell) {
      Tell.classic => bluffing ? 0.85 : (strength > 0.7 ? 0.12 : 0.45),
      Tell.steady => move.kind == MoveKind.fold ? 0.15 : 0.45,
      Tell.random => rng.nextDouble(),
      Tell.fast => 0.1 + rng.nextDouble() * 0.25,
      Tell.reverse => strength > 0.7 ? 0.9 : (bluffing ? 0.15 : 0.4),
    };
    // Tells aren't perfect: a quarter of the time, anything goes.
    if (rng.nextDouble() < 0.25) t = rng.nextDouble();
    if (easy) t *= 0.5;
    if (big) t = min(1.0, t + 0.25);
    return t;
  }

  // --- Reading the table -----------------------------------------------------

  /// Players still to act after this one before the flop.
  int _playersBehind() {
    final n = h.players.length;
    if (h.headsUp) return i == h.button ? 1 : 0;
    final o = (i - h.button - 1) % n; // 0 = SB, 1 = BB, 2 = first to act, ...
    if (o == 0) return 1;
    if (o == 1) return 0;
    return (n - 1 - o) + 2;
  }

  static double _openWidth(int behind, int n) {
    if (n == 2) return behind == 1 ? 0.75 : 0.5;
    return switch (behind) {
      0 => 0.5,
      1 => 0.36,
      2 => 0.38,
      3 => 0.25,
      4 => 0.18,
      5 => 0.14,
      _ => 0.12,
    };
  }

  Iterable<int> _blindSeats() => [seats[h.smallBlindIndex], seats[h.bigBlindIndex]];

  int? _lastRaiser() {
    final r = reads;
    if (r != null && r.aggressor != null && r.aggressorStreet == h.street) {
      final k = seats.indexOf(r.aggressor!);
      if (k >= 0 && k != i) return k;
    }
    int? best;
    for (final k in opponents) {
      if (best == null || h.players[k].bet > h.players[best].bet) best = k;
    }
    return best;
  }

  /// How likely [who] (table seats) fold to a bet, from what's been seen.
  double _foldiness(Iterable<int> who) {
    final list = who.toList();
    if (list.isEmpty) return 0.45;
    var sum = 0.0;
    for (final s in list) {
      final r = reads?.players[s];
      final conf = r == null ? 0.0 : min(1.0, r.facedBets / 12) * style.adapt * reading;
      sum += 0.45 * (1 - conf) + (r?.foldToBetRate ?? 0.45) * conf;
    }
    return sum / list.length;
  }

  /// Extra reason to call [bettor] down: the style's suspicion, plus their
  /// bluffs seen at showdowns.
  double _suspicion(int? bettor) {
    var s = style.suspicion;
    if (bettor == null) return s;
    final r = reads?.players[seats[bettor]];
    if (r != null && r.aggressiveShowdowns > 0) {
      final conf = min(1.0, r.aggressiveShowdowns / 5) * style.adapt * reading;
      s += (r.bluffRate - 0.25) * conf;
    }
    return s;
  }

  /// Bullying: a short-stacked or timid opponent (heads up) invites
  /// pressure. 0 none .. 1 lots.
  double _pressure() {
    if (style.bullying == 0 || opponents.length != 1) return 0;
    final o = h.players[opponents.single];
    final short = (o.stack + o.bet) / bb < 15 ? 0.6 : 0.0;
    final timid = max(0.0, _foldiness([seats[opponents.single]]) - 0.45);
    return (short + timid) * style.bullying;
  }

  /// Tournament sense: calling off a lot with a stack to protect while
  /// someone shorter could go out first costs extra.
  double _icmTax(int call) {
    if (h.players.length < 3 || call < me.stack * 0.4) return 0;
    final shorter = h.players.any(
      (p) => p != me && p.stack + p.bet < (me.stack + me.bet) * 0.5 && p.stack > 0,
    );
    final bigStack = h.players.every((p) => p == me || p.stack + p.bet <= me.stack + me.bet);
    if (bigStack) return -0.02;
    return shorter ? 0.06 : 0.02;
  }

  bool _previous(Street? s) => s != null && s.index == h.street.index - 1;

  /// A board with nothing much going on (no pairs, no flush or straight
  /// draws): good for a cheap c-bet.
  bool _dry() {
    final b = h.board;
    final suits = <Suit, int>{};
    for (final c in b) {
      suits[c.suit] = (suits[c.suit] ?? 0) + 1;
    }
    final ranks = b.map((c) => c.rank).toList()..sort();
    final paired = ranks.toSet().length < ranks.length;
    final connected = ranks.length >= 3 && ranks.last - ranks.first <= 4;
    return !paired && !connected && suits.values.every((v) => v < 2);
  }

  // --- Ranges and equity -----------------------------------------------------

  /// How wide [k]'s pre-flop range is (fraction of hands, best first).
  double _preflopWidth(int k) {
    final seat = seats[k];
    final r = reads?.players[seat];
    final n = h.players.length;
    final conf = r == null ? 0.0 : min(1.0, r.hands / 25) * style.adapt * reading;
    final vpip = (n <= 3 ? 0.55 : 0.35) * (1 - conf) + (r?.vpipRate ?? 0) * conf;
    final pfr = 0.18 * (1 - conf) + (r?.pfrRate ?? 0) * conf;
    final acts = _preflopActs(k);
    final raises = acts.where(
      (l) => l == ActionLabel.raise || l == ActionLabel.bet || l == ActionLabel.allIn,
    );
    if (raises.length >= 2 || (raises.isNotEmpty && _raisesBefore(k) > 0)) return max(0.04, pfr * 0.35);
    if (raises.isNotEmpty) return max(0.06, pfr);
    if (acts.contains(ActionLabel.call)) return max(0.1, vpip);
    return 1.0;
  }

  List<ActionLabel> _preflopActs(int k) {
    final r = reads;
    if (r != null) {
      return [
        for (final a in r.actionsOf(seats[k]))
          if (a.street == Street.preflop) a.label,
      ];
    }
    final l = h.street == Street.preflop ? h.players[k].lastAction?.label : null;
    return l == null ? const [] : [l];
  }

  int _raisesBefore(int k) {
    final r = reads;
    if (r == null) return 0;
    var n = 0;
    for (final a in r.actions) {
      if (a.street != Street.preflop) break;
      if (a.seat == seats[k]) return n;
      if (a.label == ActionLabel.raise || a.label == ActionLabel.allIn) n++;
    }
    return n;
  }

  /// Weights over every two-card hand for opponent [k]: their pre-flop
  /// range, narrowed by how they've played since (bets keep strong hands,
  /// draws and their share of bluffs; calls drop the junk; checks drop
  /// some of the monsters). Null: any two cards.
  List<double>? _range(int k, Map<int, Made> made) {
    if (reading == 0) return null;
    final width = _preflopWidth(k);
    final seat = seats[k];
    final r = reads?.players[seat];
    final conf = r == null ? 0.0 : min(1.0, r.aggressiveShowdowns / 5) * style.adapt * reading;
    final bluffy = 0.25 * (1 - conf) + (r?.bluffRate ?? 0.25) * conf + style.suspicion * 0.5;
    // Their sizing tell, once seen: big bets mean strength (or don't).
    final tellConf = r == null ? 0.0 : min(1.0, r.bigBetsShown / 4) * style.adapt * reading;
    final bigHonest = r == null || r.bigBetsShown == 0 ? 0.5 : r.bigBetsStrong / r.bigBetsShown;
    final acts = <({ActionLabel label, bool big})>[];
    if (reads case final reads?) {
      for (final a in reads.actionsOf(seat)) {
        if (a.street != Street.preflop) acts.add((label: a.label, big: a.to > a.pot * 0.7));
      }
    } else if (h.players[k].lastAction case final l? when h.street != Street.preflop) {
      acts.add((label: l.label, big: l.amount > pot * 0.5));
    }
    final out = List<double>.filled(_combos.length, 0);
    for (var c = 0; c < _combos.length; c++) {
      final rank = _comboRank[c];
      var w = rank <= width ? 1.0 : exp(-(rank - width) / 0.07);
      if (h.board.isNotEmpty) {
        final m = made[c] ?? Made.air;
        for (final a in acts) {
          final strong = m.index >= Made.strong.index;
          w *= switch (a.label) {
            ActionLabel.bet || ActionLabel.raise || ActionLabel.allIn =>
              switch (m) {
                    Made.monster || Made.strong => 1.0,
                    Made.goodPair => 0.7,
                    Made.weakPair => 0.4,
                    Made.draw => 0.6,
                    Made.air => bluffy,
                  } *
                  (a.big
                      ? (strong ? 1 + (bigHonest - 0.5) * tellConf : 1 - (bigHonest - 0.5) * tellConf)
                      : 1.0),
            ActionLabel.call => switch (m) {
              Made.monster => 0.5,
              Made.air => 0.25,
              _ => 1.0,
            },
            ActionLabel.check => switch (m) {
              Made.monster => 0.45,
              Made.strong => 0.7,
              _ => 1.0,
            },
            _ => 1.0,
          };
        }
      }
      out[c] = w;
    }
    // Normal bots blend in a little of "anything".
    if (reading < 1) {
      for (var c = 0; c < out.length; c++) {
        out[c] = out[c] * reading + (1 - reading) * 0.3;
      }
    }
    return out;
  }

  double _equity({required int sims}) {
    final made = <int, Made>{};
    if (reading > 0 && h.board.isNotEmpty) {
      final dead = {...me.hole, ...h.board};
      for (var c = 0; c < _combos.length; c++) {
        final (a, b) = _combos[c];
        if (dead.contains(a) || dead.contains(b)) continue;
        made[c] = classify([a, b], h.board);
      }
    }
    final ranges = [for (final k in opponents) _range(k, made)];
    return equityVsRanges(me.hole, h.board, ranges, sims, rng);
  }
}

// --- Hand strength helpers (also used by the app's stats) -------------------

/// What a hand amounts to on a board.
enum Made { air, draw, weakPair, goodPair, strong, monster }

/// [hole] on [board] (3-5 cards): a quick read of how good it is.
Made classify(List<PlayingCard> hole, List<PlayingCard> board) {
  final v = evaluateHand([...hole, ...board]);
  final top = board.map((c) => c.rank).reduce(max);
  final holeRanks = hole.map((c) => c.rank).toSet();
  switch (v.category) {
    case HandCategory.straightFlush || HandCategory.quads || HandCategory.fullHouse:
      return Made.monster;
    case HandCategory.flush || HandCategory.straight:
      // Only if a hole card is part of it.
      return v.cards.any(hole.contains) ? Made.monster : Made.weakPair;
    case HandCategory.trips:
      return holeRanks.contains(v.ranks.first)
          ? (hole[0].rank == hole[1].rank ? Made.monster : Made.strong)
          : Made.weakPair;
    case HandCategory.twoPair:
      final both = v.ranks.take(2).where(holeRanks.contains).length;
      return both == 2 ? Made.strong : (both == 1 ? Made.goodPair : Made.weakPair);
    case HandCategory.pair:
      final pr = v.ranks.first;
      if (!holeRanks.contains(pr)) return _draw(hole, board) ? Made.draw : Made.air;
      final pocket = hole[0].rank == hole[1].rank;
      if (pocket && pr > top) return Made.strong; // overpair
      if (pr == top) return holeRanks.any((r) => r != pr && r >= 10) || pocket ? Made.strong : Made.goodPair;
      return _draw(hole, board) ? Made.draw : (pr >= _second(board) ? Made.goodPair : Made.weakPair);
    case HandCategory.highCard:
      return _draw(hole, board) ? Made.draw : Made.air;
  }
}

int _second(List<PlayingCard> board) {
  final r = board.map((c) => c.rank).toSet().toList()..sort((a, b) => b.compareTo(a));
  return r.length > 1 ? r[1] : r.first;
}

/// A flush draw or an open-ended straight draw using a hole card (not on
/// the river).
bool _draw(List<PlayingCard> hole, List<PlayingCard> board) {
  if (board.length >= 5) return false;
  final all = [...hole, ...board];
  for (final s in Suit.values) {
    if (all.where((c) => c.suit == s).length == 4 && hole.any((c) => c.suit == s)) return true;
  }
  final ranks = {for (final c in all) c.rank, if (all.any((c) => c.rank == 14)) 1};
  for (var lo = 1; lo <= 10; lo++) {
    final run = [for (var r = lo; r < lo + 4; r++) r];
    if (run.every(ranks.contains) &&
        run.any((r) => hole.any((c) => c.rank == r || (r == 1 && c.rank == 14)))) {
      return true;
    }
  }
  return false;
}

/// Cards still to come that would improve [hole] on [board] to a better
/// kind of hand using a hole card ("outs"), with the chance of hitting one
/// by the river. Null on the river or before the flop.
({int outs, double chance})? outs(List<PlayingCard> hole, List<PlayingCard> board) {
  if (board.length < 3 || board.length >= 5) return null;
  final now = evaluateHand([...hole, ...board]).category;
  final dead = {...hole, ...board};
  var n = 0;
  for (final c in PlayingCard.fullDeck) {
    if (dead.contains(c)) continue;
    final better = evaluateHand([...hole, ...board, c]).category;
    if (better.index <= now.index) continue;
    // Not if the board alone gets there (everyone has that).
    if (board.length == 4) {
      if (evaluateHand([...board, c]).category.index >= better.index) continue;
    } else if (better.index <= HandCategory.twoPair.index && board.any((b) => b.rank == c.rank)) {
      continue; // pairing the board helps everyone
    }
    // A pair of the board's low cards isn't worth counting.
    if (better == HandCategory.pair && c.rank < board.map((b) => b.rank).reduce(max)) continue;
    n++;
  }
  final unseen = 52 - dead.length;
  final chance = board.length == 3
      ? 1 - ((unseen - n) * (unseen - n - 1)) / (unseen * (unseen - 1))
      : n / unseen;
  return (outs: n, chance: chance);
}

// --- Pre-flop ranking --------------------------------------------------------

/// Every two-card hand.
final List<(PlayingCard, PlayingCard)> _combos = [
  for (var a = 0; a < 52; a++)
    for (var b = a + 1; b < 52; b++) (PlayingCard.fullDeck[a], PlayingCard.fullDeck[b]),
];

/// Each combo's place among all hands before the flop (0 best .. 1 worst).
final List<double> _comboRank = () {
  final scores = [for (final (a, b) in _combos) _chen(a, b)];
  final sorted = [...scores]..sort((x, y) => y.compareTo(x));
  final n = sorted.length;
  final firstAt = <double, int>{};
  for (var k = 0; k < n; k++) {
    firstAt.putIfAbsent(sorted[k], () => k);
  }
  final count = <double, int>{};
  for (final s in sorted) {
    count[s] = (count[s] ?? 0) + 1;
  }
  return [for (final s in scores) (firstAt[s]! + count[s]! / 2) / n];
}();

/// Where [hole] ranks among all starting hands: 0 = the best (Aces), 1 =
/// the worst (7-2 offsuit).
double preflopRank(List<PlayingCard> hole) => _comboRank[_comboIndex(hole[0], hole[1])];

int _comboIndex(PlayingCard x, PlayingCard y) {
  var a = PlayingCard.fullDeck.indexOf(x), b = PlayingCard.fullDeck.indexOf(y);
  if (a > b) (a, b) = (b, a);
  // Index of (a, b) in the triangle above.
  return a * 51 - a * (a - 1) ~/ 2 + (b - a - 1);
}

/// Bill Chen's quick score for a starting hand.
double _chen(PlayingCard x, PlayingCard y) {
  double value(int r) => switch (r) {
    14 => 10,
    13 => 8,
    12 => 7,
    11 => 6,
    _ => r / 2,
  };
  final hi = max(x.rank, y.rank), lo = min(x.rank, y.rank);
  if (hi == lo) return max(5, value(hi) * 2);
  var s = value(hi);
  if (x.suit == y.suit) s += 2;
  final gap = hi - lo - 1;
  s -= switch (gap) {
    0 => 0,
    1 => 1,
    2 => 2,
    3 => 4,
    _ => 5,
  };
  if (gap <= 1 && hi < 12) s += 1;
  return s.ceilToDouble();
}

// --- Equity ------------------------------------------------------------------

/// Chance [hole] wins against [opponents] random hands, given [board],
/// by dealing out [simulations] random finishes. Ties count as shared.
double equity(List<PlayingCard> hole, List<PlayingCard> board, int opponents, int simulations, Random rng) =>
    equityVsRanges(hole, board, List.filled(opponents, null), simulations, rng);

/// Like [equity], each opponent's hand drawn from their weighted range
/// (weights per two-card hand, as from the bot's reads; null = any two).
double equityVsRanges(
  List<PlayingCard> hole,
  List<PlayingCard> board,
  List<List<double>?> ranges,
  int simulations,
  Random rng,
) {
  if (ranges.isEmpty) return 1;
  final dead = {...hole, ...board};
  // Per opponent: the hands they could have, with running totals.
  final pools = <({List<int> combos, List<double> cum})?>[];
  for (final w in ranges) {
    if (w == null) {
      pools.add(null);
      continue;
    }
    final combos = <int>[], cum = <double>[];
    var total = 0.0;
    for (var c = 0; c < _combos.length; c++) {
      final (a, b) = _combos[c];
      if (w[c] <= 0 || dead.contains(a) || dead.contains(b)) continue;
      total += w[c];
      combos.add(c);
      cum.add(total);
    }
    pools.add(combos.isEmpty ? null : (combos: combos, cum: cum));
  }
  final deck = [
    for (final c in PlayingCard.fullDeck)
      if (!dead.contains(c)) c,
  ];
  var won = 0.0;
  for (var s = 0; s < simulations; s++) {
    final used = <PlayingCard>{};
    final hands = <List<PlayingCard>>[];
    for (final pool in pools) {
      List<PlayingCard>? got;
      if (pool != null) {
        for (var tries = 0; tries < 12 && got == null; tries++) {
          final x = rng.nextDouble() * pool.cum.last;
          var lo = 0, hi = pool.cum.length - 1;
          while (lo < hi) {
            final mid = (lo + hi) ~/ 2;
            if (pool.cum[mid] < x) {
              lo = mid + 1;
            } else {
              hi = mid;
            }
          }
          final (a, b) = _combos[pool.combos[lo]];
          if (!used.contains(a) && !used.contains(b)) got = [a, b];
        }
      }
      if (got == null) {
        final left = deck.where((c) => !used.contains(c)).toList();
        final a = left[rng.nextInt(left.length)];
        left.remove(a);
        got = [a, left[rng.nextInt(left.length)]];
      }
      used.addAll(got);
      hands.add(got);
    }
    final left = deck.where((c) => !used.contains(c)).toList();
    final need = 5 - board.length;
    for (var k = 0; k < need; k++) {
      final j = k + rng.nextInt(left.length - k);
      final t = left[k];
      left[k] = left[j];
      left[j] = t;
    }
    final full = [...board, ...left.take(need)];
    final mine = evaluateHand([...hole, ...full]).score;
    var ties = 0;
    var beaten = false;
    for (final o in hands) {
      final theirs = evaluateHand([...o, ...full]).score;
      if (theirs > mine) {
        beaten = true;
        break;
      }
      if (theirs == mine) ties++;
    }
    if (!beaten) won += 1 / (ties + 1);
  }
  return won / simulations;
}
