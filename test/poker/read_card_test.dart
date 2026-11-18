import 'package:duel/core/theme/toon.dart';
import 'package:duel/games/poker/ui/poker_screen.dart';
import 'package:duel/games/poker/ui/table_stats.dart';
import 'package:duel/games/poker/ui/table_view.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/poker/reads.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';

PlayerReads _reads({required int hands, required int vpip, int pfr = 0}) => PlayerReads()
  ..hands = hands
  ..vpip = vpip
  ..pfr = pfr;

void main() {
  test('how many hands someone plays is judged on enough hands and against the table size', () {
    // Three of the first six: too few to call it.
    expect(readNotes(_reads(hands: 6, vpip: 3)).join(' '), isNot(contains('most hands')));
    expect(readNotes(_reads(hands: 6, vpip: 3)).join(' '), contains('read in about 9 more hands'));
    // Heads-up, half your hands is normal.
    expect(readNotes(_reads(hands: 20, vpip: 10), players: 2).join(' '), isNot(contains('hands.')));
    // Six-handed, half is a lot.
    expect(readNotes(_reads(hands: 40, vpip: 20)).join(' '), contains('Plays most hands.'));
    // A quarter at a full table: nothing to say about it.
    expect(readNotes(_reads(hands: 40, vpip: 10)).join(' '), isNot(contains('most hands')));
    // Early on it says so.
    expect(readNotes(_reads(hands: 14, vpip: 9)).join(' '), contains('So far: plays most hands.'));
  });

  test('once there is a read, a line on what kind of player', () {
    final lag = PlayerReads()
      ..hands = 30
      ..vpip = 15
      ..pfr = 10
      ..bets = 10
      ..raises = 6
      ..calls = 4;
    expect(playerType(lag, players: 6), startsWith('Loose and aggressive'));
    final rock = PlayerReads()
      ..hands = 30
      ..vpip = 3
      ..bets = 1
      ..calls = 6;
    expect(playerType(rock, players: 6), startsWith('Tight and passive'));
    expect(playerType(PlayerReads()..hands = 5, players: 6), isNull);
  });

  testWidgets('the flame and target by a name are explained on their read card', (tester) async {
    usePhone(tester, phones['pixel9pro']!);
    await tester.pumpWidget(
      MaterialApp(
        theme: Toon.theme(),
        home: const PokerScreen(bots: 3, difficulty: Difficulty.easy, pace: 0.05, seed: 3),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final c = tester.widget<TableView>(find.byType(TableView)).c;
    Future<void> open(int seat) async {
      await tester.tap(find.byKey(Key('read $seat')));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await open(1);
    expect(find.byKey(const Key('badge rival')), findsOneWidget);
    expect(find.textContaining('a read in ~'), findsOneWidget);
    await shot(tester, 'read_card_rival');
    await tester.tapAt(const Offset(20, 40));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await open(c.bountySeat!);
    expect(find.byKey(const Key('badge bounty')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
