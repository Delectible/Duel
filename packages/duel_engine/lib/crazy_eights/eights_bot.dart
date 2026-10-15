import 'dart:math';

import '../cards.dart';
import '../difficulty.dart';
import 'crazy_eights.dart';

/// A bot's move: play [card] (naming [suit] for an eight), draw, or pass.
sealed class EightsMove {
  const EightsMove();
}

class PlayCard extends EightsMove {
  const PlayCard(this.card, {this.suit});

  final PlayingCard card;
  final Suit? suit;
}

class DrawCard extends EightsMove {
  const DrawCard();
}

class PassTurn extends EightsMove {
  const PassTurn();
}

/// Crazy Eights bot.
/// - Easy: any card that fits; names a random suit.
/// - Normal: keeps its eights for when it's stuck, plays towards the suit
///   it holds most, names that suit.
/// - Hard: as Normal, and when someone is close to going out, plays and
///   names suits they've shown they don't have.
class EightsBot {
  EightsBot({required this.difficulty, required this.rng});

  final Difficulty difficulty;
  final Random rng;

  EightsMove decide(CrazyEights g, int me) {
    final options = g.playable(me);
    if (options.isEmpty) return g.canDraw ? const DrawCard() : const PassTurn();
    final hand = g.hands[me];

    if (difficulty == Difficulty.easy) {
      final card = options[rng.nextInt(options.length)];
      return PlayCard(card, suit: card.rank == 8 ? Suit.values[rng.nextInt(4)] : null);
    }

    // Suits I hold most of (eights don't count: they go anywhere).
    final counts = {for (final s in Suit.values) s: 0};
    for (final c in hand) {
      if (c.rank != 8) counts[c.suit] = counts[c.suit]! + 1;
    }

    // Hard: someone with 1-2 cards left? Steer to a suit they lack.
    Suit? squeeze;
    if (difficulty == Difficulty.hard) {
      for (var k = 1; k < g.players; k++) {
        final p = (me + k) % g.players;
        final lacks = g.lacking[p];
        if (g.hands[p].length <= 2 && lacks != null && lacks.isNotEmpty) {
          squeeze = lacks.reduce((a, b) => counts[a]! >= counts[b]! ? a : b);
          break;
        }
      }
    }

    double score(PlayingCard c) {
      if (c.rank == 8) return -10; // last resort
      var v = counts[c.suit]!.toDouble(); // stay in my long suit
      if (squeeze != null && c.suit == squeeze) v += 5;
      v += c.rank / 20; // shed high cards first, a little
      return v;
    }

    final plain = options.where((c) => c.rank != 8).toList();
    // Holding only eights that fit: play one (it's what they're for). But
    // a drawn eight we may keep for later if we have other cards.
    final pool = plain.isNotEmpty ? plain : options;
    pool.sort((a, b) => score(b).compareTo(score(a)));
    final card = pool.first;
    if (card.rank != 8) return PlayCard(card);
    final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return PlayCard(card, suit: squeeze ?? best);
  }
}
