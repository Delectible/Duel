import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phone sizes the screen tests run at (logical px), upright and on their
/// side (landscape).
const phones = {
  'pixel9pro': Size(412, 915),
  'small': Size(360, 740),
  'pixel9pro_land': Size(915, 412),
  'small_land': Size(740, 360),
};

void usePhone(WidgetTester tester, Size size) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// With SHOTS=dir set, saves what's on screen as dir/[name].png (for
/// looking at layouts without a phone).
Future<void> shot(WidgetTester tester, String name) async {
  final dir = Platform.environment['SHOTS'];
  if (dir == null) return;
  final image = await captureImage(tester.element(find.byType(MaterialApp)));
  final bytes = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
  Directory(dir).createSync(recursive: true);
  File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// Taps a card in a fanned hand where a player would: its left edge (the
/// next card covers the rest).
Future<void> tapCard(WidgetTester tester, Finder card) =>
    tester.tapAt(tester.getTopLeft(card.first) + const Offset(10, 26));
