import 'dart:math';

import 'package:duel_server/duel_server.dart';
import 'package:test/test.dart';

void main() {
  const luca = Player(uid: 'luca', name: 'Luca'), sam = Player(uid: 'sam', name: 'Sam');
  late MemoryStore store;
  late Referee ref;

  setUp(() {
    store = MemoryStore();
    ref = Referee(store, rng: Random(3), clock: () => DateTime.utc(2026, 10, 24));
  });

  Future<int> balance(String uid) async => (await store.get('wallets/$uid'))!['balance']! as int;

  test('the phone carries its balance over once (debt too); reports count once each', () async {
    expect((await ref.wallet(luca, carry: -40, id: 'a'))['balance'], -40);
    // Carrying again changes nothing: the server's number wins.
    expect((await ref.wallet(luca, carry: 500))['balance'], -40);
    expect((await ref.wallet(luca, id: 'b', delta: 25))['balance'], -15);
    expect((await ref.wallet(luca, id: 'b', delta: 25))['balance'], -15, reason: 'a resend');
    expect((await ref.wallet(luca, id: 'a', delta: 99))['balance'], -15, reason: 'the carry-over id');
    expect((await ref.wallet(sam))['balance'], Referee.startingBalance);
  });

  /// The first player stacks column 0, the other column 1: first wins.
  Future<Map<String, Object?>> playOut(Map<String, Object?> m) async {
    for (final col in [0, 1, 0, 1, 0, 1, 0]) {
      final p = (m['seats']! as List)[m['turn']! as int] == 'luca' ? luca : sam;
      m = await ref.move(p, m['id']! as String, m['version']! as int, {'column': col});
    }
    return m;
  }

  test('stakes go in at the start; the winner takes the pot', () async {
    await ref.wallet(luca, carry: 100);
    await ref.wallet(sam, carry: 30);
    final party = await ref.createParty(luca);
    await ref.joinParty(sam, party['code']! as String);
    final id = party['id']! as String;
    await expectLater(
      ref.startMatch(luca, id, 'connect4', stake: 50),
      throwsA(isA<RefereeError>().having((e) => e.message, 'message', contains('Sam has 30'))),
    );
    var m = await ref.startMatch(luca, id, 'connect4', stake: 20);
    expect([await balance('luca'), await balance('sam')], [80, 10]);
    m = await playOut(m);
    final winner = (m['seats']! as List)[(m['result']! as Map)['winner']! as int];
    expect((m['result']! as Map)['payouts'], {'${(m['seats']! as List).indexOf(winner)}': 40});
    expect(await balance(winner as String), winner == 'luca' ? 120 : 50);
    expect(await balance(winner == 'luca' ? 'sam' : 'luca'), winner == 'luca' ? 10 : 80);
  });

  test('leaving a one-on-one: the other takes the pot', () async {
    await ref.wallet(luca, carry: 100);
    await ref.wallet(sam, carry: 100);
    final party = await ref.createParty(luca);
    await ref.joinParty(sam, party['code']! as String);
    final m = await ref.startMatch(luca, party['id']! as String, 'crazy8', stake: 10);
    await ref.forfeit(sam, m['id']! as String);
    expect([await balance('luca'), await balance('sam')], [110, 90]);
  });

  test('a phone that never synced can only play free', () async {
    await ref.wallet(luca, carry: 100);
    final party = await ref.createParty(luca);
    await ref.joinParty(sam, party['code']! as String);
    await expectLater(
      ref.startMatch(luca, party['id']! as String, 'connect4', stake: 5),
      throwsA(isA<RefereeError>().having((e) => e.message, 'message', contains('latest Duel'))),
    );
    expect((await ref.startMatch(luca, party['id']! as String, 'connect4'))['status'], 'live');
  });

  test("Spades partners split the pot; a bot's share stays with the bank", () async {
    await ref.wallet(luca, carry: 100);
    await ref.wallet(sam, carry: 100);
    final party = await ref.createParty(luca);
    final id = party['id']! as String;
    await ref.joinParty(sam, party['code']! as String);
    await ref.setBots(luca, id, [
      {'name': 'Pip', 'look': 'cap', 'difficulty': 'easy'},
      {'name': 'Finn', 'look': 'fin', 'difficulty': 'easy'},
    ]);
    var m = await ref.startMatch(luca, id, 'spades', stake: 10, options: {'target': 150});
    final rng = Random(2);
    final game = onlineGames['spades']!;
    for (var i = 0; i < 2000 && m['status'] == 'live'; i++) {
      final seat = m['turn'] as int?;
      if (seat == null) break;
      final p = (m['seats']! as List)[seat] == 'luca' ? luca : sam;
      final state = (await store.get('secrets/${m['id']}'))!['state']! as Map<String, Object?>;
      m = await ref.move(p, m['id']! as String, m['version']! as int, game.autoMove(state, seat, rng));
    }
    expect(m['status'], 'over');
    final r = m['result']! as Map;
    final winners = (r['winners']! as List).cast<int>();
    expect(winners, hasLength(2));
    final seats = (m['seats']! as List).cast<String>();
    final people = {for (final w in winners) seats[w]}.where((s) => !s.startsWith('bot:')).toList();
    expect((r['payouts']! as Map).values, everyElement(20));
    for (final uid in ['luca', 'sam']) {
      expect(await balance(uid), people.contains(uid) ? 110 : 90);
    }
  });
}
