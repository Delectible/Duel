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
