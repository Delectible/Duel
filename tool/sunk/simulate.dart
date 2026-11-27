// ignore_for_file: avoid_print
// Plays bot-only games of Sunk and prints how they went, for tuning.
// dart run tool/sunk/simulate.dart [games]
import 'dart:math';

import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/sunk/sunk.dart';
import 'package:duel_engine/sunk/sunk_bot.dart';

void main(List<String> args) {
  final games = args.isEmpty ? 2000 : int.parse(args.first);
  final rng = Random(1);
  var rounds = 0,
      turns = 0,
      busts = 0,
      surfaces = 0,
      banked = 0,
      hauls = 0,
      runs = 0,
      boos = 0,
      hooks = 0,
      cuts = 0;
  final styleWins = <SunkStyle, int>{}, styleSeats = <SunkStyle, int>{};
  var hardWins = 0, hardGames = 0;
  for (var i = 0; i < games; i++) {
    final n = 2 + i % 4;
    final g = SunkGame(players: n, sea: sunkDeck()..shuffle(rng), first: rng.nextInt(n))
      ..reshuffle = (c) => c.shuffle(rng);
    final styles = [for (var p = 0; p < n; p++) SunkStyle.values[rng.nextInt(3)]];
    final levels = [
      for (var p = 0; p < n; p++)
        i.isEven && p == 0 ? Difficulty.hard : (i.isEven ? Difficulty.easy : Difficulty.normal),
    ];
    final bots = [
      for (var p = 0; p < n; p++) SunkBot(me: p, difficulty: levels[p], style: styles[p], rng: rng),
    ];
    for (var guard = 0; guard < 5000 && !g.isOver; guard++) {
      sunkPlay(g, bots[g.turn].decide(g));
      turns++;
    }
    if (!g.isOver) throw StateError('stuck');
    rounds += g.round;
    for (final e in g.events) {
      switch (e) {
        case SunkBusted():
          busts++;
        case SunkSurfaced(:final points, :final haul, :final run):
          surfaces++;
          banked += points;
          if (haul) hauls++;
          if (run) runs++;
        case SunkBoo():
          boos++;
        case SunkHooked():
          hooks++;
        case SunkCut():
          cuts++;
        default:
      }
    }
    for (var p = 0; p < n; p++) {
      styleSeats[styles[p]] = (styleSeats[styles[p]] ?? 0) + 1;
    }
    for (final w in g.winners) {
      styleWins[styles[w]] = (styleWins[styles[w]] ?? 0) + 1;
    }
    if (i.isEven) {
      hardGames++;
      if (g.winners.contains(0)) hardWins++;
    }
  }
  print(
    'rounds/game ${(rounds / games).toStringAsFixed(1)}  turns/game ${(turns / games).toStringAsFixed(0)}',
  );
  print(
    'bust ${(100 * busts / (busts + surfaces)).toStringAsFixed(0)}%  avg banked ${(banked / surfaces).toStringAsFixed(1)}',
  );
  print(
    'hauls ${(100 * hauls / surfaces).toStringAsFixed(0)}%  runs ${(100 * runs / surfaces).toStringAsFixed(0)}%',
  );
  print(
    'per game: boo ${(boos / games).toStringAsFixed(1)} hook ${(hooks / games).toStringAsFixed(1)} cut ${(cuts / games).toStringAsFixed(1)}',
  );
  for (final s in SunkStyle.values) {
    print('$s win share ${((styleWins[s] ?? 0) / (styleSeats[s] ?? 1)).toStringAsFixed(2)}');
  }
  print(
    'hard vs easy: ${(100 * hardWins / hardGames).toStringAsFixed(0)}% (fair share ~${(100 * [for (var i = 0; i < games; i += 2) 1 / (2 + i % 4)].reduce((a, b) => a + b) / hardGames).toStringAsFixed(0)}%)',
  );
}
