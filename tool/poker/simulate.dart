// ignore_for_file: avoid_print
// Plays bot-only Sit & Gos and prints how long they last and how each
// style plays, for tuning blinds and bots.
//
//   dart run tool/poker/simulate.dart [tournaments] [difficulty]
import 'dart:math';

import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/poker/bot.dart';
import 'package:duel_engine/poker/poker_hand.dart';
import 'package:duel_engine/poker/reads.dart';
import 'package:duel_engine/poker/sit_and_go.dart';

void main(List<String> args) {
  final runs = args.isNotEmpty ? int.parse(args[0]) : 20;
  final difficulty = Difficulty.values.byName(args.length > 1 ? args[1] : 'normal');
  final rng = Random(7);
  for (final players in [2, 3, 4, 6]) {
    final hands = <int>[];
    final stats = <BotStyle, List<PlayerReads>>{};
    final played = <BotStyle, int>{}, dealt = <BotStyle, int>{}, wins = <BotStyle, int>{};
    for (var t = 0; t < runs; t++) {
      final g = SitAndGo(
        names: [for (var i = 0; i < players; i++) 'P$i'],
        config: SitAndGoConfig.forPlayers(players),
        rng: rng,
      );
      final bots = [
        for (var i = 0; i < players; i++)
          PokerBot(
            style: BotStyle.values[(i + t * players) % BotStyle.values.length],
            difficulty: difficulty,
            rng: rng,
          ),
      ];
      final reads = TableReads(players);
      while (!g.isOver) {
        final h = g.startHand();
        reads.startHand(h, g.handSeats);
        final deep = [for (final p in g.players) p.stack / h.bigBlind];
        final voluntarily = <int>{};
        while (h.result == null) {
          if (h.toAct == null) {
            h.nextStreet();
            continue;
          }
          final i = h.toAct!;
          final m = bots[g.handSeats[i]].decide(h, reads: reads, seats: g.handSeats);
          if (h.street == Street.preflop &&
              (m.kind == MoveKind.call || m.kind == MoveKind.raise) &&
              !h.legalMoves().canCheck) {
            voluntarily.add(g.handSeats[i]);
          }
          reads.observe(h, g.handSeats, m);
          h.apply(m);
        }
        reads.endHand(h, g.handSeats, number: g.handsPlayed);
        for (final s in g.handSeats) {
          if (deep[s] < 30) continue;
          dealt.update(bots[s].style, (v) => v + 1, ifAbsent: () => 1);
          if (voluntarily.contains(s)) played.update(bots[s].style, (v) => v + 1, ifAbsent: () => 1);
        }
        g.finishHand();
      }
      for (var s = 0; s < players; s++) {
        stats.putIfAbsent(bots[s].style, () => []).add(reads.players[s]);
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
      final rs = stats[s] ?? const <PlayerReads>[];
      int sum(int Function(PlayerReads r) f) => rs.fold(0, (a, r) => a + f(r));
      String pc(int a, int b) => '${(100 * a / max(1, b)).toStringAsFixed(0)}%'.padLeft(4);
      final hands = sum((r) => r.hands);
      final af = (sum((r) => r.bets) + sum((r) => r.raises)) / max(1, sum((r) => r.calls));
      print(
        '  ${s.label.padRight(8)} vpip ${pc(sum((r) => r.vpip), hands)} pfr ${pc(sum((r) => r.pfr), hands)} '
        'af ${af.toStringAsFixed(1)} cbet ${pc(sum((r) => r.cbets), sum((r) => r.cbetChances))} '
        'foldToBet ${pc(sum((r) => r.foldsToBet), sum((r) => r.facedBets))} '
        'sd ${pc(sum((r) => r.showdowns), hands)} bluffs ${pc(sum((r) => r.bluffsShown), sum((r) => r.aggressiveShowdowns))} '
        'deep vpip ${pc(played[s] ?? 0, dealt[s] ?? 0)} won ${wins[s] ?? 0}/${rs.length}',
      );
    }
  }
}
