import 'package:duel/core/session/difficulty.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:duel/games/crazy_eights/ui/eights_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';

Widget app(int bots, {int seed = 1}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: Toon.theme(),
  home: EightsScreen(bots: bots, difficulty: Difficulty.normal, pace: 0.05, seed: seed),
);

bool has(Key k) => find.byKey(k).evaluate().isNotEmpty;

/// Your cards that can be played now (their tap is live).
Finder playableCards(WidgetTester tester) => find.byWidgetPredicate(
  (w) =>
      w is GestureDetector &&
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('card ') &&
      w.onTap != null,
);

/// Plays until the game ends: first card that fits, hearts for eights,
/// plays drawn cards. Calls [onStep] each frame.
Future<void> playGame(WidgetTester tester, {Future<void> Function(int step)? onStep}) async {
  for (var i = 0; i < 20000; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    await onStep?.call(i);
    if (has(const Key('again'))) return;
    if (has(const Key('suit hearts'))) {
      await tester.pump(const Duration(milliseconds: 300)); // the panel slides open
      await tester.tap(find.byKey(const Key('suit hearts')));
    } else if (has(const Key('play drawn'))) {
      await tester.tap(find.byKey(const Key('play drawn')));
    } else if (playableCards(tester).evaluate().isNotEmpty) {
      await tapCard(tester, playableCards(tester));
    } else if (has(const Key('draw')) && find.text('Draw a card').evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('draw')));
    } else if (has(const Key('pass'))) {
      await tester.tap(find.byKey(const Key('pass')));
    }
  }
  fail('game did not end');
}

void main() {
  for (final bots in [1, 2, 3]) {
    for (final MapEntry(key: phone, value: size) in phones.entries) {
      testWidgets('Crazy Eights with $bots bots on $phone plays to the end', (tester) async {
        usePhone(tester, size);
        await tester.pumpWidget(app(bots, seed: bots));
        await tester.pump(const Duration(milliseconds: 30));
        await shot(tester, 'eights_${bots}bots_deal_$phone');
        var shotTaken = false;
        await playGame(
          tester,
          onStep: (i) async {
            // A mid-game picture on your turn.
            if (!shotTaken && i > 150 && playableCards(tester).evaluate().isNotEmpty) {
              shotTaken = true;
              await shot(tester, 'eights_${bots}bots_$phone');
            }
            expect(tester.takeException(), isNull);
          },
        );
        await tester.pump(const Duration(milliseconds: 600));
        await shot(tester, 'eights_${bots}bots_over_$phone');
        expect(find.textContaining(RegExp('won')), findsWidgets);
        await tester.tap(find.byKey(const Key('again')));
        await tester.pump(const Duration(milliseconds: 5));
        expect(has(const Key('again')), isFalse);
        expect(find.textContaining('Dealing'), findsWidgets);
      });
    }
  }

  testWidgets('an eight asks for the suit; the commentary says what to do', (tester) async {
    usePhone(tester, phones['pixel9pro']!);
    await tester.pumpWidget(app(2, seed: 5));
    var picked = false;
    for (var i = 0; i < 20000 && !picked; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (has(const Key('again'))) break;
      if (has(const Key('suit spades'))) {
        expect(find.textContaining('pick the suit'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 300)); // the panel slides open
        await shot(tester, 'eights_pick_suit');
        await tester.tap(find.byKey(const Key('suit spades')));
        await tester.pump(const Duration(milliseconds: 5));
        expect(find.textContaining('chose spades'), findsWidgets);
        await tester.pump(const Duration(milliseconds: 250));
        await shot(tester, 'eights_suit_burst');
        picked = true;
      } else if (has(const Key('play drawn'))) {
        await tester.tap(find.byKey(const Key('play drawn')));
      } else if (playableCards(tester).evaluate().isNotEmpty) {
        // Prefer an eight if we have one that fits.
        final cards = playableCards(tester).evaluate().toList();
        final eight = cards.where((e) {
          final id = int.parse(((e.widget.key! as ValueKey<String>).value).split(' ').last);
          return id ~/ 4 + 2 == 8;
        });
        await tapCard(tester, find.byWidget((eight.isNotEmpty ? eight.first : cards.first).widget));
      } else if (has(const Key('draw')) && find.text('Draw a card').evaluate().isNotEmpty) {
        expect(find.textContaining('Tap the deck to draw'), findsOneWidget);
        await tester.tap(find.byKey(const Key('draw')));
      } else if (has(const Key('pass'))) {
        await tester.tap(find.byKey(const Key('pass')));
      }
    }
    expect(picked, isTrue, reason: 'seed 5 should hand us an eight');
  });

  testWidgets('the ? button opens How to play at the current stage', (tester) async {
    usePhone(tester, phones['small']!);
    await tester.pumpWidget(app(1));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.tap(find.byKey(const Key('guide')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('How to play'), findsOneWidget);
    expect(find.text('You are here'), findsOneWidget);
    await shot(tester, 'eights_guide');
    expect(tester.takeException(), isNull);
  });
}
