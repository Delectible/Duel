import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/toon.dart';

/// Chip values and their colours, biggest first (casino style: yellow
/// thousands, purple five hundreds, black hundreds, green 25s, red 5s,
/// white ones).
const chipValues = <(int, Color)>[
  (1000, Toon.yellow),
  (500, Toon.purple),
  (100, Toon.inkLight),
  (25, Toon.green),
  (5, Toon.red),
  (1, Toon.cardFace),
];

/// [amount] as chips, biggest first, at most [cap] of them (the biggest).
List<Color> chipsFor(int amount, {int cap = 15}) {
  final out = <Color>[];
  var left = amount;
  for (final (value, color) in chipValues) {
    while (left >= value && out.length < cap) {
      out.add(color);
      left -= value;
    }
  }
  return out;
}

/// Stacks of round chips seen from a little above, with the amount in a
/// pill beside them. Up to [stacks] stacks of [perStack] chips.
class ChipPile extends StatelessWidget {
  const ChipPile({super.key, required this.amount, this.label = '', this.stacks = 1, this.perStack = 6});

  final int amount;
  final String label;
  final int stacks;
  final int perStack;

  static const chipWidth = 22.0;
  static const _thick = 3.6;

  @override
  Widget build(BuildContext context) {
    final colors = chipsFor(amount, cap: stacks * perStack);
    // Fill the stacks evenly, biggest chips at the bottom of each.
    final n = max(1, min(stacks, (colors.length / 3).ceil()));
    final piles = [
      for (var s = 0; s < n; s++) [for (var i = s; i < colors.length; i += n) colors[i]],
    ];
    final tallest = piles.map((p) => p.length).reduce(max);
    final width = chipWidth + (n - 1) * chipWidth * 0.78;
    final height = chipWidth * 0.5 + _thick * tallest + 2;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(size: Size(width, height), painter: _ChipsPainter(piles)),
        const SizedBox(width: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: Toon.inkLight.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$label${chips(amount)}', style: Toon.text(13, color: Colors.white)),
        ),
      ],
    );
  }
}

class _ChipsPainter extends CustomPainter {
  _ChipsPainter(this.piles);

  final List<List<Color>> piles;

  @override
  void paint(Canvas canvas, Size size) {
    const w = ChipPile.chipWidth, t = ChipPile._thick;
    const e = w * 0.5; // the top's height (an ellipse: seen from above)
    for (final (s, pile) in piles.indexed) {
      // Back stacks a touch higher, so the front ones overlap them.
      final x = s * w * 0.78;
      final base = size.height - e / 2 - 1 - (s.isOdd ? 2 : 0);
      for (final (i, color) in pile.indexed) {
        _chip(canvas, Offset(x + w / 2, base - i * t), color, top: i == pile.length - 1);
      }
    }
  }

  /// One chip whose top face is centred at [c].
  void _chip(Canvas canvas, Offset c, Color color, {required bool top}) {
    const w = ChipPile.chipWidth, t = ChipPile._thick, e = w * 0.5;
    final face = Rect.fromCenter(center: c, width: w, height: e);
    final ink = Paint()
      ..color = Toon.inkLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final light = color.computeLuminance() > 0.6;
    final stripe = light ? Toon.red : Colors.white;
    // The edge: a band below the face, darker.
    final side = Path()
      ..moveTo(face.left, c.dy)
      ..arcTo(face.shift(const Offset(0, t)), pi, -pi, false)
      ..lineTo(face.right, c.dy)
      ..arcTo(face, 0, pi, false)
      ..close();
    canvas.drawPath(side, Paint()..color = Color.lerp(color, Colors.black, light ? 0.18 : 0.3)!);
    // Edge stripes, the casino way.
    final stripes = Paint()..color = stripe;
    for (final a in [0.35, 0.95, 1.55, 2.15, 2.75]) {
      final x = c.dx - cos(a) * w / 2 * 0.98;
      final y = c.dy + sin(a) * e / 2;
      canvas.drawRect(Rect.fromLTWH(x - 1.2, y + 0.4, 2.4, t - 0.8), stripes);
    }
    canvas.drawPath(side, ink);
    // The face.
    canvas.drawOval(face, Paint()..color = color);
    if (top) {
      // Rim dashes and an inlay ring.
      for (var k = 0; k < 6; k++) {
        final a = k * pi / 3 + 0.3;
        final p = c + Offset(cos(a) * w * 0.4, sin(a) * e * 0.4);
        canvas.drawOval(Rect.fromCenter(center: p, width: 3.2, height: 1.8), stripes);
      }
      canvas.drawOval(
        face.deflate(w * 0.2),
        Paint()
          ..color = Colors.white.withValues(alpha: light ? 0.0 : 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      // A shine.
      canvas.drawArc(
        face.deflate(2),
        pi * 1.1,
        pi * 0.5,
        false,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
    canvas.drawOval(face, ink);
  }

  @override
  bool shouldRepaint(_ChipsPainter old) => true;
}
