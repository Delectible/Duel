import 'dart:math';

import 'package:duel/core/cards/cards.dart';
import 'package:duel/core/session/difficulty.dart';
import 'package:duel/games/crazy_eights/engine/crazy_eights.dart';
import 'package:duel/games/crazy_eights/engine/eights_bot.dart';
import 'package:flutter_test/flutter_test.dart';

PlayingCard c(String s) => PlayingCard.parse(s);

/// A game with chosen hands and top card.
CrazyEights rigged(List<String> hands, String top, {String pile = ''}) {
  final g = CrazyEights(players: hands.length, rng: Random(1), dealer: hands.length - 1);
  for (var p = 0; p < hands.length; p++) {
    g.hands[p]
      ..clear()
      ..addAll(PlayingCard.parseAll(hands[p]));
  }
  g.discard
    ..clear()
    ..add(c(top));
  g.drawPile
    ..clear()
    ..addAll(PlayingCard.parseAll(pile));
  g.suit = c(top).suit;
  g.turn = 0;
  return g;
}

void main() {
  test('deal: 7 cards heads-up, 5 with 3-4; starter is never an eight', () {
    for (var seed = 0; seed < 200; seed++) {
      for (final n in [2, 3, 4]) {
        final g = CrazyEights(players: n, rng: Random(seed));
        expect(g.hands.every((h) => h.length == (n == 2 ? 7 : 5)), isTrue);
        expect(g.top.rank, isNot(8));
        expect(g.hands.fold(0, (s, h) => s + h.length) + g.drawPile.length + g.discard.length, 52);
      }
    }
  });

  test('match by suit or number; eights go on anything and name the suit', () {
    final g = rigged(['7h Kc 8s 2d', '3c 4c'], '7c');
    expect(g.playable(0).toSet(), {c('7h'), c('Kc'), c('8s')});
    expect(() => g.play(0, c('2d')), throwsArgumentError);
    expect(() => g.play(0, c('8s')), throwsArgumentError, reason: 'an eight needs a suit');
    g.play(0, c('8s'), chose: Suit.diamonds);
    expect(g.suit, Suit.diamonds);
    expect(g.turn, 1);
    // On an eight, only the named suit (or another eight) fits.
    expect(g.playable(1), isEmpty);
    expect(g.fits(c('3d')), isTrue);
    expect(g.fits(c('8c')), isTrue);
  });

  test("draw: a card that fits may be played or kept; one that doesn't ends the turn", () {
    final g = rigged(['2d', '3c'], '7c', pile: '9s 5c');
    final drawn = g.draw(0); // 5c fits
    expect(drawn, c('5c'));
    expect(g.turn, 0);
    expect(g.playable(0), [c('5c')]);
    expect(g.canPass, isTrue);
    g.pass(0);
    expect(g.turn, 1);
    final g2 = rigged(['2d', '3c'], '7c', pile: '9s');
    g2.draw(0); // 9s doesn't fit
    expect(g2.turn, 1);
    expect(g2.lacking[0], {Suit.clubs});
  });

  test('empty draw pile: the discards are shuffled back in', () {
    final g = rigged(['2d', '3c'], '7c');
    g.discard.insertAll(0, PlayingCard.parseAll('4s 5s 6s'));
    g.draw(0);
    expect(g.events.whereType<Reshuffled>(), hasLength(1));
    expect(g.discard, [c('7c')]);
    expect(g.drawPile.length, 2);
  });

  test('playing your last card wins', () {
    final g = rigged(['7h', '3c'], '7c');
    g.play(0, c('7h'));
    expect(g.winner, 0);
    expect(g.events.last, isA<Won>());
  });

  test('blocked: nobody can play or draw, fewest cards wins', () {
    final g = rigged(['2d 3d', '4d'], '7c');
    g.pass(0);
    g.pass(1);
    expect(g.winner, 1);
    expect((g.events.last as Won).blocked, isTrue);
  });

  test('normal bots save eights and name their long suit', () {
    final g = rigged(['8s 7h Kh Qh 2c', '3c'], '7c');
    final bot = EightsBot(difficulty: Difficulty.normal, rng: Random(1));
    final m = bot.decide(g, 0) as PlayCard;
    expect(m.card, c('7h'), reason: 'switch to hearts, keep the eight');
    final g2 = rigged(['8s Kh Qh 2s', '3c'], '7c');
    final m2 = bot.decide(g2, 0) as PlayCard;
    expect(m2.card, c('8s'));
    expect(m2.suit, Suit.hearts);
  });

  for (final difficulty in Difficulty.values) {
    for (final n in [2, 3, 4]) {
      test('${difficulty.label} bots finish $n-player games', () {
        final rng = Random(n * 10 + difficulty.index);
        for (var game = 0; game < 40; game++) {
          final g = CrazyEights(players: n, rng: rng);
          final bots = [for (var p = 0; p < n; p++) EightsBot(difficulty: difficulty, rng: rng)];
          var moves = 0;
          while (!g.isOver) {
            expect(++moves, lessThan(2000));
            final p = g.turn;
            switch (bots[p].decide(g, p)) {
              case PlayCard(:final card, :final suit):
                g.play(p, card, chose: suit);
              case DrawCard():
                g.draw(p);
              case PassTurn():
                g.pass(p);
            }
            expect(g.hands.fold(0, (s, h) => s + h.length) + g.drawPile.length + g.discard.length, 52);
          }
        }
      });
    }
  }
}
