import 'dart:math';

import 'package:duel_engine/blackjack/bj_bot.dart';
import 'package:duel_engine/blackjack/blackjack.dart';
import 'package:duel_engine/cards.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

List<PlayingCard> c(String s) => PlayingCard.parseAll(s);

void main() {
  test('totals: Aces count 11 until that busts', () {
    expect(bjTotal(c('As Kd')), (total: 21, soft: true));
    expect(bjTotal(c('As 6d 9c')), (total: 16, soft: false));
    expect(bjTotal(c('As Ad 9c')), (total: 21, soft: true));
    expect(bjTotal(c('Qs Jd')), (total: 20, soft: false));
  });

  test('blackjack pays 3 to 2; the dealer stands on soft 17', () {
    // Deal order: you, dealer, you, dealer (hole).
    final shoe = Shoe(Random(1), stacked: c('As 6h Kd Ac'));
    final r = BjRound(shoe: shoe, bets: [100]);
    expect(r.turn, isNull, reason: 'blackjack: nothing to play');
    expect(r.dealerTotal, 17);
    expect(r.dealer.length, 2, reason: 'stands on soft 17');
    expect(r.hands[0].single.result, BjResult.blackjack);
    expect(r.net(0), 150);
  });

  test('the dealer peeks: a dealer blackjack beats everything but a blackjack', () {
    final shoe = Shoe(Random(1), stacked: c('Ts Ah 9d Kc'));
    final r = BjRound(shoe: shoe, bets: [50]);
    expect(r.insuring, isTrue, reason: 'an Ace up: insurance first');
    r.insure({});
    expect(r.settled, isTrue);
    expect(r.net(0), -50);
  });

  test('split, double after split, the dealer busts', () {
    // You 8 8 vs dealer 6 + T (16); split: 8+3 (double -> +T = 21), 8+9 = 17; dealer draws T: bust.
    final shoe = Shoe(Random(1), stacked: c('8s 6h 8d Tc 3h Tc 9s Td'));
    final r = BjRound(shoe: shoe, bets: [10]);
    expect(r.moves(), contains(BjMove.split));
    r.act(BjMove.split);
    expect(r.hands[0].length, 2);
    expect(r.current.total, 11);
    r.act(BjMove.double);
    expect(r.hands[0][0].total, 21);
    expect(r.current.total, 17);
    r.act(BjMove.stand);
    expect(r.settled, isTrue);
    expect(r.dealerTotal, greaterThan(21));
    expect(r.net(0), 20 + 10);
  });

  test('basic strategy: the classics', () {
    BjHand h(String s) => BjHand(10)..cards.addAll(c(s));
    const all = BjMove.values;
    expect(basicStrategy(h('Ts 6d'), PlayingCard.parse('Th'), all), BjMove.hit);
    expect(basicStrategy(h('Ts 6d'), PlayingCard.parse('6h'), all), BjMove.stand);
    expect(basicStrategy(h('6s 5d'), PlayingCard.parse('Th'), all), BjMove.double);
    expect(basicStrategy(h('8s 8d'), PlayingCard.parse('Th'), all), BjMove.split);
    expect(basicStrategy(h('Ts Td'), PlayingCard.parse('6h'), all), BjMove.stand);
    expect(basicStrategy(h('As 7d'), PlayingCard.parse('9h'), all), BjMove.hit);
  });

  test('over many rounds the house edge is small for the book, bigger for a cowboy', () {
    double edge(BjStyle style) {
      final rng = Random(7);
      final shoe = Shoe(rng);
      final bot = BjBot(style: style, difficulty: Difficulty.hard, rng: rng);
      var net = 0, bet = 0;
      for (var i = 0; i < 20000; i++) {
        if (shoe.due) shoe.shuffle();
        final r = BjRound(shoe: shoe, bets: [10]);
        if (r.insuring) r.insure({});
        while (r.playing) {
          r.act(bot.decide(r.current, r.upCard, r.moves()));
        }
        net += r.net(0);
        bet += 10;
      }
      return net / bet;
    }

    final book = edge(BjStyle.bookie);
    expect(book, inInclusiveRange(-0.04, 0.03));
    expect(edge(BjStyle.cowboy), lessThan(book));
  });

  group('house rules', () {
    test('a soft 17: S17 stands, H17 draws', () {
      const noIns = BjRules(insurance: false);
      // You T 9 (19) vs dealer A + 6 (soft 17); next card a 2.
      final s17 = BjRound(
        shoe: Shoe(Random(1), stacked: c('Ts As 9h 6d 2c')),
        bets: [10],
        rules: noIns,
      );
      s17.act(BjMove.stand);
      expect(s17.dealerTotal, 17);
      expect(s17.net(0), 10);
      final h17 = BjRound(
        shoe: Shoe(Random(1), stacked: c('Ts As 9h 6d 2c')),
        bets: [10],
        rules: noIns.copyWith(hitSoft17: true),
      );
      h17.act(BjMove.stand);
      expect(h17.dealerTotal, 19);
      expect(h17.net(0), 0);
    });

    test('blackjack pays 6 to 5 when the house says so', () {
      final r = BjRound(
        shoe: Shoe(Random(1), stacked: c('As 9h Kd 7c')),
        bets: [10],
        rules: const BjRules(sixToFive: true),
      );
      expect(r.net(0), 12);
    });

    test('late surrender gives back half the bet', () {
      const rules = BjRules(surrender: true);
      final r = BjRound(
        shoe: Shoe(Random(1), stacked: c('Ts 9h 6d Tc')),
        bets: [10],
        rules: rules,
      );
      expect(r.moves(), contains(BjMove.surrender));
      r.act(BjMove.surrender);
      expect(r.settled, isTrue);
      expect(r.hands[0].single.result, BjResult.surrender);
      expect(r.net(0), -5);
      // Not without the rule.
      final no = BjRound(
        shoe: Shoe(Random(1), stacked: c('Ts 9h 6d Tc')),
        bets: [10],
      );
      expect(no.moves(), isNot(contains(BjMove.surrender)));
    });

    test('insurance pays 2 to 1 against a dealer blackjack, and is lost otherwise', () {
      final hit = BjRound(
        shoe: Shoe(Random(1), stacked: c('Ts Ah 9d Kc')),
        bets: [10],
      );
      hit.insure({0});
      expect(hit.staked(0), 15);
      expect(hit.net(0), 0, reason: '-10 on the hand, +10 on the insurance');
      final miss = BjRound(
        shoe: Shoe(Random(1), stacked: c('Ts Ah 9d 5c 7s')),
        bets: [10],
      );
      miss.insure({0});
      expect(miss.playing, isTrue);
      miss.act(BjMove.stand);
      expect(miss.insuranceNet(0), -5);
    });

    test('no double after a split unless the house allows it; decks in the shoe', () {
      final r = BjRound(
        shoe: Shoe(Random(1), stacked: c('8s 6h 8d Tc 3h Tc 9s Td')),
        bets: [10],
        rules: const BjRules(doubleAfterSplit: false),
      );
      r.act(BjMove.split);
      expect(r.moves(), isNot(contains(BjMove.double)));
      expect(Shoe(Random(1), decks: 1).left, 52);
      expect(Shoe(Random(1), decks: 8).left, 416);
      expect(
        BjRules.fromJson(const BjRules(decks: 2, hitSoft17: true).toJson()),
        const BjRules(decks: 2, hitSoft17: true),
      );
    });
  });
}
