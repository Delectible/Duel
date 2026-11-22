import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/toon.dart';

/// A 3 x 3 rotation (row-major), enough to turn a die in space.
class Turn {
  const Turn(this.m);

  final List<double> m;

  static const identity = Turn([1, 0, 0, 0, 1, 0, 0, 0, 1]);

  /// About the up axis (z): which way the die faces on the table.
  factory Turn.yaw(double a) => Turn([cos(a), -sin(a), 0, sin(a), cos(a), 0, 0, 0, 1]);

  /// About any unit [axis] by [a] (Rodrigues).
  factory Turn.about((double, double, double) axis, double a) {
    final (x, y, z) = axis;
    final c = cos(a), s = sin(a), t = 1 - c;
    return Turn([
      t * x * x + c, t * x * y - s * z, t * x * z + s * y, //
      t * x * y + s * z, t * y * y + c, t * y * z - s * x,
      t * x * z - s * y, t * y * z + s * x, t * z * z + c,
    ]);
  }

  Turn operator *(Turn o) => Turn([
    for (var r = 0; r < 3; r++)
      for (var c = 0; c < 3; c++) m[r * 3] * o.m[c] + m[r * 3 + 1] * o.m[3 + c] + m[r * 3 + 2] * o.m[6 + c],
  ]);

  (double, double, double) apply((double, double, double) v) {
    final (x, y, z) = v;
    return (m[0] * x + m[1] * y + m[2] * z, m[3] * x + m[4] * y + m[5] * z, m[6] * x + m[7] * y + m[8] * z);
  }
}

/// A die's faces in its own space: the normal and two edge directions for
/// the pips. Opposite faces add up to 7, as on a real die.
const _faces = <int, ((double, double, double), (double, double, double), (double, double, double))>{
  1: ((0, 0, 1), (1, 0, 0), (0, 1, 0)),
  6: ((0, 0, -1), (1, 0, 0), (0, -1, 0)),
  2: ((0, -1, 0), (1, 0, 0), (0, 0, -1)),
  5: ((0, 1, 0), (-1, 0, 0), (0, 0, -1)),
  3: ((1, 0, 0), (0, 1, 0), (0, 0, -1)),
  4: ((-1, 0, 0), (0, -1, 0), (0, 0, -1)),
};

/// Turns a die so [value] faces up (+z).
Turn faceUp(int value) => switch (value) {
  1 => Turn.identity,
  6 => const Turn([1, 0, 0, 0, -1, 0, 0, 0, -1]),
  2 => const Turn([1, 0, 0, 0, 0, 1, 0, -1, 0]),
  5 => const Turn([1, 0, 0, 0, 0, -1, 0, 1, 0]),
  3 => const Turn([0, 0, -1, 0, 1, 0, 1, 0, 0]),
  _ => const Turn([0, 0, 1, 0, 1, 0, -1, 0, 0]),
};

/// One six-sided die showing [value] on top, drawn as a real cube seen from
/// a little in front (top, front and a side face, lit from the top left),
/// in the cartoon look. [angle] turns it on the table.
class Die extends StatelessWidget {
  const Die(this.value, {super.key, this.size = 40, this.angle = 0, this.color = Toon.cardFace});

  final int value;
  final double size;
  final double angle;
  final Color color;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.square(size),
      painter: CubePainter(Turn.yaw(angle + 0.45) * faceUp(value), color),
    ),
  );
}

/// Paints a die turned by [turn] (world: x right, y away, z up), filling
/// about [Size.width] across.
class CubePainter extends CustomPainter {
  CubePainter(this.turn, this.color);

  final Turn turn;
  final Color color;

  // The camera looks down at the table, tilted this far from straight down.
  static final _ct = cos(0.62), _st = sin(0.62);

  static const _pips = {
    1: [(1, 1)],
    2: [(0, 0), (2, 2)],
    3: [(0, 0), (1, 1), (2, 2)],
    4: [(0, 0), (2, 0), (0, 2), (2, 2)],
    5: [(0, 0), (2, 0), (1, 1), (0, 2), (2, 2)],
    6: [(0, 0), (2, 0), (0, 1), (2, 1), (0, 2), (2, 2)],
  };

