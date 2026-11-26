import 'dart:math';

import 'package:duel_engine/scoreboard/scoreboard.dart';
import 'package:duel_server/duel_server.dart';
import 'package:test/test.dart';

/// The party's scoreboard: everyone adds themselves once and scores their
/// own; the host adds anyone and does anything, and can let anyone score.
void main() {
  const luca = Player(uid: 'luca', name: 'Luca'), sam = Player(uid: 'sam', name: 'Sam');
  const kim = Player(uid: 'kim', name: 'Kim');

  test('rights', () async {
    final ref = Referee(MemoryStore(), rng: Random(1));
    final p = await ref.createParty(luca);
    final id = p['id']! as String;
    await ref.joinParty(sam, p['code']! as String);
    Map<Object?, Object?> board(Map<String, Object?> d) => d['board']! as Map;
    String idOf(Map<String, Object?> d, String name) =>
        ((board(d)['players']! as List).firstWhere((x) => (x as Map)['name'] == name) as Map)['id']!
            as String;

    var d = await ref.board(sam, id, {'op': 'add', 'name': 'Sam', 'self': true});
    await expectLater(
      ref.board(sam, id, {'op': 'add', 'name': 'Sam again', 'self': true}),
      throwsA(isA<RefereeError>()),
    );
    await expectLater(ref.board(sam, id, {'op': 'add', 'name': 'Bob'}), throwsA(isA<RefereeError>()));
    d = await ref.board(luca, id, {'op': 'add', 'name': 'Gran'});
    d = await ref.board(luca, id, {'op': 'add', 'name': 'Grandpa'});
    final samId = idOf(d, 'Sam'), gran = idOf(d, 'Gran');
    d = await ref.board(sam, id, {'op': 'score', 'id': samId, 'delta': 5});
    await expectLater(
      ref.board(sam, id, {'op': 'score', 'id': gran, 'delta': 5}),
      throwsA(isA<RefereeError>()),
    );
    await expectLater(
      ref.board(sam, id, {'op': 'settings', 'anyoneScores': true}),
      throwsA(isA<RefereeError>()),
    );
    d = await ref.board(luca, id, {'op': 'settings', 'anyoneScores': true});
    d = await ref.board(sam, id, {'op': 'score', 'id': gran, 'delta': 7});
    d = await ref.board(luca, id, {'op': 'score', 'id': samId, 'delta': 10});
    // Sam's undo takes back Sam's own last change, not Luca's.
    d = await ref.board(sam, id, {'op': 'undo'});
    final b = ScoreBoard.fromJson(board(d));
    expect(b.score(samId), 15);
    expect(b.score(gran), 0);
    expect(d['members'], ['luca', 'sam']);
    await expectLater(ref.board(kim, id, {}), throwsA(isA<RefereeError>()));
  });
}
