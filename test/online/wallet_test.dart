import 'package:duel/core/account/account.dart';
import 'package:duel/core/online/party.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_server.dart';

/// Pips online: carried over once, bot games reported (offline too), and
/// online stakes moved by the referee.
void main() {
  Future<void> settle() => pumpEventQueue(times: 50);

  Future<int?> serverBalance(FakeServer srv, String uid) async =>
      (await srv.store.get('wallets/$uid'))?['balance'] as int?;

  test('the phone carries its balance over once, debt and all', () async {
    final srv = FakeServer();
    final store = MemoryStore();
    final luca = Account(store: store);
    // Lost everything, then a pip on credit: in debt.
    for (final stake in [100, 1]) {
      luca.settle(
        gameId: 'x',
        stake: luca.placeStake(stake),
        outcome: Outcome.loss,
        opponents: 1,
        difficulty: Difficulty.normal,
      );
    }
    expect(luca.balance, -1);
    final party = PartyService(srv.player('luca'), account: luca);
    await settle();
    expect(await serverBalance(srv, 'luca'), -1);
    expect(luca.walletDue, isFalse);

    // Reopening the app: the server's number wins, nothing is added twice.
    party.dispose();
    final again = Account(store: store);
    expect(again.balance, -1);
    PartyService(srv.player('luca'), account: again);
    await settle();
    expect(await serverBalance(srv, 'luca'), -1);
  });

  test('bot games are reported; played offline, they wait', () async {
    final srv = FakeServer();
    final luca = Account();
    PartyService(srv.player('luca'), account: luca);
    await settle();
    expect(await serverBalance(srv, 'luca'), 100);

    final stake = luca.placeStake(10);
    luca.settle(gameId: 'x', stake: stake, outcome: Outcome.win, opponents: 2, difficulty: Difficulty.normal);
    await settle();
    expect(await serverBalance(srv, 'luca'), 120);

    srv.offline = true;
    luca.settle(
      gameId: 'x',
      stake: luca.placeStake(10),
      outcome: Outcome.loss,
      opponents: 1,
      difficulty: Difficulty.normal,
    );
    await settle();
    expect(luca.balance, 110, reason: 'shown at once');
    expect(await serverBalance(srv, 'luca'), 120);
    expect(luca.walletDue, isTrue);

    srv.offline = false;
    luca.sound = false; // any change tries again
    await settle();
    expect(await serverBalance(srv, 'luca'), 110);
    expect(luca.balance, 110);
    expect(luca.walletDue, isFalse);
  });

  test('online: the referee takes the stakes and the winner takes the pot', () async {
    final srv = FakeServer();
    final luca = Account(), sam = Account()..name = 'Sam';
    final host = PartyService(srv.player('luca'), account: luca);
    final guest = PartyService(srv.player('sam'), account: sam);
    await settle();
    expect(await host.create(), isNull);
    expect(await guest.join(host.code!), isNull);
    expect(await host.start('crazy8', stake: 500), contains('not enough'));
    expect(await host.start('crazy8', stake: 30), isNull);
    await settle();
    expect([luca.balance, sam.balance], [70, 70]);

    final ticket = host.ticket(luca, host.match!);
    expect(await guest.forfeit(stake: 30), isNull);
    await settle();
    expect([luca.balance, sam.balance], [130, 70]);
    expect(ticket.settle(Outcome.win), 30, reason: 'the pot less your own stake');
    expect(luca.balance, 130, reason: 'the ticket only keeps stats');
    expect(luca.stats('crazy8').won, 1);
  });
}
