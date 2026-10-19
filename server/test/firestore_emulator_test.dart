import 'dart:io';
import 'dart:math';

import 'package:duel_server/duel_server.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

/// The referee on real Firestore (the local emulator):
/// `firebase emulators:exec --only firestore "dart test"` in firebase/.
void main() {
  final host = Platform.environment['FIRESTORE_EMULATOR_HOST'];
  final skip = host == null ? 'needs the Firestore emulator (FIRESTORE_EMULATOR_HOST)' : false;

  test('a whole game of Four in a Row on Firestore, with racing moves', () async {
    final store = FirestoreStore(_Owner(), projectId: 'demo-duel', emulatorHost: host);
    final ref = Referee(store, rng: Random(3));
    const luca = Player(uid: 'luca', name: 'Luca'), sam = Player(uid: 'sam', name: 'Sam');
    final party = await ref.createParty(luca);
    await ref.joinParty(sam, party['code']! as String);
    var m = await ref.startMatch(luca, party['id']! as String, 'connect4');
    final id = m['id']! as String;
    Player turn() => (m['seats']! as List)[m['turn']! as int] == 'luca' ? luca : sam;

    // The same move sent twice at once: exactly one lands.
    final tries = await Future.wait([
      for (var i = 0; i < 2; i++)
        ref.move(turn(), id, 1, {'column': 3}).then<Object>((x) => x, onError: (Object e) => e),
    ]);
    expect(tries.whereType<RefereeError>(), hasLength(1));
    m = (await store.get('matches/$id'))!;
    expect((m['state']! as Map)['moves'], [3]);

    for (final col in [0, 3, 0, 3, 0, 3]) {
      m = await ref.move(turn(), id, m['version']! as int, {'column': col});
    }
    expect(m['status'], 'over');
    expect((await store.get('matches/$id'))!['result'], isNotNull);
  }, skip: skip);

  test("Hold'em on Firestore: two friends, two bots, every kind of move", () async {
    final store = FirestoreStore(_Owner(), projectId: 'demo-duel', emulatorHost: host);
    var now = DateTime.now().toUtc();
    final ref = Referee(store, rng: Random(5), clock: () => now);
    final rng = Random(11);
    const luca = Player(uid: 'luca', name: 'Luca'), sam = Player(uid: 'sam', name: 'Sam');
    final party = await ref.createParty(luca);
    await ref.joinParty(sam, party['code']! as String);
    await ref.setBots(luca, party['id']! as String, [
      {'name': 'Pip', 'look': 'cap', 'difficulty': 'easy'},
      {'name': 'Finn', 'look': 'fin', 'difficulty': 'hard'},
    ]);
    var m = await ref.startMatch(luca, party['id']! as String, 'holdem', stake: 10);
    final id = m['id']! as String;
    for (var i = 0; i < 400 && m['status'] == 'live'; i++) {
      final p = (m['seats']! as List)[m['turn']! as int] == 'luca' ? luca : sam;
      final move = switch (rng.nextInt(8)) {
        0 => {'kind': 'fold'},
        1 || 2 => {'kind': 'check'},
        3 || 4 || 5 => {'kind': 'call'},
        _ => {'kind': 'raise', 'amount': rng.nextInt(600) + 1},
      };
      try {
        m = await ref.move(p, id, m['version']! as int, move);
      } on RefereeError {
        m = await ref
            .move(p, id, m['version']! as int, {'kind': 'check'})
            .catchError((Object _) => ref.move(p, id, m['version']! as int, {'kind': 'call'}));
      }
      now = now.add(const Duration(seconds: 2));
    }
    expect(m['status'], 'over');
    // Both ask for a rematch: a new table starts.
    await ref.rematch(luca, id);
    final over = await ref.rematch(sam, id);
    expect(over['next'], isA<String>());
    expect((await store.get('matches/${over['next']}'))!['status'], 'live');
  }, skip: skip);

  test('leaving, a bot sitting in and coming back, on Firestore', () async {
    final store = FirestoreStore(_Owner(), projectId: 'demo-duel', emulatorHost: host);
    final ref = Referee(store, rng: Random(7));
    const luca = Player(uid: 'luca', name: 'Luca'),
        sam = Player(uid: 'sam', name: 'Sam'),
        kit = Player(uid: 'kit', name: 'Kit');
    final party = await ref.createParty(luca);
    await ref.joinParty(sam, party['code']! as String);
    await ref.joinParty(kit, party['code']! as String);
    final id = (await ref.startMatch(luca, party['id']! as String, 'holdem'))['id']! as String;
    var m = await ref.forfeit(sam, id);
    expect((m['paused']! as Map)['decider'], 'luca');
    m = await ref.decide(luca, id, 'bot');
    expect((m['standIns']! as Map).length, 1);
    m = await ref.rejoin(sam, id);
    expect(m['standIns'], isEmpty);
    expect((await store.get('matches/$id'))!['left'], isEmpty);
    m = await ref.endMatch(luca, id);
    expect((await store.get('matches/$id'))!['result'], containsPair('reason', 'ended'));
  }, skip: skip);
}

/// The emulator's full-access token.
class _Owner extends http.BaseClient {
  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['authorization'] = 'Bearer owner';
    return _inner.send(request);
  }
}
