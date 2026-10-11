import 'package:duel/core/session/play_setup.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:duel/features/preview/game_preview_screen.dart';
import 'package:duel/games/catalog.dart';
import 'package:duel/games/poker/ui/poker_screen.dart';
import 'package:duel/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screens.dart';

/// Whether Play! is on.
bool playOn(WidgetTester tester) =>
    tester.widget<ToonButton>(find.byKey(const Key('play'))).onPressed != null;

Future<void> openPreview(WidgetTester tester, GameInfo game) async {
  await tester.ensureVisible(find.text(game.name));
  await tester.pumpAndSettle();
  await tester.tap(find.text(game.name));
  await tester.pumpAndSettle();
  expect(find.byType(GamePreviewScreen), findsOneWidget);
}

void main() {
  test('every game has rules, a time per player count and a sample board', () {
    for (final g in games) {
      expect(g.rules, isNotEmpty, reason: g.name);
      for (var p = g.minPlayers; p <= g.maxPlayers; p++) {
        expect(g.minutes(p), greaterThan(0), reason: '${g.name} $p');
      }
    }
    final holdem = games.first;
    expect(holdem.minutes(2), lessThan(holdem.minutes(6)), reason: 'more players, longer game');
  });

  for (final MapEntry(key: phone, value: size) in phones.entries) {
    for (final game in games) {
      testWidgets('${game.name} preview on $phone', (tester) async {
        usePhone(tester, size);
        await tester.pumpWidget(DuelApp(setup: PlaySetup()..botCount = 1));
        await openPreview(tester, game);
        expect(find.text('How to play'), findsOneWidget);
        expect(find.textContaining('About ${game.minutes(2)} min · 2 players'), findsOneWidget);
        expect(playOn(tester), game.available);
        if (!game.available) expect(find.text('${game.name} is coming soon.'), findsOneWidget);
        await shot(tester, 'preview_${game.id}_$phone');
        expect(tester.takeException(), isNull);
        // Nevermind: back to the games, nothing started.
        await tester.tap(find.byKey(const Key('nevermind')));
        await tester.pumpAndSettle();
        expect(find.text('Pick a game'), findsOneWidget);
      });
    }
  }

  testWidgets("Play! starts Hold'em; leaving it goes back to the games", (tester) async {
    usePhone(tester, phones['pixel9pro']!);
    await tester.pumpWidget(DuelApp(setup: PlaySetup()..botCount = 3));
    await openPreview(tester, games.first);
    expect(find.textContaining('About 20 min · 4 players'), findsOneWidget);
    await tester.tap(find.byKey(const Key('play')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(PokerScreen), findsOneWidget);
    expect(find.byType(GamePreviewScreen), findsNothing);
  });

  testWidgets("Friend mode: the preview shows but Play! waits for online play", (tester) async {
    usePhone(tester, phones['pixel9pro']!);
    await tester.pumpWidget(DuelApp(setup: PlaySetup()..mode = PlayMode.friends));
    await openPreview(tester, games.first);
    expect(playOn(tester), isFalse);
    expect(find.textContaining('invite a friend'), findsOneWidget);
  });
}
