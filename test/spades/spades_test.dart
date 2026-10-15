import 'dart:math';

import 'package:duel_engine/cards.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:duel/games/catalog.dart';
import 'package:duel_engine/spades/spades.dart';
import 'package:duel_engine/spades/spades_bot.dart';
import 'package:flutter_test/flutter_test.dart';

List<PlayingCard> cards(String s) => PlayingCard.parseAll(s);

/// Plays a whole game with bots in every seat; returns the winning team.
int botGame(int players, List<Difficulty> levels, {required int seed, int target = 250}) {
  final rng = Random(seed);
  final g = Spades(players: players, target: target, rng: rng, dealer: seed % players);
  final bots = [for (final d in levels) SpadesBot(difficulty: d, rng: rng)];
  for (var guard = 0; guard < 100000 && !g.isOver; guard++) {
    final p = g.turn;
    final bot = bots[p];
    switch (g.phase) {
      case SpadesPhase.draw:
        g.draw(p, keep: bot.keep(g, p, g.offered!));
      case SpadesPhase.bid:
        g.bid(p, bot.bid(g, p));
      case SpadesPhase.play:
        g.play(p, bot.play(g, p));
      case SpadesPhase.handOver:
        g.nextHand();
      case SpadesPhase.gameOver:
        break;
    }
  }
  expect(g.isOver, isTrue);
  return g.winner!;
}

