import 'dart:math';

import '../difficulty.dart';
import 'farkle.dart';

/// How a bot pushes its luck.
enum FarkleStyle { careful, steady, reckless }

/// A bot's choice after a roll: which dice to keep, and whether to roll on.
class FarkleChoice {
  const FarkleChoice(this.keep, {required this.rollOn});
  final List<int> keep;
  final bool rollOn;
}

/// Picks dice and decides when to stop. It banks once the turn's points
/// pass a line that depends on how many dice it would roll (the fewer, the
/// likelier a Farkle: 1 die 67%, 2 dice 44%, 3 dice 28%, 4 dice 16%, 5 dice
/// 8%, 6 dice 2%). Normal and Hard keep fewer dice to roll more when it
/// pays; Hard also chases the leader and plays the last round to win.
class FarkleBot {
  FarkleBot({required this.me, required this.difficulty, required this.style, Random? rng})
    : _rng = rng ?? Random();

  final int me;
  final Difficulty difficulty;
  final FarkleStyle style;
  final Random _rng;

  static const _line = {1: 300, 2: 300, 3: 400, 4: 700, 5: 2000, 6: 1 << 30};

  double get _nerve => switch (style) {
    FarkleStyle.careful => 0.7,
    FarkleStyle.steady => 1.0,
    FarkleStyle.reckless => 1.6,
  };

  bool _rollsOn(FarkleGame g, int points, int dice) {
    final score = g.scores[me];
    if (score == 0 && points < g.entry) return true;
    final beat = g.toBeat;
    if (beat != null && g.closer != me) return score + points <= beat;
    var line = _line[dice]! * _nerve;
    if (difficulty == Difficulty.hard) {
      // Behind: push; near the target: take it.
      final leader = [
        for (var p = 0; p < g.players; p++)
          if (p != me) g.scores[p],
      ].fold(0, max);
      if (leader - score > 2000) line *= 1.3;
      if (score + points >= g.target) return false;
    }
    if (difficulty == Difficulty.easy) line *= 0.6 + _rng.nextDouble() * 0.9;
    return points < line;
  }

  FarkleChoice decide(FarkleGame g) {
    final dice = g.rolled;
    final (best, bestScore) = farkleBestKeep(dice);
    final left = dice.length - best.length;
    // Hot dice: keep everything, roll six again (unless the line is passed).
    if (left == 0) {
      return FarkleChoice(best, rollOn: _rollsOn(g, g.turnPoints + bestScore, 6));
    }
    final rollOn = _rollsOn(g, g.turnPoints + bestScore, left);
    if (rollOn && difficulty != Difficulty.easy) {
      // Rolling on: keep fewer dice when the points given up are small.
      final (few, fewScore) = farkleBestKeep(dice, fewest: true);
      final extra = best.length - few.length;
      if (extra > 0 && bestScore - fewScore <= 50 * extra + (difficulty == Difficulty.hard ? 50 : 0)) {
        return FarkleChoice(few, rollOn: true);
      }
    }
    return FarkleChoice(best, rollOn: rollOn);
  }
}
