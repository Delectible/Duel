import 'dart:math';

import 'package:duel/core/cards/cards.dart';
import 'package:duel/core/session/difficulty.dart';
import 'package:duel/games/go_fish/engine/fish_bot.dart';
import 'package:duel/games/go_fish/engine/go_fish.dart';
import 'package:flutter_test/flutter_test.dart';

GoFish rigged(List<String> hands, {String pond = ''}) {
  final g = GoFish(players: hands.length, rng: Random(1), dealer: hands.length - 1);
  for (var p = 0; p < hands.length; p++) {
    g.hands[p]
      ..clear()
      ..addAll(PlayingCard.parseAll(hands[p]));
    g.books[p].clear();
  }
  g.pond
    ..clear()
    ..addAll(PlayingCard.parseAll(pond));
  g.events.clear();
  g.turn = 0;
  return g;
}

int total(GoFish g) => g.hands.fold(0, (s, h) => s + h.length) + g.pond.length + g.booksMade * 4;

void main() {
  test('deal: 7 cards with 2-3 players, 5 with 4-6', () {
    for (final n in [2, 3, 4, 6]) {
      final g = GoFish(players: n, rng: Random(n), dealer: 0);
      expect(total(g), 52);
      for (var p = 0; p < n; p++) {
        expect(g.hands[p].length + g.books[p].length * 4, n <= 3 ? 7 : 5);
      }
    }
  });

  test('a hit hands over every card of the rank and you go again', () {
    final g = rigged(['7h 2c', '7c 7d 9s'], pond: 'Kd');
    expect(g.ask(0, 1, 7), 2);
    expect(g.count(0, 7), 3);
    expect(g.turn, 0);
    expect(g.mustFish, isFalse);
  });

  test('a miss is go fish; a lucky catch goes again, else the turn passes', () {
    final g = rigged(['7h 2c', '9s 3d'], pond: '5d 7c');
    expect(g.ask(0, 1, 7), 0);
    expect(g.mustFish, isTrue);
    expect(() => g.ask(0, 1, 2), throwsStateError);
    g.fish(0); // 7c: lucky
    expect((g.events.last as Fished).lucky, isTrue);
    expect(g.turn, 0);
    g.ask(0, 1, 2);
    g.fish(0); // 5d
    expect(g.turn, 1);
  });

  test("four of a kind is a book; you can only ask for ranks you hold", () {
    final g = rigged(['7h 7d 7s 2c', '7c 3d'], pond: '5d');
    expect(() => g.ask(0, 1, 9), throwsArgumentError);
    g.ask(0, 1, 7);
    expect(g.books[0], [7]);
    expect(g.count(0, 7), 0);
    expect(g.events.whereType<Booked>(), hasLength(1));
  });

  for (final d in Difficulty.values) {
    for (final n in [2, 3, 6]) {
      test('${d.label} bots finish a $n-player game; all 13 books are made', () {
        final rng = Random(n * 7 + d.index);
        for (var game = 0; game < 30; game++) {
          final g = GoFish(players: n, rng: rng);
          final bots = [for (var p = 0; p < n; p++) FishBot(me: p, difficulty: d, rng: rng)];
          var steps = 0;
          while (!g.isOver) {
            expect(++steps, lessThan(3000));
            final p = g.turn;
            if (g.mustFish) {
              g.fish(p);
            } else {
              final (t, r) = bots[p].decide(g);
              g.ask(p, t, r);
            }
            expect(total(g), 52);
          }
          expect(g.booksMade, 13);
          expect(g.winners, isNotEmpty);
        }
      });
    }
  }

  test('Hard bots beat Easy bots most of the time', () {
    final rng = Random(5);
    var hardWins = 0, games = 200;
    for (var i = 0; i < games; i++) {
      final g = GoFish(players: 2, rng: rng);
      final bots = [
        FishBot(me: 0, difficulty: Difficulty.hard, rng: rng),
        FishBot(me: 1, difficulty: Difficulty.easy, rng: rng),
      ];
      while (!g.isOver) {
        final p = g.turn;
        if (g.mustFish) {
          g.fish(p);
        } else {
          final (t, r) = bots[p].decide(g);
          g.ask(p, t, r);
        }
      }
      if (g.winners!.length == 1 && g.winners!.single == 0) hardWins++;
    }
    expect(hardWins / games, greaterThan(0.55));
  });
}
