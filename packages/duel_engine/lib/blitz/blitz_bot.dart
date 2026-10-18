import 'dart:math';

import '../cards.dart';
import '../difficulty.dart';
import 'blitz.dart';

/// Plays Blitz for a bot.
///
/// Easy picks almost at random (an attack when it sees one, half the
/// time). Normal and Hard score every move: a Blitz on the castle with the
/// most face-up cards, then knocking out a castle's last card, pairs (free
/// cards and another go), strikes on the biggest castle, fortifying when
/// low, and scouting with the card it needs least. Hard aims harder (always
/// at the leader), hoards a colour for its next Blitz and saves its Aces.
class BlitzBot {
  BlitzBot({required this.difficulty, required this.rng});

  final Difficulty difficulty;
  final Random rng;

  BlitzMove decide(Blitz g, int me) {
    final moves = g.moves(me);
    if (moves.length == 1) return moves.single;
    if (difficulty == Difficulty.easy) {
      final attacks = moves.where((m) => m is Strike || m is BlitzAttack).toList();
      if (attacks.isNotEmpty && rng.nextBool()) return attacks[rng.nextInt(attacks.length)];
      final calm = moves.where((m) => m is! Scout).toList();
      final pool = calm.isNotEmpty && rng.nextBool() ? calm : moves;
      return pool[rng.nextInt(pool.length)];
    }
    final hard = difficulty == Difficulty.hard;
    final noise = hard ? 3.0 : 12.0;
    BlitzMove? best;
    var bestScore = -1e9;
    for (final m in moves) {
      final s = _score(g, me, m, hard) + rng.nextDouble() * noise;
      if (s > bestScore) {
        bestScore = s;
        best = m;
      }
    }
    return best!;
  }

  double _score(Blitz g, int me, BlitzMove m, bool hard) {
    final hand = g.hands[me];
    final mine = g.castles[me].length;
    final leader = g.alive.where((p) => p != me).map((p) => g.castles[p].length).fold(0, max);
    // A bigger castle is a bigger threat; Hard always goes for the leader.
    double threat(int q) => g.castles[q].length / max(1, leader) * (hard ? 20 : 8);
    final red = hand.where((c) => c.suit.isRed).length;
    final black = hand.length - red;
    final hoard = red >= black; // the colour Hard is saving for a Blitz
    final counts = <int, int>{};
    for (final c in hand) {
      counts[c.rank] = (counts[c.rank] ?? 0) + 1;
    }
    // What a hand card is worth keeping.
    double keep(PlayingCard c) {
      var v = c.rank / 14;
      if (c.rank == 14) v += hard ? 30 : 12;
      if ((counts[c.rank] ?? 0) >= 2) v += 10;
      if (hard && c.suit.isRed == hoard && max(red, black) >= 3) v += 6;
      return v;
    }

    switch (m) {
      case BlitzAttack(:final target):
        final up = g.faceUpCount(target);
        final kills = up == g.castles[target].length;
        return 90 + up * 12 + (kills ? 40 : 0) + threat(target);
      case Strike(:final card, :final target, :final index):
        final castle = g.castles[target];
        final blind = !castle[index].faceUp;
        var s = (blind ? 52 : 60) + threat(target) - keep(card);
        if (castle.length == 1) s += 35; // knocks them out
        return s;
      case Pair(:final rank):
        return 68 - (rank == 14 ? (hard ? 40 : 15) : 0);
      case Fortify(:final card):
        return (mine <= 2 ? 72 : (mine <= 4 ? 58 : 40)) - keep(card);
      case Scout(:final card, :final target):
        // Scouting a castle we could then hit (a matching card in hand).
        return 20 + threat(target) * 0.5 - keep(card) * 1.5;
      case Discard(:final card):
        // Throw away the card worth least to keep.
        return -50 - keep(card);
      case PassTurn():
        return -100;
    }
  }
}
