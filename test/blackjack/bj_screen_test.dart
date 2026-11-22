import 'dart:math';

import 'package:duel/core/account/account.dart';
import 'package:duel_engine/blackjack/blackjack.dart';
import 'package:duel/core/cards/card_view.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:duel/games/blackjack/ui/bj_controller.dart';
import 'package:duel/games/blackjack/ui/bj_lobby.dart';
import 'package:duel/games/blackjack/ui/bj_tables.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';

bool has(Key k) => find.byKey(k).evaluate().isNotEmpty;

bool on(WidgetTester t, Key k) => has(k) && t.widget<ToonButton>(find.byKey(k)).onPressed != null;

void main() {
  for (final MapEntry(key: phone, value: size) in phones.entries) {
    testWidgets('Blackjack on $phone: pick a table, play hands, bets come off the balance', (tester) async {
      usePhone(tester, size);
      final account = Account()..setBalance(1000);
      await tester.pumpWidget(
        AccountScope(
          account: account,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: Toon.theme(),
            home: BjLobby(pace: 0.05, seed: 2, now: () => 0),
          ),
        ),
      );
      await tester.pump();
      await shot(tester, 'bj_lobby_$phone');
      // Surrender on, to see it offered.
      account.bjRules = const BjRules(surrender: true);
      await tester.pump();
      expect(find.text(account.bjRules.summary), findsOneWidget);
      final list = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.byKey(const Key('locked 250')), 120, scrollable: list);
      expect(has(const Key('locked 250')), isTrue, reason: 'High limit needs 2,500');
      await tester.scrollUntilVisible(find.byKey(const Key('sit 10')), -120, scrollable: list);
      await tester.pump();
      await tester.tap(find.byKey(const Key('sit 10')));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await shot(tester, 'bj_bet_$phone');
      var hands = 0, moves = 0, insured = 0, skipped = 0, shotPlay = false, shotPaid = false;
      for (var i = 0; i < 60000; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(tester.takeException(), isNull);
        if (on(tester, const Key('deal'))) {
          if (hands == 6) break;
          if (hands == 1) await tester.tap(find.byKey(const Key('chip 50')));
          await tester.tap(find.byKey(const Key('deal')));
          hands++;
        } else if (hands.isOdd && on(tester, const Key('hurry'))) {
          await tester.tap(find.byKey(const Key('hurry')));
          skipped++;
        } else if (on(tester, const Key('no insurance'))) {
          await shot(tester, 'bj_insurance_$phone');
          final take = insured.isEven && on(tester, const Key('insure'));
          insured++;
          await tester.tap(find.byKey(Key(take ? 'insure' : 'no insurance')));
        } else if (on(tester, const Key('stand'))) {
          if (!shotPlay) {
            shotPlay = true;
            await shot(tester, 'bj_play_$phone');
          }
          // Hit on 11 or less, double when offered every other time.
          if (moves.isEven && on(tester, const Key('double'))) {
            await tester.tap(find.byKey(const Key('double')));
          } else {
            await tester.tap(find.byKey(const Key('stand')));
          }
          moves++;
        } else if (!shotPaid && hands >= 2 && find.textContaining('Next hand').evaluate().isNotEmpty) {
          shotPaid = true;
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump();
          await shot(tester, 'bj_paid_$phone');
          final backs = tester
              .widgetList<CardView>(find.byType(CardView))
              .where((c) => !c.faceUp && c.card != null);
          expect(backs.length, lessThanOrEqualTo(4), reason: 'only the shoe is face down: ${backs.length}');
        }
      }
      expect(hands, 6);
      expect(skipped, greaterThan(0), reason: 'Skip shows while the others play');
      expect(account.stats('blackjack').played, greaterThanOrEqualTo(5));
      expect(account.balance, isNot(1000), reason: 'money moved');
      expect(account.balance - 1000, account.stats('blackjack').net);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }

  testWidgets('house rules: change them, and back to the usual', (tester) async {
    usePhone(tester, phones['pixel9pro']!);
    final account = Account();
    await tester.pumpWidget(
      AccountScope(
        account: account,
        child: MaterialApp(debugShowCheckedModeBanner: false, theme: Toon.theme(), home: const BjLobby()),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('house rules')));
    await tester.pumpAndSettle();
    for (final k in ['rule h17 1', 'rule pays 1', 'rule decks 0', 'rule das 1', 'rule ins 1', 'rule sur 1']) {
      await tester.ensureVisible(find.byKey(Key(k)));
      await tester.tap(find.byKey(Key(k)));
      await tester.pump();
    }
    expect(
      account.bjRules,
      const BjRules(
        decks: 1,
        hitSoft17: true,
        sixToFive: true,
        surrender: true,
        insurance: false,
        doubleAfterSplit: false,
      ),
    );
    await shot(tester, 'bj_rules');
    await tester.ensureVisible(find.byKey(const Key('rules reset')));
    await tester.tap(find.byKey(const Key('rules reset')));
    await tester.pump();
    expect(account.bjRules, const BjRules());
  });

  testWidgets('insurance and surrender at the table: the pips add up', (tester) async {
    final account = Account()..setBalance(5000);
    final c = BjController(
      table: bjTables[1],
      account: account,
      bots: 3,
      rules: const BjRules(surrender: true),
      pace: 0.02,
      rng: Random(4),
    );
    var insured = 0, surrendered = 0;
    for (var i = 0; i < 60000 && (insured < 2 || surrendered < 1); i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (c.canDeal) c.deal();
      if (c.canInsure) {
        c.insure(true);
        insured++;
      }
      if (c.yourTurn) {
        final m = c.moves;
        if (m.contains(BjMove.surrender) && c.round!.current.total >= 15) {
          c.act(BjMove.surrender);
          surrendered++;
        } else {
          c.act(c.round!.current.total < 12 ? BjMove.hit : BjMove.stand);
        }
      }
    }
    expect(insured, 2);
    expect(surrendered, greaterThan(0));
    // Let the last round finish.
    for (var i = 0; i < 500 && c.phase != BjPhase.betting; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (c.canInsure) c.insure(false);
      if (c.yourTurn) c.act(BjMove.stand);
    }
    expect(account.balance - 5000, account.stats('blackjack').net);
    c.dispose();
  });
}
