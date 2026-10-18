import 'dart:math';

import 'package:duel_engine/cards.dart';
import 'package:duel_engine/poker/odds.dart';
import 'package:flutter_test/flutter_test.dart';

List<PlayingCard> c(String s) => PlayingCard.parseAll(s);

void main() {
  test('a made hand on the river wins outright', () {
    final p = winChances([c('As Ad'), c('Ks Kd')], c('2c 7h 9d Jc 3s'), rng: Random(1));
    expect(p, [1.0, 0.0]);
  });

  test('a split pot is shared', () {
    final p = winChances([c('2c 3d'), c('2d 3c')], c('As Ks Qs Js Ts'), rng: Random(1));
    expect(p, [0.5, 0.5]);
  });

  test('one card to come is counted exactly', () {
    // Kings need one of the two Kings left among 44 cards.
    final p = winChances([c('As Ad'), c('Ks Kd')], c('2c 7h 9d Jc'), rng: Random(1));
    expect(p[1], closeTo(2 / 44, 1e-9));
    expect(p[0] + p[1], closeTo(1, 1e-9));
  });

  test('preflop: Aces are big favourites over Kings', () {
    final p = winChances([c('As Ad'), c('Ks Kd')], const [], rng: Random(2), simulations: 2000);
    expect(p[0], inInclusiveRange(0.75, 0.88));
  });
}
