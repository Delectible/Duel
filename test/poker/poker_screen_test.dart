import 'package:duel/core/session/difficulty.dart';
import 'package:duel/games/poker/ui/poker_screen.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';

Widget app(int bots, {double pace = 0.05, Duration? resultTimeout}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: Toon.theme(),
  home: PokerScreen(
    bots: bots,
    difficulty: Difficulty.easy,
    pace: pace,
    seed: bots,
    resultTimeout: resultTimeout,
  ),
);

/// Plays (calling) until a showdown result is up.
Future<void> untilShowdown(WidgetTester tester) async {
  final next = find.byKey(const Key('next hand'));
  for (var i = 0; i < 20000 && next.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (find.byKey(const Key('deck')).evaluate().isNotEmpty) await shuffleAndDeal(tester);
    if (yourTurn()) {
      await settleButtons(tester);
      await tester.tap(find.byKey(const Key('call')));
    }
  }
  expect(next, findsOneWidget);
}

bool yourTurn() => find.byKey(const Key('fold')).evaluate().isNotEmpty;

/// Lets the action buttons finish sliding in (they grow in landscape).
Future<void> settleButtons(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

/// Between your turns: Next hand after a showdown, and on your deal one
/// shuffle then Deal. True if it did either.
Future<bool> shuffleAndDeal(WidgetTester tester) async {
  if (find.byKey(const Key('next hand')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('next hand')));
    await tester.pump();
    return true;
  }
  if (find.byKey(const Key('deck')).evaluate().isEmpty) return false;
  await tester.tap(find.byKey(const Key('deck')));
  await tester.pump(const Duration(milliseconds: 800));
  await tester.tap(find.byKey(const Key('deal')));
  await tester.pump();
  return true;
}

/// Plays your turns until [hands] hands are done or the game ends: calls
/// or checks, or with [raise] bets the pot whenever it can.
Future<void> play(WidgetTester tester, {required int hands, bool raise = false}) async {
  for (var i = 0; i < 6000; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (find.text('Play again').evaluate().isNotEmpty) return;
    // "Hand 4" upright; "Hand 4 · Blinds …" in the landscape side panel.
    final hand = find.textContaining(RegExp(r'^Hand \d+'));
    final number = hand.evaluate().isEmpty
        ? 0
        : int.parse(RegExp(r'^Hand (\d+)').firstMatch(tester.widget<Text>(hand.first).data!)!.group(1)!);
    if (number > hands) return;
    if (await shuffleAndDeal(tester)) continue;
    if (!yourTurn()) continue;
    await settleButtons(tester);
    final raiseButton = tester.widget<ToonButton>(find.byKey(const Key('raise')));
    if (raise && raiseButton.onPressed != null) {
      await tester.tap(find.byKey(const Key('raise')));
      await settleButtons(tester);
      if (find.byKey(const Key('quick Pot')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('quick Pot')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('confirm raise')));
      }
    } else {
      await tester.tap(find.byKey(const Key('call')));
    }
  }
}

