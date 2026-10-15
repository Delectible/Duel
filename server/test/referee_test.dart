import 'dart:math';

import 'package:duel_server/duel_server.dart';
import 'package:test/test.dart';

void main() {
  const luca = Player(uid: 'luca', name: 'Luca');
  const sam = Player(uid: 'sam', name: 'Sam');
  const eve = Player(uid: 'eve', name: 'Eve');
  late MemoryStore store;
  late Referee ref;
  var now = DateTime.utc(2026, 10, 15);

  setUp(() {
    store = MemoryStore();
    now = DateTime.utc(2026, 10, 15);
    ref = Referee(store, rng: Random(1), clock: () => now);
  });

  /// Luca hosts, Sam joins, Four in a Row starts.
  Future<Map<String, Object?>> startGame() async {
    final party = await ref.createParty(luca);
    await ref.joinParty(sam, party['code']! as String);
    return ref.startMatch(luca, party['id']! as String, 'connect4');
  }

  Player whoseTurn(Map<String, Object?> m) => (m['seats']! as List)[m['turn']! as int] == 'luca' ? luca : sam;

  test('a party: code to join, members and names, leave and close', () async {
    final party = await ref.createParty(luca);
    final code = party['code']! as String;
    expect(code, hasLength(6));
    final joined = await ref.joinParty(sam, code.toLowerCase());
    expect(joined['members'], ['luca', 'sam']);
    expect((joined['names']! as Map)['sam'], 'Sam');
    await ref.joinParty(sam, code); // twice is fine
    expect(((await store.get('parties/${party['id']}'))!['members']! as List), hasLength(2));
    await expectLater(ref.joinParty(eve, 'ZZZZZZ'), throwsA(isA<RefereeError>()));
    await ref.leaveParty(luca, party['id']! as String);
    expect((await store.get('parties/${party['id']}'))!['host'], 'sam', reason: 'host passes on');
    await ref.leaveParty(sam, party['id']! as String);
    expect(await store.get('parties/${party['id']}'), isNull);
    expect(await store.get('codes/$code'), isNull);
  });

  test('only the host starts, and only a game that fits the party', () async {
    final party = await ref.createParty(luca);
    final id = party['id']! as String;
    await expectLater(ref.startMatch(luca, id, 'connect4'), throwsA(isA<RefereeError>()), reason: 'alone');
    await ref.joinParty(sam, party['code']! as String);
    await expectLater(ref.startMatch(sam, id, 'connect4'), throwsA(isA<RefereeError>()), reason: 'not host');
    await expectLater(ref.startMatch(luca, id, 'chess'), throwsA(isA<RefereeError>()));
    final m = await ref.startMatch(luca, id, 'connect4');
    expect(m['status'], 'live');
    expect((await store.get('parties/$id'))!['matchId'], m['id']);
  });

  test('moves: right player, right version, legal column; plays to a win', () async {
    var m = await startGame();
    final id = m['id']! as String;
    final first = whoseTurn(m);
    final second = first == luca ? sam : luca;
    await expectLater(
      ref.move(second, id, 1, {'column': 3}),
      throwsA(isA<RefereeError>()),
      reason: 'not your turn',
    );
    await expectLater(
      ref.move(first, id, 9, {'column': 3}),
      throwsA(isA<RefereeError>()),
      reason: 'stale version',
    );
    await expectLater(
      ref.move(first, id, 1, {'column': 7}),
      throwsA(isA<RefereeError>()),
      reason: 'off the board',
    );
    await expectLater(ref.move(eve, id, 1, {'column': 3}), throwsA(isA<RefereeError>()), reason: 'not in it');
    // First stacks column 0, second column 1: first wins on its 4th disc.
    for (final col in [0, 1, 0, 1, 0, 1, 0]) {
      m = await ref.move(whoseTurn(m), id, m['version']! as int, {'column': col});
    }
    expect(m['status'], 'over');
    final result = m['result']! as Map;
    expect((m['seats']! as List)[result['winner']! as int], first.uid);
    expect(result['reason'], 'won');
    await expectLater(
      ref.move(second, id, m['version']! as int, {'column': 2}),
      throwsA(isA<RefereeError>()),
    );
  });

  test('a double tap lands once', () async {
    final m = await startGame();
    final p = whoseTurn(m);
    final a = ref.move(p, m['id']! as String, 1, {'column': 3});
    final b = ref.move(p, m['id']! as String, 1, {'column': 3});
    await a;
    await expectLater(b, throwsA(isA<RefereeError>()));
    expect(((await store.get('matches/${m['id']}'))!['state']! as Map)['moves'], [3]);
  });

  test('time runs out: a move is made for you, twice and you forfeit', () async {
    var m = await startGame();
    final id = m['id']! as String;
    final slow = whoseTurn(m);
    final other = slow == luca ? sam : luca;
    await expectLater(ref.claimTimeout(other, id), throwsA(isA<RefereeError>()), reason: 'still time');
    now = now.add(const Duration(seconds: 46));
    m = await ref.claimTimeout(other, id);
    expect((m['state']! as Map)['moves'], hasLength(1), reason: 'an auto move');
    m = await ref.move(other, id, m['version']! as int, {'column': 6});
    now = now.add(const Duration(seconds: 46));
    m = await ref.claimTimeout(other, id);
    expect(m['status'], 'over');
    expect((m['result']! as Map)['reason'], 'timeout');
    expect((m['seats']! as List)[(m['result']! as Map)['winner']! as int], other.uid);
  });

  test('forfeit, then a rematch when both ask (the other side starts)', () async {
    var m = await startGame();
    final id = m['id']! as String;
    final first = ((m['state']! as Map)['first'])! as int;
    m = await ref.forfeit(sam, id);
    expect(m['status'], 'over');
    expect((m['seats']! as List)[(m['result']! as Map)['winner']! as int], 'luca');
    m = await ref.rematch(luca, id);
    expect(m['next'], isNull);
    m = await ref.rematch(sam, id);
    final next = (await store.get('matches/${m['next']}'))!;
    expect(next['status'], 'live');
    expect((next['state']! as Map)['first'], (first + 1) % 2);
  });
}
