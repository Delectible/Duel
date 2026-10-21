import 'package:duel/core/session/play_setup.dart';
import 'package:duel/games/catalog.dart';
import 'package:duel/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screens.dart';

void main() {
  for (final MapEntry(key: phone, value: size) in phones.entries) {
    testWidgets('home on $phone: games grey out by player count', (tester) async {
      usePhone(tester, size);
      final setup = PlaySetup()..botCount = 1;
      await tester.pumpWidget(DuelApp(setup: setup));
      await tester.pumpAndSettle();
      expect(find.text('Pick a game'), findsOneWidget);
      expect(find.text("Texas Hold'em"), findsOneWidget);
      expect(find.text('You + 1 bot · 2 players'), findsOneWidget);
      await shot(tester, 'home_$phone');

      await tester.tap(find.byTooltip('More bots'));
      await tester.pumpAndSettle();
      expect(setup.botCount, 2);
      expect(find.text('You + 2 bots · 3 players'), findsOneWidget);

      // Friend mode: a party of one can't play Hold'em (2+).
      await tester.tap(find.text('Friend'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Party · 1'), findsOneWidget);
      // Every game needs 2+ (the grid may scroll some off screen).
      expect(find.text('Needs 2+'), findsWidgets);
      expect(games.every((g) => g.blocked(setup)?.$1 == 'Needs 2+'), isTrue);
      await shot(tester, 'home_friend_$phone');
      await tester.tap(find.textContaining('Party · 1'));
      await tester.pumpAndSettle();
      expect(find.text('Your party'), findsOneWidget);
      await shot(tester, 'party_$phone');
    });
  }

  testWidgets('difficulty cycles; bot count stays 1..5', (tester) async {
    usePhone(tester, phones['pixel9pro']!);
    final setup = PlaySetup()..botCount = 5;
    await tester.pumpWidget(DuelApp(setup: setup));
    await tester.tap(find.text('Normal'));
    await tester.pump();
    expect(find.text('Hard'), findsOneWidget);
    await tester.tap(find.byTooltip('More bots'));
    await tester.pump();
    expect(setup.botCount, 5);
  });

  testWidgets('About shows the version', (tester) async {
    usePhone(tester, phones['pixel9pro']!);
    await tester.pumpWidget(DuelApp());
    await tester.tap(find.byKey(const Key('settings')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('about')), 200);
    await tester.tap(find.byKey(const Key('about')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Duel 0.'), findsWidgets); // the button and the sheet
  });

  testWidgets('turning the phone fades the new layout in', (tester) async {
    usePhone(tester, phones['pixel9pro']!);
    await tester.pumpWidget(DuelApp(setup: PlaySetup()));
    await tester.pumpAndSettle();
    double opacity() => tester.widget<FadeTransition>(find.byType(FadeTransition).first).opacity.value;
    expect(opacity(), 1);
    usePhone(tester, phones['pixel9pro_land']!);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(opacity(), lessThan(0.2));
    await tester.pumpAndSettle();
    expect(opacity(), 1);
    expect(find.text('Pick a game'), findsOneWidget);
  });

  testWidgets('on its side the system bars hide (a swipe brings them back); upright they show', (
    tester,
  ) async {
    final modes = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setEnabledSystemUIMode') modes.add('${call.arguments}');
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    usePhone(tester, phones['pixel9pro']!);
    await tester.pumpWidget(DuelApp(setup: PlaySetup()));
    await tester.pumpAndSettle();
    expect(modes.last, contains('edgeToEdge'));
    usePhone(tester, phones['pixel9pro_land']!);
    await tester.pumpAndSettle();
    expect(modes.last, contains('immersiveSticky'));
    usePhone(tester, phones['pixel9pro']!);
    await tester.pumpAndSettle();
    expect(modes.last, contains('edgeToEdge'));
  });
}