void main() {
  test('four players: 13 each, bidding goes round from the dealer\'s left', () {
    final g = Spades(players: 4, rng: Random(1), dealer: 3);
    expect(g.phase, SpadesPhase.bid);
    for (final h in g.hands) {
      expect(h, hasLength(13));
    }
    expect(g.hands.expand((h) => h).toSet(), hasLength(52));
    expect(g.turn, 0);
    for (final p in [0, 1, 2, 3]) {
      g.bid(p, 3);
    }
    expect(g.phase, SpadesPhase.play);
    expect(g.turn, 0, reason: 'left of the dealer leads');
  });

  test('two-handed draw: keep one, lose one, until both have 13', () {
    final g = Spades(players: 2, rng: Random(2), dealer: 0);
    expect(g.phase, SpadesPhase.draw);
    expect(g.turn, 1);
    var turns = 0;
    while (g.phase == SpadesPhase.draw) {
      final top = g.offered!;
      final next = g.stock[1];
      final taken = g.draw(g.turn, keep: turns.isEven);
      expect(taken, turns.isEven ? top : next);
      turns++;
    }
    expect(turns, 26);
    expect(g.hands[0], hasLength(13));
    expect(g.hands[1], hasLength(13));
    expect(g.phase, SpadesPhase.bid);
  });

  test('follow suit; no spade leads until broken (unless only spades)', () {
    final g = Spades(players: 4, rng: Random(3), dealer: 3);
    g.hands[0] = cards('As Kh 2c');
    g.hands[1] = cards('3s 5h 9d');
    for (final p in [0, 1, 2, 3]) {
      g.bid(p, 1);
    }
    expect(g.legal(0), cards('Kh 2c'), reason: "can't lead spades yet");
    g.play(0, PlayingCard.parse('Kh'));
    expect(g.legal(1), cards('5h'), reason: 'must follow hearts');
    g.hands[0] = cards('As Ks');
    expect(Spades.beats(PlayingCard.parse('2s'), PlayingCard.parse('Ah'), Suit.hearts), isTrue);
    expect(Spades.beats(PlayingCard.parse('Ad'), PlayingCard.parse('2h'), Suit.hearts), isFalse);
  });

  test('a trick goes to the highest spade, else the highest of the suit led', () {
    final g = Spades(players: 4, rng: Random(4), dealer: 3);
    g.hands[0] = cards('Kh 2c');
    g.hands[1] = cards('Ah 3c');
    g.hands[2] = cards('2s 4c');
    g.hands[3] = cards('Qh 5c');
    for (final p in [0, 1, 2, 3]) {
      g.bid(p, 1);
    }
    g.play(0, PlayingCard.parse('Kh'));
    g.play(1, PlayingCard.parse('Ah'));
    expect(g.spadesBroken, isFalse);
    g.play(2, PlayingCard.parse('2s')); // void in hearts: trumps
    expect(g.spadesBroken, isTrue);
    g.play(3, PlayingCard.parse('Qh'));
    expect(g.tricksWon[2], 1);
    expect(g.turn, 2, reason: 'the winner leads next');
  });

  test('scoring: made bids, bags, missed bids, Nil, and the bag penalty', () {
    final g = Spades(players: 4, rng: Random(5));
    // Us: 4 + Nil (made); them: 5 + 4, took 5 (missed by 4).
    g.bids = [4, 5, 0, 4];
    g.tricksWon = [8, 3, 0, 2];
    g.bagCount[0] = 7;
    scoreNow(g);
    final r = g.events.whereType<HandScored>().last;
    final us = r.results[0], them = r.results[1];
    // Us: 40 for the bid, 4 bags (+4), Nil +100; bags 7 + 4 = 11: -100.
    expect(us.contractPoints, 40);
    expect(us.bags, 4);
    expect(us.nils, [(2, true)]);
    expect(us.bagPenalty, -100);
    expect(us.total, 40 + 4 + 100 - 100);
    expect(g.bagCount[0], 1);
    // Them: bid 9, won 5: -90.
    expect(them.contractPoints, -90);
    expect(them.total, -90);
  });

  test('first to the target wins; at -200 you lose', () {
    final g = Spades(players: 2, rng: Random(6), target: 150);
    g.scores = [140, 60];
    g.bids = [2, 3];
    g.tricksWon = [2, 3];
    scoreNow(g);
    expect(g.isOver, isTrue);
    expect(g.winner, 0);

    final m = Spades(players: 4, rng: Random(7));
    m.scores = [-150, 0];
    m.bids = [6, 1, 6, 1];
    m.tricksWon = [2, 4, 3, 4];
    scoreNow(m);
    expect(m.scores[0], lessThanOrEqualTo(Spades.mercy));
    expect(m.winner, 1);
  });

  test('bots play whole games, two-handed and in teams, to every length', () {
    for (var seed = 0; seed < 12; seed++) {
      botGame(4, [Difficulty.normal, Difficulty.hard, Difficulty.easy, Difficulty.normal], seed: seed);
      botGame(2, [Difficulty.hard, Difficulty.normal], seed: seed, target: const [150, 250, 500][seed % 3]);
    }
  });

  test('Hard bots beat Easy bots', () {
    var hardTeam = 0;
    const games = 40;
    for (var seed = 0; seed < games; seed++) {
      // Team 0 (seats 0, 2) Hard; team 1 Easy. Swap who's who half the time.
      final swap = seed.isOdd;
      final h = Difficulty.hard, e = Difficulty.easy;
      final w = botGame(4, swap ? [e, h, e, h] : [h, e, h, e], seed: 100 + seed);
      if (w == (swap ? 1 : 0)) hardTeam++;
    }
    expect(hardTeam, greaterThan(games * 0.65), reason: 'Hard won $hardTeam of $games');
  });

  test('bids: a strong hand bids high, a weak one goes Nil (Normal)', () {
    final strong = cards('As Ks Qs Js 9s Ah Kh Ad Kd 2c 3c 4c 5c');
    final weak = cards('2s 3s 2h 4h 6h 3d 5d 7d 9d 2c 4c 6c 8c');
    expect(SpadesBot.estimate(strong), greaterThan(7));
    expect(SpadesBot.nilHand(weak), isTrue);
    expect(SpadesBot.nilHand(strong), isFalse);
  });

  test('on the picker for 2 or 4 players, with a length to pick', () {
    final spades = games.singleWhere((g) => g.id == 'spades');
    expect(spades.available, isTrue);
    expect(spades.fits(2), isTrue);
    expect(spades.fits(3), isFalse);
    expect(spades.fits(4), isTrue);
    expect(spades.choice!.values, [150, 250, 500]);
  });
}

/// Scores the hand as if the 13th trick just ended.
void scoreNow(Spades g) => g.scoreHand();
