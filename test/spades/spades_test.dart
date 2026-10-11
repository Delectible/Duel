import 'dart:math';

import 'package:duel/core/session/difficulty.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:duel/games/catalog.dart';
import 'package:duel/games/spades/engine/spades.dart';
import 'package:duel/games/spades/ui/spades_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';

void main() {
  test('deals 13 different cards each, two-handed or partners', () {
    for (final players in [2, 4]) {
      final g = Spades(players: players, rng: Random(1));
      expect(g.hands, hasLength(players));
      for (final h in g.hands) {
        expect(h, hasLength(13));
      }
      final all = g.hands.expand((h) => h).toSet();
      expect(all, hasLength(13 * players));
      expect(g.bids, everyElement(isNull));
      expect(g.turn, 1);
    }
  });

  test('on the picker as Soon', () {
    final spades = games.singleWhere((g) => g.id == 'spades');
    expect(spades.available, isFalse);
    expect(spades.rules, isNotEmpty);
  });

  for (final MapEntry(key: phone, value: size) in phones.entries) {
    for (final bots in [1, 3]) {
      testWidgets('template screen, $bots bots on $phone', (tester) async {
        usePhone(tester, size);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: Toon.theme(),
            home: SpadesScreen(bots: bots, difficulty: Difficulty.normal, seed: 1),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Spades'), findsOneWidget);
        await shot(tester, 'spades_${bots}bots_$phone');
        await tester.tap(find.byKey(const Key('guide')));
        await tester.pumpAndSettle();
        expect(find.text('You are here'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
