import 'package:flutter/material.dart';

import '../theme/toon.dart';

/// Table colours, low stakes to high: green, blue, red, black (black
/// tables deal gold-trimmed cards: `GoldCards`).
enum Felt {
  green(Toon.felt, Color(0xFF47B067), Color(0xFFFFE9A8), Toon.wood),
  blue(Color(0xFF1C3A5E), Color(0xFF2A5687), Color(0xFFF2C14E), Color(0xFF5A3A26)),
  red(Color(0xFF8E2433), Color(0xFFAD3443), Color(0xFFFFF1D6), Color(0xFF3A2A26)),
  black(Color(0xFF1F1D1C), Color(0xFF3A3530), cardGoldLine, Color(0xFF2A211B));

  const Felt(this.felt, this.lit, this.line, this.rail);

  /// The felt, its lamp-lit middle, the printed lines and the rail.
  final Color felt, lit, line, rail;

  bool get gold => this == black;

  /// The [level]th of [count] stakes (0 = lowest), spread over the colours.
  static Felt forLevel(int level, int count) {
    if (count <= 1) return green;
    final i = (level * (values.length - 1) / (count - 1)).round();
    return values[i.clamp(0, values.length - 1)];
  }
}

const cardGoldLine = Color(0xFFD9A93A);
