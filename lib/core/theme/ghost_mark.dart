import 'dart:math';

import 'package:flutter/material.dart';

import 'toon.dart';

/// Duel's ghost, drawn like the app icon (`tool/icon/make_icons.py`, same
/// 192-unit grid): white with scanlines, split into red and blue at the
/// edges, glancing sideways with a spade glinting in each eye. Outlined in
/// ink so it reads on Duel's yellow.
class GhostMark extends StatelessWidget {
  const GhostMark({super.key, this.size = 120, this.split = 5, this.glint = 1});

  final double size;

  /// The RGB split, in grid units (the icon uses 5).
  final double split;

  /// The spade glints' scale (0 = none; pops above 1 when they twinkle).
  final double glint;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: GhostPainter(split: split, glint: glint),
    ),
  );
}

class GhostPainter extends CustomPainter {
  GhostPainter({required this.split, required this.glint});

  final double split, glint;

  static Path body() {
    Path oval(double x, double y, double rx, double ry) =>
        Path()..addOval(Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2));
    var p = Path.combine(
      PathOperation.union,
      oval(96, 92, 56, 56),
      Path()..addRect(const Rect.fromLTRB(40, 92, 152, 150)),
    );
    for (final x in <double>[54, 82, 110, 138]) {
      p = Path.combine(PathOperation.union, p, oval(x, 150, 14, 16));
    }
    return p;
  }

  static Path spade(double cx, double cy, double r) => Path()
    ..addOval(Rect.fromCircle(center: Offset(cx - r * 0.5, cy + r * 0.2), radius: r * 0.55))
    ..addOval(Rect.fromCircle(center: Offset(cx + r * 0.5, cy + r * 0.2), radius: r * 0.55))
    ..addPolygon([
      Offset(cx - r * 1.02, cy + 0.3 * r),
      Offset(cx + r * 1.02, cy + 0.3 * r),
      Offset(cx, cy - r),
    ], true)
    ..addPolygon([
      Offset(cx, cy + 0.3 * r),
      Offset(cx - r * 0.35, cy + r * 1.05),
      Offset(cx + r * 0.35, cy + r * 1.05),
    ], true);

  static final _body = body();

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 132;
    canvas.save();
    // The ghost spans x 40..152, y 36..166 on its grid: centre it.
    canvas.scale(u);
    canvas.translate(-30, -35);
    // The split: red to the left, blue to the right.
    canvas.drawPath(_body.shift(Offset(-split, 0)), Paint()..color = const Color(0xFFFF3B5C));
    canvas.drawPath(_body.shift(Offset(split, 0)), Paint()..color = const Color(0xFF2E9BFF));
    canvas.drawPath(_body, Paint()..color = Colors.white);
    // Scanlines.
    canvas.save();
    canvas.clipPath(_body);
    final scan = Paint()..color = const Color(0xFFD6D6DE);
    for (var y = 36.0; y < 168; y += 4) {
      canvas.drawRect(Rect.fromLTWH(30, y, 132, 1.6), scan);
    }
    canvas.restore();
    canvas.drawPath(
      _body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..color = Toon.inkLight,
    );
    // Eyes, glancing left, a spade glinting in each.
    final ink = Paint()..color = Toon.inkLight;
    for (final x in <double>[72, 108]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(x, 94), width: 20, height: 28), ink);
    }
    if (glint > 0) {
      final white = Paint()..color = Colors.white;
      for (final x in <double>[69, 105]) {
        canvas.drawPath(spade(x, 88, 4.6 * min(glint, 1.8)), white);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(GhostPainter old) => old.split != split || old.glint != glint;
}
