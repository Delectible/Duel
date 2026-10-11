import 'package:duel/core/session/difficulty.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:duel/games/go_fish/ui/fish_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';

Widget app(int bots, {int seed = 1, double pace = 0.05}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: Toon.theme(),
  home: FishScreen(bots: bots, difficulty: Difficulty.normal, pace: pace, seed: seed),
);

bool has(Key k) => find.byKey(k).evaluate().isNotEmpty;

Finder live(String prefix) => find.byWidgetPredicate(
  (w) =>
      w is GestureDetector &&
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith(prefix) &&
      w.onTap != null,
);

/// Plays until the end: fish when told, else ask for the first card's
/// rank from the first player you can.
Future<void> playGame(WidgetTester tester, {Future<void> Function(int i)? onStep}) async {
  for (var i = 0; i < 30000; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    await onStep?.call(i);
    if (has(const Key('again'))) return;
    if (has(const Key('go fish'))) {
      await tester.tap(find.byKey(const Key('go fish')));
    } else if (live('ask ').evaluate().isNotEmpty) {
      await tester.tap(live('ask ').first);
    } else if (live('card ').evaluate().isNotEmpty) {
      await tapCard(tester, live('card '));
    }
  }
  fail('game did not end');
}

void main() {
  for (final bots in [1, 3, 5]) {
    for (final MapEntry(key: phone, value: size) in phones.entries) {
      testWidgets('Go Fish with $bots bots on $phone plays to the end', (tester) async {
        usePhone(tester, size);
        await tester.pumpWidget(app(bots, seed: bots));
        var shotTaken = false;
        await playGame(
          tester,
          onStep: (i) async {
            if (!shotTaken && i > 120 && live('card ').evaluate().isNotEmpty) {
              shotTaken = true;
              await shot(tester, 'fish_${bots}bots_$phone');
            }
            expect(tester.takeException(), isNull);
          },
        );
        await tester.pump(const Duration(milliseconds: 600));
        await shot(tester, 'fish_${bots}bots_over_$phone');
        await tester.tap(find.byKey(const Key('again')));
        await tester.pump(const Duration(milliseconds: 5));
        expect(has(const Key('again')), isFalse);
      });
    }
  }

  testWidgets('asking: pick a rank, then a player; a miss means tapping the pond', (tester) async {
    usePhone(tester, phones['pixel9pro']!);
    await tester.pumpWidget(app(3, seed: 9, pace: 0.3));
    var asked = false, fished = false;
    for (var i = 0; i < 20000 && !(asked && fished); i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (has(const Key('again'))) break;
      if (has(const Key('go fish'))) {
        expect(find.textContaining('Tap the pond'), findsOneWidget);
        await shot(tester, 'fish_go_fish');
        await tester.tap(find.byKey(const Key('pond')));
        fished = true;
      } else if (live('ask ').evaluate().isNotEmpty) {
        expect(find.textContaining('Tap a player'), findsOneWidget);
        await shot(tester, 'fish_pick_player');
        await tester.tap(live('ask ').first);
        await tester.pump(const Duration(milliseconds: 60));
        expect(find.textContaining('got any'), findsWidgets);
        asked = true;
      } else if (live('card ').evaluate().isNotEmpty) {
        await tapCard(tester, live('card '));
      }
    }
    expect(asked, isTrue);
    expect(fished, isTrue);
  });
}
