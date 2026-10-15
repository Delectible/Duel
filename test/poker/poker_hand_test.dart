import 'dart:math';

import 'package:duel_engine/cards.dart';
import 'package:duel_engine/poker/poker_hand.dart';
import 'package:flutter_test/flutter_test.dart';

/// A deck that deals [holes] (by player index) and [board].
Deck stacked({
  required int players,
  required int button,
  required Map<int, String> holes,
  String board = '',
}) {
  final h = holes.map((i, s) => MapEntry(i, PlayingCard.parseAll(s)));
  final b = PlayingCard.parseAll(board);
  final used = {...h.values.expand((x) => x), ...b};
  final spare = PlayingCard.fullDeck.where((c) => !used.contains(c)).iterator;
  PlayingCard filler() => (spare..moveNext()).current;
  final top = <PlayingCard>[
    for (var round = 0; round < 2; round++)
      for (var k = 1; k <= players; k++) h[(button + k) % players]?[round] ?? filler(),
  ];
  if (b.length == 5) {
    top.addAll([filler(), b[0], b[1], b[2], filler(), b[3], filler(), b[4]]);
  }
  return Deck.stacked(top);
}

PokerHand hand(List<int> stacks, {int button = 0, int sb = 10, int bb = 20, Deck? deck}) => PokerHand(
  players: [for (var i = 0; i < stacks.length; i++) HandPlayer(seat: i, stack: stacks[i])],
  button: button,
  smallBlind: sb,
  bigBlind: bb,
  rng: Random(1),
  deck: deck,
);

int total(PokerHand h) => h.players.fold(0, (s, p) => s + p.stack + p.committed);

void runOut(PokerHand h) {
  while (h.result == null) {
    expect(h.toAct, isNull);
    h.nextStreet();
  }
}

