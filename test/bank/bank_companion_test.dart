import 'package:duel/core/theme/toon.dart';
import 'package:duel/games/bank/ui/bank_companion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';

bool has(Key k) => find.byKey(k).evaluate().isNotEmpty;

Widget _app(Widget home) => MaterialApp(debugShowCheckedModeBanner: false, theme: Toon.theme(), home: home);

void main() {
  for (final MapEntry(key: phone, value: size) in phones.entries) {
    testWidgets('Bank! companion on $phone: names, the dice, banking, undo, rounds to the end', (
      tester,
    ) async {
      usePhone(tester, size);
      await tester.pumpWidget(_app(const BankCompanionSetup()));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byKey(const Key('add player')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('add player')));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byKey(const Key('name 2')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byKey(const Key('name 2')), 'Sam');
      await tester.scrollUntilVisible(
        find.byKey(const Key('rounds 10')),
        -100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('rounds 10')));
      await tester.pump();
      await shot(tester, 'bank_home_setup_$phone');
      await tester.scrollUntilVisible(
        find.byKey(const Key('start companion')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('start companion')));
      await tester.pumpAndSettle();
      expect(find.text('Sam'), findsOneWidget);
      var rolls = 0, shots = 0;
      for (var i = 0; i < 3000 && !find.text('Play again').evaluate().isNotEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        if (has(const Key('next round'))) {
          await tester.pump();
          await tester.pump(const Duration(seconds: 2));
          if (shots == 1) {
            shots++;
            await shot(tester, 'bank_home_round_$phone');
          }
          if (find.text('Play again').evaluate().isNotEmpty) break;
          await tester.tap(find.byKey(const Key('next round')));
          continue;
        }
        // Bank a player every few rolls in the danger zone.
        if (rolls % 4 == 3) {
          for (var p = 0; p < 3; p++) {
            final t = find.byKey(Key('player $p'));
            if (find.descendant(of: t, matching: find.text('Tap to BANK')).evaluate().isNotEmpty) {
              await tester.tap(t);
              break;
            }
          }
        }
        await tester.tap(find.byKey(const Key('roll')));
        rolls++;
        if (rolls == 5 && shots == 0) {
          await tester.pump(const Duration(seconds: 1));
          shots++;
          await shot(tester, 'bank_home_dice_$phone');
          // Undo puts the last roll back.
          final before = find.textContaining('roll ').evaluate().length;
          await tester.tap(find.byKey(const Key('undo')));
          await tester.pump();
          expect(find.textContaining('roll ').evaluate().length, before);
        }
      }
      expect(find.text('Play again'), findsOneWidget);
      await shot(tester, 'bank_home_over_$phone');
    });
  }

  testWidgets('scoring only: tap in the totals; doubles after the safe rolls double the bank', (
    tester,
  ) async {
    usePhone(tester, phones['pixel9pro']!);
    await tester.pumpWidget(_app(const BankCompanion(names: ['Ann', 'Bo'], rounds: 10, dice: false)));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sum 7')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('70'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sum 5')));
    await tester.tap(find.byKey(const Key('sum 9')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('84'), findsOneWidget);
    await tester.tap(find.byKey(const Key('doubles')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sum 4')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('168'), findsOneWidget);
    await shot(tester, 'bank_home_scores');
    // Ann banks; then a 7 ends it and Bo gets nothing.
    await tester.tap(find.byKey(const Key('player 0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sum 7')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Round 1 done'), findsOneWidget);
    expect(find.textContaining('Nothing for Bo'), findsOneWidget);
    // Fix a score by hand: hold the name.
    await tester.tap(find.byKey(const Key('next round')));
    await tester.pump();
    await tester.longPress(find.byKey(const Key('player 1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('edit score')), '50');
    await tester.tap(find.byKey(const Key('save score')));
    await tester.pumpAndSettle();
    expect(find.text('50'), findsOneWidget);
  });
}
