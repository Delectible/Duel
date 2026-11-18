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
  test('how many hands someone plays: some read early, labelled, and judged against the table size', () {
    // The first hands: the count, not a label.
    expect(readNotes(_reads(hands: 3, vpip: 2)).join(' '), contains('Played 2 of 3 hands so far.'));
    expect(readNotes(_reads(hands: 2, vpip: 2)).join(' '), contains('Too soon'));
    // Three of the first six at a full table: a lot of hands, but only "Early", never "most".
    final early = readNotes(_reads(hands: 6, vpip: 3)).join(' ');
    expect(early, contains('Early: plays a lot of hands.'));
    expect(early, isNot(contains('most hands')));
    expect(early, contains('read in about 9 more hands'));
    // A few more of the same and it says most, still early.
    expect(readNotes(_reads(hands: 14, vpip: 9)).join(' '), contains('Early: plays most hands.'));
    // Heads-up, half your hands is normal.
    expect(readNotes(_reads(hands: 20, vpip: 10), players: 2).join(' '), isNot(contains('plays')));
    // Six-handed, half is a lot, and with enough hands there's no "Early".
    final late = readNotes(_reads(hands: 40, vpip: 20)).join(' ');
    expect(late, contains('Plays most hands.'));
    expect(late, isNot(contains('Early')));
    // A quarter at a full table: nothing to say about it.
    expect(readNotes(_reads(hands: 40, vpip: 10)).join(' '), isNot(contains('most hands')));
    // A quarter early on isn't "most" either (the complaint).
    expect(readNotes(_reads(hands: 8, vpip: 2)).join(' '), isNot(contains('most hands')));
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
