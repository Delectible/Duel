import 'dart:math';

import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/goofspiel/goofspiel.dart';
import 'package:duel_engine/goofspiel/gops_bot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('highest bid takes the prize; a tie carries it to the next winner', () {
    final g = Goofspiel(players: 2, prizeOrder: [for (var v = 13; v >= 1; v--) v]);
    expect(g.prize, 13);
    expect(g.bid(0, 13), isNull);
    final r = g.bid(1, 12)!;
    expect(r.winner, 0);
    expect(g.scores, [13, 0]);
    // A tie on the 12: it waits; the 11 joins it.
    expect(g.bid(0, 5), isNull);
    expect(g.bid(1, 5)!.winner, isNull);
    expect(g.pot, [12, 11]);
    g.bid(0, 1);
    final r2 = g.bid(1, 2)!;
    expect(r2.winner, 1);
    expect(r2.worth, 23);
    expect(g.scores, [13, 23]);
    expect(() => g.bid(0, 13), throwsStateError, reason: 'used up');
  });

  test('a game runs to the end: 91 points shared out (a last tie throws its prize away)', () {
    for (var seed = 0; seed < 50; seed++) {
      final rng = Random(seed);
      final n = 2 + seed % 2;
      final g = Goofspiel(players: n, rng: rng);
      final bots = [
        for (var p = 0; p < n; p++) GopsBot(me: p, difficulty: Difficulty.values[seed % 3], rng: rng),
      ];
      while (!g.isOver) {
        for (var p = 0; p < n; p++) {
          g.bid(p, bots[p].decide(g));
        }
      }
      expect(g.scores.fold(0, (a, b) => a + b) + g.lost, 91);
      expect(g.hands.every((h) => h.isEmpty), isTrue);
    }
  });

  test('hard beats easy more often than not', () {
    var hard = 0, easy = 0;
    for (var seed = 0; seed < 300; seed++) {
      final rng = Random(seed);
      final g = Goofspiel(players: 2, rng: rng);
      final bots = [
        GopsBot(me: 0, difficulty: Difficulty.hard, rng: rng),
        GopsBot(me: 1, difficulty: Difficulty.easy, rng: rng),
      ];
      while (!g.isOver) {
        g.bid(0, bots[0].decide(g));
        g.bid(1, bots[1].decide(g));
      }
      if (g.scores[0] > g.scores[1]) hard++;
      if (g.scores[1] > g.scores[0]) easy++;
    }
    expect(hard, greaterThan(easy));
    // ...but not hopeless for the easy one.
    expect(easy, greaterThan(30));
  });
}
