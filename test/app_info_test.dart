import 'dart:io';

import 'package:duel/core/app_info.dart';
import 'package:flutter_test/flutter_test.dart';

/// About shows AppInfo.version: keep it in step with pubspec.yaml.
void main() {
  test('AppInfo.version matches pubspec.yaml', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    final version = line.split(':')[1].trim().split('+').first;
    expect(AppInfo.version, version);
  });

  test("Play's What's new fits (500 characters with the version)", () {
    expect('${AppInfo.version}: ${AppInfo.latest}'.length, lessThanOrEqualTo(500));
  });
}
