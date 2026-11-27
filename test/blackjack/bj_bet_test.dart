import 'package:duel/core/account/account.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:duel/games/blackjack/ui/bj_screen.dart';
import 'package:duel_engine/blackjack/bj_tables.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';

/// Betting with + and −: ones at a tap, faster in bigger steps when held;
/// your balance in view.
void main() {
  testWidgets('blackjack bet: + / − by one, held speeds up', (tester) async {
    usePhone(tester, phones['small']!);
    final account = Account()..setBalance(1000);
    await tester.pumpWidget(
      AccountScope(
        account: account,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: Toon.theme(),
          home: BjScreen(table: bjTables[1], bots: 2, pace: 0.05, seed: 3),
        ),
      ),
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byKey(const Key('balance')), findsOneWidget);
    final c = tester.state(find.byType(BjScreen)) as dynamic;
    int bet() => (c.controllerForTests as dynamic).bet as int;
    final before = bet();
    await tester.tap(find.byKey(const Key('bet plus')));
    await tester.pump();
    expect(bet(), before + 1);
    await tester.tap(find.byKey(const Key('bet minus')));
    await tester.pump();
    expect(bet(), before);
    // Held for three seconds: well past ones.
    final g = await tester.startGesture(tester.getCenter(find.byKey(const Key('bet plus'))));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await g.up();
    await tester.pump();
    expect(bet(), greaterThan(before + 30));
    expect(bet() % 5, 0, reason: 'lands on round numbers');
    await shot(tester, 'bj_bet_small');
    expect(tester.takeException(), isNull);
  });
}
