import 'dart:math';

import 'package:duel_engine/blitz/blitz.dart';
import 'package:duel_engine/blitz/blitz_bot.dart';
import 'package:duel_engine/cards.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

PlayingCard c(String s) => PlayingCard.parse(s);

/// Castle from notation: '[7h]' face down, '7h' face up; last is the top.
List<CastleCard> castle(String s) => [
  for (final t in s.split(' '))
    t.startsWith('[') ? CastleCard(c(t.substring(1, t.length - 1))) : CastleCard(c(t), faceUp: true),
];

/// A game set up by hand: [castles] and [hands] per player, player 0 to move
/// (already drawn), a deck to draw from.
Blitz table(
  List<String> castles,
  List<String> hands, {
  bool wars = false,
  String deck = '2c 3c 4c 5c 6c 7c 8c 9c',
}) {
  final g = Blitz(players: castles.length, rng: Random(1), wars: wars, first: 0);
  for (var p = 0; p < castles.length; p++) {
    g.castles[p]
      ..clear()
      ..addAll(castle(castles[p]));
    g.hands[p]
      ..clear()
      ..addAll(PlayingCard.parseAll(hands[p]));
  }
  g.drawPile
    ..clear()
    ..addAll(PlayingCard.parseAll(deck));
  g.discard.clear();
  g.turn = 0;
  g.pairUsed = false;
  return g;
}