  static Offset _screen((double, double, double) v, double s) =>
      Offset(v.$1 * s, (-v.$2 * _ct - v.$3 * _st) * s);
  static double _depth((double, double, double) v) => -v.$2 * _st + v.$3 * _ct;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width * 0.6; // edge length
    final c = size.center(Offset.zero);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    final ink = Toon.inkLight;
    final edge = Color.lerp(color, Colors.black, 0.35)!;
    // Light from the top left, a little in front.
    const light = (-0.45, -0.35, 0.82);

    final visible =
        <(double, int, (double, double, double), (double, double, double), (double, double, double))>[];
    for (final MapEntry(key: v, value: (n, a, b)) in _faces.entries) {
      final wn = turn.apply(n);
      final d = _depth(wn);
      if (d > 0.02) visible.add((d, v, wn, turn.apply(a), turn.apply(b)));
    }
    visible.sort((x, y) => x.$1.compareTo(y.$1));

    // The silhouette: every corner, the outline round them all.
    final corners = <Offset>[
      for (final x in [-0.5, 0.5])
        for (final y in [-0.5, 0.5])
          for (final z in [-0.5, 0.5]) _screen(turn.apply((x, y, z)), s),
    ];
    final hull = _hull(corners);
    final outline = Path()..addPolygon(hull, true);
    final stroke = (size.width * 0.05).clamp(1.2, 3.2);
    // A shadow under it.
    canvas.drawPath(
      outline.shift(Offset(0, size.width * 0.04)),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
    canvas.drawPath(outline, Paint()..color = edge);

    for (final (_, v, n, a, b) in visible) {
      final o = (
        n.$1 * 0.5 - (a.$1 + b.$1) * 0.5,
        n.$2 * 0.5 - (a.$2 + b.$2) * 0.5,
        n.$3 * 0.5 - (a.$3 + b.$3) * 0.5,
      );
      final po = _screen(o, s), pa = _screen(a, s), pb = _screen(b, s);
      final lit = (n.$1 * light.$1 + n.$2 * light.$2 + n.$3 * light.$3).clamp(0.0, 1.0);
      final face = Color.lerp(Color.lerp(color, Colors.black, 0.28)!, color, 0.25 + 0.75 * lit)!;
      canvas.save();
      // Face space: (0,0)..(1,1) across the face.
      canvas.transform(
        Float64List.fromList([pa.dx, pa.dy, 0, 0, pb.dx, pb.dy, 0, 0, 0, 0, 1, 0, po.dx, po.dy, 0, 1]),
      );
      final rr = RRect.fromRectAndRadius(
        const Rect.fromLTRB(0.06, 0.06, 0.94, 0.94),
        const Radius.circular(0.2),
      );
      canvas.drawRRect(rr, Paint()..color = face);
      final pip = Paint()..color = Color.lerp(v == 1 ? Toon.red : ink, Colors.black, (1 - lit) * 0.3)!;
      for (final (x, y) in _pips[v]!) {
        canvas.drawCircle(Offset(0.22 + x * 0.28, 0.22 + y * 0.28), v == 1 ? 0.14 : 0.095, pip);
      }
      canvas.restore();
    }
    canvas.drawPath(
      outline,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  /// Convex hull (monotone chain).
  static List<Offset> _hull(List<Offset> pts) {
    final p = [...pts]..sort((a, b) => a.dx != b.dx ? a.dx.compareTo(b.dx) : a.dy.compareTo(b.dy));
    double cross(Offset o, Offset a, Offset b) =>
        (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
    final lower = <Offset>[], upper = <Offset>[];
    for (final q in p) {
      while (lower.length >= 2 && cross(lower[lower.length - 2], lower.last, q) <= 1e-9) {
        lower.removeLast();
      }
      lower.add(q);
    }
    for (final q in p.reversed) {
      while (upper.length >= 2 && cross(upper[upper.length - 2], upper.last, q) <= 1e-9) {
        upper.removeLast();
      }
      upper.add(q);
    }
    return [...lower..removeLast(), ...upper..removeLast()];
  }

  @override
  bool shouldRepaint(CubePainter old) => !_same(old.turn.m, turn.m) || old.color != color;

  static bool _same(List<double> a, List<double> b) {
    for (var i = 0; i < 9; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
