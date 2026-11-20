import 'dart:math';

import '../difficulty.dart';
import 'goofspiel.dart';

/// Picks a bid. Easy: roughly matches the prize, often off. Normal: matches
/// the prize's place among what's left, with some noise. Hard: also watches
/// what the others have left: wins a big prize as cheaply as it can, dumps
/// its lowest on prizes it can't or needn't win, and bluffs now and then.
class GopsBot {
  GopsBot({required this.me, required this.difficulty, Random? rng}) : _rng = rng ?? Random();

  final int me;
  final Difficulty difficulty;
  final Random _rng;

  int decide(Goofspiel g) {
    final hand = g.hands[me].toList()..sort();
    if (hand.length == 1) return hand.single;
    final worth = g.potWorth;
    // How this pot ranks against the prizes still to come (0 low .. 1 high).
    final rest = [...g.unseen, worth]..sort();
    final q = rest.length == 1 ? 1.0 : rest.indexOf(worth) / (rest.length - 1);
    final noise = switch (difficulty) {
      Difficulty.easy => 0.35,
      Difficulty.normal => 0.18,
      Difficulty.hard => 0.08,
    };
    int at(double f) => hand[((f.clamp(0.0, 1.0)) * (hand.length - 1)).round()];
    if (difficulty == Difficulty.hard) {
      final best = [
        for (var p = 0; p < g.players; p++)
          if (p != me) g.hands[p].reduce(max),
      ].reduce(max);
      final beats = hand.where((v) => v > best).toList();
      // A big pot we're sure to take: take it as cheaply as possible.
      if (q >= 0.6 && beats.isNotEmpty) return beats.first;
      // A small pot: throw the lowest card away (sometimes a surprise).
      if (q <= 0.3 && _rng.nextDouble() > 0.15) return hand.first;
    }
    final pick = q + (_rng.nextDouble() * 2 - 1) * noise;
    return at(pick);
  }
}
