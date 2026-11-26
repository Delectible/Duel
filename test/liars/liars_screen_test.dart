import 'package:duel/core/theme/toon.dart';
import 'package:duel/games/liars/ui/liars_screen.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';

bool has(Key k) => find.byKey(k).evaluate().isNotEmpty;

bool on(WidgetTester t, Key k) =>
    has(k) &&
    switch (t.widget(find.byKey(k))) {
      final ToonButton b => b.onPressed != null,
      _ => false,
    };

void main() {
  for (final bots in [1, 3, 5]) {
    for (final MapEntry(key: phone, value: size) in phones.entries) {
      testWidgets("Liar's Dice with $bots bots on $phone plays to the end", (tester) async {
        usePhone(tester, size);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: Toon.theme(),
            home: LiarsScreen(bots: bots, difficulty: Difficulty.normal, pace: 0.05, seed: bots),
          ),
        );
        var turns = 0, calls = 0;
        final shots = <String>{};
        for (var i = 0; i < 60000 && !has(const Key('again')); i++) {
          await tester.pump(const Duration(milliseconds: 20));
          expect(tester.takeException(), isNull);
          if (shots.isEmpty && find.text('Counting… 1').evaluate().isNotEmpty) {
            shots.add('count');
            await shot(tester, 'liars_${bots}bots_reveal_$phone');
          }
          if (on(tester, const Key('bid')) || on(tester, const Key('liar'))) {
            if (turns == 1 && shots.add('turn')) await shot(tester, 'liars_${bots}bots_$phone');
            turns++;
            if (on(tester, const Key('liar')) && turns % 3 == 0) {
              await tester.tap(find.byKey(const Key('liar')));
              calls++;
            } else if (on(tester, const Key('bid'))) {
              await tester.tap(find.byKey(const Key('bid')));
            } else {
              await tester.tap(find.byKey(const Key('liar')));
              calls++;
            }
          }
        }
        expect(has(const Key('again')), isTrue);
        expect(calls, greaterThan(0));
        await shot(tester, 'liars_over_${bots}bots_$phone');
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}
