import 'package:duel/core/account/account.dart';
import 'package:duel/core/cards/card_view.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:duel/games/blackjack/ui/bj_screen.dart';
import 'package:duel_engine/difficulty.dart';
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
            home: const BjLobby(bots: 3, difficulty: Difficulty.normal, pace: 0.05, seed: 2),
          ),
        ),
      );
      await tester.pump();
      await shot(tester, 'bj_lobby_$phone');
      expect(has(const Key('locked 250')), isTrue, reason: 'High limit needs 2,500');
      await tester.tap(find.byKey(const Key('sit 50')));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await shot(tester, 'bj_bet_$phone');
      var hands = 0, moves = 0, shotPlay = false, shotPaid = false;
      for (var i = 0; i < 20000; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(tester.takeException(), isNull);
        if (on(tester, const Key('deal'))) {
          if (hands == 6) break;
          if (hands == 1) await tester.tap(find.byKey(const Key('chip 250')));
          await tester.tap(find.byKey(const Key('deal')));
          hands++;
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
      expect(account.stats('blackjack').played, greaterThanOrEqualTo(5));
      expect(account.balance, isNot(1000), reason: 'money moved');
      expect(account.balance - 1000, account.stats('blackjack').net);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
