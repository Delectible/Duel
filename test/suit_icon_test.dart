import 'package:duel/core/cards/card_view.dart';
import 'package:duel/core/cards/cards.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Black suits off the cards get a light outline in dark mode (and only
/// then): on dark buttons, the felt and overlays they'd be hard to see.
void main() {
  Future<bool> outlined(WidgetTester tester, Suit suit, {required bool dark, bool onLight = false}) async {
    Toon.dark = dark;
    addTearDown(() => Toon.dark = false);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(child: SuitIcon(suit, size: 40, onLight: onLight)),
      ),
    );
    final paint = tester.widget<CustomPaint>(
      find.descendant(of: find.byType(SuitIcon), matching: find.byType(CustomPaint)),
    );
    // The painter is private: read its outline colour dynamically.
    return (paint.painter! as dynamic).outline != null;
  }

  testWidgets('dark mode: black suits off the cards are outlined', (tester) async {
    expect(await outlined(tester, Suit.spades, dark: true), isTrue);
    expect(await outlined(tester, Suit.clubs, dark: true), isTrue);
  });

  testWidgets('no outline in light mode, on cards, or for red suits', (tester) async {
    expect(await outlined(tester, Suit.spades, dark: false), isFalse);
    expect(await outlined(tester, Suit.spades, dark: true, onLight: true), isFalse);
    expect(await outlined(tester, Suit.hearts, dark: true), isFalse);
  });
}
