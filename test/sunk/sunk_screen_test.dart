import 'package:duel/core/theme/toon.dart';
import 'package:duel/games/sunk/ui/sunk_screen.dart';
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
      testWidgets('Sunk with $bots bots on $phone plays to the end', (tester) async {
        usePhone(tester, size);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: Toon.theme(),
            home: SunkScreen(bots: bots, difficulty: Difficulty.normal, target: 60, pace: 0.05, seed: bots),
          ),
        );
        var dives = 0;
        final shots = <String>{};
        for (var i = 0; i < 80000 && !has(const Key('again')); i++) {
          await tester.pump(const Duration(milliseconds: 20));
          expect(tester.takeException(), isNull);
          if (find.textContaining('SANK').evaluate().isNotEmpty && shots.add('sank')) {
            await shot(tester, 'sunk_${bots}bots_sank_$phone');
          }
          final aim = find.byWidgetPredicate(
            (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('aim '),
          );
          if (aim.evaluate().isNotEmpty) {
            if (shots.add('aim')) await shot(tester, 'sunk_${bots}bots_aim_$phone');
            await tester.tap(aim.first);
          } else if (on(tester, const Key('take it'))) {
            if (shots.add('map')) await shot(tester, 'sunk_${bots}bots_map_$phone');
            await tester.tap(find.byKey(const Key('take it')));
          } else if (on(tester, const Key('dive'))) {
            if (dives == 2 && shots.add('turn')) await shot(tester, 'sunk_${bots}bots_$phone');
            // Surface once the bag's worth a bit.
            if (on(tester, const Key('surface')) && dives % 4 == 3) {
              await tester.tap(find.byKey(const Key('surface')));
            } else {
              await tester.tap(find.byKey(const Key('dive')));
            }
            dives++;
          }
        }
        expect(has(const Key('again')), isTrue);
        await shot(tester, 'sunk_over_${bots}bots_$phone');
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}
