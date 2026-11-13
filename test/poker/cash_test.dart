import 'dart:math';

import 'package:duel/core/account/account.dart';
import 'package:duel/core/avatars/faces.dart';
import 'package:duel/core/session/play_setup.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:duel/games/poker/lounge/cash_lobby.dart';
import 'package:duel/games/poker/ui/cash_screen.dart';
import 'package:duel/games/poker/ui/poker_controller.dart';
import 'package:duel/games/poker/ui/table_view.dart';
import 'package:duel_engine/poker/cash.dart';
import 'package:duel_engine/poker/poker_hand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';

void main() {
  test('the bots play on while nobody watches; the table looks different later', () {
    final rng = Random(1);
    final t = CashTableState.fresh(CashStake.kitchen, rng, 0);
    final before = t.toJson().toString();
    final chipsBefore = t.seats.nonNulls.length;
    expect(chipsBefore, inInclusiveRange(3, 5));
    t.simulate(60 * 60 * 1000, rng);
    expect(t.hands, 120);
    expect(t.toJson().toString(), isNot(before));
    expect(t.filled, greaterThanOrEqualTo(2));
    // Round trip.
    expect(CashTableState.fromJson(t.toJson()).toJson().toString(), t.toJson().toString());
    // A person seated: no simulating (real hands are played).
    t.seats[t.seats.contains(null) ? t.seats.indexOf(null) : 0] = CashSeat(
      id: 'luca',
      name: 'Luca',
      stack: 1000,
    );
    final h = t.hands;
    t.simulate(3 * 60 * 60 * 1000, rng);
    expect(t.hands, h);
  });

  test('local tables are the same within a while, different later', () {
    final a = LocalCashTables.at(1000000000000);
    final b = LocalCashTables.at(1000000000000);
    expect(a.map((t) => t.toJson().toString()), b.map((t) => t.toJson().toString()));
    final c = LocalCashTables.at(1000000000000 + 3 * 60 * 60 * 1000);
    expect(c.first.toJson().toString(), isNot(a.first.toJson().toString()));
  });

  test('a cash table plays hand after hand; chips are conserved apart from rebuys', () async {
    final table = CashTableState.fresh(CashStake.backRoom, Random(3), 0);
    final c = CashController.sit(
      table: table,
      buyIn: 4000,
      you: const Persona.you(),
      pace: 0,
      rng: Random(4),
    );
    expect(c.game.players[0].stack, 4000);
    c.start();
    for (var i = 0; i < 4000 && c.handNumber < 12; i++) {
      await Future<void>.delayed(Duration.zero);
      if (c.phase == TablePhase.shuffle) {
        c.shuffleDeck();
        c.deal();
      }
      if (c.yourTurn) c.act(const Move.fold());
      if (c.waitingForYou) c.nextHand();
    }
    expect(c.handNumber, greaterThanOrEqualTo(12));
    expect(c.game.players.where((p) => !p.empty).length, greaterThanOrEqualTo(2));
    c.dispose();
  });

  for (final MapEntry(key: phone, value: size) in phones.entries) {
    testWidgets('$phone: the lobby, sitting down, topping up, cashing out', (tester) async {
      usePhone(tester, size);
      final account = Account()..cashIn(0);
      // Plenty of pips: the Back Room is open, the Penthouse locked.
      account.bonus('test', 9900);
      await tester.pumpWidget(
        AccountScope(
          account: account,
          child: PlaySetupScope(
            setup: PlaySetup(),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: Toon.theme(),
              home: const CashLobbyScreen(pace: 0.05),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('local tables')), findsOneWidget);
      await shot(tester, 'cash_lobby_$phone');
      await tester.tap(find.byKey(const Key('table kitchen')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('buy in')), findsOneWidget);
      await tester.tap(find.byKey(const Key('buy in go')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CashScreen), findsOneWidget);
      expect(account.balance, 10000 - 1000);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(TableView), findsOneWidget);
      await shot(tester, 'cash_table_$phone');
      await tester.tap(find.byKey(const Key('leave')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('cash out')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('cash lobby')), findsOneWidget);
      expect(account.atCashTable, isFalse);
      expect(account.balance, greaterThan(9000 - 1000), reason: 'most of the chips came back');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 20));
    });
  }
}
