import 'package:duel/core/account/account.dart';
import 'package:duel/core/debug/perf.dart';
import 'package:duel/core/session/play_setup.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:duel/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screens.dart';

void main() {
  for (final MapEntry(key: phone, value: size) in phones.entries) {
    testWidgets('$phone: long-press About opens the debug menu; the frame rate shows', (tester) async {
      usePhone(tester, size);
      addTearDown(() => Perf.instance.fps = false);
      final account = Account();
      await tester.pumpWidget(
        AccountScope(
          account: account,
          child: PlaySetupScope(
            setup: PlaySetup(),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: Toon.theme(),
              builder: (context, child) => PerfOverlay(child: child!),
              home: const SettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // About is at the end of one of the page's columns.
      final about = find.byKey(const Key('about'));
      for (final scrollable in find.byType(Scrollable).evaluate().toList()) {
        if (about.evaluate().isNotEmpty) break;
        try {
          await tester.scrollUntilVisible(
            about,
            200,
            scrollable: find.byWidget(scrollable.widget),
            maxScrolls: 20,
          );
        } on StateError {
          // Not in this column.
        }
      }
      await tester.ensureVisible(about);
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(const Key('about')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('debug sheet')), findsOneWidget);
      expect(find.byKey(const Key('debug screen')), findsOneWidget);

      await tester.tap(find.byKey(const Key('debug fps')));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('fps badge')), findsOneWidget);
      await tester.tap(find.byKey(const Key('debug fps')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fps badge')), findsNothing);

      // Any amount of money.
      await tester.scrollUntilVisible(
        find.byKey(const Key('debug money 100000')),
        200,
        scrollable: find
            .descendant(of: find.byKey(const Key('debug sheet')), matching: find.byType(Scrollable))
            .first,
      );
      await tester.tap(find.byKey(const Key('debug money 100000')));
      await tester.pump();
      expect(account.balance, 100000);
      await tester.enterText(find.byKey(const Key('debug money field')), '-250');
      await tester.tap(find.byKey(const Key('debug money set')));
      await tester.pump();
      expect(account.balance, -250);
      expect(tester.takeException(), isNull);
    });
  }
}
