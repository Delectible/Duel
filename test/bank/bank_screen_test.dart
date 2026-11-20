import 'package:duel/core/theme/toon.dart';
import 'package:duel/games/bank/ui/bank_screen.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';

bool has(Key k) => find.byKey(k).evaluate().isNotEmpty;

bool on(WidgetTester t, Key k) => has(k) && t.widget<ToonButton>(find.byKey(k)).onPressed != null;

void main() {
  for (final bots in [2, 5]) {
    for (final MapEntry(key: phone, value: size) in phones.entries) {
      testWidgets('Bank! with $bots bots on $phone plays to the end', (tester) async {
        usePhone(tester, size);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: Toon.theme(),
            home: BankScreen(bots: bots, difficulty: Difficulty.normal, rounds: 10, pace: 0.05, seed: bots),
          ),
        );
        var rolls = 0, banks = 0, shots = 0;
        for (var i = 0; i < 40000 && !has(const Key('again')); i++) {
          await tester.pump(const Duration(milliseconds: 20));
          expect(tester.takeException(), isNull);
          if (on(tester, const Key('bank')) && rolls % 5 == 4) {
            await tester.tap(find.byKey(const Key('bank')));
            banks++;
            rolls++;
          } else if (on(tester, const Key('roll'))) {
            if (shots == 0 && rolls >= 3) {
              shots++;
              await tester.pump(const Duration(milliseconds: 900));
              await tester.pump();
              await shot(tester, 'bank_${bots}bots_$phone');
            }
            await tester.tap(find.byKey(const Key('roll')));
            rolls++;
          }
        }
        expect(has(const Key('again')), isTrue);
        expect(banks, greaterThan(0));
        await shot(tester, 'bank_over_${bots}bots_$phone');
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}
