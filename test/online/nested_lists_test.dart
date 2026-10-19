import 'package:duel/core/online/nested_lists.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("the referee's wrapped inner lists come back as lists", () {
    expect(
      unnestLists({
        'hands': [
          {
            'moves': [
              {
                '_list': [0, 0],
              },
              {
                '_list': [3, 120],
              },
            ],
            'board': ['As'],
          },
        ],
        'n': 1,
      }),
      {
        'hands': [
          {
            'moves': [
              [0, 0],
              [3, 120],
            ],
            'board': ['As'],
          },
        ],
        'n': 1,
      },
    );
  });
}
