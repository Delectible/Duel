import 'dart:async';

import 'package:duel/core/account/account.dart';
import 'package:duel/core/online/party.dart';
import 'package:duel/core/avatars/faces.dart';
import 'package:duel/core/session/play_setup.dart';
import 'package:duel/games/poker/ui/table_view.dart';
import 'package:duel/main.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/poker/poker_hand.dart';
import 'package:duel_server/duel_server.dart' as server;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';
import 'fake_server.dart';

/// Texas Hold'em online: Luca's phone on screen, Sam's driven by its party
/// service, two bots run by the referee (in memory).
void main() {
  for (final MapEntry(key: phone, value: size) in phones.entries) {
    if (phone.startsWith('pixel')) continue;
    testWidgets('online poker on $phone: bots in the party, hands replayed to match the server', (
      tester,
    ) async {
      usePhone(tester, size);
      final srv = FakeServer(seed: 3);
      final account = Account()..name = 'Luca';
      final party = PartyService(srv.player('luca'), account: account);
      final sam = PartyService(srv.player('sam'), account: Account()..name = 'Sam');
      final setup = PlaySetup(party: party);

      Future<void> wait([int ms = 300]) async {
        for (var i = 0; i < 4; i++) {
          unawaited(srv.publish());
          await tester.pump(Duration(milliseconds: ms ~/ 4));
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
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(done, isTrue);
        return result;
      }

      await tester.pumpWidget(DuelApp(account: account, setup: setup, party: party));
      await wait();
      await tester.tap(find.text('Friend'));
      await wait();
      await tester.tap(find.textContaining('Party ·'));
      await wait();
      await tester.tap(find.byKey(const Key('create party')));
      await wait();
      expect(await run(() => sam.join(party.code!)), isNull);
      await wait();

      // The host adds two bots and makes one Hard.
      for (var i = 0; i < 2; i++) {
        await tester.ensureVisible(find.byKey(const Key('add bot')));
        await tester.tap(find.byKey(const Key('add bot')));
        await wait(600);
      }
      expect(party.bots, hasLength(2));
      expect(sam.bots, hasLength(2), reason: 'Sam sees them too');
      await tester.ensureVisible(find.byKey(const Key('bot 1 difficulty')));
      await tester.tap(find.byKey(const Key('bot 1 difficulty')));
      await wait(600);
      expect(party.bots.map((b) => b.difficulty), [Difficulty.normal, Difficulty.hard]);
      await shot(tester, 'online_bots_$phone');

      // Four in a Row doesn't fit four; Hold'em does. Host starts it.
      await tester.ensureVisible(find.byKey(const Key('pick game')));
      await tester.tap(find.byKey(const Key('pick game')));
      await wait(600);
      await tester.tap(find.text("Texas Hold'em"));
      await wait(600);
      await tester.tap(find.byKey(const Key('play')));
      await wait(1500);
      expect(find.byType(TableView), findsOneWidget);
      expect(sam.playing, isTrue);

      final table = tester.widget<TableView>(find.byType(TableView)).c;
      expect(table.personas.first.name, 'Luca');
      expect(table.personas.map((p) => p.name), containsAll(['Sam', ...party.bots.map((b) => b.name)]));

      /// The server's table, replayed from its secret state.
      server.PokerTable truth() {
        final id = party.match!['id'];
        return server.PokerGame.replay(
          ((srv.store.docs['secrets/$id']!['state']! as Map).cast<String, Object?>()),
        );
      }

      // Play a few hands: Luca taps Check / Call, Sam calls (or checks).
      var shotTaken = false;
      for (var step = 0; step < 400 && table.handNumber < 4 && party.playing; step++) {
        await wait(400);
        if (!shotTaken && table.yourTurn) {
          await shot(tester, 'online_poker_$phone');
          shotTaken = true;
        }
        if (find.byKey(const Key('next hand')).evaluate().isNotEmpty) {
          await tester.tap(find.byKey(const Key('next hand')));
          continue;
        }
        if (table.yourTurn && find.byKey(const Key('call')).evaluate().isNotEmpty) {
          await tester.tap(find.byKey(const Key('call')));
          continue;
        }
        final m = sam.match!;
        if (m['status'] == 'live' && m['turn'] == sam.seat) {
          final e = await run(() => sam.move({'kind': 'call'}));
          if (e != null) await run(() => sam.move({'kind': 'check'}));
        }
      }
      expect(table.handNumber, greaterThanOrEqualTo(2), reason: 'hands went by');
      // Between hands, every stack here is the server's.
      final t = truth();
      final me = party.seat;
      final n = table.personas.length;
      if (table.hand == null || table.hand!.street == Street.preflop) {
        for (var local = 0; local < n; local++) {
          final s = (local + me) % n;
          expect(
            table.game.players[local].stack + (table.handPlayer(local)?.committed ?? 0),
            t.game.players[s].stack + (t.hand.players.where((p) => p.seat == s).firstOrNull?.committed ?? 0),
            reason: 'seat $local',
          );
        }
      }
      expect(table.hand?.players[table.handIndex(0) ?? 0].hole.first, isNot(const Object()));
      expect(tester.takeException(), isNull);

      // Luca leaves: Sam is the only person left with the bots, so the game
      // ends (Sam's stake back); Luca's back home in the party.
      await tester.tap(find.byTooltip('Leave table'));
      await wait();
      await tester.tap(find.byKey(const Key('leave')));
      await wait(800);
      expect(find.byType(TableView), findsNothing);
      expect(sam.match!['status'], 'over');
      expect(sam.match!['result'], containsPair('reason', 'ended'));
      expect((sam.match!['result'] as Map)['left'], [party.seat]);
      await tester.pumpWidget(const SizedBox());
    }, timeout: const Timeout(Duration(minutes: 3)));
  }

  testWidgets('both people bust: the bots are placed, a full lineup on the card', (tester) async {
    usePhone(tester, phones['small']!);
    // The same deal as the referee's test (seed 6): the people go out first.
    final srv = FakeServer(seed: 6);
    final account = Account()..name = 'Luca';
    final party = PartyService(srv.player('luca'), account: account);
    final sam = PartyService(srv.player('sam'), account: Account()..name = 'Sam');

    Future<void> wait([int ms = 300]) async {
      for (var i = 0; i < 4; i++) {
        unawaited(srv.publish());
        await tester.pump(Duration(milliseconds: ms ~/ 4));
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
      for (var i = 0; i < 400 && !done; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(done, isTrue);
      return result;
    }

    await tester.pumpWidget(
      DuelApp(
        account: account,
        setup: PlaySetup(party: party),
        party: party,
      ),
    );
    await wait();
    await run(party.create);
    await run(() => sam.join(party.code!));
    await run(
      () => party.setBots(const [
        PartyBot(name: 'Pip', look: Look.cap, difficulty: Difficulty.easy),
        PartyBot(name: 'Finn', look: Look.fin, difficulty: Difficulty.hard),
      ]),
    );
    await run(() => party.start('holdem', stake: 10));
    await wait(1500);
    final table = tester.widget<TableView>(find.byType(TableView)).c;

    // Both shove whenever they can (as in the referee's test).
    for (var step = 0; step < 3000 && party.match!['status'] == 'live'; step++) {
      await wait(400);
      if (find.byKey(const Key('next hand')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('next hand')));
        continue;
      }
      if (table.yourTurn) {
        final legal = table.hand!.legalMoves();
        table.act(
          legal.canRaise
              ? Move.raiseTo(legal.maxRaiseTo)
              : legal.canCheck
              ? const Move.check()
              : const Move.call(),
        );
        continue;
      }
      final m = sam.match!;
      if (m['status'] == 'live' && m['turn'] == sam.seat) {
        Future<String?> go(String kind) => sam.move({'kind': kind, 'amount': 100000});
        if (await run(() => go('raise')) != null && await run(() => go('call')) != null) {
          await run(() => go('check'));
        }
      }
    }
    expect(party.match!['status'], 'over');
    expect((party.match!['state']! as Map)['simulated'], isTrue);
    for (var i = 0; i < 60 && find.byKey(const Key('lineup')).evaluate().isEmpty; i++) {
      await wait(500);
      if (find.byKey(const Key('next hand')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('next hand')));
      }
    }
    expect(find.byKey(const Key('lineup')), findsOneWidget);
    for (final place in ['1st', '2nd', '3rd', '4th']) {
      expect(
        find.descendant(of: find.byKey(const Key('lineup')), matching: find.text(place)),
        findsOneWidget,
      );
    }
    expect(find.textContaining('placed by their chances'), findsOneWidget);
    expect(find.text('Rematch'), findsOneWidget);
    await shot(tester, 'online_poker_lineup');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(minutes: 5)));
}
