import 'package:duel_engine/cards.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:duel_engine/poker/hand_eval.dart';
import 'package:duel/games/poker/ui/hand_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';

void main() {
  test('the chart lists every hand, best first, and its examples are that hand', () {
    expect(handRanks, hasLength(10));
    for (var i = 0; i < handRanks.length; i++) {
      final r = handRanks[i];
      final v = evaluateHand(PlayingCard.parseAll(r.example));
      expect(v.category, r.category, reason: r.name);
      expect(v.category == HandCategory.straightFlush && v.ranks.first == 14, r.royal, reason: r.name);
      if (i > 0) {
        expect(v.score, lessThan(evaluateHand(PlayingCard.parseAll(handRanks[i - 1].example)).score));
      }
    }
  });

  for (final MapEntry(key: phone, value: size) in phones.entries) {
    for (final r in handRanks) {
      testWidgets('chart on $phone with ${r.name} outlined', (tester) async {
        usePhone(tester, size);
        await tester.pumpWidget(
          MaterialApp(
            theme: Toon.theme(),
            home: Scaffold(
              body: HandChart(
                category: r.category,
                royal: r.royal,
                cards: PlayingCard.parseAll(r.example),
                name: r.name,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('You'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (r.name == 'Two pair') await shot(tester, 'hand_chart_$phone');
      });
    }
  }
}
