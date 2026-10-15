import 'dart:math';

import '../difficulty.dart';
import '../cards.dart';
import 'hand_eval.dart';
import 'poker_hand.dart';

extension on Difficulty {
  /// Monte Carlo deals per decision: more = a sharper read of its hand.
  int get simulations => const [80, 250, 600][index];

  /// How far off its read of its own hand can be (equity points).
  double get misread => const [0.14, 0.06, 0.0][index];
}

/// How a bot plays.
enum BotStyle {
  /// Calls too much, rarely raises.
  rookie('Rookie', looseness: 0.10, aggression: 0.25, bluff: 0.03, sticky: 0.35),

  /// Tight: plays few hands, bets them when it does.
  rock('Rock', looseness: -0.08, aggression: 0.45, bluff: 0.02, sticky: 0.0),

  /// Solid and aggressive.
  shark('Shark', looseness: 0.0, aggression: 0.7, bluff: 0.10, sticky: 0.0),

  /// Raises and bluffs a lot.
  maniac('Maniac', looseness: 0.12, aggression: 0.85, bluff: 0.25, sticky: 0.10);

  const BotStyle(
    this.label, {
    required this.looseness,
    required this.aggression,
    required this.bluff,
    required this.sticky,
  });

  final String label;

  /// Plays weaker hands (> 0) or only strong ones (< 0).
  final double looseness;

  /// Chance to bet / raise a good hand rather than check / call it.
  final double aggression;

  /// Chance to bet with nothing.
  final double bluff;

  /// Chance to call a bet it should fold ("I have to see it").
  final double sticky;
}

/// Picks moves for one bot seat.
class PokerBot {
  PokerBot({required this.style, required this.difficulty, required this.rng});

  final BotStyle style;
  final Difficulty difficulty;
  final Random rng;

  Move decide(PokerHand hand) {
    final me = hand.players[hand.toAct!];
    final legal = hand.legalMoves();
    final opponents = hand.players.where((p) => p != me && !p.folded).length;
    final bb = hand.bigBlind;
    final pot = hand.pot;
    final call = legal.callAmount;

    final misread = difficulty.misread;
    final eq =
        (equity(me.hole, hand.board, opponents, difficulty.simulations, rng) +
                (rng.nextDouble() * 2 - 1) * misread)
            .clamp(0.0, 1.0);
    // 1.0 = an average hand against this many opponents.
    final strength = eq * (opponents + 1);
    final roll = rng.nextDouble();

    Move raiseTo(int target) {
      if (!legal.canRaise) return legal.canCheck ? const Move.check() : const Move.call();
      // Round sizes to the small blind, like a person stacking chips.
      final unit = hand.smallBlind;
      var to = ((target / unit).round() * unit).clamp(legal.minRaiseTo, legal.maxRaiseTo);
      // Don't leave a silly sliver behind: most of the stack in means all-in.
      if (to - me.bet > me.stack * 0.6) to = legal.maxRaiseTo;
      return Move.raiseTo(to);
    }

    // Short stack before the flop: push or fold.
    if (hand.street == Street.preflop && me.stack + me.bet <= 10 * bb) {
      if (strength > 1.25 - style.looseness) {
        return legal.canRaise ? Move.raiseTo(legal.maxRaiseTo) : const Move.call();
      }
      return legal.canCheck ? const Move.check() : const Move.fold();
    }

    if (legal.canCheck) {
      if (strength > 1.45 - style.looseness && roll < style.aggression) {
        // Value bet: half pot for good hands, up to the pot for monsters.
        final size = pot * (0.5 + 0.5 * min(1.0, strength - 1.45));
        return raiseTo(
          legal.isBet ? max(bb, size.round()) : hand.currentBet + max(hand.minRaise, size.round()),
        );
      }
      if (roll < style.bluff) return raiseTo(legal.isBet ? max(bb, (pot * 0.6).round()) : legal.minRaiseTo);
      return const Move.check();
    }

    final potOdds = call / (pot + call);
    final needed = potOdds - style.looseness * 0.5;
    if (eq < needed) {
      if (roll < style.sticky && call <= me.stack * 0.25) return const Move.call();
      if (roll < style.bluff * 0.4 && legal.canRaise) return raiseTo(hand.currentBet * 3);
      return const Move.fold();
    }
    if (strength > 1.8 - style.looseness && roll < style.aggression) {
      return raiseTo(hand.currentBet + max(hand.minRaise, (pot * 0.75).round()));
    }
    return const Move.call();
  }
}

/// Chance [hole] wins against [opponents] random hands, given [board],
/// by dealing out [simulations] random finishes. Ties count as shared.
double equity(List<PlayingCard> hole, List<PlayingCard> board, int opponents, int simulations, Random rng) {
  if (opponents == 0) return 1;
  final known = {...hole, ...board};
  final deck = [
    for (final c in PlayingCard.fullDeck)
      if (!known.contains(c)) c,
  ];
  final need = opponents * 2 + (5 - board.length);
  var won = 0.0;
  for (var s = 0; s < simulations; s++) {
    // Partial shuffle: only the cards we draw.
    for (var k = 0; k < need; k++) {
      final j = k + rng.nextInt(deck.length - k);
      final t = deck[k];
      deck[k] = deck[j];
      deck[j] = t;
    }
    final fullBoard = [...board, ...deck.sublist(opponents * 2, need)];
    final mine = evaluateHand([...hole, ...fullBoard]).score;
    var ties = 0;
    var beaten = false;
    for (var o = 0; o < opponents; o++) {
      final theirs = evaluateHand([deck[o * 2], deck[o * 2 + 1], ...fullBoard]).score;
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
