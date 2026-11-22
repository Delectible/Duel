import 'dart:async';

import 'package:duel/core/account/account.dart';
import 'package:duel/core/online/bj_service.dart';
import 'package:duel/core/online/party.dart';
import 'package:duel/core/session/play_setup.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:duel/games/blackjack/ui/bj_controller.dart';
import 'package:duel/games/blackjack/ui/bj_lobby.dart';
import 'package:duel/games/blackjack/ui/bj_screen.dart';
import 'package:duel_engine/blackjack/blackjack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';
import 'fake_server.dart';

/// The shared blackjack tables: the referee in memory, Luca's phone.
void main() {
  Future<T> Function<T>(Future<T> Function()) runner(WidgetTester tester) => <T>(f) async {
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
  };

  testWidgets('online table: rounds play out between the referee and the phone; the pips add up', (
    tester,
  ) async {
    usePhone(tester, phones['small']!);
    final srv = FakeServer(seed: 4);
    final account = Account()..name = 'Luca';
    account.bonus('test', 2900);
    final party = PartyService(srv.player('luca'), account: account);
    final service = BjService(party);
    final run = runner(tester);
    Future<void> wait([int ms = 400]) async {
      for (var i = 0; i < 4; i++) {
        srv.now = srv.now.add(Duration(milliseconds: ms ~/ 4));
        unawaited(srv.publish());
        await tester.pump(Duration(milliseconds: ms ~/ 4));
      }
    }

    await wait(1500);
    expect(account.balance, 3000);
    final doc = await run(() => service.sit('main'));
    final c = OnlineBjController(service: service, doc: doc, account: account, pace: 0.05);
    var rounds = 0, moves = 0, insured = 0;
    var lastRound = -1;
    for (var i = 0; i < 3000 && rounds < 6; i++) {
      await wait(150);
      if (c.canDeal) {
        c.deal();
      } else if (c.canInsure) {
        c.insure(insured.isEven);
        insured++;
      } else if (c.yourTurn) {
        c.act(c.round!.current.total < 12 ? BjMove.hit : BjMove.stand);
        moves++;
      }
      if (c.phase == BjPhase.paid && c.rounds != lastRound) {
        lastRound = c.rounds;
        rounds++;
      }
    }
    expect(rounds, 6, reason: 'rounds dealt and played to the end on the phone');
    expect(moves, greaterThan(0));
    // The referee moved the pips; the phone kept the stats.
    for (var i = 0; i < 20; i++) {
      await wait(300);
    }
    final st = account.stats('blackjack');
    expect(st.played, greaterThanOrEqualTo(6));
    final wallet = (await run(() => srv.store.get('wallets/luca')))!['balance']! as int;
    expect(account.balance, wallet);
    await run(c.leaveTable);
    c.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the floor: Online shows the shared tables with their rules; Local your house rules', (
    tester,
  ) async {
    usePhone(tester, phones['pixel9pro']!);
    final srv = FakeServer(seed: 4);
    final account = Account()..name = 'Luca';
    account.bonus('test', 2900);
    final party = PartyService(srv.player('luca'), account: account);
    Future<void> wait([int ms = 400]) async {
      for (var i = 0; i < 4; i++) {
        unawaited(srv.publish());
        await tester.pump(Duration(milliseconds: ms ~/ 4));
      }
    }

    await wait(1500);
    await tester.pumpWidget(
      AccountScope(
        account: account,
        child: PlaySetupScope(
          setup: PlaySetup(party: party),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: Toon.theme(),
            home: const BjLobby(pace: 0.05),
          ),
        ),
      ),
    );
    await wait(1200);
    expect(find.byKey(const Key('rules corner')), findsOneWidget);
    expect(find.byKey(const Key('house rules')), findsNothing);
    await shot(tester, 'bj_lobby_online');
    await tester.tap(find.byKey(const Key('where local')));
    await wait();
    expect(find.byKey(const Key('house rules')), findsOneWidget);
    expect(find.byKey(const Key('rules corner')), findsNothing);
    // Back online and sit at the Corner table.
    await tester.tap(find.byKey(const Key('where online')));
    await wait(1200);
    await tester.tap(find.byKey(const Key('sit 10')));
    await wait(1500);
    expect(find.byType(BjScreen), findsOneWidget);
    expect(find.textContaining('Online'), findsWidgets);
    await shot(tester, 'bj_table_online');
    await tester.pumpWidget(const SizedBox());
    await wait(4000);
  });
}
