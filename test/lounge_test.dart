import 'package:duel/core/account/account.dart';
import 'package:duel/core/account/achievements.dart';
import 'package:duel/core/session/play_setup.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:duel/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screens.dart';

void main() {
  for (final MapEntry(key: phone, value: size) in phones.entries) {
    testWidgets('$phone: home opens the Poker Lounge; its tables, rivals and achievements', (tester) async {
      usePhone(tester, size);
      final account = Account()
        ..earn(Achievement.firstWin)
        ..rivalResult('Vinnie', won: true);
      await tester.pumpWidget(
        AccountScope(
          account: account,
          child: PlaySetupScope(
            setup: PlaySetup(),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: Toon.theme(),
              home: const HomeScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("Hold'em Sit & Go"), findsNothing, reason: 'it lives in the lounge');
      await tester.tap(find.byKey(const Key('poker lounge')));
      await tester.pumpAndSettle();
      expect(find.text('Poker Lounge'), findsOneWidget);
      expect(find.byKey(const Key('lounge sitgo')), findsOneWidget);
      await shot(tester, 'lounge_$phone');

      // Cash games: the tables.
      await tester.tap(find.byKey(const Key('lounge cash')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cash lobby')), findsOneWidget);
      await tester.tap(find.byKey(const Key('lobby back')));
      await tester.pumpAndSettle();

      for (final id in ['tournament', 'bosses']) {
        await tester.ensureVisible(find.byKey(Key('lounge $id')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key('lounge $id')));
        await tester.pumpAndSettle();
        expect(find.byKey(Key('mode $id')), findsOneWidget);
        await shot(tester, 'lounge_${id}_$phone');
        await tester.tap(find.byKey(const Key('mode back')));
        await tester.pumpAndSettle();
      }

      // Sit & Go: the Hold'em preview.
      await tester.ensureVisible(find.byKey(const Key('lounge sitgo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lounge sitgo')));
      await tester.pumpAndSettle();
      expect(find.text("Hold'em Sit & Go"), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('achievement firstWin')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.byKey(const Key('lounge rivals')), findsOneWidget);
      expect(find.text('1–0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
