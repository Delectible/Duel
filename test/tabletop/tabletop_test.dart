import 'dart:async';

import 'package:duel/core/account/account.dart';
import 'package:duel/core/online/party.dart';
import 'package:duel/core/session/play_setup.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:duel/features/tabletop/scorer/scorer_controller.dart';
import 'package:duel/features/tabletop/scorer/scorer_screen.dart';
import 'package:duel/main.dart';
import 'package:duel_engine/scoreboard/scoreboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../online/fake_server.dart';
import '../screens.dart';

Widget wrap(Widget home, Account a, {PlaySetup? setup}) => AccountScope(
  account: a,
  child: PlaySetupScope(
    setup: setup ?? PlaySetup(),
    child: MaterialApp(debugShowCheckedModeBanner: false, theme: Toon.theme(), home: home),
  ),
);

Future<void> settle(WidgetTester t, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  for (final MapEntry(key: phone, value: size) in phones.entries) {
    testWidgets('home → Tabletop: dice & tools, every Play at home guide ($phone)', (tester) async {
      usePhone(tester, size);
      final account = Account();
      await tester.pumpWidget(DuelApp(account: account, setup: PlaySetup()));
      await settle(tester);
      await tester.tap(find.byKey(const Key('tabletop')));
      await settle(tester);
      expect(find.byKey(const Key('score counter')), findsOneWidget);
      await shot(tester, 'tabletop_$phone');
      expect(tester.takeException(), isNull, reason: 'hybrid');
      await tester.tap(find.byKey(const Key('tabletop atHome')));
      await settle(tester);
      await shot(tester, 'tabletop_guides_$phone');
      expect(tester.takeException(), isNull, reason: 'guides');
      await tester.scrollUntilVisible(
        find.byKey(const Key('guide liars')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('guide liars')));
      await settle(tester);
      await shot(tester, 'tabletop_guide_$phone');
      expect(find.text('Play at home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final MapEntry(key: phone, value: size) in phones.entries) {
    testWidgets('score counter on this phone: new board, taps, keypad, undo, rounds ($phone)', (
      tester,
    ) async {
      usePhone(tester, size);
      final account = Account()..name = 'Luca';
      await tester.pumpWidget(wrap(const ScorerHome(), account));
      await settle(tester);
      await tester.tap(find.byKey(const Key('new board')));
      await settle(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('add player')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('add player')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('name field')), 'Sam');
      await tester.tap(find.byKey(const Key('name ok')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('start board')));
      await settle(tester);
      // Tap Luca's top half three times, Sam's bottom once.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('plus Luca')));
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.tap(find.byKey(const Key('minus Sam')));
      await tester.pump(const Duration(milliseconds: 100));
      await shot(tester, 'scorer_tiles_$phone');
      var b = ScoreBoard.fromJson(account.scoreBoards.first);
      expect(b.score(b.players.firstWhere((p) => p.name == 'Luca').id), 3);
      expect(b.score(b.players.firstWhere((p) => p.name == 'Sam').id), -1);
      // Hold for any amount.
      await tester.longPress(find.byKey(const Key('plus Sam')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('key 4')));
      await tester.tap(find.byKey(const Key('key 2')));
      await tester.pump();
      await shot(tester, 'scorer_keypad_$phone');
      await tester.tap(find.byKey(const Key('pad plus')));
      await settle(tester);
      b = ScoreBoard.fromJson(account.scoreBoards.first);
      expect(b.score(b.players.firstWhere((p) => p.name == 'Sam').id), 41);
      await tester.tap(find.byKey(const Key('undo')));
      await settle(tester);
      b = ScoreBoard.fromJson(account.scoreBoards.first);
      expect(b.score(b.players.firstWhere((p) => p.name == 'Sam').id), -1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('score counter: Spades works out the hand', (tester) async {
    usePhone(tester, phones['pixel9pro']!);
    final account = Account();
    await tester.pumpWidget(wrap(const ScorerSetup(), account));
    await settle(tester);
    await tester.tap(find.byKey(const Key('preset spades')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('start board')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('add round')));
    await settle(tester);
    await shot(tester, 'scorer_spades');
    await tester.tap(find.byKey(const Key('save round')));
    await settle(tester);
    final b = ScoreBoard.fromJson(account.scoreBoards.first);
    // Us bid 6, took 7 (61); Them bid 5, took 6 (51).
    expect([for (final p in b.players) b.score(p.id)], [61, 51]);
    await shot(tester, 'scorer_rounds');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the party board: add yourself once, score your own; the host does anything', (tester) async {
    usePhone(tester, phones['pixel9pro']!);
    final srv = FakeServer();
    final luca = PartyService(srv.player('luca'), account: Account()..name = 'Luca');
    final sam = PartyService(srv.player('sam'), account: Account()..name = 'Sam');
    Future<T> run<T>(Future<T> Function() f) async {
      late T result;
      var done = false;
      unawaited(
        f().then((v) {
          result = v;
          done = true;
        }),
      );
      for (var i = 0; i < 400 && !done; i++) {
        unawaited(srv.publish());
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(done, isTrue);
      return result;
    }

    await run(luca.create);
    await run(() => sam.join(luca.code!));
    final host = ScorerController.shared(account: luca.account, party: luca);
    final guest = ScorerController.shared(account: sam.account, party: sam);
    await settle(tester);
    expect(await run(() => host.addPlayer('Gran', 3)), isTrue);
    expect(await run(() => guest.addPlayer('Sam', 1, self: true)), isTrue);
    expect(await run(() => guest.addPlayer('Sam 2', 2, self: true)), isFalse);
    expect(await run(() => guest.addPlayer('Bob', 2)), isFalse);
    await settle(tester);
    final samP = guest.board.players.firstWhere((p) => p.name == 'Sam');
    final gran = guest.board.players.firstWhere((p) => p.name == 'Gran');
    expect(guest.canScore(samP), isTrue);
    expect(guest.canScore(gran), isFalse);
    expect(await run(() => guest.score(samP, 5)), isTrue);
    expect(await run(() => guest.score(gran, 5)), isFalse);
    expect(await run(() => host.apply({'op': 'settings', 'anyoneScores': true})), isTrue);
    await settle(tester);
    expect(await run(() => guest.score(gran, 2)), isTrue);
    await settle(tester);
    expect(host.board.score(gran.id), 2);
    expect(host.board.score(samP.id), 5);
    // On screen: the guest's view.
    await tester.pumpWidget(wrap(ScorerScreen(controller: guest), sam.account));
    await settle(tester);
    await shot(tester, 'scorer_party');
    expect(find.byKey(const Key('add me')), findsNothing);
    expect(tester.takeException(), isNull);
    host.dispose();
  });
}
