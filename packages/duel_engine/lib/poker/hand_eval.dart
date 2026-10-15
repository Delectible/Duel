import '../cards.dart';

enum HandCategory { highCard, pair, twoPair, trips, straight, flush, fullHouse, quads, straightFlush }

/// The best five-card hand out of 5..7 cards.
class HandValue implements Comparable<HandValue> {
  HandValue._(this.category, this.ranks, this.cards)
    : score = ranks.fold(category.index, (s, r) => s * 16 + r) * _pad(ranks.length);

  final HandCategory category;

  /// Ranks that decide ties, most important first.
  final List<int> ranks;

  /// The five cards that make the hand (for highlighting).
  final List<PlayingCard> cards;

  /// Higher wins; equal means a split.
  final int score;

  static int _pad(int n) {
    var p = 1;
    for (var i = n; i < 5; i++) {
      p *= 16;
    }
    return p;
  }

  @override
  int compareTo(HandValue other) => score.compareTo(other.score);

  /// "Two pair, Kings and Sevens", "Flush, Ace high", ...
  String describe() {
    final r = ranks;
    return switch (category) {
      HandCategory.straightFlush => r[0] == 14 ? 'Royal flush' : 'Straight flush, ${rankName(r[0])} high',
      HandCategory.quads => 'Four ${rankPlural(r[0])}',
      HandCategory.fullHouse => 'Full house, ${rankPlural(r[0])} full of ${rankPlural(r[1])}',
      HandCategory.flush => 'Flush, ${rankName(r[0])} high',
      HandCategory.straight => 'Straight, ${rankName(r[0])} high',
      HandCategory.trips => 'Three ${rankPlural(r[0])}',
      HandCategory.twoPair => 'Two pair, ${rankPlural(r[0])} and ${rankPlural(r[1])}',
      HandCategory.pair => 'Pair of ${rankPlural(r[0])}',
      HandCategory.highCard => '${rankName(r[0])} high',
    };
  }

  @override
  String toString() => describe();
}

/// Evaluates 5 to 7 cards.
HandValue evaluateHand(List<PlayingCard> cards) {
  assert(cards.length >= 5 && cards.length <= 7);
  final sorted = [...cards]..sort((a, b) => b.rank.compareTo(a.rank));
  final counts = List<int>.filled(15, 0);
  final bySuit = <Suit, List<PlayingCard>>{};
  for (final c in sorted) {
    counts[c.rank]++;
    bySuit.putIfAbsent(c.suit, () => []).add(c);
  }

  // Flush and straight flush.
  List<PlayingCard>? flush;
  for (final l in bySuit.values) {
    if (l.length >= 5) flush = l;
  }
  if (flush != null) {
    final sf = _straight(flush);
    if (sf != null) return HandValue._(HandCategory.straightFlush, [_high(sf)], sf);
  }

  final quads = <int>[], trips = <int>[], pairs = <int>[];
  for (var r = 14; r >= 2; r--) {
    switch (counts[r]) {
      case 4:
        quads.add(r);
      case 3:
        trips.add(r);
      case 2:
        pairs.add(r);
    }
  }

  List<PlayingCard> ofRank(int r, int n) => sorted.where((c) => c.rank == r).take(n).toList();
  List<PlayingCard> kickers(Set<int> used, int n) =>
      sorted.where((c) => !used.contains(c.rank)).take(n).toList();

  if (quads.isNotEmpty) {
    final q = quads.first;
    final k = kickers({q}, 1);
    return HandValue._(HandCategory.quads, [q, k.first.rank], [...ofRank(q, 4), ...k]);
  }
  if (trips.isNotEmpty && (trips.length > 1 || pairs.isNotEmpty)) {
    final t = trips.first;
    final p = [
      if (trips.length > 1) trips[1],
      if (pairs.isNotEmpty) pairs.first,
    ].reduce((a, b) => a > b ? a : b);
    return HandValue._(HandCategory.fullHouse, [t, p], [...ofRank(t, 3), ...ofRank(p, 2)]);
  }
  if (flush != null) {
    final five = flush.take(5).toList();
    return HandValue._(HandCategory.flush, [for (final c in five) c.rank], five);
  }
  final straight = _straight(sorted);
  if (straight != null) return HandValue._(HandCategory.straight, [_high(straight)], straight);
  if (trips.isNotEmpty) {
    final t = trips.first;
    final k = kickers({t}, 2);
    return HandValue._(HandCategory.trips, [t, for (final c in k) c.rank], [...ofRank(t, 3), ...k]);
  }
  if (pairs.length >= 2) {
    final a = pairs[0], b = pairs[1];
    final k = kickers({a, b}, 1);
    return HandValue._(HandCategory.twoPair, [a, b, k.first.rank], [...ofRank(a, 2), ...ofRank(b, 2), ...k]);
  }
  if (pairs.isNotEmpty) {
    final p = pairs.first;
    final k = kickers({p}, 3);
    return HandValue._(HandCategory.pair, [p, for (final c in k) c.rank], [...ofRank(p, 2), ...k]);
  }
  final five = sorted.take(5).toList();
  return HandValue._(HandCategory.highCard, [for (final c in five) c.rank], five);
}

/// The highest five-card straight in [cards] (sorted high to low), or null.
/// The ace also plays low (A-2-3-4-5).
List<PlayingCard>? _straight(List<PlayingCard> cards) {
  final byRank = <int, PlayingCard>{};
  for (final c in cards) {
    byRank.putIfAbsent(c.rank, () => c);
  }
  if (byRank.containsKey(14)) byRank[1] = byRank[14]!;
  for (var high = 14; high >= 5; high--) {
    final run = [for (var r = high; r > high - 5; r--) byRank[r]];
    if (run.every((c) => c != null)) return run.cast<PlayingCard>();
  }
  return null;
}

/// High card of a straight (the wheel's run starts at its 5).
int _high(List<PlayingCard> straight) => straight[0].rank;
