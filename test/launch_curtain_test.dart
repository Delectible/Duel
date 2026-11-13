import 'package:duel/core/startup/launch_curtain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screens.dart';

void main() {
  for (final MapEntry(key: phone, value: size) in phones.entries) {
    testWidgets('$phone: the launch curtain fans the cards, then lifts', (tester) async {
      usePhone(tester, size);
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: LaunchCurtain(
            child: Scaffold(
              body: Center(
                child: TextButton(onPressed: () => taps++, child: const Text('Play')),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byKey(const Key('launch curtain')), findsOneWidget);
      expect(find.byKey(const Key('launch line')), findsOneWidget);
      await shot(tester, 'launch_$phone');
      await tester.tap(find.text('Play'), warnIfMissed: false);
      expect(taps, 0, reason: 'no taps through the curtain');
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('launch curtain')), findsNothing);
      await tester.tap(find.text('Play'));
      expect(taps, 1);
    });
  }
}
