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

  test('behind: only a newer x.Y counts (the last number never does)', () {
    final parts = AppInfo.version.split('.').map(int.parse).toList();
    expect(AppInfo.behind(AppInfo.version), isFalse);
    expect(AppInfo.behind('${parts[0]}.${parts[1]}.${parts[2] + 5}'), isFalse);
    expect(AppInfo.behind('${parts[0]}.${parts[1] + 1}.0'), isTrue);
    expect(AppInfo.behind('${parts[0] + 1}.0.0'), isTrue);
    expect(AppInfo.behind('0.0.1'), isFalse);
    expect(AppInfo.behind('junk'), isFalse);
  });
}
