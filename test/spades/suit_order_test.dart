import 'package:duel_engine/cards.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('your hand: spades first, then red and black take turns', () {
    expect(suitOrder(Suit.values.toSet()), [Suit.spades, Suit.hearts, Suit.clubs, Suit.diamonds]);
    expect(suitOrder({Suit.spades, Suit.clubs, Suit.diamonds}), [Suit.spades, Suit.diamonds, Suit.clubs]);
    expect(suitOrder({Suit.hearts, Suit.diamonds, Suit.clubs}), [Suit.hearts, Suit.clubs, Suit.diamonds]);
    expect(suitOrder({Suit.spades, Suit.clubs}), [Suit.spades, Suit.clubs]);
  });

  test('every game sorts hands this way: by suit, or by rank with the colours taking turns', () {
    final cards = [
      for (final s in ['2d', 'Kc', '5s', '9h', '5d', '5c']) PlayingCard.parse(s),
    ];
    expect(sortBySuit(cards).map((c) => c.toString()), ['5s', '9h', '5c', 'Kc', '2d', '5d']);
    expect(sortByRank(cards).map((c) => c.toString()), ['2d', '5s', '5d', '5c', '9h', 'Kc']);
  });
}
