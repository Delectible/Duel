import 'package:duel/core/account/account.dart';
import 'package:duel/core/account/achievements.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:duel/games/poker/lounge/lounge_play.dart';
import 'package:duel/games/poker/ui/lounge_games.dart';
import 'package:duel/games/poker/ui/poker_controller.dart';
import 'package:duel/games/poker/ui/poker_screen.dart';
import 'package:duel_engine/difficulty.dart';
import 'dart:math';

import 'package:duel_engine/poker/reads.dart';
import 'package:duel_engine/poker/tournament.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';
import 'poker_screen_test.dart' show settleButtons, shuffleAndDeal, yourTurn;

Widget _app(Account account, Widget home) => AccountScope(
  account: account,
  child: MaterialApp(debugShowCheckedModeBanner: false, theme: Toon.theme(), home: home),
);

/// Your turns until the game's over or [done]: all in every time (quick
/// games), or folding ([shove] false: a long game).
Future<void> _play(WidgetTester tester, {bool Function()? done, bool shove = true, int steps = 40000}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (find.byKey(const Key('over title')).evaluate().isNotEmpty) return;
    if (done?.call() ?? false) return;
    if (await shuffleAndDeal(tester)) continue;
    if (!yourTurn()) continue;
    await settleButtons(tester);
    final raise = tester.widget<ToonButton>(find.byKey(const Key('raise')));
    if (shove && raise.onPressed != null) {
      await tester.tap(find.byKey(const Key('raise')));
      await settleButtons(tester);
      await tester.tap(find.byKey(const Key('quick All-in')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('confirm raise')));
    } else {
      await tester.tap(find.byKey(const Key('fold')));
    }
  }
}

