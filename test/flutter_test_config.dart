import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Tests measure and draw text with the real fonts: the bundled Fredoka and
/// the Material icons from the Flutter SDK running the tests. Layout checks
/// then catch overflows the phone would show.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final fredoka = FontLoader('Fredoka');
  for (final w in ['Medium', 'SemiBold', 'Bold']) {
    final f = File('assets/fonts/Fredoka-$w.ttf');
    if (f.existsSync()) fredoka.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  }
  await fredoka.load();
  final fonts = _sdkFonts();
  if (fonts != null) {
    final icons = File('${fonts.path}/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())))).load();
    }
  }
  await testMain();
}

/// `sdk/bin/cache/artifacts/material_fonts`, from FLUTTER_ROOT or the path
/// of the flutter_tester binary running us.
Directory? _sdkFonts() {
  final roots = [
    Platform.environment['FLUTTER_ROOT'],
    // .../bin/cache/artifacts/engine/<platform>/flutter_tester
    File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path,
  ];
  for (final r in roots) {
    if (r == null) continue;
    final d = Directory('$r/bin/cache/artifacts/material_fonts');
    if (d.existsSync()) return d;
  }
  return null;
}