void main() {
  test('heads-up: the button is the small blind and acts first preflop, last after', () {
    final h = hand([1000, 1000], button: 0);
    expect(h.smallBlindIndex, 0);
    expect(h.bigBlindIndex, 1);
    expect(h.players[0].bet, 10);
    expect(h.players[1].bet, 20);
    expect(h.toAct, 0);
    h.apply(const Move.call());
    expect(h.toAct, 1, reason: 'big blind has the option');
    expect(h.legalMoves().canCheck, isTrue);
    h.apply(const Move.check());
    expect(h.toAct, isNull);
    h.nextStreet();
    expect(h.board, hasLength(3));
    expect(h.toAct, 1, reason: 'big blind acts first after the flop');
  });

  test('three-handed: blinds left of the button, button acts first preflop', () {
    final h = hand([1000, 1000, 1000], button: 2);
    expect(h.smallBlindIndex, 0);
    expect(h.bigBlindIndex, 1);
    expect(h.toAct, 2);
  });

  test('a raise must be at least the last raise', () {
    final h = hand([1000, 1000, 1000]);
    // Button (0) opens to 60: a raise of 40.
    expect(h.legalMoves().minRaiseTo, 40);
    h.apply(const Move.raiseTo(60));
    expect(h.legalMoves().minRaiseTo, 100);
    // Too small a raise is lifted to the minimum.
    h.apply(const Move.raiseTo(70));
    expect(h.players[1].bet, 100);
    expect(h.currentBet, 100);
  });

  test("an all-in short of a full raise doesn't reopen the betting", () {
    // Button A raises to 100, small blind B goes all-in for 150 (a raise of
    // 50 < 80), big blind C calls. A may call or fold but not re-raise.
    final h = hand([1000, 150, 1000], button: 0);
    h.apply(const Move.raiseTo(100));
    expect(h.toAct, 1);
    expect(h.legalMoves().maxRaiseTo, 150);
    h.apply(const Move.raiseTo(150));
    expect(h.players[1].allIn, isTrue);
    expect(h.toAct, 2);
    expect(h.legalMoves().canRaise, isTrue, reason: 'C has not acted yet');
    h.apply(const Move.call());
    expect(h.toAct, 0);
    final legal = h.legalMoves();
    expect(legal.callAmount, 50);
    expect(legal.canRaise, isFalse);
  });

  test('side pots go to the best hand each player is in for', () {
    final deck = stacked(
      players: 3,
      button: 0,
      holes: {0: 'Ah Ad', 1: 'Kh Kd', 2: 'Qh Qd'},
      board: '2c 7s 9d Jc 3h',
    );
    final h = hand([100, 300, 500], deck: deck);
    final before = total(h);
    h.apply(const Move.raiseTo(100)); // A all-in
    h.apply(const Move.raiseTo(300)); // B all-in
    expect(h.legalMoves().canRaise, isFalse, reason: 'nobody left to call a raise');
    h.apply(const Move.call()); // C calls 300
    expect(h.isAllInRunout, isTrue);
    runOut(h);
    final r = h.result!;
    expect(r.showdown, isTrue);
    expect([for (final p in r.pots) p.amount], [300, 400]);
    expect(r.pots[0].winners, [0]);
    expect(r.pots[1].winners, [1]);
    expect(r.pots[0].hand!.describe(), 'Pair of Aces');
    expect([for (final p in h.players) p.stack], [300, 400, 200]);
    expect(h.players.fold(0, (s, p) => s + p.stack), before);
  });

  test('an uncalled bet comes back as its own pot', () {
    final deck = stacked(players: 2, button: 0, holes: {0: '2c 7d', 1: 'Ah Ad'}, board: '3c 8s 9d Jc 4h');
    final h = hand([500, 100], deck: deck);
    h.apply(const Move.raiseTo(500)); // button shoves 500
    h.apply(const Move.call()); // big blind calls all-in for 100: 400 uncalled
    runOut(h);
    expect(h.result!.pots.map((p) => p.amount), [200, 400]);
    expect(h.result!.pots.last.eligible, [0]);
    expect([for (final p in h.players) p.stack], [400, 200]);
  });

  test('a split pot gives the odd chip to the first winner left of the button', () {
    final deck = stacked(
      players: 3,
      button: 0,
      holes: {0: '2c 3d', 1: '4c 5d', 2: '2h 3h'},
      board: 'As Ks Qs Js Ts',
    );
    final h = hand([1000, 1000, 1000], sb: 5, bb: 10, deck: deck);
    h.apply(const Move.call()); // button
    h.apply(const Move.fold()); // small blind: 5 dead
    h.apply(const Move.check()); // big blind
    for (var s = 0; s < 3; s++) {
      h.nextStreet();
      h.apply(const Move.check());
      h.apply(const Move.check());
    }
    h.nextStreet();
    expect(h.result!.pots.single.amount, 25);
    expect(h.result!.pots.single.winners, [2, 0]);
    expect(h.result!.winnings, {2: 13, 0: 12});
  });

  test('everyone folds: the last player takes it without a showdown', () {
    final h = hand([1000, 1000, 1000]);
    h.apply(const Move.raiseTo(60));
    h.apply(const Move.fold());
    h.apply(const Move.fold());
    expect(h.result, isNotNull);
    expect(h.result!.showdown, isFalse);
    expect(h.players[0].stack, 1030);
  });

  test('short blinds: a big blind all-in for less still plays', () {
    final h = hand([1000, 1000, 15]);
    expect(h.players[2].allIn, isTrue);
    expect(h.currentBet, 20);
    h.apply(const Move.call());
    h.apply(const Move.call());
    expect(h.toAct, isNull);
    // The two with chips left keep betting on the later streets.
    while (h.result == null) {
      h.toAct == null ? h.nextStreet() : h.apply(const Move.check());
    }
    expect(h.result!.pots.first.amount, 45);
    expect(h.result!.pots.first.eligible, [0, 1, 2]);
    expect(h.players.fold(0, (s, p) => s + p.stack), 2015);
  });

  test('random legal play always ends and never makes or loses chips', () {
    final rng = Random(42);
    for (var n = 0; n < 2000; n++) {
      final count = 2 + rng.nextInt(5);
      final stacks = [for (var i = 0; i < count; i++) 1 + rng.nextInt(400)];
      final h = PokerHand(
        players: [for (var i = 0; i < count; i++) HandPlayer(seat: i, stack: stacks[i])],
        button: rng.nextInt(count),
        smallBlind: 5,
        bigBlind: 10,
        rng: rng,
      );
      final chips = stacks.reduce((a, b) => a + b);
      var steps = 0;
      while (h.result == null) {
        expect(++steps, lessThan(200));
        if (h.toAct == null) {
          h.nextStreet();
          continue;
        }
        final legal = h.legalMoves();
        final r = rng.nextDouble();
        if (r < 0.15) {
          h.apply(const Move.fold());
        } else if (r < 0.7 || !legal.canRaise) {
          h.apply(legal.canCheck ? const Move.check() : const Move.call());
        } else {
          h.apply(Move.raiseTo(legal.minRaiseTo + rng.nextInt(legal.maxRaiseTo - legal.minRaiseTo + 1)));
        }
      }
      expect(h.players.fold(0, (s, p) => s + p.stack), chips);
      expect(h.result!.pots.fold(0, (s, p) => s + p.amount), h.players.fold(0, (s, p) => s + p.committed));
    }
  });
}
