import 'package:duel_server/duel_server.dart';
import 'package:test/test.dart';

void main() {
  test('lists inside lists survive Firestore (stored as {_list: [...]})', () {
    final doc = {
      'hands': [
        [
          [0, 0],
          [3, 120],
        ],
        <Object?>[],
      ],
      'flat': [1, 2],
      'map': {
        'moves': [
          [2, 0],
        ],
      },
    };
    final fields = FirestoreStore.toFields(doc);
    // No array directly inside an array.
    final hands = fields['hands']!.arrayValue!.values!;
    expect(hands.every((v) => v.arrayValue == null && v.mapValue != null), isTrue);
    expect(FirestoreStore.fromFields(fields), doc);
  });
}
