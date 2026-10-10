import 'package:duel/core/app_info.dart';
import 'package:duel/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home screen shows both modes and About', (tester) async {
    // A phone-sized screen (Pixel 9 Pro: 412 x 915 dp).
    tester.view.physicalSize = const Size(1280, 2856);
    tester.view.devicePixelRatio = 1280 / 412;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const DuelApp());
    expect(find.text('Duel'), findsOneWidget);

    await tester.tap(find.text('Play vs bot'));
    await tester.pump();
    expect(find.text('Play vs bot is coming soon.'), findsOneWidget);

    await tester.tap(find.byTooltip('About'));
    await tester.pumpAndSettle();
    expect(find.text('Duel ${AppInfo.version}'), findsOneWidget);
  });
}
