import 'package:duel/core/account/account.dart';
import 'package:duel/core/account/achievements.dart';
import 'package:duel/games/poker/ui/poker_controller.dart';
import 'package:duel/games/poker/ui/rivals.dart';
import 'package:duel_engine/cards.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/poker/poker_hand.dart';
import 'package:duel_engine/poker/story.dart';
import 'package:flutter_test/flutter_test.dart';

PlayingCard c(String s) => PlayingCard.parse(s);

void main() {
  test('hand of the game: a bad call and a good fold', () {
    final call = YourDecision(
      hand: 4,
      street: Street.river,
      action: ActionLabel.call,
      hole: [c('7c'), c('2d')],
      board: const [],
      equity: 0.05,
      toCall: 800,
      pot: 400,
      bigBlind: 40,
    )..net = -900;
    final fold = YourDecision(
      hand: 9,
      street: Street.turn,
      action: ActionLabel.fold,
      hole: [c('Qh'), c('Jh')],
      board: const [],
      equity: 0.2,
      toCall: 300,
      pot: 300,
      bigBlind: 40,
      against: 'Finn',
    )..wouldHaveWon = false;
    final r = handOfTheGame([call, fold]);
    expect(r.worst, contains('Hand 4'));
    expect(r.best, contains("Finn's turn bet"));
  });

  test('the table story names the winner and the big moments', () {
    final lines = tableStory(
      names: const ['You', 'Pip', 'Finn'],
      events: const [BigPot(2, 4000, 'Flush, Ace high', 12), KnockOut(1, 0, 15), Comeback(1.5)],
      winner: 0,
      hands: 30,
    );
    expect(lines.first, 'You outlasted the table in 30 hands.');
    expect(
      lines.join(' '),
      allOf(contains('Finn'), contains('You knocked out Pip'), contains('fought back')),
    );
  });

  test('a rival sits in seat 1 with its own name and style; the account keeps scores', () {
    final rival = Rival.all.first;
    final t = PokerController(bots: 3, difficulty: Difficulty.normal, pace: 0, rival: rival, bountySeat: 2);
    expect(t.personas[1].name, rival.name);
    expect(t.styles[1], rival.style);
    expect(t.personas.map((p) => p.name).toSet().length, 4);
    t.dispose();
    final a = Account();
    a.rivalResult(rival.name, won: true);
    expect(a.rivalRecord(rival.name), (wins: 1, losses: 0));
    expect(a.earn(Achievement.bounty), isTrue);
    expect(a.earn(Achievement.bounty), isFalse);
    final store = MemoryStore();
    final b = Account(store: store)
      ..earn(Achievement.royal)
      ..rivalResult('Roxy', won: false)
      ..bonus('holdem', 25);
    final back = Account(store: store);
    expect(back.earned.keys, [Achievement.royal]);
    expect(back.rivalRecord('Roxy'), (wins: 0, losses: 1));
    expect(back.balance, b.balance);
  });
}
