import 'package:duel_server/duel_server.dart';
import 'package:test/test.dart';

void main() {
  test('documents survive the trip to Firestore values and back', () {
    final doc = <String, Object?>{
      'id': 'abc',
      'version': 3,
      'deadline': 1760000000000,
      'ratio': 0.5,
      'live': true,
      'result': null,
      'seats': ['luca', 'sam'],
      'state': {
        'first': 1,
        'moves': [3, 3, 4],
      },
      'rematch': <String>[],
    };
    expect(FirestoreStore.fromFields(FirestoreStore.toFields(doc)), doc);
  });
}
