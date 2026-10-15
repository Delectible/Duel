import 'package:duel_engine/difficulty.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:duel/games/spades/ui/spades_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';

Widget app(int bots, {int seed = 1, int target = 150}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: Toon.theme(),
  home: SpadesScreen(bots: bots, difficulty: Difficulty.normal, target: target, pace: 0.05, seed: seed),
);

bool has(Key k) => find.byKey(k).evaluate().isNotEmpty;

/// Your cards you may play now.
Finder playable() => find.byWidgetPredicate(
  (w) =>
      w is GestureDetector &&
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('card ') &&
      w.onTap != null,
);

/// Plays to the end: keeps every other card drawn, takes the suggested
/// bid, plays the first card it may. [onStep] runs every frame.
Future<int> playGame(WidgetTester tester, {Future<void> Function(int i)? onStep}) async {
  var hands = 0;
  for (var i = 0; i < 60000; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    await onStep?.call(i);
    if (has(const Key('again'))) return hands;
    if (has(const Key('next hand'))) {
      hands++;
      await tester.tap(find.byKey(const Key('next hand')));
    } else if (has(const Key('draw keep'))) {
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.byKey(Key(i.isEven ? 'draw keep' : 'draw pass')));
    } else if (has(const Key('bid'))) {
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.byKey(const Key('bid')));
    } else if (playable().evaluate().isNotEmpty) {
      await tapCard(tester, playable());
    }
  }
  fail('game did not end');
}

void main() {
  for (final bots in [1, 3]) {
    for (final MapEntry(key: phone, value: size) in phones.entries) {
      testWidgets('Spades with $bots bots on $phone plays to the end', (tester) async {
        usePhone(tester, size);
        await tester.pumpWidget(app(bots, seed: bots));
        var shotBid = false, shotPlay = false, shotDraw = false;
        final hands = await playGame(
          tester,
          onStep: (i) async {
            if (!shotDraw && has(const Key('draw keep'))) {
              shotDraw = true;
              await tester.pump(const Duration(milliseconds: 300));
              await shot(tester, 'spades_${bots}bots_draw_$phone');
            }
            if (!shotBid && has(const Key('bid'))) {
              shotBid = true;
              await tester.pump(const Duration(milliseconds: 300));
              await shot(tester, 'spades_${bots}bots_bid_$phone');
            }
            if (!shotPlay &&
                find.text('Bid —').evaluate().isEmpty &&
                find.textContaining('won 2').evaluate().isNotEmpty) {
              shotPlay = true;
              await shot(tester, 'spades_${bots}bots_play_$phone');
            }
            if (i == 0) return;
          },
        );
        expect(hands, greaterThan(0));
        await shot(tester, 'spades_${bots}bots_over_$phone');
        expect(find.byKey(const Key('again')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('bidding: - goes down to Nil, + back up; the hand result waits for Next hand', (tester) async {
    usePhone(tester, phones['pixel9pro']!);
    await tester.pumpWidget(app(3, seed: 4));
    for (var i = 0; i < 4000 && !has(const Key('bid')); i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Your bid'), findsOneWidget);
    String value() => tester.widget<Text>(find.byKey(const Key('bid value'))).data!;
    for (var i = 0; i < 14; i++) {
      await tester.tap(find.byKey(const Key('bid minus')), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(value(), 'Nil');
    expect(find.textContaining('win no tricks'), findsOneWidget);
    await tester.tap(find.byKey(const Key('bid plus')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(value(), '1');
    await tester.tap(find.byKey(const Key('bid')));
    for (var i = 0; i < 20000 && !has(const Key('next hand')); i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (playable().evaluate().isNotEmpty) await tapCard(tester, playable());
    }
    expect(find.text('Hand 1'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await shot(tester, 'spades_hand_result');
    // It waits: still there a while later.
    await tester.pump(const Duration(seconds: 5));
    expect(find.byKey(const Key('next hand')), findsOneWidget);
  });

  // At real speed: where the trick lands, and the hand result card.
  for (final bots in [1, 3]) {
    for (final phone in ['pixel9pro', 'small_land']) {
      testWidgets('a trick at real speed, $bots bots on $phone', (tester) async {
        usePhone(tester, phones[phone]!);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: Toon.theme(),
            home: SpadesScreen(bots: bots, difficulty: Difficulty.normal, seed: 9),
          ),
        );
        var took = 0;
        for (var i = 0; i < 6000 && took < 2; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          if (has(const Key('draw keep'))) await tester.tap(find.byKey(const Key('draw keep')));
          if (has(const Key('bid'))) {
            await tester.pump(const Duration(milliseconds: 300));
            await tester.tap(find.byKey(const Key('bid')));
          }
          if (playable().evaluate().isNotEmpty) {
            await tester.pump(const Duration(milliseconds: 400));
            await tapCard(tester, playable());
            // Let the rest of the trick come in, then look.
            for (var k = 0; k < 40 && find.textContaining('the trick with').evaluate().isEmpty; k++) {
              await tester.pump(const Duration(milliseconds: 50));
            }
            await tester.pump(const Duration(milliseconds: 400));
            await shot(tester, 'spades_${bots}bots_trick${took}_$phone');
            took++;
          }
        }
        expect(took, 2);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
