import 'dart:math';

import 'package:duel_engine/bank/bank.dart';
import 'package:duel_engine/bank/bank_bot.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('safe rolls: a 7 adds 70, doubles add their total', () {
    final g = BankGame(players: 3, rounds: 10);
    expect(g.roll(3, 4).kind, BankRollKind.safeSeven);
    expect(g.bank, 70);
    expect(g.roll(2, 2).kind, BankRollKind.add);
    expect(g.bank, 74);
    g.roll(5, 6);
    expect(g.bank, 85);
    // From the fourth roll: doubles double it, a 7 loses it.
    expect(g.roll(1, 1).kind, BankRollKind.doubled);
    expect(g.bank, 170);
    g.bankFor(1);
    expect(g.scores[1], 170);
    expect(g.roll(6, 1).kind, BankRollKind.bust);
    expect(g.roundOver, isTrue);
    expect(g.scores, [0, 170, 0]);
    g.nextRound();
    expect(g.bank, 0);
    expect(g.banked, [false, false, false]);
  });

  test('the round ends when everyone has banked; the roller skips the banked', () {
    final g = BankGame(players: 3, rounds: 1);
    g.roll(2, 3);
    expect(g.roller, 1);
    g.bankFor(1);
    expect(g.roller, 2);
    g.bankFor(0);
    g.bankFor(2);
    expect(g.roundOver, isTrue);
    expect(g.isOver, isTrue);
    expect(g.winners, [0, 1, 2]);
  });

  test('bots finish games and the styles all win some', () {
    final wins = <BankStyle, int>{};
    for (var seed = 0; seed < 400; seed++) {
      final rng = Random(seed);
      final styles = BankStyle.values;
      final g = BankGame(players: 3, rounds: 15);
      final bots = [
        for (var p = 0; p < 3; p++) BankBot(me: p, style: styles[p], difficulty: Difficulty.normal, rng: rng),
      ];
      while (!g.isOver) {
        if (g.roundOver) g.nextRound();
        g.roll(1 + rng.nextInt(6), 1 + rng.nextInt(6));
        for (final b in bots) {
          if (b.wantsToBank(g)) g.bankFor(b.me);
        }
        if (g.rolls > 200) fail('a round that never ends');
      }
      for (final w in g.winners) {
        wins.update(styles[w], (v) => v + 1, ifAbsent: () => 1);
      }
    }
    for (final s in BankStyle.values) {
      expect(wins[s] ?? 0, greaterThan(40), reason: '$s: $wins');
    }
  });
}
