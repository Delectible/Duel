import 'dart:math';

import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/poker/bot.dart';
import 'package:duel_engine/poker/poker_hand.dart';
import 'package:duel_engine/poker/reads.dart';
import 'package:duel_engine/poker/tournament.dart';
import 'package:flutter_test/flutter_test.dart';

Tournament _fresh(Random rng) => Tournament.fresh(
  you: 'You',
  yourLook: 'cap',
  bots: [
    for (var i = 1; i < tournamentPlayers; i++)
      (name: 'Bot$i', look: 'cap', style: BotStyle.values[i % BotStyle.values.length].name),
  ],
  rng: rng,
);

void main() {
  for (final seed in [1, 2, 3]) {
    test('bots play an 18-player tournament to the end (seed $seed): tables break, nobody shares a seat, '
        'you never move', () {
      final rng = Random(seed);
      var t = _fresh(rng);
      final home = t.you.table;
      final chips = tournamentPlayers * Tournament.startingStack;
      PokerBot bot(Entrant e) => PokerBot(style: e.botStyle, difficulty: Difficulty.normal, rng: rng);
      var rounds = 0;
      while (!t.over) {
        expect(++rounds, lessThan(400), reason: 'the blinds should end it');
        for (final table in t.tables) {
          t.playHand(table, bot, rng);
        }
        t.endRound();
        t.balance(rng);
        // Saved and restored between rounds, as the app does.
        t = Tournament.fromJson(t.toJson());
        expect(t.entrants.fold(0, (s, e) => s + e.stack), chips);
        final seats = <(int, int)>{};
        for (final e in t.entrants.where((e) => e.live)) {
          expect(seats.add((e.table, e.seat)), isTrue, reason: 'two players in one seat');
        }
        for (final table in t.tables) {
          expect(t.playersAt(table).length, lessThanOrEqualTo(tournamentSeats));
          if (t.tables.length > 1) expect(t.playersAt(table).length, greaterThanOrEqualTo(2));
        }
        if (t.you.live) expect(t.you.table, home, reason: 'you never move');
        if (t.left <= tournamentSeats) expect(t.tables.length, 1, reason: 'a final table');
      }
      expect({for (final e in t.entrants) e.place}, {for (var p = 1; p <= tournamentPlayers; p++) p});
      // About 20-30 minutes at a person's pace (a hand every ~25 s): ~50 rounds.
      expect(rounds, inInclusiveRange(30, 90));
    });
  }

  test('prizes: 50 / 30 / 20 of the pool', () {
    expect(Tournament.prize(9000, 1), 4500);
    expect(Tournament.prize(9000, 2), 2700);
    expect(Tournament.prize(9000, 3), 1800);
    expect(Tournament.prize(9000, 4), 0);
  });

  test('a bot remembers how you played, fading a little each game', () {
    final game = PlayerReads()
      ..hands = 40
      ..facedBets = 20
      ..foldsToBet = 16;
    var m = ReadMemory().remember(game);
    expect(m.hands, 40);
    m = m.remember(game);
    expect(m.hands, closeTo(64, 0.01));
    expect(m.reads.foldToBetRate, closeTo(0.8, 0.02));
    m = ReadMemory.fromJson(m.toJson()).remember(game);
    expect(m.hands, lessThanOrEqualTo(80), reason: 'capped');
    final now = PlayerReads()..hands = 2;
    expect(now.withMemory(m, 0.5).hands, closeTo(2 + m.hands / 2, 1));
    expect(now.hands, 2, reason: 'the game\'s own read is left alone');
  });

  group('boss quirks', () {
    // A spot: [bot] to act, facing a pot-sized bet on [board].
    PokerHand spot(List<String> board, {bool facingBet = true}) {
      final h = PokerHand(
        players: [HandPlayer(seat: 0, stack: 2000), HandPlayer(seat: 1, stack: 2000)],
        button: 0,
        smallBlind: 10,
        bigBlind: 20,
        rng: Random(1),
      );
      // Both limp in; then deal out streets by checking.
      while (h.street == Street.preflop) {
        h.apply(h.legalMoves().canCheck ? const Move.check() : const Move.call());
        if (h.toAct == null) h.nextStreet();
      }
      while (h.board.length < board.length) {
        h.apply(const Move.check());
        if (h.toAct == null) h.nextStreet();
      }
      if (facingBet) h.apply(Move.raiseTo(h.pot));
      return h;
    }

    test('Lucky Lou calls every river bet', () {
      var calls = 0, plainCalls = 0;
      for (var k = 0; k < 40; k++) {
        final h = spot(['a', 'b', 'c', 'd', 'e']);
        final lou = PokerBot(
          style: BotStyle.fish,
          difficulty: Difficulty.easy,
          rng: Random(k),
          quirk: Quirk.callsRivers,
        );
        final plain = PokerBot(style: BotStyle.fish, difficulty: Difficulty.easy, rng: Random(k));
        if (lou.decide(h).kind != MoveKind.fold) calls++;
        if (plain.decide(h).kind != MoveKind.fold) plainCalls++;
      }
      expect(calls, 40);
      expect(plainCalls, lessThan(40));
    });

    test('Captain Chaos raises almost every hand before the flop', () {
      var raises = 0;
      for (var k = 0; k < 60; k++) {
        final h = PokerHand(
          players: [for (var s = 0; s < 6; s++) HandPlayer(seat: s, stack: 2000)],
          button: 0,
          smallBlind: 10,
          bigBlind: 20,
          rng: Random(k),
        );
        final chaos = PokerBot(
          style: BotStyle.maniac,
          difficulty: Difficulty.normal,
          rng: Random(k),
          quirk: Quirk.raisesEverything,
        );
        if (chaos.decide(h).kind == MoveKind.raise) raises++;
      }
      expect(raises, greaterThan(45));
    });

    test('The Mime always takes the same time', () {
      final tempos = <double>{};
      for (var k = 0; k < 30; k++) {
        final h = PokerHand(
          players: [for (var s = 0; s < 4; s++) HandPlayer(seat: s, stack: 2000)],
          button: 0,
          smallBlind: 10,
          bigBlind: 20,
          rng: Random(k),
        );
        tempos.add(
          PokerBot(
            style: BotStyle.shark,
            difficulty: Difficulty.hard,
            rng: Random(k),
            quirk: Quirk.noTells,
          ).think(h).tempo,
        );
      }
      expect(tempos, {0.4});
    });
  });
}
