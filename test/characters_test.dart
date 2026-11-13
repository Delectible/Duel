import 'package:duel/core/avatars/characters.dart';
import 'package:duel/core/avatars/faces.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screens.dart';

void main() {
  testWidgets('the rivals and bosses have faces of their own', (tester) async {
    usePhone(tester, phones['pixel9pro']!);
    expect(CharacterFaces.byName.values.toSet(), hasLength(8), reason: 'all different');
    await tester.pumpWidget(
      MaterialApp(
        theme: Toon.theme(),
        home: Scaffold(
          body: Center(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final e in CharacterFaces.byName.entries)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Face(Persona(name: e.key, look: Look.cap, avatar: e.value), size: 80),
                      Text(e.key),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await shot(tester, 'characters');
    expect(tester.takeException(), isNull);
  });
}
