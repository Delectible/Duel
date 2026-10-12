import 'dart:math';

import 'package:duel/core/session/difficulty.dart';
import 'package:duel/games/four_in_a_row/ui/row_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// At real speed the bot thinks in a background isolate (tests elsewhere
/// run sped up, which skips it): it must still move.
void main() {
  for (final d in Difficulty.values) {
    test('${d.label} bot answers your move at real speed', () async {
      final c = RowController(difficulty: d, pace: 1, rng: Random(1));
      addTearDown(c.dispose);
      // Whoever starts, get to a point where the bot has to answer.
      for (var i = 0; i < 100 && c.game.turn != 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      final before = c.game.moves.length;
      c.drop(3);
      for (var i = 0; i < 100 && c.game.moves.length < before + 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(c.game.moves.length, before + 2, reason: 'the bot never moved');
      expect(c.thinking, isFalse);
    });
  }
}
