import 'dart:async';

import 'package:duel/core/account/account.dart';
import 'package:duel/core/avatars/faces.dart';
import 'package:duel/core/online/party.dart';
import 'package:duel/core/session/play_setup.dart';
import 'package:duel/games/poker/ui/table_view.dart';
import 'package:duel/main.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';
import 'fake_server.dart';

/// Leaving and coming back, with three friends and a bot at Hold'em: one
/// phone on screen, the others driven by their party services.
void main() {
  late FakeServer srv;
  late WidgetTester t;

  Future<void> wait([int ms = 300]) async {
    for (var i = 0; i < 4; i++) {
      unawaited(srv.publish());
      await t.pump(Duration(milliseconds: ms ~/ 4));
    }
  }

  Future<T> run<T>(Future<T> Function() f) async {
    late T result;
    var done = false;
    unawaited(
      f().then((v) {
        result = v;
        done = true;
      }),
    );
    for (var i = 0; i < 200 && !done; i++) {
      unawaited(srv.publish());
      await t.pump(const Duration(milliseconds: 20));
    }
    expect(done, isTrue);
    return result;
  }

  /// Three in a party (the first one is the host) with a bot, Hold'em on.
  Future<List<PartyService>> table(List<(String, Account)> who) async {
    final parties = [for (final (uid, a) in who) PartyService(srv.player(uid), account: a)];
    expect(await run(() => parties.first.create()), isNull);
    for (final p in parties.skip(1)) {
      expect(await run(() => p.join(parties.first.code!)), isNull);
    }
    expect(
      await run(
        () =>
            parties.first.setBots([const PartyBot(name: 'Pip', look: Look.cap, difficulty: Difficulty.easy)]),
      ),
      isNull,
    );
    expect(await run(() => parties.first.start('holdem', stake: 10)), isNull);
    await wait(600);
    return parties;
  }

  for (final MapEntry(key: phone, value: size) in phones.entries) {
    if (phone.startsWith('pixel')) continue;
    testWidgets('$phone: someone leaves, the host brings in a bot, they come back; then the host ends it', (
      tester,
    ) async {
      t = tester;
      usePhone(tester, size);
      srv = FakeServer(seed: 3);
      final luca = Account()..name = 'Luca', sam = Account()..name = 'Sam', kit = Account()..name = 'Kit';
      final [host, samP, kitP] = await table([('luca', luca), ('sam', sam), ('kit', kit)]);
      final setup = PlaySetup(party: host);
      await tester.pumpWidget(DuelApp(account: luca, setup: setup, party: host));
      await wait(1500);
      expect(find.byType(TableView), findsOneWidget, reason: 'the game opened by itself');

      // Sam leaves (losing the stake): Luca's table pauses and asks.
      final samBefore = sam.balance;
      expect(await run(() => samP.forfeit(stake: 10)), isNull);
      await wait();
      expect(samP.leftGame, isTrue);
      expect(find.byKey(const Key('paused')), findsOneWidget);
      expect(find.byKey(const Key('bring in bot')), findsOneWidget);
      expect(kitP.deciding, isFalse, reason: 'only the host decides');
      await shot(tester, 'lobby_paused_$phone');
      await tester.tap(find.byKey(const Key('bring in bot')));
      await wait(800);
      expect(find.byKey(const Key('paused')), findsNothing);
      expect(find.textContaining('Sam (bot)'), findsOneWidget, reason: 'the bot plays as Sam');

      // Sam comes back: the seat as it stands, and the stake back in.
      expect(await run(() => samP.rejoin()), isNull);
      await wait(800);
      expect(samP.inGame, isTrue);
      expect(sam.balance, samBefore + 10, reason: 'rejoining undoes the lost stake');
      expect(find.textContaining('Sam (bot)'), findsNothing);

      // Kit leaves; this time Luca ends the game: stakes back for those in.
      final lucaBefore = luca.balance;
      expect(await run(() => kitP.forfeit(stake: 10)), isNull);
      await wait();
      await tester.tap(find.byKey(const Key('end game')));
      await wait(800);
      expect(host.match!['result'], containsPair('reason', 'ended'));
      expect(find.text('Game ended'), findsOneWidget);
      expect(find.textContaining('Kit left'), findsOneWidget);
      expect(luca.balance, lucaBefore + 10, reason: 'Luca gets the stake back');
      await shot(tester, 'lobby_ended_$phone');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, timeout: const Timeout(Duration(minutes: 3)));

    testWidgets('$phone: whoever left sees Game In Progress and can rejoin', (tester) async {
      t = tester;
      usePhone(tester, size);
      srv = FakeServer(seed: 4);
      final luca = Account()..name = 'Luca', sam = Account()..name = 'Sam', kit = Account()..name = 'Kit';
      final [host, samP, _] = await table([('luca', luca), ('sam', sam), ('kit', kit)]);
      // Sam's phone on screen; Sam left (the host has a bot sit in).
      final setup = PlaySetup(party: samP)..mode = PlayMode.friends;
      await tester.pumpWidget(DuelApp(account: sam, setup: setup, party: samP));
      await wait(1500);
      expect(find.byType(TableView), findsOneWidget);
      await tester.tap(find.byTooltip('Leave table'));
      await wait();
      await tester.tap(find.byKey(const Key('leave')));
      await wait(800);
      expect(find.byType(TableView), findsNothing);
      expect(await run(() => host.decide('bot')), isNull);
      await wait(800);
      expect(find.byType(TableView), findsNothing, reason: "the game doesn't pull Sam back in");

      // Another game can't be started; this one says Game In Progress.
      await tester.tap(find.text("Texas Hold'em"));
      await wait(600);
      expect(find.text('Game In Progress'), findsOneWidget);
      await shot(tester, 'lobby_in_progress_$phone');
      await tester.tap(find.byKey(const Key('rejoin')));
      await wait();
      expect(find.byKey(const Key('rejoin dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('yes')));
      await wait(1500);
      expect(samP.inGame, isTrue);
      expect(find.byType(TableView), findsOneWidget, reason: 'back at the table');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}
