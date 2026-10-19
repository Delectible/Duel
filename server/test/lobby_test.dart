import 'dart:math';

import 'package:duel_server/duel_server.dart';
import 'package:test/test.dart';

/// Leaving and coming back: three friends and a bot at Hold'em.
void main() {
  late MemoryStore store;
  late Referee ref;
  late DateTime now;
  const luca = Player(uid: 'luca', name: 'Luca'),
      sam = Player(uid: 'sam', name: 'Sam'),
      kit = Player(uid: 'kit', name: 'Kit');
  final people = {'luca': luca, 'sam': sam, 'kit': kit};

  setUp(() {
    store = MemoryStore();
    now = DateTime.utc(2026, 10, 19);
    ref = Referee(store, rng: Random(2), clock: () => now);
  });

  Future<(String, Map<String, Object?>)> table({bool bot = true}) async {
    final party = await ref.createParty(luca);
    final id = party['id']! as String;
    await ref.joinParty(sam, party['code']! as String);
    await ref.joinParty(kit, party['code']! as String);
    if (bot) {
      await ref.setBots(luca, id, [
        {'name': 'Pip', 'look': 'cap', 'difficulty': 'easy'},
      ]);
    }
    return (id, await ref.startMatch(luca, id, 'holdem', stake: 10));
  }

  int seatOf(Map<String, Object?> m, String uid) => (m['seats']! as List).indexOf(uid);
  Player turn(Map<String, Object?> m) => people[(m['seats']! as List)[m['turn']! as int]]!;
  Map<String, Object?> paused(Map<String, Object?> m) => (m['paused']! as Map).cast<String, Object?>();

  /// Plays calls / checks until the turn is someone in [who] (or it's over).
  Future<Map<String, Object?>> playUntil(Map<String, Object?> m, Set<String> who) async {
    for (var i = 0; i < 200 && m['status'] == 'live' && !who.contains(turn(m).uid); i++) {
      final p = turn(m);
      m = await ref
          .move(p, m['id']! as String, m['version']! as int, {'kind': 'check'})
          .catchError((Object _) => ref.move(p, m['id']! as String, m['version']! as int, {'kind': 'call'}));
    }
    return m;
  }

  test('someone leaves: the game pauses for the host, nobody can move', () async {
    final (_, start) = await table();
    final id = start['id']! as String;
    final m = await ref.forfeit(sam, id);
    expect(m['status'], 'live');
    expect(m['left'], [seatOf(m, 'sam')]);
    expect(paused(m)['seats'], [seatOf(m, 'sam')]);
    expect(paused(m)['decider'], 'luca');
    expect(m['turn'], isNull);
    expect(m['deadline'], isNull);
    final p = luca; // anyone
    await expectLater(ref.move(p, id, m['version']! as int, {'kind': 'fold'}), throwsA(isA<RefereeError>()));
    await expectLater(ref.claimTimeout(kit, id), throwsA(isA<RefereeError>()));
    // Only the host decides (until the time is up).
    await expectLater(ref.decide(kit, id, 'bot'), throwsA(isA<RefereeError>()));
    await expectLater(ref.decide(kit, id, 'end'), throwsA(isA<RefereeError>()));
    // Leaving twice changes nothing.
    expect((await ref.forfeit(sam, id))['version'], m['version']);
  });

  test('the host brings in a bot: it plays the seat, the game goes on', () async {
    final (_, start) = await table();
    final id = start['id']! as String;
    var m = await ref.forfeit(sam, id);
    m = await ref.decide(luca, id, 'bot');
    expect(m['paused'], isNull);
    expect((m['standIns']! as Map).keys, ['${seatOf(m, 'sam')}']);
    expect(
      ['luca', 'kit'],
      contains((m['seats']! as List)[m['turn']! as int]),
      reason: 'bots (and Sam\'s) moved',
    );
    expect(m['deadline'], isNotNull);
    // Deciding again (a late tap) changes nothing.
    expect((await ref.decide(luca, id, 'end'))['status'], 'live');
    // Play on a while: Sam's seat is played for them.
    m = await playUntil(m, {'nobody'});
    expect(m['status'], 'over');
  });

  test('nobody decides: after 30 seconds anyone can bring in the bot', () async {
    final (_, start) = await table();
    final id = start['id']! as String;
    await ref.forfeit(sam, id);
    now = now.add(Referee.decideTime + const Duration(seconds: 1));
    final m = await ref.decide(kit, id, 'bot');
    expect(m['paused'], isNull);
    expect((m['standIns']! as Map), contains('${seatOf(m, 'sam')}'));
  });

  test('the host ends it: stakes back for those still in', () async {
    final (_, start) = await table();
    final id = start['id']! as String;
    await ref.forfeit(sam, id);
    final m = await ref.decide(luca, id, 'end');
    expect(m['status'], 'over');
    expect(m['result'], {
      'winner': null,
      'draw': false,
      'reason': 'ended',
      'left': [seatOf(m, 'sam')],
    });
  });

  test('the host leaves: the next one still playing becomes host and decides', () async {
    final (partyId, start) = await table();
    final id = start['id']! as String;
    final m = await ref.forfeit(luca, id);
    expect(paused(m)['decider'], 'sam');
    expect((await store.get('parties/$partyId'))!['host'], 'sam');
    expect((await ref.decide(sam, id, 'bot'))['paused'], isNull);
  });

  test('two leave, one is left among bots: the game ends', () async {
    final (_, start) = await table();
    final id = start['id']! as String;
    await ref.forfeit(sam, id);
    final m = await ref.forfeit(kit, id);
    expect(m['status'], 'over');
    expect(m['result'], containsPair('reason', 'ended'));
    expect((m['result']! as Map)['left'], unorderedEquals([seatOf(m, 'sam'), seatOf(m, 'kit')]));
  });

  test('coming back while the host decides: straight back in, play goes on', () async {
    final (_, start) = await table();
    final id = start['id']! as String;
    await ref.forfeit(sam, id);
    final m = await ref.rejoin(sam, id);
    expect(m['left'], isEmpty);
    expect(m['paused'], isNull);
    expect(m['turn'], isNotNull);
    expect(m['deadline'], isNotNull);
  });

  test('coming back after a bot sat in: your seat as it stands', () async {
    final (_, start) = await table();
    final id = start['id']! as String;
    await ref.forfeit(sam, id);
    var m = await ref.decide(luca, id, 'bot');
    // A few moves with the bot in Sam's seat.
    for (var i = 0; i < 4 && m['status'] == 'live'; i++) {
      final p = turn(m);
      m = await ref
          .move(p, id, m['version']! as int, {'kind': 'check'})
          .catchError((Object _) => ref.move(p, id, m['version']! as int, {'kind': 'call'}));
    }
    expect(m['status'], 'live');
    m = await ref.rejoin(sam, id);
    expect(m['left'], isEmpty);
    expect(m['standIns'], isEmpty);
    // Sam is a person again: the server waits for them on their turn.
    m = await playUntil(m, {'sam'});
    if (m['status'] == 'live') expect(turn(m), sam);
  });

  test('one game at a time: no new one while it is live, unless it was abandoned', () async {
    final (partyId, start) = await table();
    await expectLater(
      ref.startMatch(luca, partyId, 'holdem'),
      throwsA(isA<RefereeError>().having((e) => e.status, 'status', 409)),
    );
    // Everyone closed the app: long past the turn clock, it can be replaced.
    now = now.add(const Duration(minutes: 30));
    final next = await ref.startMatch(luca, partyId, 'holdem');
    expect(next['id'], isNot(start['id']));
    final old = (await store.get('matches/${start['id']}'))!;
    expect(old['result'], containsPair('reason', 'ended'));
  });

  test('the host can end a live game from the party; nobody else can', () async {
    final (_, start) = await table();
    final id = start['id']! as String;
    await expectLater(ref.endMatch(sam, id), throwsA(isA<RefereeError>()));
    final m = await ref.endMatch(luca, id);
    expect(m['result'], containsPair('reason', 'ended'));
  });

  test('leaving the party leaves the game too', () async {
    final (partyId, start) = await table();
    final id = start['id']! as String;
    await ref.leaveParty(sam, partyId);
    final m = (await store.get('matches/$id'))!;
    expect(m['left'], [seatOf(m, 'sam')]);
    expect(m['paused'], isNotNull);
  });

  test('a rematch is for those who stayed', () async {
    final (_, start) = await table();
    final id = start['id']! as String;
    await ref.forfeit(sam, id);
    var m = await ref.decide(luca, id, 'end');
    await expectLater(ref.rematch(sam, id), throwsA(isA<RefereeError>()));
    await ref.rematch(luca, id);
    m = await ref.rematch(kit, id);
    final next = (await store.get('matches/${m['next']}'))!;
    expect(next['seats'], unorderedEquals(['luca', 'kit', 'bot:0']));
  });

  test('random leaving, deciding and coming back never breaks a game', () async {
    for (var seed = 0; seed < 25; seed++) {
      store = MemoryStore();
      now = DateTime.utc(2026, 10, 19);
      ref = Referee(store, rng: Random(seed), clock: () => now);
      final rng = Random(seed + 100);
      final (_, start) = await table(bot: seed.isEven);
      final id = start['id']! as String;
      var m = start;
      for (var i = 0; i < 600 && m['status'] == 'live'; i++) {
        final who = people.values.toList()[rng.nextInt(3)];
        final roll = rng.nextInt(20);
        try {
          if (roll == 0) {
            m = await ref.forfeit(who, id);
          } else if (roll == 1) {
            m = await ref.rejoin(who, id);
          } else if (m['paused'] != null) {
            final decider = people[paused(m)['decider']]!;
            if (roll < 4) now = now.add(Referee.decideTime);
            m = await ref.decide(roll < 4 ? who : decider, id, roll == 5 ? 'end' : 'bot');
          } else if (m['turn'] != null) {
            final p = turn(m);
            m = await ref
                .move(p, id, m['version']! as int, {'kind': rng.nextBool() ? 'call' : 'check'})
                .catchError((Object _) => ref.move(p, id, m['version']! as int, {'kind': 'fold'}));
          }
        } on RefereeError {
          m = (await store.get('matches/$id'))!;
        }
        now = now.add(const Duration(seconds: 1));
        // Never paused with nobody to wait for, never live with no one to move.
        if (m['status'] == 'live') {
          expect(m['paused'] != null || m['turn'] != null, isTrue, reason: 'seed $seed');
          if (m['paused'] != null) expect(paused(m)['seats'], isNotEmpty);
        }
      }
    }
  });
}
