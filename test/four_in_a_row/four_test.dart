import 'dart:math';

import 'package:duel/core/session/difficulty.dart';
import 'package:duel/games/four_in_a_row/engine/four_in_a_row.dart';
import 'package:flutter_test/flutter_test.dart';

FourInARow play(String cols) {
  final g = FourInARow();
  for (final ch in cols.split('')) {
    g.drop(int.parse(ch));
  }
  return g;
}

void main() {
  test('discs stack; four across, up or diagonal wins', () {
    expect(play('0101010').winner, 0, reason: 'four up column 0');
    expect(play('0011223').winner, 0, reason: 'four across the bottom');
    final diag = play('01122323433');
    expect(diag.winner, 0);
    expect(diag.winningLine, [(0, 0), (1, 1), (2, 2), (3, 3)]);
    final g = play('00');
    expect(g.height(0), 2);
    expect(g.turn, 0);
  });

  test('a full column refuses; a full board with no four is a draw', () {
    final g = play('000000');
    expect(g.canDrop(0), isFalse);
    expect(() => g.drop(0), throwsArgumentError);
    // A known drawn filling: columns in pairs so nobody lines up four.
    final d = FourInARow();
    const order = '01234560123456654321065432100123456012345665432106543210';
    for (final ch in order.split('')) {
      if (d.isOver) break;
      final c = int.parse(ch);
      if (d.canDrop(c)) d.drop(c);
    }
    expect(d.isOver, isTrue);
  });

  test('every bot takes a win and Normal+ blocks one', () {
    for (final diff in Difficulty.values) {
      final bot = RowBot(difficulty: diff, rng: Random(1));
      // Bot to move with three in a row on the bottom: 1 at cols 4,5,6.
      final g = FourInARow(first: 1);
      for (final c in [4, 0, 5, 0, 6, 1]) {
        g.drop(c);
      }
      expect(bot.decide(g), 3, reason: '${diff.label} takes the win');
      if (diff != Difficulty.easy) {
        final h = FourInARow();
        for (final c in [0, 6, 1, 6, 2]) {
          h.drop(c);
        }
        expect(bot.decide(h), 3, reason: '${diff.label} blocks');
      }
    }
  });

  test('Hard beats Easy and holds its own against Normal', () {
    final rng = Random(2);
    var hardVsEasy = 0, hardVsNormal = 0;
    for (var i = 0; i < 10; i++) {
      for (final (other, win) in [(Difficulty.easy, 0), (Difficulty.normal, 1)]) {
        final g = FourInARow(first: i % 2);
        final bots = [
          RowBot(difficulty: Difficulty.hard, rng: rng, me: 0),
          RowBot(difficulty: other, rng: rng, me: 1),
        ];
        while (!g.isOver) {
          g.drop(bots[g.turn].decide(g));
        }
        if (g.winner == 0) win == 0 ? hardVsEasy++ : hardVsNormal++;
      }
    }
    expect(hardVsEasy, greaterThanOrEqualTo(8));
    expect(hardVsNormal, greaterThanOrEqualTo(5));
  });

  test('Hard thinks fast enough for a phone', () {
    final g = play('3');
    final sw = Stopwatch()..start();
    RowBot(difficulty: Difficulty.hard, rng: Random(1)).decide(g);
    expect(sw.elapsedMilliseconds, lessThan(1500));
  });
}
