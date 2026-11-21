import 'package:duel/core/account/account.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:duel/games/blackjack/ui/bj_screen.dart';
import 'package:duel/games/blackjack/ui/bj_tables.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';

void main() {
  for (final felt in BjFelt.values) {
    for (final phone in ['pixel9pro', 'pixel9pro_land']) {
      for (final dark in [false, true]) {
        testWidgets('felt ${felt.name} $phone $dark', (tester) async {
          usePhone(tester, phones[phone]!);
          BjScreen.felt = felt;
          final account = Account()..setBalance(1000);
          Toon.dark = dark;
          await tester.pumpWidget(
            AccountScope(
              account: account,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: Toon.theme(),
                home: BjScreen(table: bjTables[1], bots: 3, difficulty: Difficulty.normal, pace: 0.05, seed: 2),
              ),
            ),
          );
          for (var i = 0; i < 4000; i++) {
            await tester.pump(const Duration(milliseconds: 20));
            final deal = find.byKey(const Key('deal'));
            final stand = find.byKey(const Key('stand'));
            if (stand.evaluate().isNotEmpty && tester.widget<ToonButton>(stand).onPressed != null) {
              await tester.pump(const Duration(milliseconds: 600));
              await shot(tester, 'felt_${felt.name}_${phone}_${dark ? 'dark' : 'light'}');
              break;
            }
            if (deal.evaluate().isNotEmpty && tester.widget<ToonButton>(deal).onPressed != null) {
              await tester.tap(deal);
            }
          }
          Toon.dark = false;
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 3));
        });
      }
    }
  }
}
