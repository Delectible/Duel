import 'package:duel/core/session/play_setup.dart';
import 'package:duel/games/catalog.dart';
import 'package:duel/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screens.dart';

/// Scrolls the steps down to the Next / Done button.
Future<void> toNext(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('home next')),
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}

void main() {
  test('every game has a play-at-home guide: what you need, setup, gameplay, winning', () {
    for (final g in games) {
      final h = g.atHome;
      expect(h.needs, isNotEmpty, reason: g.name);
      // Says how many players.
      expect(h.needs.any((n) => n.$2.contains('player')), isTrue, reason: g.name);
      for (final part in h.parts) {
        expect(part, isNotEmpty, reason: g.name);
      }
    }
  });

  for (final MapEntry(key: phone, value: size) in phones.entries) {
    for (final game in games) {
      testWidgets('${game.name}: Play at home on $phone', (tester) async {
        usePhone(tester, size);
        await tester.pumpWidget(DuelApp(setup: PlaySetup()..botCount = 1));
        await tester.scrollUntilVisible(find.text(game.name), 150, scrollable: find.byType(Scrollable).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text(game.name));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('play at home')));
        await tester.pumpAndSettle();
        expect(find.text('Play at home'), findsOneWidget);
        expect(find.text('What you need'), findsOneWidget);
        expect(find.text(game.atHome.setup.first), findsOneWidget);
        if (game.id == 'holdem') await shot(tester, 'at_home_setup_$phone');
        // Next walks through Gameplay and Winning, then Done goes back.
        for (final part in [game.atHome.play, game.atHome.win]) {
          await toNext(tester);
          await tester.tap(find.byKey(const Key('home next')));
          await tester.pumpAndSettle();
          expect(find.text(part.first), findsOneWidget);
        }
        if (game.id == 'gofish') await shot(tester, 'at_home_win_$phone');
        await toNext(tester);
        await tester.tap(find.byKey(const Key('home next')));
        await tester.pumpAndSettle();
        expect(find.text('Play at home'), findsOneWidget); // the preview's button
        expect(find.text('What you need'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
