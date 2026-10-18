import 'package:duel/core/theme/toon.dart';
import 'package:duel/games/blitz/ui/blitz_screen.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:duel/core/table/table_bits.dart';

import '../screens.dart';

Widget app(int bots, {int seed = 1, bool wars = false}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: Toon.theme(),
  home: BlitzScreen(bots: bots, difficulty: Difficulty.normal, pace: 0.05, seed: seed, wars: wars),
);

bool has(Key k) => find.byKey(k).evaluate().isNotEmpty;

/// Castle cards you can tap now (what your picked-up card can do).
Finder liveCastle() => find.byWidgetPredicate(
  (w) =>
      w is GestureDetector &&
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('castle ') &&
      w.onTap != null,
);

/// Plays to the end by tapping like a person: Blitz when lit (first
/// castle), else a pair, else pick up each card in turn until one can do
/// something, and do it.
Future<void> playGame(WidgetTester tester, {Future<void> Function(int step)? onStep}) async {
  Future<void> tapHand(int i) =>
      tester.tapAt(tester.getTopLeft(find.byKey(Key('hand $i'))) + const Offset(8, 20));
  for (var i = 0; i < 30000; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    await onStep?.call(i);
    if (has(const Key('again'))) return;
    if (has(const Key('cancel blitz'))) {
      // The first castle still standing.
      for (var p = 1; p < 6 && has(const Key('cancel blitz')); p++) {
        if (has(Key('strip $p'))) {
          await tester.tap(find.byKey(Key('strip $p')));
          await tester.pump();
        }
      }
    } else if (has(const Key('blitz'))) {
      await tester.tap(find.byKey(const Key('blitz')));
    } else if (has(const Key('pair'))) {
      await tester.tap(find.byKey(const Key('pair')));
    } else if (has(const Key('discard'))) {
      await tapHand(0);
      await tester.pump();
      await tester.tap(find.byKey(const Key('discard')));
    } else if (has(const Key('pass'))) {
      await tester.tap(find.byKey(const Key('pass')));
    } else if (find.text('Pick up a card').evaluate().isNotEmpty) {
      for (var k = 0; has(Key('hand $k')); k++) {
        await tapHand(k);
        await tester.pump();
        if (liveCastle().evaluate().isNotEmpty) {
          // Overlapped cards: tap the visible left edge.
          await tester.tapAt(tester.getTopLeft(liveCastle().first) + const Offset(4, 12));
          break;
        }
        await tapHand(k); // does nothing: put it back
        await tester.pump();
      }
    }
  }
  final strip = tester.widget<CommentaryStrip>(find.byType(CommentaryStrip));
  debugPrint('STUCK: ${strip.text}');
  fail('game did not end');
}

void main() {
  for (final bots in [1, 3, 5]) {
    for (final MapEntry(key: phone, value: size) in phones.entries) {
      testWidgets('Blitz with $bots bots on $phone plays to the end', (tester) async {
        usePhone(tester, size);
        await tester.pumpWidget(app(bots, seed: bots, wars: bots == 3));
        await tester.pump(const Duration(milliseconds: 30));
        await shot(tester, 'blitz_${bots}bots_deal_$phone');
        var picked = false, lit = false, spoke = false;
        await playGame(
          tester,
          onStep: (i) async {
            if (!picked && liveCastle().evaluate().isNotEmpty) {
              picked = true;
              await shot(tester, 'blitz_${bots}bots_pick_$phone');
            }
            if (!spoke && find.byType(SpeechBubble).evaluate().isNotEmpty) {
              spoke = true;
              await tester.pump(const Duration(milliseconds: 300)); // popped in
              await shot(tester, 'blitz_${bots}bots_bubble_$phone');
            }
            if (!lit && has(const Key('cancel blitz'))) {
              lit = true;
              await shot(tester, 'blitz_${bots}bots_target_$phone');
            }
          },
        );
        await tester.pump(const Duration(milliseconds: 600));
        await shot(tester, 'blitz_${bots}bots_over_$phone');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
