import 'dart:math';

import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/farkle/farkle.dart';
import 'package:duel_engine/farkle/farkle_bot.dart';
import 'package:flutter_test/flutter_test.dart';

/// Farkle: scoring, keeping, hot dice, Farkles, the last round.
void main() {
  test('scoring', () {
    expect(farkleScore([1]), 100);
    expect(farkleScore([5, 5]), 100);
    expect(farkleScore([2]), isNull);
    expect(farkleScore([2, 2, 2]), 200);
    expect(farkleScore([1, 1, 1]), 1000);
    expect(farkleScore([4, 4, 4, 4]), 1000);
    expect(farkleScore([6, 6, 6, 6, 6, 6]), 3000);
    expect(farkleScore([1, 2, 3, 4, 5, 6]), 1500);
    expect(farkleScore([2, 2, 3, 3, 6, 6]), 1500);
    expect(farkleScore([3, 3, 3, 4, 4, 4]), 2500);
    expect(farkleScore([3, 3, 3, 1, 5]), 450);
    expect(farkleBest([2, 3, 4, 6, 6, 2]), 0);
    expect(farkleBest([1, 5, 2, 3, 3, 3]), 450);
    expect(farkleBestKeep([1, 5, 2, 4], fewest: true).$1, [0]);
  });

  test('a turn: keep, roll on, hot dice, bank; a Farkle loses the turn', () {
    final g = FarkleGame(players: 2);
    g.roll([1, 1, 1, 5, 5, 5]);
    g.keep([0, 1, 2, 3, 4, 5]);
    expect(g.turnPoints, 2500, reason: "two triples");
    expect(g.hotDice, isTrue);
    g.roll([1, 2, 3, 4, 6, 6]);
    expect(g.keepScore([1, 2]), isNull);
    g.keep([0]);
    expect(g.diceLeft, 5);
    g.bank();
    expect(g.scores, [2600, 0]);
    expect(g.turn, 1);
    g.roll([2, 3, 4, 6, 6, 2]);
    expect(g.farkled, isTrue);
    g.pass();
    expect(g.scores, [2600, 0]);
    expect(g.turn, 0);
  });

  test('reaching the target gives everyone else one last turn', () {
    final g = FarkleGame(players: 3, target: 1000);
    g.roll([1, 1, 1, 2, 3, 4]);
    g.keep([0, 1, 2]);
    g.bank();
    expect(g.closer, 0);
    expect(g.isOver, isFalse);
    g.roll([2, 3, 4, 6, 6, 2]);
    g.pass();
    g.roll([5, 2, 3, 4, 6, 6]);
    g.keep([0]);
    g.bank();
    expect(g.isOver, isTrue);
    expect(g.winners, [0]);
  });

  int play(List<Difficulty> levels, Random rng) {
    final n = levels.length;
    final g = FarkleGame(players: n, first: rng.nextInt(n));
    final bots = [
      for (var i = 0; i < n; i++)
        FarkleBot(me: i, difficulty: levels[i], style: FarkleStyle.values[rng.nextInt(3)], rng: rng),
    ];
    for (var guard = 0; guard < 20000 && !g.isOver; guard++) {
      g.roll(g.rollFor(rng));
      if (g.farkled) {
        g.pass();
        continue;
      }
      final c = bots[g.turn].decide(g);
      g.keep(c.keep);
      if (!c.rollOn && g.canBank) g.bank();
    }
    expect(g.isOver, isTrue);
    return g.winners.first;
  }

  test('bots finish; Hard beats Easy', () {
    final rng = Random(3);
    var hard = 0;
    const games = 300;
    for (var i = 0; i < games; i++) {
      final seat = i % 2;
      if (play(seat == 0 ? [Difficulty.hard, Difficulty.easy] : [Difficulty.easy, Difficulty.hard], rng) ==
          seat) {
        hard++;
      }
    }
    expect(hard, greaterThan(games * 0.55), reason: 'Hard won $hard of $games');
  });
}
