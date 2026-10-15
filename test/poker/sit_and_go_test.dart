import 'dart:math';

import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/poker/bot.dart';
import 'package:duel_engine/cards.dart';
import 'package:duel_engine/poker/sit_and_go.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('blind pace depends on the table size', () {
    expect(SitAndGoConfig.forPlayers(2).handsPerLevel, lessThan(SitAndGoConfig.forPlayers(6).handsPerLevel));
    final g = SitAndGo(
      names: ['a', 'b'],
      config: const SitAndGoConfig(startingStack: 1000, handsPerLevel: 2),
      rng: Random(1),
    );
    expect(g.blinds, (10, 20));
    expect(g.handsToNextLevel, 2);
    g.handsPlayed = 2;
    expect(g.blinds, (15, 30));
  });

  for (final players in [2, 3, 6]) {
    test('bots play a $players-player Sit & Go to the end', () {
      final rng = Random(players);
      final g = SitAndGo(
        names: [for (var i = 0; i < players; i++) 'P$i'],
        config: SitAndGoConfig.forPlayers(players),
        rng: rng,
      );
      final bots = [
        for (var i = 0; i < players; i++)
          PokerBot(style: BotStyle.values[i % 4], difficulty: Difficulty.easy, rng: rng),
      ];
      final chips = players * g.config.startingStack;
      var hands = 0;
      while (!g.isOver) {
        expect(++hands, lessThan(600), reason: 'blinds should end it');
        final h = g.startHand();
        while (h.result == null) {
          if (h.toAct == null) {
            h.nextStreet();
          } else {
            h.apply(bots[g.handSeats[h.toAct!]].decide(h));
          }
        }
        g.finishHand();
        expect(g.players.fold(0, (s, p) => s + p.stack), chips);
      }
      final places = g.players.map((p) => p.place).toList()..sort();
      expect(places, [for (var i = 1; i <= players; i++) i]);
      expect(g.players.firstWhere((p) => p.place == 1).stack, chips);
    });
  }

  test('equity: aces beat a random hand most of the time', () {
    final aces = PlayingCard.parseAll('As Ah');
    final e = equity(aces, const [], 1, 2000, Random(3));
    expect(e, closeTo(0.85, 0.04));
    final junk = equity(PlayingCard.parseAll('7c 2d'), const [], 1, 2000, Random(3));
    expect(junk, closeTo(0.35, 0.04));
  });
}
