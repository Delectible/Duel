import 'dart:math';

import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/sunk/sunk.dart';
import 'package:duel_engine/sunk/sunk_bot.dart';
import 'package:flutter_test/flutter_test.dart';

SunkCard t(int v) => SunkCard(SunkKind.treasure, v);
const air = SunkCard(SunkKind.air), boo = SunkCard(SunkKind.boo), hook = SunkCard(SunkKind.hook);
const cut = SunkCard(SunkKind.cut), map = SunkCard(SunkKind.map);

/// [top] first off the sea.
SunkGame game(List<SunkCard> top, {int players = 2}) => SunkGame(players: players, sea: [...top.reversed]);

void main() {
  test('a duplicate busts you; Spare Air saves you once', () {
    final g = game([t(3), t(5), t(3), air, t(5), t(5)]);
    g.draw(0); // 0: 3
    g.draw(1); // 1: 5
    g.draw(0); // 0: 3 again: bust
    expect(g.state[0], SunkState.busted);
    expect(g.turn, 1);
    g.draw(1); // 1: air
    g.draw(1); // 1: 5 again, saved
    expect(g.state[1], SunkState.diving);
    expect(g.air[1], 0);
    g.surface(1);
    expect(g.scores, [0, 5]);
    expect(g.round, 2);
  });

  test('a run of three adds a bonus; six different surface you with more', () {
    final g = game([t(1), t(8), t(2), t(3), t(4), t(5), t(6)]);
    g.draw(0);
    g.draw(1);
    g.draw(0);
    g.surface(1); // 8
    g.draw(0);
    expect(g.worth(0), 6 + sunkRunBonus);
    g.draw(0);
    g.draw(0);
    g.draw(0); // 1..6: six different
    expect(g.events.whereType<SunkSurfaced>().last.haul, isTrue);
    expect(g.scores[0], 21 + sunkRunBonus + sunkHaulBonus);
  });

  test('Boo! makes everyone else still under draw', () {
    final g = game([t(2), t(4), boo, t(4), t(7)], players: 3);
    g.draw(0); // 2
    g.draw(1); // 4
    g.draw(2); // boo: 0 draws 4, 1 draws 7
    expect(g.bags[0].map((c) => c.value), [2, 4]);
    expect(g.bags[1].map((c) => c.value), [4, 7]);
  });

  test('Hook steals the best you lack; Cut Line sinks the best', () {
    final g = game([t(8), t(2), t(3), hook, t(6), cut], players: 2);
    g.draw(0); // 8
    g.draw(1); // 2
    g.draw(0); // 3
    g.draw(1); // hook
    expect(g.pending, SunkKind.hook);
    expect(g.targets, [0]);
    g.aim(1, 0);
    expect(g.bags[1].map((c) => c.value), [2, 8]);
    expect(g.bags[0].map((c) => c.value), [3]);
    g.draw(0); // 6
    g.draw(1); // cut
    g.aim(1, 0);
    expect(g.bags[0].map((c) => c.value), [3]);
    expect(g.sea.first, t(6));
  });

  test('Map: peek, then take or pass', () {
    final g = game([t(4), map, t(4), t(1)]);
    g.draw(0);
    g.draw(1); // map: peeks the 4
    expect(g.peeked, t(4));
    g.chart(1, take: false);
    expect(g.turn, 0);
    g.draw(0); // 0 draws the 4: bust
    expect(g.state[0], SunkState.busted);
  });

  test('bots finish every game; Hard beats Easy', () {
    final rng = Random(5);
    var hard = 0;
    const games = 400;
    for (var i = 0; i < games; i++) {
      final g = SunkGame(players: 2, sea: sunkDeck()..shuffle(rng), first: i % 2)
        ..reshuffle = (c) => c.shuffle(rng);
      final bots = [
        SunkBot(me: 0, difficulty: Difficulty.hard, style: SunkStyle.steady, rng: rng),
        SunkBot(me: 1, difficulty: Difficulty.easy, style: SunkStyle.values[i % 3], rng: rng),
      ];
      for (var k = 0; k < 4000 && !g.isOver; k++) {
        sunkPlay(g, bots[g.turn].decide(g));
      }
      expect(g.isOver, isTrue);
      if (g.winners.contains(0)) hard++;
    }
    expect(hard, greaterThan(games * 0.55), reason: 'Hard won $hard of $games');
  });
}
