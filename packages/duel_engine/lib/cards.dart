import 'dart:math';

enum Suit {
  clubs,
  diamonds,
  hearts,
  spades;

  bool get isRed => this == diamonds || this == hearts;

  String get letter => const ['c', 'd', 'h', 's'][index];
}

/// A playing card. Ranks run 2..14 (Jack 11, Queen 12, King 13, Ace 14).
class PlayingCard {
  const PlayingCard(this.rank, this.suit) : assert(rank >= 2 && rank <= 14);

  /// Parses short notation: 'As', 'Td', '7h', '10c'.
  factory PlayingCard.parse(String s) {
    final suit = Suit.values.firstWhere((x) => x.letter == s[s.length - 1].toLowerCase());
    final r = s.substring(0, s.length - 1).toUpperCase();
    final rank = switch (r) {
      'A' => 14,
      'K' => 13,
      'Q' => 12,
      'J' => 11,
      'T' || '10' => 10,
      _ => int.parse(r),
    };
    return PlayingCard(rank, suit);
  }

  final int rank;
  final Suit suit;

  /// 0..51, unique per card.
  int get id => (rank - 2) * 4 + suit.index;

  /// What's printed in the card's corner.
  String get rankLabel => switch (rank) {
    14 => 'A',
    13 => 'K',
    12 => 'Q',
    11 => 'J',
    _ => '$rank',
  };

  @override
  bool operator ==(Object other) => other is PlayingCard && other.id == id;

  @override
  int get hashCode => id;

  @override
  String toString() => '${rank == 10 ? 'T' : rankLabel}${suit.letter}';

  static List<PlayingCard> parseAll(String s) =>
      s.split(' ').where((x) => x.isNotEmpty).map(PlayingCard.parse).toList();

  static final List<PlayingCard> fullDeck = [
    for (var rank = 2; rank <= 14; rank++)
      for (final suit in Suit.values) PlayingCard(rank, suit),
  ];
}

/// A shuffled 52-card deck dealt from the top.
class Deck {
  Deck.shuffled(Random rng) : _cards = [...PlayingCard.fullDeck]..shuffle(rng);

  /// A deck in a fixed order (tests); the rest of the deck follows.
  Deck.stacked(List<PlayingCard> top)
    : _cards = [...top, ...PlayingCard.fullDeck.where((c) => !top.contains(c))];

  final List<PlayingCard> _cards;
  var _next = 0;

  int get remaining => _cards.length - _next;

  PlayingCard draw() => _cards[_next++];
}

/// Rank names for hand descriptions.
String rankName(int rank) => const [
  '', '', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', //
  'Ten', 'Jack', 'Queen', 'King', 'Ace',
][rank];

String rankPlural(int rank) => rank == 6 ? 'Sixes' : '${rankName(rank)}s';

String suitName(Suit s, {bool plural = true}) {
  final n = const ['club', 'diamond', 'heart', 'spade'][s.index];
  return plural ? '${n}s' : n;
}

String rankWord(int rank) => switch (rank) {
  14 => 'Ace',
  13 => 'King',
  12 => 'Queen',
  11 => 'Jack',
  _ => '$rank',
};

/// "7 of hearts", "Queen of spades".
String cardName(PlayingCard c) => '${rankWord(c.rank)} of ${suitName(c.suit)}';
