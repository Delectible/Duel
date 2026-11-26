import 'dart:math';

import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/liars/liars.dart';
import 'package:duel_engine/liars/liars_bot.dart';
import 'package:flutter_test/flutter_test.dart';

/// Liar's Dice: bids, calls, spot on, being knocked out; bots that know
/// the odds beat ones that guess.
void main() {
  LiarsGame rolled(List<List<int>> cups, {LiarsRules rules = const LiarsRules()}) {
    final g = LiarsGame(
      players: cups.length,
      rules: LiarsRules(dice: cups.first.length, onesWild: rules.onesWild, spotOn: rules.spotOn),
    );
    g.roll(cups);
    return g;
  }

  test('a bid must go up: more dice, or the same on a higher face', () {
    final g = rolled([
      [2, 3, 4],
      [5, 6, 1],
    ]);
    g.raise(0, const LiarsBid(2, 4));
    expect(g.beats(const LiarsBid(2, 3)), isFalse);
    expect(g.beats(const LiarsBid(2, 5)), isTrue);
    expect(g.beats(const LiarsBid(3, 2)), isTrue);
    expect(g.beats(const LiarsBid(2, 1)), isFalse, reason: 'ones are wild, not bid');
    expect(g.lowest(3), const LiarsBid(3, 3));
    expect(g.lowest(6), const LiarsBid(2, 6));
  });

  test('liar: a short bid costs the bidder, a good one the caller; ones are wild', () {
    final g = rolled([
      [4, 4, 1],
      [4, 2, 3],
    ]);
    g.raise(0, const LiarsBid(4, 4)); // 4, 4, wild, 4 = 4
    final r = g.challenge(1, LiarsCall.liar);
    expect(r.found, 4);
    expect(r.loser, 1);
    expect(g.counts, [3, 2]);
    expect(g.turn, 1, reason: 'the loser starts');
    expect(g.needsRoll, isTrue);
    g.roll([
      [6, 6, 6],
      [2, 2],
    ]);
    g.raise(1, const LiarsBid(3, 2));
    final r2 = g.challenge(0, LiarsCall.liar);
    expect(r2.loser, 1);
    expect(g.counts, [3, 1]);
  });

  test('spot on wins a die back, misses lose one; the last with dice wins', () {
    final g = rolled([
      [3, 3],
      [3, 5],
    ]);
    g.raise(0, const LiarsBid(3, 3));
    expect(g.challenge(1, LiarsCall.spotOn).gainer, isNull, reason: 'already full');
    g.roll([
      [3, 3],
      [3, 5],
    ]);
    g.raise(1, const LiarsBid(2, 5));
    expect(g.challenge(0, LiarsCall.spotOn).loser, 0);
    g.roll([
      [2],
      [2, 2],
    ]);
    g.raise(0, const LiarsBid(3, 3));
    g.challenge(1, LiarsCall.liar);
    expect(g.isOver, isTrue);
    expect(g.winner, 1);
    expect(g.outOrder, [0, 1]);
  });

  test('odds: at least / exactly', () {
    expect(LiarsGame.atLeast(0, 5, 1 / 3), 1);
    expect(LiarsGame.atLeast(6, 5, 1 / 3), 0);
    expect(LiarsGame.atLeast(1, 1, 1 / 6), closeTo(1 / 6, 1e-9));
    expect(LiarsGame.exactly(2, 4, 0.5), closeTo(6 / 16, 1e-9));
  });

  int play(List<Difficulty> levels, Random rng) {
    final n = levels.length;
    final g = LiarsGame(players: n, first: rng.nextInt(n));
    final reads = [for (var i = 0; i < n; i++) LiarsReads(n)];
    final bots = [
      for (var i = 0; i < n; i++)
        LiarsBot(
          me: i,
          difficulty: levels[i],
          style: LiarsStyle.values[(i + rng.nextInt(3)) % 3],
          rng: rng,
          reads: reads[i],
        ),
    ];
    for (var guard = 0; guard < 2000 && !g.isOver; guard++) {
      if (g.needsRoll) g.roll(g.rollFor(rng));
      final m = bots[g.turn].decide(g);
      if (m.bid != null) {
        g.raise(g.turn, m.bid!);
      } else {
        final r = g.challenge(g.turn, m.call!);
        for (final x in reads) {
          x.saw(r);
        }
      }
    }
    expect(g.isOver, isTrue);
    return g.winner!;
  }

  test('bots finish every game; Hard beats Easy', () {
    final rng = Random(7);
    var hard = 0;
    const games = 300;
    for (var i = 0; i < games; i++) {
      final hardSeat = i % 2;
      final w = play(
        hardSeat == 0 ? [Difficulty.hard, Difficulty.easy] : [Difficulty.easy, Difficulty.hard],
        rng,
      );
      if (w == hardSeat) hard++;
    }
    expect(hard, greaterThan(games * 0.6), reason: 'Hard won $hard of $games');
    for (var i = 0; i < 40; i++) {
      play([Difficulty.normal, Difficulty.hard, Difficulty.easy, Difficulty.normal, Difficulty.hard], rng);
    }
  });
}
