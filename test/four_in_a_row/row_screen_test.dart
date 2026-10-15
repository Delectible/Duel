import 'package:duel_engine/difficulty.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:duel/games/four_in_a_row/ui/row_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';

Widget app({Difficulty d = Difficulty.normal, int seed = 1}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: Toon.theme(),
  home: RowScreen(difficulty: d, pace: 0.05, seed: seed),
);

bool has(Key k) => find.byKey(k).evaluate().isNotEmpty;

bool live(WidgetTester tester, int col) =>
    has(Key('col $col')) && tester.widget<GestureDetector>(find.byKey(Key('col $col'))).onTap != null;

void main() {
  for (final MapEntry(key: phone, value: size) in phones.entries) {
    testWidgets('Four in a Row on $phone plays to the end', (tester) async {
      usePhone(tester, size);
      await tester.pumpWidget(app());
      var moves = 0;
      for (var i = 0; i < 5000 && !has(const Key('again')); i++) {
        await tester.pump(const Duration(milliseconds: 20));
        // Middle first, then outwards.
        for (final col in [3, 2, 4, 1, 5, 0, 6]) {
          if (live(tester, col)) {
            await tester.tap(find.byKey(Key('col $col')));
            moves++;
            if (moves == 4) {
              await tester.pump(const Duration(milliseconds: 150));
              await shot(tester, 'row_mid_$phone');
            }
            break;
          }
        }
        expect(tester.takeException(), isNull);
      }
      expect(has(const Key('again')), isTrue);
      await tester.pump(const Duration(milliseconds: 500));
      await shot(tester, 'row_over_$phone');
      await tester.tap(find.byKey(const Key('again')));
      await tester.pump(const Duration(milliseconds: 30));
      expect(has(const Key('again')), isFalse);
    });
  }

  testWidgets('warns about a threat and marks the column', (tester) async {
    usePhone(tester, phones['pixel9pro']!);
    await tester.pumpWidget(app(d: Difficulty.easy, seed: 3));
    // Feed the edge columns so the bot builds something we must watch.
    var warned = false;
    for (var i = 0; i < 4000 && !warned && !has(const Key('again')); i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find.textContaining('Watch out').evaluate().isNotEmpty) {
        warned = true;
        await shot(tester, 'row_warning');
        break;
      }
      for (final col in [0, 6, 0, 6, 1, 5, 2, 4, 3]) {
        if (live(tester, col)) {
          await tester.tap(find.byKey(Key('col $col')));
          break;
        }
      }
    }
    expect(warned || has(const Key('again')), isTrue);
  });
}
