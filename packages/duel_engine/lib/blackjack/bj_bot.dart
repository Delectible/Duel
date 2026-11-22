import 'dart:math';

import '../cards.dart';
import '../difficulty.dart';
import 'blackjack.dart';

/// Basic strategy for these rules (6 decks, dealer stands on soft 17,
/// double after split): what a perfect player does without counting.
BjMove basicStrategy(BjHand h, PlayingCard up, List<BjMove> allowed) {
  final d = bjValue(up) == 11 ? 11 : bjValue(up);
  final can = allowed.toSet();
  BjMove dbl(BjMove otherwise) => can.contains(BjMove.double) ? BjMove.double : otherwise;
  if (can.contains(BjMove.split) && h.cards.length == 2 && bjValue(h.cards[0]) == bjValue(h.cards[1])) {
    final v = bjValue(h.cards.first);
    final split = switch (v) {
      11 || 8 => true,
      10 || 5 => false,
      9 => d != 7 && d != 10 && d != 11,
      7 => d <= 7,
      6 => d <= 6,
      4 => d == 5 || d == 6,
      _ => d <= 7, // 2s and 3s
    };
    if (split) return BjMove.split;
  }
  final t = h.total;
  if (h.soft && h.cards.length >= 2) {
    if (t >= 20) return BjMove.stand;
    if (t == 19) return d == 6 ? dbl(BjMove.stand) : BjMove.stand;
    if (t == 18) {
      if (d <= 6) return dbl(BjMove.stand);
      return d <= 8 ? BjMove.stand : BjMove.hit;
    }
    if (t == 17) return d >= 3 && d <= 6 ? dbl(BjMove.hit) : BjMove.hit;
    if (t >= 15) return d >= 4 && d <= 6 ? dbl(BjMove.hit) : BjMove.hit;
    return d == 5 || d == 6 ? dbl(BjMove.hit) : BjMove.hit;
  }
  if (t >= 17) return BjMove.stand;
  if (t >= 13) return d <= 6 ? BjMove.stand : BjMove.hit;
  if (t == 12) return d >= 4 && d <= 6 ? BjMove.stand : BjMove.hit;
  if (t == 11) return dbl(BjMove.hit);
  if (t == 10) return d <= 9 ? dbl(BjMove.hit) : BjMove.hit;
  if (t == 9) return d >= 3 && d <= 6 ? dbl(BjMove.hit) : BjMove.hit;
  return BjMove.hit;
}

/// How a bot sits at the table.
enum BjStyle {
  /// Plays by the book, bets flat.
  bookie,

  /// Hates busting: stands on 12 and up.
  timid,

  /// Doubles and splits anything it can, chases 21.
  cowboy,

  /// Plays the hunch: by the book half the time.
  gut,
}

/// A bot player: its moves and its bets. Hard bots count cards (Hi-Lo)
/// and bet more when the shoe is rich in 10s.
class BjBot {
  BjBot({required this.style, required this.difficulty, Random? rng}) : _rng = rng ?? Random();

  final BjStyle style;
  final Difficulty difficulty;
  final Random _rng;

  /// How often it slips from its style.
  double get _slip => switch (difficulty) {
    Difficulty.easy => 0.25,
    Difficulty.normal => 0.1,
    Difficulty.hard => 0.02,
  };

  BjMove decide(BjHand h, PlayingCard up, List<BjMove> allowed) {
    // Late surrender by the book: hard 16 against 9, 10 or an Ace, hard 15
    // against a 10. The timid give up a little more often.
    if (allowed.contains(BjMove.surrender) && !h.soft) {
      final d = bjValue(up);
      final t = h.total;
      if ((t == 16 && d >= 9) ||
          (t == 15 && d == 10) ||
          (style == BjStyle.timid && t >= 14 && t <= 16 && d >= 9)) {
        if (style != BjStyle.cowboy && _rng.nextDouble() >= _slip) return BjMove.surrender;
      }
    }
    final book = basicStrategy(h, up, allowed);
    if (_rng.nextDouble() < _slip) {
      // A slip: hit or stand on a hunch.
      return h.total <= 15 ? BjMove.hit : BjMove.stand;
    }
    switch (style) {
      case BjStyle.bookie:
        return book;
      case BjStyle.timid:
        if (!h.soft && h.total >= 12) return BjMove.stand;
        return book == BjMove.double ? BjMove.hit : book;
      case BjStyle.cowboy:
        if (allowed.contains(BjMove.split) && bjValue(h.cards[0]) == bjValue(h.cards[1])) return BjMove.split;
        if (allowed.contains(BjMove.double) && h.total >= 9 && h.total <= 11) return BjMove.double;
        if (!h.soft && h.total <= 16 && _rng.nextDouble() < 0.5) return BjMove.hit;
        return book;
      case BjStyle.gut:
        if (_rng.nextBool()) return book;
        return h.total <= 13 + _rng.nextInt(4) ? BjMove.hit : BjMove.stand;
    }
  }

  /// Takes insurance? Only counters, when the shoe is rich in 10s (it's a
  /// bad bet otherwise); now and then a timid bot buys it out of fear.
  bool insure(double trueCount) =>
      (difficulty == Difficulty.hard && trueCount >= 3) ||
      (style == BjStyle.timid && _rng.nextDouble() < 0.3);

  /// Its bet for the next round, between [min] and [max], from [chips].
  int bet({required int min, required int max, required int chips, required double trueCount}) {
    var units = switch (style) {
      BjStyle.bookie => 2,
      BjStyle.timid => 1,
      BjStyle.cowboy => 3 + _rng.nextInt(4),
      BjStyle.gut => 1 + _rng.nextInt(5),
    };
    // Counting: a shoe full of 10s and Aces is worth betting into.
    if (difficulty == Difficulty.hard && trueCount >= 2) units *= trueCount.floor().clamp(2, 5);
    final b = (min * units).clamp(min, max);
    return b > chips ? chips : b;
  }
}
