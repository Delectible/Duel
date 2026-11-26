import 'dart:math';

/// What a set of dice scores in Farkle, or null if any die in it doesn't
/// count (every die you keep must score).
///
/// 1 = 100, 5 = 50; three of a kind = face × 100 (three 1s = 1000); four of
/// a kind 1000, five 2000, six 3000; a straight 1-6 1500; three pairs 1500;
/// four of a kind with a pair 1500; two triples 2500.
int? farkleScore(List<int> dice) {
  if (dice.isEmpty) return null;
  final counts = List.filled(7, 0);
  for (final d in dice) {
    counts[d]++;
  }
  // Six-dice combinations.
  if (dice.length == 6) {
    if (counts.skip(1).every((c) => c == 1)) return 1500;
    final groups = counts.skip(1).where((c) => c > 0).toList()..sort();
    if (groups.length == 3 && groups.every((c) => c == 2)) return 1500;
    if (groups.length == 2 && groups[0] == 2 && groups[1] == 4) return 1500;
    if (groups.length == 2 && groups[0] == 3 && groups[1] == 3) return 2500;
  }
  var score = 0;
  for (var face = 1; face <= 6; face++) {
    var n = counts[face];
    if (n >= 3) {
      score += switch (n) {
        3 => face == 1 ? 1000 : face * 100,
        4 => 1000,
        5 => 2000,
        _ => 3000,
      };
      n = 0;
    }
    if (n > 0) {
      if (face == 1) {
        score += n * 100;
      } else if (face == 5) {
        score += n * 50;
      } else {
        return null;
      }
    }
  }
  return score;
}

/// The most a roll can score (all of its scoring dice kept), or 0 for a
/// Farkle.
int farkleBest(List<int> dice) => farkleBestKeep(dice).$2;

/// The keep that scores most: (indices into [dice], points). With [fewest]
/// set, the fewest dice that still score at least [atLeast] (to roll more
/// dice again).
(List<int>, int) farkleBestKeep(List<int> dice, {bool fewest = false, int atLeast = 0}) {
  var best = (<int>[], 0);
  final n = dice.length;
  for (var mask = 1; mask < (1 << n); mask++) {
    final idx = [
      for (var i = 0; i < n; i++)
        if (mask & (1 << i) != 0) i,
    ];
    final s = farkleScore([for (final i in idx) dice[i]]);
    if (s == null) continue;
    if (fewest) {
      if (s < atLeast) continue;
      if (best.$1.isEmpty || idx.length < best.$1.length || (idx.length == best.$1.length && s > best.$2)) {
        best = (idx, s);
      }
    } else if (s > best.$2 || (s == best.$2 && idx.length > best.$1.length)) {
      best = (idx, s);
    }
  }
  return best;
}

/// What a turn did.
enum FarkleEnd { banked, farkled }

class FarkleTurn {
  const FarkleTurn(this.player, this.points, this.end);
  final int player, points;
  final FarkleEnd end;
}

/// Farkle: on your turn roll six dice, keep at least one scoring die (or
/// set), then roll the rest or bank what you've kept this turn. A roll
/// with nothing to keep is a Farkle: the turn's points are lost. Keep all
/// six and you have hot dice: roll all six again. The first to reach the
/// target at the end of a turn sets the score to beat: everyone else gets
/// one last turn; the highest score wins.
class FarkleGame {
  FarkleGame({required this.players, this.target = 10000, this.entry = 0, int first = 0})
    : scores = List.filled(players, 0),
      turn = first % players;

  final int players;
  final int target;

  /// Points needed in one turn to get on the board (0: none).
  final int entry;

  final List<int> scores;
  int turn;

  /// This turn: points kept so far, the dice on the table (after a roll),
  /// and how many are left to roll.
  int turnPoints = 0;
  List<int> rolled = const [];
  int diceLeft = 6;

  /// Whether the dice on the table still need keeping (just rolled).
  bool get mustKeep => rolled.isNotEmpty && !farkled;

  /// The roll scored nothing.
  bool farkled = false;

  /// Who reached the target first (everyone else gets a last turn).
  int? closer;

  /// Players still to have their last turn.
  final Set<int> lastTurns = {};

  bool isOver = false;

  final List<FarkleTurn> history = [];

  /// Rolls [diceLeft] dice: [dice] are their faces.
  void roll(List<int> dice) {
    if (isOver) throw StateError('Over');
    if (mustKeep) throw StateError('Keep some dice first');
    if (dice.length != diceLeft) throw StateError('Roll $diceLeft dice');
    rolled = [...dice];
    farkled = farkleBest(rolled) == 0;
  }

  /// A fair roll for the dice left.
  List<int> rollFor(Random rng) => [for (var i = 0; i < diceLeft; i++) 1 + rng.nextInt(6)];

  /// What keeping [indices] of the roll would add, or null if it can't.
  int? keepScore(Iterable<int> indices) {
    final set = indices.toSet();
    if (set.isEmpty || set.any((i) => i < 0 || i >= rolled.length)) return null;
    return farkleScore([for (final i in set) rolled[i]]);
  }

  /// Keeps those dice (they must all score). Hot dice: six fresh dice.
  void keep(Iterable<int> indices) {
    if (!mustKeep) throw StateError('Nothing to keep');
    final s = keepScore(indices);
    if (s == null) throw StateError('Those dice do not all score');
    turnPoints += s;
    diceLeft -= indices.toSet().length;
    if (diceLeft == 0) diceLeft = 6;
    rolled = const [];
  }

  bool get hotDice => diceLeft == 6 && turnPoints > 0 && rolled.isEmpty;

  /// Can bank now: something kept, nothing waiting to keep, and on the
  /// board (or this turn gets there).
  bool get canBank =>
      !isOver && rolled.isEmpty && turnPoints > 0 && (scores[turn] > 0 || turnPoints >= entry);

  /// Banks the turn's points; the next player's turn.
  FarkleTurn bank() {
    if (!canBank) throw StateError("Can't bank");
    scores[turn] += turnPoints;
    final t = FarkleTurn(turn, turnPoints, FarkleEnd.banked);
    _end(t);
    return t;
  }

  /// After a Farkle: the turn's lost; next player.
  FarkleTurn pass() {
    if (!farkled) throw StateError('Not a Farkle');
    final t = FarkleTurn(turn, turnPoints, FarkleEnd.farkled);
    _end(t);
    return t;
  }

  void _end(FarkleTurn t) {
    history.add(t);
    final p = turn;
    if (closer == null && scores[p] >= target) {
      closer = p;
      lastTurns.addAll([
        for (var q = 0; q < players; q++)
          if (q != p) q,
      ]);
    } else {
      lastTurns.remove(p);
    }
    turnPoints = 0;
    rolled = const [];
    diceLeft = 6;
    farkled = false;
    if (closer != null && lastTurns.isEmpty) {
      isOver = true;
      return;
    }
    turn = (turn + 1) % players;
  }

  List<int> get winners {
    final top = scores.reduce(max);
    return [
      for (var p = 0; p < players; p++)
        if (scores[p] == top) p,
    ];
  }

  /// The score to beat in the last round (the leader's), if it's on.
  int? get toBeat => closer == null ? null : scores.reduce(max);
}
