import 'package:flutter/material.dart';

import '../../core/theme/toon.dart';

/// One six-sided die showing [value], in the cartoon look.
class Die extends StatelessWidget {
  const Die(this.value, {super.key, this.size = 40, this.angle = 0, this.color = Toon.cardFace});

  final int value;
  final double size;
  final double angle;
  final Color color;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle,
    child: RepaintBoundary(
      child: CustomPaint(size: Size.square(size), painter: _DiePainter(value, color)),
    ),
  );
}

class _DiePainter extends CustomPainter {
  _DiePainter(this.value, this.color);

  final int value;
  final Color color;

  static const _pips = {
    1: [(1, 1)],
    2: [(0, 0), (2, 2)],
    3: [(0, 0), (1, 1), (2, 2)],
    4: [(0, 0), (2, 0), (0, 2), (2, 2)],
    5: [(0, 0), (2, 0), (1, 1), (0, 2), (2, 2)],
    6: [(0, 0), (2, 0), (0, 1), (2, 1), (0, 2), (2, 2)],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final ink = Paint()
      ..color = Toon.inkLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = (s * 0.06).clamp(1.2, 3);
    final box = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.2));
    // A darker edge below for depth.
    canvas.drawRRect(box.shift(Offset(0, s * 0.06)), Paint()..color = Color.lerp(color, Colors.black, 0.3)!);
    canvas.drawRRect(box, Paint()..color = color);
    canvas.drawRRect(box, ink);
    final pip = Paint()..color = value == 1 ? Toon.red : Toon.inkLight;
    for (final (x, y) in _pips[value]!) {
      canvas.drawCircle(
        Offset(s * (0.25 + x * 0.25), s * (0.25 + y * 0.25)),
        s * (value == 1 ? 0.12 : 0.085),
        pip,
      );
    }
  }

  @override
  bool shouldRepaint(_DiePainter old) => old.value != value || old.color != color;
}
