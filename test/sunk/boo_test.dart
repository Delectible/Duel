import 'package:duel/core/theme/toon.dart';
import 'package:duel/games/sunk/ui/sunk_art.dart';
import 'package:duel/games/sunk/ui/sunk_controller.dart';
import 'package:duel_engine/sunk/sunk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';

void main() {
  testWidgets('Captain Boo in every mood, and the cards', (tester) async {
    usePhone(tester, const Size(900, 420));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: Toon.theme(),
        home: Scaffold(
          backgroundColor: Deep.mid,
          body: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [for (final m in GhostMood.values) CaptainBoo(size: 120, t: 0.2, mood: m)],
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (var v = 1; v <= 8; v++) SunkCardView(card: SunkCard(SunkKind.treasure, v), width: 70),
                  for (final k in SunkKind.values.skip(1)) SunkCardView(card: SunkCard(k), width: 70),
                  const SunkCardView(card: null, width: 70),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await shot(tester, 'sunk_art');
    expect(tester.takeException(), isNull);
  });
}
