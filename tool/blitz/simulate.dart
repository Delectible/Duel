// ignore_for_file: avoid_print
import 'dart:math';

import 'package:duel_engine/blitz/blitz.dart';
import 'package:duel_engine/blitz/blitz_bot.dart';
import 'package:duel_engine/difficulty.dart';

/// Bot-only Blitz games for tuning: how long games run, how often they
/// stall, and whether harder bots win more.
///
/// dart run tool/blitz/simulate.dart [games]
void main(List<String> args) {
  final n = args.isEmpty ? 400 : int.parse(args.first);
  for (final wars in [false, true]) {
    for (var players = 2; players <= 6; players++) {
      final rng = Random(players * 7 + (wars ? 1 : 0));
      var turns = 0, stalls = 0, flips = 0;
      final wins = {for (final d in Difficulty.values) d: 0};
      final seats = {for (final d in Difficulty.values) d: 0};
      for (var i = 0; i < n; i++) {
        final g = Blitz(players: players, rng: rng, wars: wars);
        final level = [for (var p = 0; p < players; p++) Difficulty.values[(p + i) % 3]];
        for (final d in level) {
          seats[d] = seats[d]! + 1;
        }
        final bots = [for (final d in level) BlitzBot(difficulty: d, rng: rng)];
        while (!g.isOver) {
          g.apply(bots[g.turn].decide(g, g.turn));
        }
        turns += g.turns;
        if (g.events.last is Won && (g.events.last as Won).stalled) stalls++;
        flips += g.events.whereType<War>().length;
        wins[level[g.winner!]] = wins[level[g.winner!]]! + 1;
      }
      final rate = [
        for (final d in Difficulty.values) '${d.name} ${(100 * wins[d]! / seats[d]! * players).round()}%',
      ].join('  ');
      print(
        '${wars ? 'wars' : 'plain'} $players players: ${(turns / n).toStringAsFixed(0)} turns, '
        '$stalls stalls, ${(flips / n).toStringAsFixed(1)} wars/game · win share vs fair: $rate',
      );
    }
  }
}
