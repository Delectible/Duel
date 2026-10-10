import 'package:duel/core/session/difficulty.dart';
import 'package:duel/games/poker/ui/poker_screen.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';

Widget app(int bots, {double pace = 0.05}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: Toon.theme(),
  home: PokerScreen(bots: bots, difficulty: Difficulty.easy, pace: pace, seed: bots),
);

bool yourTurn() => find.byKey(const Key('fold')).evaluate().isNotEmpty;

/// Plays your turns until [hands] hands are done or the game ends: calls
/// or checks, or with [raise] bets the pot whenever it can.
Future<void> play(WidgetTester tester, {required int hands, bool raise = false}) async {
  for (var i = 0; i < 6000; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (find.text('Play again').evaluate().isNotEmpty) return;
    final hand = find.textContaining(RegExp(r'^Hand \d+$'));
    final number = hand.evaluate().isEmpty ? 0 : int.parse(tester.widget<Text>(hand).data!.split(' ').last);
    if (number > hands) return;
    if (!yourTurn()) continue;
    final raiseButton = tester.widget<ToonButton>(find.byKey(const Key('raise')));
    if (raise && raiseButton.onPressed != null) {
      await tester.tap(find.byKey(const Key('raise')));
      await tester.pump();
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

  testWidgets('the raise panel steps and sizes the raise', (tester) async {
    usePhone(tester, phones['pixel9pro']!);
    await tester.pumpWidget(app(2));
    for (var i = 0; i < 500 && !yourTurn(); i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.tap(find.byKey(const Key('raise')));
    await tester.pump();
    await shot(tester, 'poker_raise_panel');
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
        final note = find.textContaining(RegExp(r' with [A-Z]'));
        for (var i = 0; i < 20000 && note.evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 20));
          if (yourTurn()) await tester.tap(find.byKey(const Key('call')));
        }
        expect(note, findsOneWidget);
        await tester.pump(const Duration(milliseconds: 600));
        await shot(tester, 'showdown_${bots}bots_$phone');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
