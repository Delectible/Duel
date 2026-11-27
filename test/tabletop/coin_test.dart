import 'dart:math';

import 'package:duel/core/theme/toon.dart';
import 'package:duel/features/tabletop/tools/flip_spin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';

void main() {
  testWidgets('the coin from every side', (tester) async {
    usePhone(tester, const Size(900, 260));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: Toon.theme(),
        home: Scaffold(
          body: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final a in [-1.05, 0.0, 0.7, 1.3, pi / 2, 2.0, pi, pi - 1.05]) Coin3D(angle: a, size: 96),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await shot(tester, 'coin_angles');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a flip, frame by frame', (tester) async {
    usePhone(tester, phones['pixel9pro']!);
    await tester.pumpWidget(
      MaterialApp(debugShowCheckedModeBanner: false, theme: Toon.theme(), home: const FlipSpin(seed: 4)),
    );
    await tester.pump();
    await shot(tester, 'coin_0');
    await tester.tap(find.byKey(const Key('flip')));
    for (final (i, ms) in [180, 300, 300, 300, 300, 250, 400].indexed) {
      await tester.pump(Duration(milliseconds: ms));
      await shot(tester, 'coin_${i + 1}');
    }
    await tester.pump(const Duration(seconds: 1));
    await shot(tester, 'coin_done');
    expect(find.byKey(const Key('coin result')), findsOneWidget);
    await tester.tap(find.byKey(const Key('show wheel')));
    await tester.pump();
    await shot(tester, 'wheel_0');
    await tester.tap(find.byKey(const Key('spin')));
    await tester.pump(const Duration(milliseconds: 800));
    await shot(tester, 'wheel_1');
    await tester.pump(const Duration(seconds: 5));
    await shot(tester, 'wheel_done');
    expect(find.byKey(const Key('wheel result')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
