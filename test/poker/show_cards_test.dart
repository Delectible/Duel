import 'dart:math';

import 'package:duel/games/poker/ui/poker_controller.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/poker/hand_eval.dart';
import 'package:duel_engine/poker/poker_hand.dart';
import 'package:flutter_test/flutter_test.dart';

/// Showing your cards after a hand changes how the bots see you.
void main() {
  testWidgets(
    'a bluff shown after everyone folds: the table reads it, whoever folded is stung, someone says so',
    (tester) async {
      var shownBluff = false;
      for (var seed = 1; seed < 40 && !shownBluff; seed++) {
        final c = PokerController(bots: 3, difficulty: Difficulty.normal, pace: 0.02, rng: Random(seed));
        c.start();
        for (var i = 0; i < 4000 && !shownBluff && c.phase != TablePhase.finished; i++) {
          await tester.pump(const Duration(milliseconds: 20));
          if (c.phase == TablePhase.shuffle) {
            c.shuffleDeck();
            c.deal();
          }
          if (c.yourTurn) {
            // Bet the pot with anything: folds to a bluff follow.
            final legal = c.hand!.legalMoves();
            c.act(
              legal.canRaise
                  ? Move.raiseTo(min(legal.maxRaiseTo, c.hand!.currentBet + c.hand!.pot))
                  : const Move.call(),
            );
          }
          if (!c.waitingForYou || !c.canShowCards || c.hand!.result!.showdown) continue;
          final h = c.hand!;
          final me = c.handPlayer(0)!;
          final weak = h.board.length >= 3
              ? evaluateHand([...me.hole, ...h.board]).category == HandCategory.highCard
              : me.hole[0].rank != me.hole[1].rank && max(me.hole[0].rank, me.hole[1].rank) < 12;
          if (!weak) {
            c.nextHand();
            continue;
          }
          final folders = [
            for (final (k, p) in h.players.indexed)
              if (p.folded) c.game.handSeats[k],
          ];
          final tilt = {for (final s in folders) s: c.reads.players[s].tilt};
          final before = c.reads.players[0].bluffsShown;
          c.showCards();
          expect(c.reads.players[0].bluffsShown, before + 1, reason: 'the bots now know you bluff');
          expect(folders.any((s) => c.reads.players[s].tilt > tilt[s]!), isTrue, reason: 'stung');
          expect(c.talk.keys.any(folders.contains), isTrue, reason: 'someone says something');
          shownBluff = true;
        }
        c.dispose();
        await tester.pump(const Duration(seconds: 1));
      }
      expect(shownBluff, isTrue);
    },
  );
}
