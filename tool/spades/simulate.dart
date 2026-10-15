// ignore_for_file: avoid_print
// Bot-only Spades for tuning: dart run tool/spades/simulate.dart [games]
import 'dart:math';

import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/spades/spades.dart';
import 'package:duel_engine/spades/spades_bot.dart';

void main(List<String> args) {
  final n = args.isEmpty ? 200 : int.parse(args.first);
  const e = Difficulty.easy, m = Difficulty.normal, h = Difficulty.hard;
  for (final (name, a, b) in [('Hard v Easy', h, e), ('Hard v Normal', h, m), ('Normal v Easy', m, e)]) {
    for (final players in [4, 2]) {
      var wins = 0, hands = 0, made = 0, bids = 0, nils = 0, nilMade = 0;
      for (var i = 0; i < n; i++) {
        final swap = i.isOdd;
        final rng = Random(i * 7 + players);
        final levels = players == 4 ? (swap ? [b, a, b, a] : [a, b, a, b]) : (swap ? [b, a] : [a, b]);
        final g = Spades(players: players, rng: rng, dealer: i % players);
        final bots = [for (final d in levels) SpadesBot(difficulty: d, rng: rng)];
        while (!g.isOver) {
          final p = g.turn;
          switch (g.phase) {
            case SpadesPhase.draw:
              g.draw(p, keep: bots[p].keep(g, p, g.offered!));
            case SpadesPhase.bid:
              g.bid(p, bots[p].bid(g, p));
            case SpadesPhase.play:
              g.play(p, bots[p].play(g, p));
            case SpadesPhase.handOver:
              for (final r in (g.events.whereType<HandScored>().last).results) {
                if (r.bid > 0) {
                  bids++;
                  if (r.made) made++;
                }
                nils += r.nils.length;
                nilMade += r.nils.where((x) => x.$2).length;
              }
              g.nextHand();
            case SpadesPhase.gameOver:
              break;
          }
        }
        hands += g.handNumber;
        if (g.winner == (swap ? 1 : 0)) wins++;
      }
      print(
        '$name, $players players: first wins ${(100 * wins / n).round()}%, '
        '${(hands / n).toStringAsFixed(1)} hands/game, bids made ${(100 * made / bids).round()}%, '
        'nils $nils (made $nilMade)',
      );
    }
  }
}
