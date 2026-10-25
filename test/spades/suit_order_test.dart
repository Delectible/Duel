import 'package:duel/games/spades/ui/spades_screen.dart';
import 'package:duel_engine/cards.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('your hand: spades first, then red and black take turns', () {
    expect(suitOrder(Suit.values.toSet()), [Suit.spades, Suit.hearts, Suit.clubs, Suit.diamonds]);
    expect(suitOrder({Suit.spades, Suit.clubs, Suit.diamonds}), [Suit.spades, Suit.diamonds, Suit.clubs]);
    expect(suitOrder({Suit.hearts, Suit.diamonds, Suit.clubs}), [Suit.hearts, Suit.clubs, Suit.diamonds]);
    expect(suitOrder({Suit.spades, Suit.clubs}), [Suit.spades, Suit.clubs]);
  });
}
