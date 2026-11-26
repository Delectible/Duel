import 'package:duel/core/theme/toon.dart';
import 'package:duel/games/bank/ui/bank_bits.dart';
import 'package:duel/games/farkle/ui/farkle_screen.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';

bool has(Key k) => find.byKey(k).evaluate().isNotEmpty;

bool on(WidgetTester t, Key k) =>
    has(k) &&
    switch (t.widget(find.byKey(k))) {
      final ToonButton b => b.onPressed != null,
      final SwipeToRoll s => s.enabled,
      _ => false,
    };

void main() {
  for (final bots in [1, 3]) {
    for (final MapEntry(key: phone, value: size) in phones.entries) {
      testWidgets('Farkle with $bots bots on $phone plays to the end', (tester) async {
        usePhone(tester, size);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: Toon.theme(),
            home: FarkleScreen(
              bots: bots,
              difficulty: Difficulty.normal,
              target: 3000,
              pace: 0.05,
              seed: bots,
            ),
          ),
        );
        var rolls = 0, picks = 0;
        final shots = <String>{};
        for (var i = 0; i < 60000 && !has(const Key('again')); i++) {
          await tester.pump(const Duration(milliseconds: 20));
          expect(tester.takeException(), isNull);
          if (on(tester, const Key('keep roll')) || on(tester, const Key('best'))) {
            if (!on(tester, const Key('keep roll'))) {
              // Pick a die by hand first, then the rest.
              if (has(const Key('die 0')) && picks == 0) await tester.tap(find.byKey(const Key('die 0')));
              await tester.tap(find.byKey(const Key('best')));
              picks++;
              await tester.pump();
              if (shots.add('pick')) {
                await tester.pump(const Duration(milliseconds: 1400));
                await tester.pump(const Duration(milliseconds: 200));
                await shot(tester, 'farkle_${bots}bots_pick_$phone');
              }
              continue;
            }
            final bank = on(tester, const Key('keep bank')) && rolls % 3 == 2;
            await tester.tap(find.byKey(Key(bank ? 'keep bank' : 'keep roll')));
            rolls++;
          } else if (on(tester, const Key('roll'))) {
            await tester.tap(find.byKey(const Key('roll')));
            rolls++;
          }
          if (find.text('FARKLE!').evaluate().isNotEmpty && shots.add('farkle')) {
            await tester.pump(const Duration(milliseconds: 1400));
            await shot(tester, 'farkle_${bots}bots_farkle_$phone');
          }
        }
        expect(has(const Key('again')), isTrue);
        await shot(tester, 'farkle_over_${bots}bots_$phone');
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}
