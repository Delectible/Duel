import 'dart:math';

import 'package:duel_engine/cards.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/poker/bot.dart';
import 'package:duel_engine/poker/poker_hand.dart';
import 'package:duel_engine/poker/reads.dart';
import 'package:duel_engine/poker/sit_and_go.dart';
import 'package:duel/games/poker/ui/table_stats.dart';
import 'package:flutter_test/flutter_test.dart';

import 'poker_hand_test.dart' show hand, stacked;

List<PlayingCard> cards(String s) => PlayingCard.parseAll(s);

void main() {
  group('TableReads', () {
    test('notes raises, calls, c-bets and folds to bets', () {
      // Three-handed, button 0: 1 small blind, 2 big blind, 0 first in.
      final h = hand([1000, 1000, 1000]);
      final seats = [0, 1, 2];
      final reads = TableReads(3)..startHand(h, seats);
      void play(Move m) {
        reads.observe(h, seats, m);
        h.apply(m);
      }

      play(const Move.raiseTo(60)); // 0 opens
      play(const Move.fold()); // 1 folds the small blind
      play(const Move.call()); // 2 defends
      h.nextStreet();
      play(const Move.check()); // 2 checks to the raiser
      play(const Move.raiseTo(80)); // 0 c-bets
      play(const Move.fold()); // 2 folds
      expect(h.result, isNotNull);
      reads.endHand(h, seats, number: 1);

      final opener = reads.players[0], defender = reads.players[2];
      expect(opener.vpip, 1);
      expect(opener.pfr, 1);
      expect(opener.cbetChances, 1);
      expect(opener.cbets, 1);
      expect(opener.handsWon, 1);
      expect(defender.vpip, 1);
      expect(defender.pfr, 0);
      expect(defender.facedBets, 1);
      expect(defender.foldsToBet, 1);
      expect(reads.players[1].vpip, 0, reason: 'posting a blind is not choosing to play');
      expect(reads.preflopAggressor, 0);

      final record = reads.history.single;
      expect(record.number, 1);
      expect(record.won.keys, [0]);
      expect(record.winningHand, isNull, reason: 'nobody showed');
      expect(record.actions.map((a) => a.label), [
        ActionLabel.raise,
        ActionLabel.fold,
        ActionLabel.call,
        ActionLabel.check,
        ActionLabel.bet,
        ActionLabel.fold,
      ]);
    });

    test('a showdown: sizing tells, bluffs caught, and tilt for the loser', () {
      final seats = [0, 1];
      final reads = TableReads(2);
      final deck2 = stacked(players: 2, button: 0, holes: {0: '7c 2d', 1: 'Ah Ad'}, board: 'Ks 9h 4c 3s Jd');
      final h2 = hand([1000, 1000], deck: deck2);
      reads.startHand(h2, seats);
      void play2(Move m) {
        reads.observe(h2, seats, m);
        h2.apply(m);
      }

      play2(const Move.call());
      play2(const Move.check());
      for (var street = 0; street < 2; street++) {
        h2.nextStreet();
        play2(const Move.check());
        play2(const Move.check());
      }
      h2.nextStreet();
      play2(const Move.check()); // big blind (aces) checks
      play2(const Move.raiseTo(700)); // 7-2: way over the pot
      play2(const Move.call());
      while (h2.result == null) {
        h2.nextStreet();
      }
      reads.endHand(h2, seats, number: 2);
      final bluffer = reads.players[0];
      expect(bluffer.aggressiveShowdowns, 1);
      expect(bluffer.bluffsShown, 1);
      expect(bluffer.bigBetsShown, 1);
      expect(bluffer.bigBetsStrong, 0);
      expect(bluffer.tilt, greaterThan(0.4), reason: 'lost most of the stack');
      expect(reads.players[1].showdownsWon, 1);
    });
  });

  group('hand reading', () {
    test('pre-flop ranks: aces best, 7-2 offsuit near the bottom', () {
      expect(preflopRank(cards('As Ad')), lessThan(0.01));
      expect(preflopRank(cards('7c 2d')), greaterThan(0.9));
      expect(preflopRank(cards('Kh Qh')), lessThan(preflopRank(cards('Kh Qd'))));
    });

    test('classify: monsters, pairs, draws, air', () {
      expect(classify(cards('9h 9d'), cards('9s Kc 2d')), Made.monster);
      expect(classify(cards('As Kd'), cards('Ah 7c 2d')), Made.strong);
      expect(classify(cards('7s 6s'), cards('Ah 2s 9s')), Made.draw);
      expect(classify(cards('Qc 3d'), cards('Ah 8c 2d')), Made.air);
    });

    test('outs: a flush draw with two overcards', () {
      final o = outs(cards('Ah Kh'), cards('Qh 7h 2c'))!;
      expect(o.outs, 15);
      expect(o.chance, closeTo(0.54, 0.02));
      expect(outs(cards('Ah Kh'), cards('Qh 7h 2c 3d 9s')), isNull, reason: 'nothing to come on the river');
    });
  });

  group('PokerBot', () {
    test('every style makes legal moves for whole tournaments', () {
      final rng = Random(3);
      for (final style in BotStyle.values) {
        final g = SitAndGo(names: ['a', 'b', 'c', 'd'], config: SitAndGoConfig.forPlayers(4), rng: rng);
        final bots = [
          for (var i = 0; i < 4; i++)
            PokerBot(
              style: i == 0 ? style : BotStyle.values[(style.index + i) % BotStyle.values.length],
              difficulty: Difficulty.values[i % 3],
              rng: rng,
            ),
        ];
        final reads = TableReads(4);
        var hands = 0;
        while (!g.isOver && hands++ < 300) {
          final h = g.startHand();
          reads.startHand(h, g.handSeats);
          while (h.result == null) {
            if (h.toAct == null) {
              h.nextStreet();
              continue;
            }
            final d = bots[g.handSeats[h.toAct!]].think(h, reads: reads, seats: g.handSeats);
            expect(d.tempo, inInclusiveRange(0, 1));
            reads.observe(h, g.handSeats, d.move);
            h.apply(d.move); // throws on an illegal move
          }
          reads.endHand(h, g.handSeats, number: hands);
          g.finishHand();
        }
        expect(g.isOver, isTrue, reason: '${style.label} table should finish');
      }
    });

    test('folds 7-2 to a shove and calls with aces', () {
      for (final style in [BotStyle.rock, BotStyle.shark, BotStyle.grinder]) {
        final rng = Random(5);
        PokerHand facingShove(String hole) {
          final deck = stacked(players: 2, button: 0, holes: {0: 'Kd Kc', 1: hole});
          final h = hand([1500, 1500], deck: deck);
          h.apply(const Move.raiseTo(1500));
          return h;
        }

        final bot = PokerBot(style: style, difficulty: Difficulty.hard, rng: rng);
        expect(bot.decide(facingShove('7c 2d')).kind, MoveKind.fold, reason: style.label);
        expect(bot.decide(facingShove('As Ah')).kind, MoveKind.call, reason: style.label);
      }
    });
  });

  test('end-of-game quotes: one per player, no line twice', () {
    final players = [for (var i = 0; i < 4; i++) PlayerReads()];
    for (final r in players) {
      r.hands = 30;
      r.facedBets = 10;
    }
    players[0]
      ..vpip = 20
      ..foldsToBet = 2;
    players[1]
      ..vpip = 4
      ..foldsToBet = 8;
    players[2]
      ..vpip = 18
      ..foldsToBet = 1;
    players[3]
      ..vpip = 9
      ..foldsToBet = 4
      ..allIns = 6;
    final quotes = pickQuotes(players, seats: [0, 1, 2, 3]);
    expect(quotes.keys.toSet(), {0, 1, 2, 3});
    expect(quotes.values.toSet().length, 4);
    expect(quotes[3], contains('Shoved 6 times'));
  });
}
