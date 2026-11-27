import 'dart:async';

import 'package:duel/core/account/account.dart';
import 'package:duel/core/online/party.dart';
import 'package:duel/core/session/play_setup.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:duel/features/tabletop/tabletop_screen.dart';
import 'package:duel/features/tabletop/tools/card_dealer.dart';
import 'package:duel/features/tabletop/tools/chip_bank.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../online/fake_server.dart';
import '../screens.dart';

Widget wrap(Widget home, Account a) => AccountScope(
  account: a,
  child: PlaySetupScope(
    setup: PlaySetup(),
    child: MaterialApp(debugShowCheckedModeBanner: false, theme: Toon.theme(), home: home),
  ),
);

Future<void> settle(WidgetTester t, [int n = 30]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> open(WidgetTester t, String key) async {
  await t.scrollUntilVisible(find.byKey(Key('tool $key')), 120, scrollable: find.byType(Scrollable).first);
  await t.tap(find.byKey(Key('tool $key')));
  await settle(t);
}

void main() {
  test('settle up: the fewest payments', () {
    final pays = settleUp({'A': 50, 'B': -30, 'C': -20, 'D': 0});
    expect(pays, [('B', 'A', 30), ('C', 'A', 20)]);
    expect(settleUp({'A': 10, 'B': 15, 'C': -25}), [('C', 'B', 15), ('C', 'A', 10)]);
  });

  for (final MapEntry(key: phone, value: size) in phones.entries) {
    testWidgets('Tabletop tools open and work ($phone)', (tester) async {
      usePhone(tester, size);
      final account = Account()..name = 'Luca';
      await tester.pumpWidget(wrap(const TabletopScreen(), account));
      await settle(tester);
      await shot(tester, 'tools_$phone');

      // Who goes first: three fingers, held.
      await open(tester, 'first');
      final area = tester.getRect(find.byKey(const Key('touch area')));
      final fingers = [
        for (final f in [const Offset(0.3, 0.3), const Offset(0.7, 0.4), const Offset(0.5, 0.75)])
          await tester.startGesture(
            Offset(area.left + area.width * f.dx, area.top + area.height * f.dy),
            pointer: 10 + f.hashCode % 50,
          ),
      ];
      await settle(tester, 50);
      await shot(tester, 'tool_first_$phone');
      for (final f in fingers) {
        await f.up();
      }
      await settle(tester, 4);
      await tester.pageBack();
      await settle(tester);

      // Teams.
      await open(tester, 'teams');
      await tester.tap(find.byKey(const Key('make teams')));
      await settle(tester, 30);
      expect(find.textContaining('Team Red'), findsOneWidget);
      await shot(tester, 'tool_teams_$phone');
      await tester.pageBack();
      await settle(tester);

      // Dice: roll, keep one, roll again.
      await open(tester, 'dice');
      await tester.tap(find.byKey(const Key('more dice')));
      await tester.tap(find.byKey(const Key('more dice')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('roll')));
      await settle(tester, 40);
      await tester.tap(find.byKey(const Key('die 0')));
      await tester.pump();
      expect(find.byKey(const Key('kept 0')), findsOneWidget);
      await tester.tap(find.byKey(const Key('roll')));
      await settle(tester, 40);
      await shot(tester, 'tool_dice_$phone');
      await tester.pageBack();
      await settle(tester);

      // Card dealer, one phone: deal, peek, play.
      await open(tester, 'dealer');
      await tester.tap(find.byKey(const Key('deal')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('deal 5')));
      await settle(tester);
      final peek = await tester.startGesture(tester.getCenter(find.byKey(const Key('peek'))));
      await tester.pump();
      final cards = find.byWidgetPredicate(
        (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('card '),
      );
      expect(cards, findsNWidgets(5));
      await shot(tester, 'tool_dealer_$phone');
      await peek.up();
      await tester.pump();
      expect(cards, findsNothing);
      await tester.tap(find.byKey(const Key('deck')));
      await settle(tester, 4);
      await tester.pageBack();
      await settle(tester);

      // Chip bank: two buy in, cash out, settle.
      await open(tester, 'chips');
      await tester.tap(find.byKey(const Key('buy in Luca')));
      final list = find.descendant(of: find.byType(ChipBank), matching: find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(find.byKey(const Key('buy in Player 2')), 60, scrollable: list);
      await tester.pump();
      await tester.tap(find.byKey(const Key('buy in Player 2')));
      await tester.pump();
      for (final (name, keys) in [
        ('Luca', ['3', '0']),
        ('Player 2', ['1', '0']),
      ]) {
        await tester.scrollUntilVisible(find.byKey(Key('cash out $name')), -60, scrollable: list);
        await tester.pump();
        await tester.tap(find.byKey(Key('cash out $name')));
        await settle(tester);
        for (final k in keys) {
          await tester.tap(find.byKey(Key('key $k')));
          await tester.pump();
        }
        await tester.tap(find.byKey(const Key('pad plus')));
        await settle(tester);
      }
      await shot(tester, 'tool_chips_$phone');
      expect(find.text('The chips add up.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('settle up')));
      await settle(tester);
      expect(find.text('Player 2'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('card dealer with the party: hands stay on their own phones', (tester) async {
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
    final host = DealerController.shared(luca);
    final guest = DealerController.shared(sam);
    await settle(tester);
    expect(await run(() => guest.apply({'op': 'deal', 'n': 5})), isFalse);
    expect(await run(() => host.apply({'op': 'deal', 'n': 5})), isTrue);
    for (var i = 0; i < 10; i++) {
      unawaited(srv.publish());
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(host.hand, hasLength(5));
    expect(guest.hand, hasLength(5));
    expect(host.hand.toSet().intersection(guest.hand.toSet()), isEmpty);
    final card = guest.hand.first;
    expect(await run(() => guest.apply({'op': 'play', 'card': '$card'})), isTrue);
    for (var i = 0; i < 10; i++) {
      unawaited(srv.publish());
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(host.pile.last, card);
    await tester.pumpWidget(wrap(CardDealer(controller: guest), sam.account));
    await settle(tester);
    await shot(tester, 'tool_dealer_party');
    expect(tester.takeException(), isNull);
    host.dispose();
  });
}
