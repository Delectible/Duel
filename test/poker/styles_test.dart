import 'dart:math';

import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/poker/bot.dart';
import 'package:duel_engine/poker/poker_hand.dart';
import 'package:duel_engine/poker/reads.dart';
import 'package:flutter_test/flutter_test.dart';

/// How often [style] plays a hand first in from early position at a full
/// table, with [reads] as the table's memory.
double _plays(BotStyle style, {TableReads? reads, int seat = 2}) {
  var played = 0;
  const n = 400;
  for (var k = 0; k < n; k++) {
    final h = PokerHand(
      players: [for (var s = 0; s < 6; s++) HandPlayer(seat: s, stack: 3000)],
      button: 5,
      smallBlind: 10,
      bigBlind: 20,
      rng: Random(k),
    );
    // Folds round to the bot in seat [seat].
    while (h.toAct != seat) {
      h.apply(const Move.fold());
    }
    final m = PokerBot(
      style: style,
      difficulty: Difficulty.normal,
      rng: Random(k * 7),
    ).decide(h, reads: reads);
    if (m.kind != MoveKind.fold) played++;
  }
  return played / n;
}

void main() {
  test('the Nit folds far more than the Gambler or a Maniac', () {
    expect(_plays(BotStyle.nit), lessThan(_plays(BotStyle.maniac)));
    expect(_plays(BotStyle.nit), lessThan(0.15));
  });

  test('the Copycat plays like seat 0: loose against a loose player, tight against a tight one', () {
    TableReads table(int vpip) {
      final r = TableReads(6);
      r.players[0]
        ..hands = 40
        ..vpip = vpip
        ..pfr = vpip ~/ 2
        ..bets = 8
        ..calls = 8;
      return r;
    }

    expect(
      _plays(BotStyle.copycat, reads: table(28)),
      greaterThan(_plays(BotStyle.copycat, reads: table(4))),
    );
  });

  test('the Wildcard changes gear every six hands', () {
    TableReads at(int hands) => TableReads(6)..players[2].hands = hands;
    final tight = _plays(BotStyle.wildcard, reads: at(0)), wild = _plays(BotStyle.wildcard, reads: at(6));
    expect(wild, greaterThan(tight));
  });
}
