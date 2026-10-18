import 'dart:math';

import 'package:duel/core/table/table_bits.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:duel/games/poker/ui/poker_controller.dart';
import 'package:duel/games/poker/ui/shuffle_deck.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/poker/poker_hand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';
import 'poker_screen_test.dart' show app, shuffleAndDeal, yourTurn, settleButtons;

void main() {
  testWidgets('bots think for 2 to 10 seconds; Skip hurries them', (tester) async {
    final c = PokerController(bots: 3, difficulty: Difficulty.easy, rng: Random(4))..start();
    // Time each bot's turn, from its turn starting to its move, in 50 ms
    // steps; Skip once, on the sixth.
    final times = <int>[];
    int? turnOf, hurried;
    var since = 0, now = 0, turns = 0, skipping = false;
    while (times.length < 10 && now < 600000) {
      if (c.phase == TablePhase.shuffle) {
        c.shuffleDeck();
        c.deal();
      }
      if (c.yourTurn) c.act(c.hand!.legalMoves().canCheck ? const Move.check() : const Move.call());
      final seat = c.actingSeat;
      final key = seat == null || seat == 0 ? null : seat * 1000 + c.hand!.street.index * 10 + c.handNumber;
      if (key != turnOf) {
        if (turnOf != null) {
          skipping ? hurried = now - since : times.add(now - since);
        }
        skipping = false;
        turnOf = key;
        since = now;
        if (key != null && ++turns == 6) {
          c.hurry();
          skipping = true;
        }
      }
      await tester.pump(const Duration(milliseconds: 50));
      now += 50;
    }
    expect(hurried, lessThan(500), reason: 'Skip: the bot moves at once');
    for (final t in times) {
      expect(t, inInclusiveRange(1950, 10100));
    }
    expect(times.where((t) => t < 4500).length, greaterThan(times.length ~/ 2), reason: 'mostly quick');
    c.dispose();
  });

  testWidgets('shuffling a lot gets cheeky', (tester) async {
    Future<String> line(int n) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ShuffleDeck(shuffles: n, onShuffle: () {}),
            ),
          ),
        ),
      );
      return tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .firstWhere((d) => d.startsWith('Shuffled') || d.startsWith('Tap'));
    }

    expect(await line(3), contains('Again, or deal'));
    expect(await line(10), contains('Not random enough for you?'));
    expect(await line(20), contains('dizzy'));
  });

  testWidgets('all in: odds on the cards, a banner, table talk and a big-pot splash', (tester) async {
    usePhone(tester, phones.values.first);
    await tester.pumpWidget(app(3, pace: 0.4));
    var allIn = false, odds = false, talk = false, big = false;
    for (var i = 0; i < 30000 && !(allIn && odds && talk && big); i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('Play again').evaluate().isNotEmpty) break;
      if (find.text('ALL IN!').evaluate().isNotEmpty) {
        allIn = true;
        odds |= find.textContaining(RegExp(r'^\d+%$')).evaluate().isNotEmpty;
      }
      talk |= find.byType(SpeechBubble).evaluate().isNotEmpty;
      big |= find.text('HUGE POT!').evaluate().isNotEmpty || find.text('BIG WIN!').evaluate().isNotEmpty;
      if (allIn && !big && find.text('HUGE POT!').evaluate().isNotEmpty) await shot(tester, 'poker_big_pot');
      if (await shuffleAndDeal(tester)) continue;
      if (!yourTurn()) continue;
      await settleButtons(tester);
      // Shove every hand.
      final raise = tester.widget<ToonButton>(find.byKey(const Key('raise')));
      if (raise.onPressed != null) {
        await tester.tap(find.byKey(const Key('raise')));
        await settleButtons(tester);
        final shove = find.byKey(const Key('quick All-in'));
        if (shove.evaluate().isNotEmpty) {
          await tester.tap(shove);
          await tester.pump();
        }
        await tester.tap(find.byKey(const Key('confirm raise')));
      } else {
        await tester.tap(find.byKey(const Key('call')));
      }
    }
    expect([allIn, odds, talk, big], [true, true, true, true]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });
}
