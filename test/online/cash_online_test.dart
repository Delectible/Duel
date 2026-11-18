import 'dart:math';
import 'dart:async';

import 'package:duel/core/account/account.dart';
import 'package:duel/core/online/cash_service.dart';
import 'package:duel/core/online/party.dart';
import 'package:duel/core/session/play_setup.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:duel/games/poker/lounge/cash_lobby.dart';
import 'package:duel/games/poker/ui/action_bar.dart';
import 'package:duel/games/poker/ui/cash_screen.dart';
import 'package:duel/games/poker/ui/poker_controller.dart';
import 'package:duel/games/poker/ui/table_view.dart';
import 'package:duel_engine/poker/cash.dart';
import 'package:duel_engine/poker/poker_hand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';
import 'fake_server.dart';

/// The shared cash tables: Luca's phone on screen, Sam's driven by its
/// service, the referee in memory.
void main() {
  for (final MapEntry(key: phone, value: size) in phones.entries) {
    if (phone.startsWith('pixel')) continue;
    testWidgets('$phone: shared tables online; a friend shows in the lobby; offline, local tables', (
      tester,
    ) async {
      usePhone(tester, size);
      final srv = FakeServer(seed: 5);
      final account = Account()..name = 'Luca';
      account.bonus('test', 2900);
      final party = PartyService(srv.player('luca'), account: account);
      final samParty = PartyService(
        srv.player('sam'),
        account: Account()
          ..name = 'Sam'
          ..bonus('test', 2900),
      );
      final sam = CashService(samParty);

      Future<void> wait([int ms = 400]) async {
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

      await wait(1500);
      // Sam sits at the Kitchen Table first.
      await run(() => sam.sit(CashStake.kitchen, 600));
      await tester.pumpWidget(
        AccountScope(
          account: account,
          child: PlaySetupScope(
            setup: PlaySetup(party: party),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: Toon.theme(),
              home: const CashLobbyScreen(pace: 0.05),
            ),
          ),
        ),
      );
      // Opening: a moment finding the shared tables, never this phone's first.
      expect(find.byKey(const Key('finding tables')), findsOneWidget);
      expect(find.byKey(const Key('local tables')), findsNothing);
      await wait(800);
      expect(find.byKey(const Key('online tables')), findsOneWidget);
      expect(find.textContaining('1 person here: Sam'), findsOneWidget);
      await shot(tester, 'cash_lobby_online_$phone');

      // Luca joins Sam.
      await tester.tap(find.byKey(const Key('table kitchen')));
      await wait();
      await pickSeat(tester, () => wait());
      await tester.tap(find.byKey(const Key('buy in go')));
      await wait(1200);
      expect(find.byType(CashScreen), findsOneWidget);
      expect(find.byKey(const Key('online tables')), findsOneWidget);
      expect(find.byType(TableView), findsOneWidget);
      expect(account.balance, 2000, reason: 'the referee took the buy-in');
      await shot(tester, 'cash_table_online_$phone');
      final t = CashTableState.fromJson((await run(() => srv.store.get('cash/kitchen')))!);
      expect(t.people.map((p) => p.name), containsAll(['Luca', 'Sam']));

      // The network goes: the lobby quietly shows this phone's tables.
      await tester.tap(find.byKey(const Key('leave')));
      await wait();
      await tester.tap(find.byKey(const Key('cash out')));
      await wait(1200);
      expect(find.byKey(const Key('cash lobby')), findsOneWidget);
      srv.offline = true;
      await wait(16000);
      expect(find.byKey(const Key('local tables')), findsOneWidget);
      expect(find.textContaining('Sam'), findsNothing);
      srv.offline = false;
      await wait(16000);
      expect(find.byKey(const Key('online tables')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await wait(16000);
    });
  }

  testWidgets('online table: hands play out between the server and the phone', (tester) async {
    usePhone(tester, phones['small']!);
    final srv = FakeServer(seed: 5);
    final account = Account()..name = 'Luca';
    account.bonus('test', 2900);
    final party = PartyService(srv.player('luca'), account: account);
    final service = CashService(party);

    // The referee's clock and the phone's run on the test's time.
    Future<void> wait([int ms = 400]) async {
      for (var i = 0; i < 4; i++) {
        srv.now = srv.now.add(Duration(milliseconds: ms ~/ 4));
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
      for (var i = 0; i < 300 && !done; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(done, isTrue);
      return result;
    }

    await wait(1500);
    expect(account.balance, 3000);
    final doc = await run(() => service.sit(CashStake.kitchen, 1000));
    await wait();
    expect(account.balance, 2000, reason: 'the referee took the buy-in');
    final c = OnlineCashController.forTable(
      service,
      doc,
      you: account.persona,
      pace: 0.05,
      clock: () => srv.now,
    );
    c.start();
    var acted = 0;
    for (var i = 0; i < 600 && acted < 6; i++) {
      await wait(200);
      if (c.yourTurn) {
        c.act(const Move.fold());
        acted++;
      }
      if (c.waitingForYou) c.nextHand();
    }
    expect(acted, greaterThanOrEqualTo(6), reason: 'several hands dealt to the phone');
    await run(c.leave);
    for (var i = 0; i < 100 && service.uid != null; i++) {
      await wait(400);
      final t = await run(() => srv.store.get('cash/kitchen'));
      if (!CashTableState.fromJson(t!).people.any((s) => s.id == 'luca')) break;
      srv.now = srv.now.add(const Duration(seconds: 10));
      await run(() => service.tick(CashStake.kitchen));
    }
    await wait(800);
    expect(account.balance, greaterThan(2000), reason: 'cashed out what was left');
    c.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('online table at real pace: the next hand comes quickly; no clock under a bot; your 30 s start '
      'when your turn shows', (tester) async {
    usePhone(tester, phones['small']!);
    final srv = FakeServer(seed: 9);
    final account = Account()..name = 'Luca';
    account.bonus('test', 2900);
    final party = PartyService(srv.player('luca'), account: account);
    final service = CashService(party);
    Future<void> wait([int ms = 400]) async {
      for (var i = 0; i < 4; i++) {
        srv.now = srv.now.add(Duration(milliseconds: ms ~/ 4));
        unawaited(srv.publish());
        await tester.pump(Duration(milliseconds: ms ~/ 4));
      }
    }

    await wait(1500);
    late Doc doc;
    var sat = false;
    unawaited(
      service.sit(CashStake.kitchen, 1000).then((d) {
        doc = d;
        sat = true;
      }),
    );
    for (var i = 0; i < 50 && !sat; i++) {
      await wait(100);
    }
    final c = OnlineCashController.forTable(service, doc, you: account.persona, clock: () => srv.now);
    c.start();
    var turns = 0, lastHand = c.handNumber;
    int? turnAt, resultAt;
    final myClock = <int>[], gaps = <int>[];
    var botClock = 0;
    for (var i = 0; i < 12000 && gaps.length < 8; i++) {
      await wait(100);
      final ms = srv.now.millisecondsSinceEpoch;
      final seat = c.actingSeat;
      if (seat != null && seat != 0 && c.turnSecondsLeft != null) botClock++;
      if (c.phase == TablePhase.payout && resultAt == null) resultAt = ms;
      if (c.handNumber != lastHand) {
        lastHand = c.handNumber;
        if (resultAt != null) gaps.add(ms - resultAt);
        resultAt = null;
      }
      if (c.yourTurn) {
        turnAt ??= ms;
        if (ms - turnAt == 0) myClock.add(c.turnSecondsLeft ?? 0);
        // A person takes a moment, then calls (or checks), or folds now and then.
        if (ms - turnAt >= 1500) {
          c.act(turns % 3 == 2 ? const Move.fold() : const Move.call());
          turns++;
          turnAt = null;
        }
      }
    }
    expect(gaps.length, 8, reason: 'kept playing');
    expect(botClock, 0, reason: 'a countdown only on a person');
    expect(
      myClock.reduce(min),
      greaterThanOrEqualTo(25),
      reason: 'your time starts when your turn shows: $myClock',
    );
    // From the result going up to the next deal: the result's own few seconds, then straight on.
    expect(gaps.reduce(max), lessThanOrEqualTo(6000), reason: 'gaps $gaps');
    c.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
    'online table: say a line (a friend sees it), the bots talk, tick a move ahead, sit out and come back',
    (tester) async {
      usePhone(tester, phones['small']!);
      final srv = FakeServer(seed: 9);
      final account = Account()..name = 'Luca';
      account.bonus('test', 2900);
      final party = PartyService(srv.player('luca'), account: account);
      final service = CashService(party);
      final samParty = PartyService(
        srv.player('sam'),
        account: Account()
          ..name = 'Sam'
          ..bonus('test', 2900),
      );
      final sam = CashService(samParty);
      Future<void> wait([int ms = 400]) async {
        for (var i = 0; i < 4; i++) {
          srv.now = srv.now.add(Duration(milliseconds: ms ~/ 4));
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
        for (var i = 0; i < 300 && !done; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(done, isTrue);
        return result;
      }

      await wait(1500);
      final doc = await run(() => service.sit(CashStake.kitchen, 1000));
      await run(() => sam.sit(CashStake.kitchen, 1000));
      final c = OnlineCashController.forTable(
        service,
        doc,
        you: account.persona,
        pace: 0.05,
        clock: () => srv.now,
      );
      c.start();
      await tester.pumpWidget(
        MaterialApp(
          theme: Toon.theme(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              // As the table screen does: rebuilt whenever the table changes.
              child: ListenableBuilder(
                listenable: c,
                builder: (context, _) => ActionBar(c: c),
              ),
            ),
          ),
        ),
      );
      await wait();
      int samSeat() => c.state.seats.indexWhere((s) => s?.id == 'sam');
      int local(int server) => (server - c.state.seats.indexWhere((s) => s?.id == 'luca')) % cashSeats;

      // Sam says something: a bubble by Sam on Luca's table.
      await run(() => sam.say(CashStake.kitchen, 0));
      await wait();
      expect(c.talk[local(samSeat())]?.text, cashChatLines[0]);
      // Luca says something: everyone's table hears it.
      c.say(3);
      await wait();
      expect(c.talk[0]?.text, cashChatLines[3]);
      expect(((await run(() => srv.store.get('cash/kitchen')))!['said']! as Map)['line'], 3);

      // Play a while: Sam calls; Luca ticks Check / Fold ahead and never taps.
      // Luca's moves as the table saw them.
      int moves() {
        final r = c.reads.players[0];
        return r.folds + r.checks + r.calls + r.bets + r.raises;
      }

      var botTalked = false, autoActed = 0, ticked = false, tickedAt = 0, turnFrames = 0;
      for (var i = 0; i < 3000 && (autoActed < 3 || !botTalked); i++) {
        await wait(100);
        for (final e in c.talk.entries) {
          final s = c.state.seats[(e.key + c.state.seats.indexWhere((x) => x?.id == 'luca')) % cashSeats];
          if (s != null && s.bot) botTalked = true;
        }
        final turn = (await run(() => srv.store.get('cash/kitchen')))!['turn'];
        if (turn == samSeat()) {
          final d = (await run(() => srv.store.get('cash/kitchen')))!;
          await run(
            () => sam
                .move(CashStake.kitchen, d['version']! as int, {'kind': 'call'})
                .catchError((Object _) => d),
          );
        }
        // A move made since the tick, without a tap: the tick made it.
        if (ticked && moves() > tickedAt) {
          autoActed++;
          ticked = false;
        }
        if (!ticked && find.byKey(const Key('pre checkFold')).evaluate().isNotEmpty) {
          await tester.tap(find.byKey(const Key('pre checkFold')));
          ticked = true;
          tickedAt = moves();
        }
        // Your turn: with a tick it goes by itself at once; without, answer it.
        turnFrames = c.yourTurn ? turnFrames + 1 : 0;
        if (c.yourTurn && ticked) {
          expect(turnFrames, lessThan(4), reason: 'the ticked move should go at once');
        }
        if (c.yourTurn && !ticked) c.act(const Move.fold());
        if (c.waitingForYou) c.nextHand();
      }
      expect(c.state.seats.firstWhere((x) => x?.id == 'luca')!.timeouts, 0, reason: 'no turn ran out');
      expect(autoActed, greaterThan(0), reason: 'the ticked move was made on its own');
      expect(botTalked, isTrue, reason: 'bots talk online too');

      // Sit out: dealt out, the seat kept; I'm back.
      await run(() => c.setSittingOut(true));
      await wait();
      expect(c.sittingOut, isTrue);
      // Once this hand's result is read, the bar says so.
      for (var i = 0; i < 100 && find.byKey(const Key('back in')).evaluate().isEmpty; i++) {
        if (c.waitingForYou) c.nextHand();
        await wait(100);
      }
      expect(find.byKey(const Key('back in')), findsOneWidget);
      await tester.tap(find.byKey(const Key('back in')));
      await wait();
      await wait();
      expect(c.sittingOut, isFalse);
      expect(tester.takeException(), isNull);
      c.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
  );

  for (final silent in [false, true]) {
    testWidgets('online table: a phone slower than the server (bots shown thinking) keeps up'
        '${silent ? '; live updates go quiet for a while' : ''}', (tester) async {
      usePhone(tester, phones['small']!);
      final srv = FakeServer(seed: 5);
      final account = Account()..name = 'Luca';
      account.bonus('test', 2900);
      final party = PartyService(srv.player('luca'), account: account);
      final service = CashService(party);

      var quiet = false;
      // The referee's clock and the phone's run on the test's time.
      Future<void> wait([int ms = 400]) async {
        for (var i = 0; i < 4; i++) {
          srv.now = srv.now.add(Duration(milliseconds: ms ~/ 4));
          // Quiet: nothing reaches the phone but what it asks for itself.
          if (!quiet) unawaited(srv.publish());
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
        for (var i = 0; i < 300 && !done; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(done, isTrue);
        return result;
      }

      await wait(1500);
      expect(account.balance, 3000);
      final doc = await run(() => service.sit(CashStake.kitchen, 1000));
      await wait();
      expect(account.balance, 2000, reason: 'the referee took the buy-in');
      final c = OnlineCashController.forTable(service, doc, you: account.persona, clock: () => srv.now);
      c.start();
      // At the bots' real pace the server finishes each hand (and may deal the
      // next) long before this phone has shown it: it must never stall.
      var acted = 0;
      var timedOut = -1;
      for (var i = 0; i < 3000 && acted < 6; i++) {
        quiet = silent && i >= 100 && i < 400;
        await wait(200);
        // Another phone at the table asks for the next hand as soon as it may.
        if (i % 5 == 0) unawaited(service.tick(CashStake.kitchen).then((_) {}, onError: (Object _) {}));
        // The first turn is left to run out: the server folds for you.
        if (c.yourTurn && timedOut < 0) timedOut = i;
        if (c.yourTurn && i > timedOut + 250) {
          c.act(const Move.fold());
          acted++;
        }
        if (c.waitingForYou) c.nextHand();
      }
      expect(acted, greaterThanOrEqualTo(6), reason: 'several hands dealt to the phone');
      await run(c.leave);
      for (var i = 0; i < 100 && service.uid != null; i++) {
        await wait(400);
        final t = await run(() => srv.store.get('cash/kitchen'));
        if (!CashTableState.fromJson(t!).people.any((s) => s.id == 'luca')) break;
        srv.now = srv.now.add(const Duration(seconds: 10));
        await run(() => service.tick(CashStake.kitchen));
      }
      await wait(800);
      expect(account.balance, greaterThan(2000), reason: 'cashed out what was left');
      c.dispose();
      await tester.pumpWidget(const SizedBox());
    });
  }
}
