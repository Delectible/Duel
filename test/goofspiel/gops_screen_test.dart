import 'package:duel/core/theme/toon.dart';
import 'package:duel/games/goofspiel/ui/gops_screen.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';

Widget app(int bots, {int seed = 1}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: Toon.theme(),
  home: GopsScreen(bots: bots, difficulty: Difficulty.normal, pace: 0.05, seed: seed),
);

bool has(Key k) => find.byKey(k).evaluate().isNotEmpty;

Finder live(String prefix) => find.byWidgetPredicate(
  (w) =>
      w is GestureDetector &&
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith(prefix) &&
      w.onTap != null,
);

void main() {
  for (final bots in [1, 2]) {
    for (final MapEntry(key: phone, value: size) in phones.entries) {
      testWidgets('Goofspiel with $bots bots on $phone plays to the end', (tester) async {
        usePhone(tester, size);
        await tester.pumpWidget(app(bots, seed: bots));
        var bids = 0, shots = 0;
        for (var i = 0; i < 20000 && !has(const Key('again')); i++) {
          await tester.pump(const Duration(milliseconds: 20));
          expect(tester.takeException(), isNull);
          if (has(const Key('bid'))) {
            if (bids == 4 && shots == 0) {
              await tester.pump(const Duration(milliseconds: 600));
              shots++;
              await shot(tester, 'gops_${bots}bots_$phone');
            }
            await tester.tap(find.byKey(const Key('bid')));
            bids++;
          } else if (live('card ').evaluate().isNotEmpty) {
            await tapCard(tester, live('card ').last);
          } else if (bids == 5 && shots == 1 && find.textContaining('carries over').evaluate().isEmpty) {
            if (find.textContaining(' take').evaluate().isNotEmpty) {
              shots++;
              await shot(tester, 'gops_reveal_${bots}bots_$phone');
            }
          }
        }
        expect(has(const Key('again')), isTrue);
        expect(bids, 13);
        await shot(tester, 'gops_over_${bots}bots_$phone');
        await tester.tap(find.byKey(const Key('again')));
        await tester.pump(const Duration(seconds: 1));
        expect(has(const Key('again')), isFalse);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}