void main() {
  test('the deal: castles of 7 with the top face up, hands of 4, decks by players', () {
    for (var players = 2; players <= 6; players++) {
      final g = Blitz(players: players, rng: Random(players), first: 0);
      for (var p = 0; p < players; p++) {
        expect(g.castles[p], hasLength(7));
        expect(g.castles[p].last.faceUp, isTrue);
        expect(g.castles[p].where((x) => x.faceUp), hasLength(1));
        expect(g.hands[p], hasLength(p == 0 ? 5 : 4), reason: 'the first player has drawn');
      }
      final total = g.drawPile.length + 11 * players + 1 + g.discard.length;
      expect(total, Blitz.decksFor(players) * 52);
    }
    expect(Blitz.decksFor(4), 1);
    expect(Blitz.decksFor(5), 2);
  });

  test('strike: same value, or an Ace either way; both cards go', () {
    final g = table(['[2s] 3s', '[4d] 9d 9h'], ['9c Kc', '5h']);
    expect(g.moves(0), contains(const Strike(PlayingCard(9, Suit.clubs), 1, 2)));
    expect(g.moves(0), contains(const Strike(PlayingCard(9, Suit.clubs), 1, 1)), reason: 'a scouted 9 too');
    expect(g.moves(0), isNot(contains(const Strike(PlayingCard(13, Suit.clubs), 1, 2))));
    g.apply(Strike(c('9c'), 1, 2));
    expect(g.castles[1].map((x) => '$x'), ['[4d]', '9d']);
    expect(g.discard, containsAll([c('9c'), c('9h')]));
    expect(g.turn, 1);

    // An Ace in hand hits anything, even face down; anything hits an Ace.
    final a = table(['3s', '[4d] Ah'], ['As 7c', '5h']);
    expect(a.moves(0), contains(Strike(c('As'), 1, 0)));
    expect(a.moves(0), contains(Strike(c('7c'), 1, 1)));
    a.apply(Strike(c('As'), 1, 0));
    expect((a.events.whereType<Struck>().last).blind, isTrue);
  });

  test('a struck top card turns up the next one', () {
    final g = table(['3s', '[4d] [5d] 9d'], ['9c', '5h']);
    g.apply(Strike(c('9c'), 1, 2));
    expect(g.castles[1].last.faceUp, isTrue);
    expect(g.events.whereType<Flipped>().last.card, c('5d'));
  });

  test('scout: discard any card, turn any face-down card up', () {
    final g = table(['3s', '[4d] [5d] 9d'], ['Kc', '5h']);
    g.apply(Scout(c('Kc'), 1, 0));
    expect(g.castles[1].first.faceUp, isTrue);
    expect(g.hands[0], isEmpty);
    expect(g.events.whereType<Scouted>().last.revealed, c('4d'));
  });

  test('fortify: match your own face-up card, two new cards on top', () {
    final g = table(['[2s] 7s', '9d'], ['7c', '5h'], deck: '4h 5h');
    g.apply(Fortify(c('7c'), 1));
    expect(g.castles[0].map((x) => '$x'), ['[2s]', '[5h]', '4h']);
  });

  test('a pair: draw two and go on; only one pair a turn', () {
    final g = table(['3s', '9d'], ['8c 8h 6c 6d', '5h'], deck: '2d 3d');
    g.apply(const Pair(8));
    expect(g.turn, 0, reason: 'still your turn');
    expect(g.hands[0], hasLength(4));
    expect(g.moves(0).whereType<Pair>(), isEmpty, reason: 'one pair a turn');
    // The other go: fortify the 3 with the 3 just drawn.
    g.apply(Fortify(c('3d'), 0));
    expect(g.turn, 1);
  });

  test('blitz: five of a colour knocks out every face-up card, then a whole new turn', () {
    final g = table(['3s', '[4d] Qd [5s] 9d'], ['2h 3h 4d 5d 6h Ac', '5h'], deck: '2c 3c 4c 5c 6c 7c 8c');
    final m = g.moves(0).whereType<BlitzAttack>().toList();
    expect(m, [const BlitzAttack(red: true, target: 1)]);
    g.apply(m.single);
    expect(g.castles[1].map((x) => '$x'), ['[4d]', '5s'], reason: 'face-up gone, new top turned');
    expect(g.turn, 0);
    expect(g.hands[0], hasLength(6), reason: '5 spent, 5 drawn, no extra draw');
    expect(g.events.whereType<TurnStarted>().last.extra, isTrue);
    // Aces count as their own colour only: four reds and a black Ace isn't one.
    final h = table(['3s', '9d'], ['2h 3h 4d 5d Ac', '5h']);
    expect(h.moves(0).whereType<BlitzAttack>(), isEmpty);
  });

  test('a castle that falls is out; the last castle wins', () {
    final g = table(['3s', '9d', '7h'], ['9c 7c', '5h', 'Kd'], deck: '2c 3c 4c 5c');
    g.apply(Strike(c('9c'), 1, 0));
    expect(g.isOut(1), isTrue);
    expect(g.places[1], 3);
    expect(g.turn, 2, reason: 'out players are skipped');
    g.apply(g.moves(2).first);
    g.turn = 0;
    g.apply(Strike(c('7c'), 2, 0));
    expect(g.winner, 0);
    expect(g.places, {1: 3, 2: 2, 0: 1});
  });

  group('wars', () {
    test('same values fight: the smallest castle keeps its card', () {
      final g = table(['[2c] 9s', '[2d] [3d] 4d', '5h'], ['4c', '5d', '6d'], wars: true, deck: '8d 8c 2h');
      // Scout reveals a 9 in the bigger castle: it loses it.
      g.castles[1].insert(0, CastleCard(c('9h')));
      g.apply(Scout(c('4c'), 1, 0));
      final war = g.events.whereType<War>().last;
      expect(war.rank, 9);
      expect(war.losers, [1]);
      expect(g.castles[1].any((x) => x.card == c('9h')), isFalse);
      // The castles as they stood before the fight, for the table to show
      // until the war scene is over.
      expect(war.before[1].any((x) => x.card == c('9h') && x.faceUp), isTrue);
      expect(war.before[0].map((x) => x.card), g.castles[0].map((x) => x.card));
    });

    test('a tie for smallest: they all lose theirs; never the last card', () {
      final g = table(['[2c] 9s', '[3d] 9h', '9d'], ['Kc', 'Kd', 'Kh'], wars: true);
      g.apply(Scout(c('Kc'), 1, 0));
      // Settled after the move: 0 and 1 (two cards each) tie and both lose;
      // 2 has one card left and keeps it.
      expect(g.castles[0].map((x) => x.card.rank), isNot(contains(9)));
      expect(g.castles[1].map((x) => x.card.rank), isNot(contains(9)));
      expect(g.castles[2].single.card, c('9d'));
    });

    test('both on their last card: nobody loses', () {
      final g = table(['9s', '9h'], ['Kc', 'Kd'], wars: true);
      expect(g.moves(0), [const PassTurn()], reason: 'nothing to hit or scout');
      g.apply(const PassTurn());
      expect(g.castles[0], hasLength(1));
      expect(g.castles[1], hasLength(1));
    });

    test('off: same values sit side by side', () {
      final g = table(['[2c] 9s', '[3d] [4d] 9h'], ['Kc', 'Kd']);
      g.apply(Scout(c('Kc'), 1, 0));
      expect(g.events.whereType<War>(), isEmpty);
    });
  });

  test('illegal moves are refused', () {
    final g = table(['3s', '9d'], ['Kc', '5h']);
    expect(() => g.apply(Strike(c('Kc'), 1, 0)), throwsArgumentError);
    expect(() => g.apply(Strike(c('Qc'), 1, 0)), throwsArgumentError, reason: 'not in hand');
    expect(() => g.apply(const Pair(13)), throwsArgumentError);
  });

  test('bots finish every game, all sizes, wars on and off', () {
    for (var seed = 0; seed < 60; seed++) {
      final players = 2 + seed % 5;
      final rng = Random(seed);
      final g = Blitz(players: players, rng: rng, wars: seed.isOdd);
      final bots = [
        for (var p = 0; p < players; p++) BlitzBot(difficulty: Difficulty.values[p % 3], rng: rng),
      ];
      while (!g.isOver) {
        g.apply(bots[g.turn].decide(g, g.turn));
      }
      expect(g.places.keys.toSet(), {for (var p = 0; p < players; p++) p});
      expect(g.places.values.toSet(), {for (var p = 1; p <= players; p++) p});
      // No card lost or made up.
      final cards =
          g.drawPile.length +
          g.discard.length +
          g.hands.fold(0, (s, h) => s + h.length) +
          g.castles.fold(0, (s, c) => s + c.length);
      expect(cards, Blitz.decksFor(players) * 52, reason: 'seed $seed');
    }
  });
}
