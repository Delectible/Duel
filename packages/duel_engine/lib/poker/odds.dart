import 'dart:math';

import '../cards.dart';
import 'hand_eval.dart';

/// Each hand's chance of winning a showdown (cards face up, the board so
/// far): exact when one card is to come, else [simulations] random
/// finishes. Ties are shared. The chances add up to 1.
List<double> winChances(
  List<List<PlayingCard>> holes,
  List<PlayingCard> board, {
  required Random rng,
  int simulations = 800,
}) {
  final known = {for (final h in holes) ...h, ...board};
  final rest = [
    for (final c in PlayingCard.fullDeck)
      if (!known.contains(c)) c,
  ];
  final need = 5 - board.length;
  final wins = List.filled(holes.length, 0.0);
  var runs = 0;

  void score(List<PlayingCard> full) {
    final values = [
      for (final h in holes) evaluateHand([...h, ...full]).score,
    ];
    final best = values.reduce(max);
    final tied = values.where((v) => v == best).length;
    for (var i = 0; i < values.length; i++) {
      if (values[i] == best) wins[i] += 1 / tied;
    }
    runs++;
  }

  if (need == 0) {
    score(board);
  } else if (need == 1) {
    for (final c in rest) {
      score([...board, c]);
    }
  } else {
    for (var s = 0; s < simulations; s++) {
      for (var k = 0; k < need; k++) {
        final j = k + rng.nextInt(rest.length - k);
        final t = rest[k];
        rest[k] = rest[j];
        rest[j] = t;
      }
      score([...board, ...rest.take(need)]);
    }
  }
  return [for (final w in wins) w / runs];
}

/// [hole]'s chance of winning against [opponents] unknown hands, given the
/// board so far ([simulations] random deals). Ties count as shared.
double equityVsRandom(
  List<PlayingCard> hole,
  List<PlayingCard> board, {
  required int opponents,
  required Random rng,
  int simulations = 300,
}) {
  if (opponents < 1) return 1;
  final known = {...hole, ...board};
  final rest = [
    for (final c in PlayingCard.fullDeck)
      if (!known.contains(c)) c,
  ];
  final need = 5 - board.length + opponents * 2;
  var wins = 0.0;
  for (var s = 0; s < simulations; s++) {
    for (var k = 0; k < need; k++) {
      final j = k + rng.nextInt(rest.length - k);
      final t = rest[k];
      rest[k] = rest[j];
      rest[j] = t;
    }
    final full = [...board, ...rest.take(5 - board.length)];
    final mine = evaluateHand([...hole, ...full]).score;
    var tied = 1;
    var lost = false;
    for (var o = 0; o < opponents; o++) {
      final at = 5 - board.length + o * 2;
      final theirs = evaluateHand([rest[at], rest[at + 1], ...full]).score;
      if (theirs > mine) {
        lost = true;
        break;
      }
      if (theirs == mine) tied++;
    }
    if (!lost) wins += 1 / tied;
  }
  return wins / simulations;
}
