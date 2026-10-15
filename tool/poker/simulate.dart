// ignore_for_file: avoid_print
// Plays bot-only Sit & Gos and prints how long they last and how each
// style plays, for tuning blinds and bots.
//
//   dart run tool/poker/simulate.dart [tournaments] [difficulty]
import 'dart:math';

import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/poker/bot.dart';
import 'package:duel_engine/poker/poker_hand.dart';
import 'package:duel_engine/poker/sit_and_go.dart';

void main(List<String> args) {
  final runs = args.isNotEmpty ? int.parse(args[0]) : 20;
  final difficulty = Difficulty.values.byName(args.length > 1 ? args[1] : 'normal');
  final rng = Random(7);
  for (final players in [2, 3, 4, 6]) {
    final hands = <int>[];
    final played = <BotStyle, int>{}, dealt = <BotStyle, int>{}, wins = <BotStyle, int>{};
    for (var t = 0; t < runs; t++) {
      final g = SitAndGo(
        names: [for (var i = 0; i < players; i++) 'P$i'],
        config: SitAndGoConfig.forPlayers(players),
        rng: rng,
      );
      final bots = [
        for (var i = 0; i < players; i++)
          PokerBot(style: BotStyle.values[(i + t) % 4], difficulty: difficulty, rng: rng),
      ];
      while (!g.isOver) {
        final h = g.startHand();
        final voluntarily = <int>{};
        while (h.result == null) {
          if (h.toAct == null) {
            h.nextStreet();
            continue;
          }
          final i = h.toAct!;
          final m = bots[g.handSeats[i]].decide(h);
          if (h.street == Street.preflop &&
              (m.kind == MoveKind.call || m.kind == MoveKind.raise) &&
              !h.legalMoves().canCheck) {
            voluntarily.add(g.handSeats[i]);
          }
          h.apply(m);
        }
        for (final s in g.handSeats) {
          dealt.update(bots[s].style, (v) => v + 1, ifAbsent: () => 1);
          if (voluntarily.contains(s)) played.update(bots[s].style, (v) => v + 1, ifAbsent: () => 1);
        }
        g.finishHand();
      }
      hands.add(g.handsPlayed);
      final winner = g.players.firstWhere((p) => p.place == 1).seat;
      wins.update(bots[winner].style, (v) => v + 1, ifAbsent: () => 1);
    }
    hands.sort();
    final avg = hands.reduce((a, b) => a + b) / hands.length;
    print(
      '$players players: hands avg ${avg.toStringAsFixed(0)}, median ${hands[hands.length ~/ 2]}, max ${hands.last}',
    );
    for (final s in BotStyle.values) {
      final vpip = (100 * (played[s] ?? 0) / (dealt[s] ?? 1)).toStringAsFixed(0);
      print('  ${s.label.padRight(7)} plays $vpip% of hands, won ${wins[s] ?? 0}');
    }
  }
}
