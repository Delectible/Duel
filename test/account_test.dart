import 'package:duel/core/account/account.dart';
import 'package:duel/core/avatars/faces.dart';
import 'package:duel/core/account/stake.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('money: free wins nothing; a win pays stake x opponents x rate; a loss costs the stake', () {
    final a = Account();
    expect(a.balance, 100);
    StakeTicket game(int stake, {int opponents = 3, Difficulty d = Difficulty.normal}) =>
        StakeTicket(account: a, gameId: 'g', stake: a.placeStake(stake), opponents: opponents, difficulty: d);
    final free = game(0)..settle(Outcome.win);
    expect(free.result, 0);
    expect(a.balance, 100);
    final win = game(10);
    expect(a.balance, 90, reason: 'the stake is taken at the start');
    win.settle(Outcome.win);
    expect(a.balance, 130);
    expect(win.result, 30);
    game(10, d: Difficulty.easy).settle(Outcome.win); // half: +15
    expect(a.balance, 145);
    game(10, opponents: 1, d: Difficulty.hard).settle(Outcome.win); // +15
    expect(a.balance, 160);
    game(20).settle(Outcome.loss);
    expect(a.balance, 140);
    game(20).settle(Outcome.tie);
    expect(a.balance, 140);
    final s = a.stats('g');
    expect([s.played, s.won, s.lost, s.tied, s.net], [6, 4, 1, 1, 40]);
  });

  test("out of money: stake 1 on credit, debt is paid off by winnings", () {
    final a = Account();
    a.placeStake(100);
    a.settle(gameId: 'g', stake: 100, outcome: Outcome.loss, opponents: 1, difficulty: Difficulty.normal);
    expect(a.balance, 0);
    expect(a.maxStake, 1);
    expect(a.placeStake(50), 1, reason: 'capped at 1 on credit');
    expect(a.balance, -1);
    expect(a.inDebt, isTrue);
    a.settle(gameId: 'g', stake: 1, outcome: Outcome.loss, opponents: 1, difficulty: Difficulty.normal);
    a.placeStake(1);
    expect(a.balance, -2);
    a.settle(gameId: 'g', stake: 1, outcome: Outcome.win, opponents: 3, difficulty: Difficulty.normal);
    expect(a.balance, 2, reason: 'stake back + 3 pays off the debt');
  });

  test('leaving early forfeits once; settling twice does nothing', () {
    final a = Account();
    final t = StakeTicket(
      account: a,
      gameId: 'g',
      stake: a.placeStake(10),
      opponents: 1,
      difficulty: Difficulty.normal,
    );
    t.forfeit();
    t.settle(Outcome.win);
    expect(a.balance, 90);
    expect(a.stats('g').lost, 1);
  });

  test('everything is saved and comes back', () {
    final store = MemoryStore();
    final a = Account(store: store)
      ..name = 'Luca'
      ..avatar = const Avatar(
        color: AvatarColor.lilac,
        shape: HeadShape.egg,
        face: Expression.cool,
        hat: Hat.crown,
      )
      ..currency = CurrencyChoice.eur
      ..theme = ThemeChoice.dark;
    a.placeStake(10);
    a.settle(gameId: 'gofish', stake: 10, outcome: Outcome.win, opponents: 2, difficulty: Difficulty.hard);
    final b = Account(store: store);
    expect(b.name, 'Luca');
    expect(
      b.avatar,
      const Avatar(color: AvatarColor.lilac, shape: HeadShape.egg, face: Expression.cool, hat: Hat.crown),
    );
    expect(b.currency, CurrencyChoice.eur);
    expect(b.theme, ThemeChoice.dark);
    expect(b.balance, 130);
    expect(b.stats('gofish').won, 1);
    expect(b.money(-1240), '−€1,240');
    expect(CurrencyChoice.pips.format(1), '1 pip');
    expect(CurrencyChoice.pips.format(1240), '1,240 pips');
  });
}