void main() {
  for (final bots in [1, 3, 5]) {
    for (final MapEntry(key: phone, value: size) in phones.entries) {
      testWidgets('poker with $bots bots on $phone: plays hands without layout errors', (tester) async {
        usePhone(tester, size);
        await tester.pumpWidget(app(bots));
        await tester.pump(const Duration(milliseconds: 100));
        await shot(tester, 'poker_${bots}bots_deal_$phone');
        await play(tester, hands: 3);
        await shot(tester, 'poker_${bots}bots_$phone');
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final phone in ['pixel9pro', 'small_land']) {
    testWidgets('the raise panel steps and sizes the raise on $phone', (tester) async {
      usePhone(tester, phones[phone]!);
      await tester.pumpWidget(app(2));
      for (var i = 0; i < 500 && !yourTurn(); i++) {
        await tester.pump(const Duration(milliseconds: 20));
        await shuffleAndDeal(tester);
      }
      await settleButtons(tester);
      await shot(tester, 'poker_buttons_$phone');
      await tester.tap(find.byKey(const Key('raise')));
      await settleButtons(tester);
      await shot(tester, 'poker_raise_panel_$phone');
      expect(find.text('½ Pot'), findsOneWidget);
      String label() => tester
          .widget<Text>(
            find.descendant(of: find.byKey(const Key('confirm raise')), matching: find.byType(Text)),
          )
          .data!;
      final before = label();
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump(const Duration(milliseconds: 50));
      expect(label(), isNot(before));
      await tester.tap(find.byKey(const Key('quick All-in')));
      await tester.pump();
      expect(label(), startsWith('All-in '));
    });
  }

  testWidgets('heads-up with raises plays to a result', (tester) async {
    usePhone(tester, phones['pixel9pro']!);
    await tester.pumpWidget(app(1));
    await play(tester, hands: 400, raise: true);
    await shot(tester, 'poker_game_over');
    expect(find.text('Play again'), findsOneWidget);
    await tester.tap(find.text('Play again'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Hand 1'), findsOneWidget);
  });

  // Turned-up cards and the result note stay clear of the board and seats.
  for (final bots in [1, 3, 5]) {
    for (final MapEntry(key: phone, value: size) in phones.entries) {
      testWidgets('showdown with $bots bots on $phone', (tester) async {
        usePhone(tester, size);
        await tester.pumpWidget(app(bots, pace: 0.2));
        await untilShowdown(tester);
        expect(find.textContaining(RegExp(r' with [A-Z]')), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 600));
        await shot(tester, 'showdown_${bots}bots_$phone');
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('your deal: shuffle the deck, then Deal', (tester) async {
    usePhone(tester, phones['pixel9pro']!);
    await tester.pumpWidget(app(1));
    // Heads-up the button alternates: your deal comes within two hands.
    final deck = find.byKey(const Key('deck'));
    for (var i = 0; i < 4000 && deck.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (yourTurn()) {
        await settleButtons(tester);
        await tester.tap(find.byKey(const Key('call')));
      }
    }
    expect(deck, findsOneWidget);
    expect(find.text('Your deal!'), findsOneWidget);
    expect(tester.widget<ToonButton>(find.byKey(const Key('deal'))).onPressed, isNull);
    await tester.tap(deck);
    await tester.pump(); // the riffle's first frame
    await tester.pump(const Duration(milliseconds: 280));
    await shot(tester, 'poker_shuffle');
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Shuffled ×1. Again, or deal'), findsOneWidget);
    await tester.tap(find.byKey(const Key('deal')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(deck, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('your hand name opens the cheat sheet with your hand outlined', (tester) async {
    usePhone(tester, phones['pixel9pro']!);
    await tester.pumpWidget(app(3));
    final chart = find.byKey(const Key('hand chart'));
    for (var i = 0; i < 4000 && chart.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await shuffleAndDeal(tester);
    }
    await tester.tap(chart);
    // The table keeps animating behind the sheet: no pumpAndSettle.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Poker hands'), findsOneWidget);
    expect(find.text('You have'), findsOneWidget);
    expect(find.text('You'), findsWidgets);
    await shot(tester, 'poker_hand_chart');
    expect(tester.takeException(), isNull);
  });

  testWidgets('bot games: the showdown result waits for Next hand', (tester) async {
    usePhone(tester, phones['pixel9pro']!);
    await tester.pumpWidget(app(3));
    await untilShowdown(tester);
    final note = find.textContaining(RegExp(r' with [A-Z]'));
    final hand = tester.widget<Text>(find.textContaining(RegExp(r'^Hand \d+$'))).data;
    await tester.pump(const Duration(minutes: 2));
    expect(note, findsOneWidget, reason: 'no time limit against bots');
    await shot(tester, 'poker_next_hand');
    await tester.tap(find.byKey(const Key('next hand')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('next hand')), findsNothing);
    expect(tester.widget<Text>(find.textContaining(RegExp(r'^Hand \d+$'))).data, isNot(hand));
  });

  testWidgets('with a timeout (online) the result counts down and moves on', (tester) async {
    usePhone(tester, phones['pixel9pro']!);
    // pace 0.2: a "second" of countdown is 200 ms.
    await tester.pumpWidget(app(3, pace: 0.2, resultTimeout: const Duration(seconds: 10)));
    await untilShowdown(tester);
    final next = find.byKey(const Key('next hand'));
    expect(find.descendant(of: next, matching: find.text('10')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 210));
    expect(find.descendant(of: next, matching: find.text('9')), findsOneWidget);
    await shot(tester, 'poker_next_hand_countdown');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(next, findsNothing, reason: 'moved on by itself');
  });

  testWidgets('the ? button opens the poker guide at the current stage', (tester) async {
    usePhone(tester, phones['pixel9pro']!);
    await tester.pumpWidget(app(3));
    for (var i = 0; i < 4000 && !yourTurn(); i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await shuffleAndDeal(tester);
    }
    await tester.tap(find.byKey(const Key('guide')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('How to play'), findsOneWidget);
    expect(find.text('You are here'), findsOneWidget);
    await shot(tester, 'poker_guide');
  });
}