/// A few frames for a page to slide in.
Future<void> _open(WidgetTester tester) async {
  for (var k = 0; k < 6; k++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  for (final phone in ['pixel9pro', 'small_land']) {
    testWidgets('$phone: the Boss Tables: challenge Lucky Lou, stake taken, the prize if you beat Lou', (
      tester,
    ) async {
      usePhone(tester, phones[phone]!);
      final account = Account()..setBalance(1000);
      await tester.pumpWidget(_app(account, const BossTablesScreen(pace: 0.05)));
      await tester.pump();
      await shot(tester, 'lounge_bosses_$phone');
      // Only the first boss is open.
      expect(tester.widget<ToonButton>(find.byKey(const Key('play boss 1'))).onPressed, isNull);
      await tester.tap(find.byKey(const Key('play boss 0')));
      await _open(tester);
      expect(find.byKey(const Key('over title')), findsNothing);
      expect(find.byType(PokerScreen), findsOneWidget);
      expect(account.balance, 800, reason: 'the stake');
      expect(account.loungeGame, isNotNull, reason: 'saved from the start');
      await shot(tester, 'boss_table_$phone');
      await _play(tester);
      expect(find.byKey(const Key('over title')), findsOneWidget);
      await shot(tester, 'boss_over_$phone');
      expect(account.loungeGame, isNull);
      expect(account.stats('bosses').played, 1);
      final beat = account.bossesBeaten == 1;
      expect(account.balance, beat ? anyOf(1400, 1600) : 800);
      expect(account.earned.containsKey(Achievement.bossLou), beat);
      expect(account.rivalRecord('Lucky Lou').wins + account.rivalRecord('Lucky Lou').losses, 1);
      expect(account.memoryOf('Lucky Lou').hands, greaterThan(0), reason: 'Lou remembers you');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a boss game left mid-way (the app closed) carries on from the same hand, stake and all', (
    tester,
  ) async {
    usePhone(tester, phones['pixel9pro']!);
    final account = Account()..setBalance(1000);
    await tester.pumpWidget(_app(account, const BossTablesScreen(pace: 0.05)));
    await tester.pump();
    await tester.tap(find.byKey(const Key('play boss 0')));
    await _open(tester);
    // A few hands, folding.
    await _play(
      tester,
      shove: false,
      done: () => ((account.loungeGame?['game'] as Map?)?['hands'] as int? ?? 0) >= 3,
    );
    final saved = account.loungeGame!;
    final stacks = (saved['game']! as Map)['stacks'];
    // The app closes.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(_app(account, const BossTablesScreen(pace: 0.05)));
    await tester.pump();
    expect(find.byKey(const Key('lounge continue')), findsOneWidget);
    expect(tester.widget<ToonButton>(find.byKey(const Key('play boss 0'))).onPressed, isNull);
    await shot(tester, 'lounge_continue');
    await tester.tap(find.byKey(const Key('continue lounge game')));
    await _open(tester);
    expect(find.byKey(const Key('over title')), findsNothing);
    expect(find.byType(PokerScreen), findsOneWidget);
    expect(account.balance, 800, reason: 'no second stake');
    final table = tester.widget<PokerScreen>(find.byType(PokerScreen));
    expect(table.lounge?.saved?['stacks'], stacks);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
    'a Regular tournament: buy in, 18 players, played to your finish; the record and the freeroll',
    (tester) async {
      usePhone(tester, phones['pixel9pro']!);
      final account = Account()..setBalance(1000);
      await tester.pumpWidget(_app(account, const TournamentScreen(pace: 0.05)));
      await tester.pump();
      await shot(tester, 'lounge_tournament');
      expect(
        tester.widget<ToonButton>(find.byKey(const Key('play main'))).onPressed,
        isNull,
        reason: 'locked',
      );
      await tester.tap(find.byKey(const Key('play regular')));
      await _open(tester);
      expect(find.text('Regular'), findsOneWidget);
      expect(find.textContaining('18 left'), findsOneWidget);
      expect(account.balance, 500);
      await shot(tester, 'tournament_table');
      await _play(tester);
      expect(find.byKey(const Key('over title')), findsOneWidget);
      expect(find.byKey(const Key('podium')), findsOneWidget);
      await shot(tester, 'tournament_over');
      final rec = account.tourneyRecord('regular');
      expect(rec.played, 1);
      expect(rec.best, inInclusiveRange(1, 18));
      final prize = switch (rec.best) {
        1 => 4500,
        2 => 2700,
        3 => 1800,
        _ => 0,
      };
      expect(account.balance, 500 + prize);
      expect(account.loungeGame, isNull);
      expect(tester.takeException(), isNull);
      // Back in the lobby: the freeroll, then it's gone for the day.
      await tester.ensureVisible(find.byKey(const Key('over leave')));
      await tester.tap(find.byKey(const Key('over leave')));
      await _open(tester);
      await tester.ensureVisible(find.byKey(const Key('play freeroll')));
      await tester.tap(find.byKey(const Key('play freeroll')));
      await _open(tester);
      expect(account.balance, 500 + prize, reason: 'free');
      expect(account.freerollPlayed, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets('a tournament played long (folding): tables break up and players come to your table', (
    tester,
  ) async {
    usePhone(tester, phones['small']!);
    final account = Account()..setBalance(1000);
    // A fixed shuffle, so the same things happen every run.
    await tester.pumpWidget(
      _app(
        account,
        PokerScreen.lounge(lounge: const LoungeGame.tournament(TournamentTier.regular), pace: 0.05, seed: 1),
      ),
    );
    await _open(tester);
    var fewest = tournamentTables, joined = false;
    await _play(
      tester,
      shove: false,
      done: () {
        final g = account.loungeGame?['game'] as Map?;
        if (g != null) fewest = min(fewest, Tournament.fromJson(g.cast<String, Object?>()).tables.length);
        joined |= find.textContaining('your table').evaluate().isNotEmpty;
        return false;
      },
    );
    expect(find.byKey(const Key('over title')), findsOneWidget);
    expect(fewest, lessThan(tournamentTables), reason: 'a table broke up while you were in');
    expect(joined, isTrue, reason: 'someone moved to your table');
    expect(account.tourneyRecord('regular').played, 1);
    expect(tester.takeException(), isNull);
  });

  test('bosses use what they remember of you, more up the ladder; they say so', () {
    final memory = ReadMemory().remember(
      PlayerReads()
        ..hands = 30
        ..facedBets = 12
        ..foldsToBet = 10,
    );
    expect(memoryLine(memory), contains('folding'));
    expect(memoryLine(ReadMemory()), isNull);
    expect(
      Boss.ladder.map((b) => b.memoryWeight),
      orderedEquals([...Boss.ladder.map((b) => b.memoryWeight)]..sort()),
    );
    expect(Boss.ladder.first.quirkStrength, greaterThan(Boss.ladder.last.quirkStrength));
    final b = Boss.ladder.first;
    final t = PokerController(
      bots: 3,
      difficulty: b.tableDifficulty,
      pace: 0,
      rival: b.rival,
      boss: b,
      rivalMemory: memory,
    );
    expect(t.personas[1].name, 'Lucky Lou');
    expect(t.title, 'vs Lucky Lou');
    expect(b.tableDifficulty, Difficulty.easy);
    t.dispose();
  });
}
