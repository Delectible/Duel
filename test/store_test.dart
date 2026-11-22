import 'package:duel/core/account/account.dart';
import 'package:duel/core/avatars/faces.dart';
import 'package:duel/core/session/play_setup.dart';
import 'package:duel/core/store/cosmetics.dart';
import 'package:duel/core/store/daily.dart';
import 'package:duel/core/store/shop.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:duel/features/store/store_screen.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screens.dart';

Widget _wrap(Widget home, Account a) => AccountScope(
  account: a,
  child: PlaySetupScope(
    setup: PlaySetup(),
    child: MaterialApp(debugShowCheckedModeBanner: false, theme: Toon.theme(), home: home),
  ),
);

void main() {
  tearDown(() {
    CardBack.chosen = CardBack.classic;
    TableFelt.chosen = TableFelt.classic;
  });

  test('buying takes the pips, owns and wears the item; no credit', () {
    final a = Account()..setBalance(250);
    final crown = Shop.byId['hat.crown']!;
    expect(a.owns(crown), isFalse);
    expect(a.buy(crown), isNull, reason: 'not enough pips');
    final cowboy = Shop.byId['hat.cowboy']!;
    expect(a.buy(Shop.byId['hat.bow']!), isEmpty);
    expect(a.balance, 100);
    expect(a.avatar.hat, Hat.bow);
    expect(a.buy(cowboy), isNull);
    expect(a.buy(Shop.byId['hat.bow']!), isNull, reason: 'already yours');
  });

  test('card backs and felts change what the tables draw', () {
    final a = Account()..setBalance(1000);
    a.buy(Shop.byId['back.ghost']!);
    a.buy(Shop.byId['felt.ocean']!);
    expect(CardBack.chosen, CardBack.ghost);
    expect(Toon.felt, TableFelt.ocean.felt);
    // Saved and back on the next launch.
    final store = MemoryStore();
    final b = Account(store: store)..setBalance(1000);
    b.buy(Shop.byId['back.stars']!);
    CardBack.chosen = CardBack.classic;
    final again = Account(store: store);
    expect(again.cardBack, CardBack.stars);
    expect(CardBack.chosen, CardBack.stars);
    expect(again.owns(Shop.byId['back.stars']!), isTrue);
  });

  test('what you wore before the store opened is yours', () {
    final store = MemoryStore()..data = '{"name":"Old","face":{"hat":"crown","extra":"monocle"},"balance":5}';
    final a = Account(store: store);
    expect(a.owns(Shop.byId['hat.crown']!), isTrue);
    expect(a.owns(Shop.byId['extra.monocle']!), isTrue);
    expect(a.owns(Shop.byId['hat.halo']!), isFalse);
  });

  test('finishing a set pays its prize once', () {
    final a = Account()..setBalance(5000);
    final pirate = Shop.collections.firstWhere((c) => c.id == 'pirate');
    for (final id in pirate.items.take(3)) {
      expect(a.buy(Shop.byId[id]!), isEmpty);
    }
    final before = a.balance;
    final last = Shop.byId[pirate.items.last]!;
    expect(a.buy(last), [pirate]);
    expect(a.balance, before - last.price + pirate.prize);
    expect(a.collectionsDone, [pirate]);
  });

  test('daily challenges count games and pay once', () {
    final a = Account();
    final today = a.daily;
    expect(today, hasLength(3));
    // Play every game a few times, winning on Hard with a stake.
    for (var round = 0; round < 6; round++) {
      for (final (id, _) in dailyGames) {
        if (id == 'blackjack') {
          a.payout(id, staked: 10, back: 20);
        } else {
          a.settle(gameId: id, stake: 1, outcome: Outcome.win, opponents: 1, difficulty: Difficulty.hard);
        }
      }
    }
    for (var i = 0; i < 3; i++) {
      expect(a.dailyDone(i), isTrue, reason: today[i].title);
    }
    final before = a.balance;
    expect(a.claimDaily(0), isTrue);
    expect(a.claimDaily(0), isFalse);
    expect(a.balance, before + today[0].reward);
    expect(a.dailyReady, 2);
  });

  test('every set names real items, every day has three challenges', () {
    for (final c in Shop.collections) {
      for (final id in c.items) {
        expect(Shop.byId[id], isNotNull, reason: id);
        expect(Shop.byId[id]!.free, isFalse, reason: id);
      }
    }
    for (var d = 1; d <= 28; d++) {
      final day = Challenge.forDay('2026-12-${d.toString().padLeft(2, '0')}');
      expect(day.map((c) => c.title).toSet(), hasLength(3));
    }
  });

  for (final MapEntry(key: phone, value: size) in phones.entries) {
    testWidgets('store on $phone: try on, buy, wear; every shelf', (tester) async {
      usePhone(tester, size);
      final a = Account()..setBalance(1200);
      await tester.pumpWidget(_wrap(const StoreScreen(), a));
      await tester.pumpAndSettle();
      await shot(tester, 'store_daily_$phone');

      Future<void> tap(String key) async {
        // The shelves scroll; the tabs are at their top.
        if (key.startsWith('store ')) {
          await tester.drag(find.byType(ListView).last, const Offset(0, 3000));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
      }

      await tap('store face');
      await tap('shelf hat');
      await tap('item hat.cowboy');
      // Tried on, not bought.
      expect(a.avatar.hat, isNot(Hat.cowboy));
      await tester.ensureVisible(find.byKey(const Key('buy')));
      await tester.pumpAndSettle();
      await shot(tester, 'store_face_$phone');
      await tester.tap(find.byKey(const Key('buy')));
      await tester.pumpAndSettle();
      expect(a.avatar.hat, Hat.cowboy);
      expect(a.balance, 900);
      expect(find.byKey(const Key('wear')), findsOneWidget);

      await tap('store backs');
      await tap('item back.ghost');
      await shot(tester, 'store_backs_$phone');
      await tap('store felts');
      await tap('item felt.midnight');
      await shot(tester, 'store_felts_$phone');
      await tap('store sets');
      await shot(tester, 'store_sets_$phone');
      expect(tester.takeException(), isNull);
    });
  }
}
