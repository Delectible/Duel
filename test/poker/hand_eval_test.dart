import 'package:duel_engine/cards.dart';
import 'package:duel_engine/poker/hand_eval.dart';
import 'package:flutter_test/flutter_test.dart';

HandValue ev(String cards) => evaluateHand(PlayingCard.parseAll(cards));

void main() {
  test('categories and descriptions', () {
    final cases = {
      'As Ks Qs Js Ts 2d 3c': ('Royal flush', HandCategory.straightFlush),
      '9h 8h 7h 6h 5h Ad Ac': ('Straight flush, Nine high', HandCategory.straightFlush),
      '7c 7d 7h 7s Kd 2c 3c': ('Four Sevens', HandCategory.quads),
      '8c 8d 8h Kd Ks 2c 3c': ('Full house, Eights full of Kings', HandCategory.fullHouse),
      'Ah 9h 6h 4h 2h Kd Kc': ('Flush, Ace high', HandCategory.flush),
      '9c 8d 7h 6s 5d Kd 2c': ('Straight, Nine high', HandCategory.straight),
      'Ac 2d 3h 4s 5d Kd 9c': ('Straight, Five high', HandCategory.straight),
      '6c 6d 6h As Kd 2c 3c': ('Three Sixes', HandCategory.trips),
      'Kc Kd 7h 7s 2d 3c 9c': ('Two pair, Kings and Sevens', HandCategory.twoPair),
      'Jc Jd 7h 4s 2d 3c 9c': ('Pair of Jacks', HandCategory.pair),
      'Ac Jd 7h 4s 2d 3c 9c': ('Ace high', HandCategory.highCard),
    };
    cases.forEach((cards, want) {
      final v = ev(cards);
      expect(v.describe(), want.$1, reason: cards);
      expect(v.category, want.$2, reason: cards);
      expect(v.cards, hasLength(5), reason: cards);
    });
  });

  test('ranking order', () {
    final ladder = [
      'Ac Jd 7h 4s 2d 3c 9c',
      'Jc Jd 7h 4s 2d 3c 9c',
      'Kc Kd 7h 7s 2d 3c 9c',
      '6c 6d 6h As Kd 2c 3c',
      'Ac 2d 3h 4s 5d Kd 9c',
      '9c 8d 7h 6s 5d Kd 2c',
      'Ah 9h 6h 4h 2h Kd Kc',
      '8c 8d 8h Kd Ks 2c 3c',
      '7c 7d 7h 7s Kd 2c 3c',
      '9h 8h 7h 6h 5h Ad Ac',
      'As Ks Qs Js Ts 2d 3c',
    ].map(ev).toList();
    for (var i = 1; i < ladder.length; i++) {
      expect(ladder[i].score, greaterThan(ladder[i - 1].score), reason: ladder[i].describe());
    }
  });

  test('kickers decide, equal hands split', () {
    expect(ev('Ac Ad Kh 7s 4d 3c 2c').score, greaterThan(ev('Ah As Qh 7c 4h 3d 2d').score));
    // Board plays: same five cards for both.
    expect(ev('2c 3d As Ks Qs Js Ts').score, ev('4c 5d As Ks Qs Js Ts').score);
    // Two pair: the fifth card is the best remaining, even a third pair.
    expect(ev('Kc Kd 7h 7s 5d 5c 9c').ranks, [13, 7, 9]);
  });

  test('wheel is the lowest straight; six-card straight takes the top', () {
    expect(ev('Ac 2d 3h 4s 5d 6d 9c').describe(), 'Straight, Six high');
    expect(ev('Ac 2d 3h 4s 5d Kd 9c').score, lessThan(ev('2c 3d 4h 5s 6d Kd 9c').score));
  });
}
