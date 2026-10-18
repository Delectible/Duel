import 'dart:math';

import 'package:duel/core/avatars/faces.dart';
import 'package:duel/games/blitz/ui/blitz_screen.dart';
import 'package:duel_engine/blitz/blitz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';

void main() {
  final personas = [const Persona.you(), ...Persona.bots(5, Random(3))];
  const each = Duration(milliseconds: 2600);

  // Roughly where the felt sits in the game.
  Widget scene(List<War> wars, Size size) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Padding(
        padding: EdgeInsets.fromLTRB(10, size.height * 0.16, 10, size.height * 0.24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: WarScene(wars: wars, personas: personas, each: each),
        ),
      ),
    ),
  );

  final cases = {
    'duel': [
      const War(7, [0, 2], [2]),
    ],
    'both_fall': [
      const War(9, [1, 3], [1, 3]),
    ],
    'nobody': [
      const War(4, [0, 1], []),
    ],
    'six': [
      const War(12, [0, 1, 2, 3, 4, 5], [0, 2, 3, 5]),
    ],
    'two_wars': [
      const War(5, [1, 2], [1]),
      const War(10, [0, 4, 5], [4, 5]),
    ],
  };

  for (final MapEntry(key: name, value: wars) in cases.entries) {
    for (final MapEntry(key: phone, value: size) in phones.entries) {
      testWidgets('war scene: $name on $phone', (tester) async {
        usePhone(tester, size);
        await tester.pumpWidget(scene(wars, size));
        await tester.pump(const Duration(milliseconds: 1000)); // swords crossed
        expect(find.text('WAR!'), findsOneWidget);
        await shot(tester, 'war_${name}_clash_$phone');
        await tester.pump(const Duration(milliseconds: 1000)); // the fall
        await shot(tester, 'war_${name}_fall_$phone');
        if (wars.length > 1) {
          await tester.pump(each); // the second war
          await shot(tester, 'war_${name}_second_$phone');
        }
        await tester.pump(each * wars.length);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
