import 'dart:math';

import 'package:duel_engine/cards.dart';
import 'package:flutter/material.dart';

import '../core/cards/card_view.dart';
import '../core/theme/toon.dart';

/// The game picker's tile pictures: small cartoon scenes in the app's look
/// (bold ink outlines, flat Toon colours, real cards). Each fills about
/// 84 x 64.

const _w = 84.0, _h = 64.0;

/// Ink outline for painted shapes.
Paint _ink([double width = 2]) => Paint()
  ..color = Toon.inkLight
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round;

Paint _fill(Color c) => Paint()..color = c;

void _shape(Canvas canvas, Path path, Color color, [double ink = 2]) {
  canvas.drawPath(path, _fill(color));
  canvas.drawPath(path, _ink(ink));
}

Widget _card(String card, double width, {double angle = 0, Offset at = Offset.zero}) => Transform.translate(
  offset: at,
  child: Transform.rotate(
    angle: angle,
    child: CardView(card: PlayingCard.parse(card), width: width),
  ),
);

// Each scene on its own layer: drawn once, not again as home scrolls.
Widget _scene(List<Widget> children) => RepaintBoundary(
  child: SizedBox(
    width: _w,
    height: _h,
    child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: children),
  ),
);

Widget _paint(CustomPainter painter, {Size size = const Size(_w, _h)}) => IgnorePointer(
  child: CustomPaint(size: size, painter: painter),
);

// --- Texas Hold'em: pocket Aces and a stack of chips ------------------------

class HoldemArt extends StatelessWidget {
  const HoldemArt({super.key});

  @override
  Widget build(BuildContext context) => _scene([
    _card('As', 36, angle: -0.22, at: const Offset(-16, -2)),
    _card('Ah', 36, angle: 0.12, at: const Offset(2, -4)),
    Positioned(right: 0, bottom: -2, child: _paint(_ChipsPainter(), size: const Size(34, 34))),
  ]);
}

class _ChipsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    // A stack of three, a fourth leaning on it.
    for (final (i, color) in [Toon.blue, Toon.red, Toon.yellow].indexed) {
      _chip(canvas, Offset(w * 0.42, size.height - 7 - i * 6.0), w * 0.36, color);
    }
    canvas.save();
    canvas.translate(w * 0.8, size.height * 0.62);
    canvas.rotate(-1.1);
    _chip(canvas, Offset.zero, w * 0.3, Toon.green);
    canvas.restore();
  }

  /// A chip seen from a little above: an edge and a face with stripes.
  void _chip(Canvas canvas, Offset c, double r, Color color) {
    final face = Rect.fromCenter(center: c, width: r * 2, height: r * 0.9);
    final side = Path()
      ..addRect(Rect.fromLTRB(face.left, c.dy, face.right, c.dy + 4))
      ..addOval(face.shift(const Offset(0, 4)));
    canvas.drawPath(side, _fill(Color.lerp(color, Colors.black, 0.25)!));
    canvas.drawOval(face.shift(const Offset(0, 4)), _ink(1.6));
    canvas.drawLine(Offset(face.left, c.dy), Offset(face.left, c.dy + 4), _ink(1.6));
    canvas.drawLine(Offset(face.right, c.dy), Offset(face.right, c.dy + 4), _ink(1.6));
    canvas.drawOval(face, _fill(color));
    // Edge stripes.
    for (final a in [0.0, pi / 2, pi, 3 * pi / 2]) {
      final p = c + Offset(cos(a) * r * 0.78, sin(a) * r * 0.35);
      canvas.drawOval(Rect.fromCenter(center: p, width: r * 0.32, height: r * 0.16), _fill(Toon.cardFace));
    }
    canvas.drawOval(face.deflate(r * 0.3), _ink(1.2));
    canvas.drawOval(face, _ink(1.6));
  }

  @override
  bool shouldRepaint(_ChipsPainter old) => false;
}

// --- Crazy Eights: an eight whirling the four suits round it ---------------

class EightsArt extends StatelessWidget {
  const EightsArt({super.key});

  @override
  Widget build(BuildContext context) => _scene([
    _paint(_WhirlPainter()),
    _card('8h', 36, angle: -0.12),
    for (final (i, suit) in Suit.values.indexed)
      () {
        final a = -pi / 2 + i * pi / 2 + 0.5;
        return Transform.translate(
          offset: Offset(cos(a) * 36, sin(a) * 26),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Toon.cardFace,
              shape: BoxShape.circle,
              border: Border.all(color: Toon.inkLight, width: 1.6),
            ),
            child: SuitIcon(suit, size: 11, onLight: true),
          ),
        );
      }(),
  ]);
}

class _WhirlPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final paint = _ink(2)..color = Toon.inkLight.withValues(alpha: 0.45);
    // Two swooshes chasing round the card.
    for (final start in [0.2, pi + 0.2]) {
      canvas.drawArc(Rect.fromCenter(center: c, width: 76, height: 56), start, 1.6, false, paint);
    }
  }

  @override
  bool shouldRepaint(_WhirlPainter old) => false;
}

// --- Go Fish: a fish that's caught a card ----------------------------------

class FishArt extends StatelessWidget {
  const FishArt({super.key});

  @override
  Widget build(BuildContext context) => _scene([
    _paint(_FishPainter()),
    // The card in its mouth (on the left, where it faces).
    _card('7d', 24, angle: -0.5, at: const Offset(-30, 4)),
  ]);
}

class _FishPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.56, cy = size.height * 0.52;
    // Tail.
    final tail = Path()
      ..moveTo(cx + 18, cy)
      ..lineTo(cx + 36, cy - 14)
      ..quadraticBezierTo(cx + 30, cy, cx + 36, cy + 14)
      ..close();
    _shape(canvas, tail, Toon.orange);
    // Body.
    final body = Path()
      ..moveTo(cx - 26, cy)
      ..quadraticBezierTo(cx - 8, cy - 22, cx + 20, cy)
      ..quadraticBezierTo(cx - 8, cy + 22, cx - 26, cy)
      ..close();
    _shape(canvas, body, Toon.orange);
    // Top fin and a stripe.
    final fin = Path()
      ..moveTo(cx - 8, cy - 11)
      ..quadraticBezierTo(cx, cy - 22, cx + 10, cy - 7)
      ..close();
    _shape(canvas, fin, Toon.yellow, 1.6);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx + 2, cy), width: 12, height: 22),
      -pi / 2,
      pi,
      false,
      _ink(1.6),
    );
    // Eye.
    canvas.drawCircle(Offset(cx - 13, cy - 4), 4, _fill(Toon.cardFace));
    canvas.drawCircle(Offset(cx - 13, cy - 4), 4, _ink(1.4));
    canvas.drawCircle(Offset(cx - 12, cy - 4), 1.8, _fill(Toon.inkLight));
    // Bubbles.
    for (final (dx, dy, r) in [(-20.0, -18.0, 3.0), (-14.0, -26.0, 2.2), (-26.0, -26.0, 1.6)]) {
      canvas.drawCircle(Offset(cx + dx, cy + dy), r, _ink(1.3));
    }
  }

  @override
  bool shouldRepaint(_FishPainter old) => false;
}

// --- Four in a Row: the board, a disc dropping in --------------------------

class RowArt extends StatelessWidget {
  const RowArt({super.key});

  static const _pattern = [
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [0, 2, 1, 0],
    [2, 1, 1, 2],
  ];

  Widget _disc(int cell) => Container(
    width: 9,
    height: 9,
    margin: const EdgeInsets.all(1.2),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: [Toon.cardFace, Toon.red, Toon.yellow][cell],
      border: Border.all(color: Toon.inkLight, width: 1.5),
    ),
  );

  @override
  Widget build(BuildContext context) => _scene([
    Transform.translate(
      offset: const Offset(0, 6),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: Toon.box(Toon.blue, radius: 7, shadow: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in _pattern)
              Row(mainAxisSize: MainAxisSize.min, children: [for (final c in row) _disc(c)]),
          ],
        ),
      ),
    ),
    // The winning disc on its way down the third column, with speed lines.
    Transform.translate(offset: const Offset(5.7, -26), child: _disc(1)),
    _paint(_DropLinesPainter()),
  ]);
}

class _DropLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2 + 5.7, top = 2.0;
    final paint = _ink(1.6)..color = Toon.inkLight.withValues(alpha: 0.6);
    for (final dx in [-4.0, 0.0, 4.0]) {
      canvas.drawLine(Offset(x + dx, top - 2 + dx.abs()), Offset(x + dx, top - 9 + dx.abs()), paint);
    }
  }

  @override
  bool shouldRepaint(_DropLinesPainter old) => false;
}

// --- Spades: a spade (the digging kind) with a spade for a blade -----------

class SpadesArt extends StatelessWidget {
  const SpadesArt({super.key});

  @override
  Widget build(BuildContext context) =>
      _scene([_card('As', 36, angle: -0.18, at: const Offset(-14, -2)), _paint(_ShovelPainter())]);
}

class _ShovelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width * 0.66, size.height * 0.52);
    canvas.rotate(0.5);
    // Handle: a wooden shaft and a T grip.
    final shaft = RRect.fromRectAndRadius(const Rect.fromLTRB(-2.5, -32, 2.5, 6), const Radius.circular(2));
    canvas.drawRRect(shaft, _fill(Toon.wood));
    canvas.drawRRect(shaft, _ink(1.6));
    final grip = RRect.fromRectAndRadius(const Rect.fromLTRB(-8, -36, 8, -30), const Radius.circular(3));
    canvas.drawRRect(grip, _fill(Toon.wood));
    canvas.drawRRect(grip, _ink(1.6));
    // Blade: the spade suit, point down, in steel.
    final blade = suitPath(Suit.spades, 26).transform(
      (Matrix4.identity()
            ..translateByDouble(13, 30, 0, 1)
            ..scaleByDouble(1, -1, 1, 1)
            ..translateByDouble(0, 0, 0, 1))
          .storage,
    );
    final placed = blade.shift(const Offset(-26, -2));
    _shape(canvas, placed, const Color(0xFFC9D3DE), 1.8);
    // A glint.
    canvas.drawLine(const Offset(-8, 14), const Offset(-5, 22), _ink(1.6)..color = Colors.white);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShovelPainter old) => false;
}

// --- Blitz: a fighter plane firing cards ------------------------------------

class BlitzArt extends StatelessWidget {
  const BlitzArt({super.key});

  @override
  Widget build(BuildContext context) => _scene([
    _paint(_PlanePainter()),
    // The rounds: cards flying out of the gun, spinning.
    _card('9d', 11, angle: 0.5, at: const Offset(24, 8)),
    _card('Ks', 11, angle: -0.5, at: const Offset(31, -3)),
    _card('Ah', 11, angle: 0.9, at: const Offset(39, 7)),
  ]);
}

class _PlanePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Facing right, climbing a touch; the gun fires along y = 38.
    canvas.save();
    canvas.translate(13, 9);
    canvas.scale(0.76);
    const body = Toon.blue, trim = Toon.yellow;
    // Far wing, behind the body.
    _shape(
      canvas,
      Path()
        ..moveTo(22, 26)
        ..lineTo(34, 26)
        ..lineTo(28, 14)
        ..lineTo(22, 14)
        ..close(),
      Color.lerp(trim, Colors.black, 0.2)!,
      1.6,
    );
    // Tail fin and tailplane.
    _shape(
      canvas,
      Path()
        ..moveTo(2, 14)
        ..lineTo(9, 14)
        ..lineTo(15, 27)
        ..lineTo(3, 27)
        ..close(),
      trim,
      1.6,
    );
    // Fuselage.
    final fuselage = Path()
      ..moveTo(3, 26)
      ..quadraticBezierTo(14, 21, 32, 21)
      ..quadraticBezierTo(46, 21, 50, 28)
      ..quadraticBezierTo(46, 35, 30, 35)
      ..quadraticBezierTo(14, 35, 3, 29)
      ..close();
    _shape(canvas, fuselage, body);
    // Cockpit canopy.
    _shape(
      canvas,
      Path()
        ..moveTo(26, 22)
        ..quadraticBezierTo(31, 12, 39, 22)
        ..close(),
      const Color(0xFFBFE4FF),
      1.6,
    );
    // Near wing, over the body, with a roundel.
    _shape(
      canvas,
      Path()
        ..moveTo(19, 27)
        ..lineTo(36, 27)
        ..lineTo(29, 41)
        ..lineTo(19, 41)
        ..close(),
      trim,
      1.6,
    );
    canvas.drawCircle(const Offset(25.5, 34), 3, _fill(Toon.red));
    canvas.drawCircle(const Offset(25.5, 34), 3, _ink(1.2));
    // Gun under the nose and its muzzle flash.
    canvas.drawLine(const Offset(42, 33), const Offset(53, 33), _ink(2.6));
    final flash = Path();
    for (var i = 0; i < 10; i++) {
      final a = i * pi / 5;
      final r = i.isEven ? 6.0 : 2.6;
      final p = Offset(57 + cos(a) * r, 33 + sin(a) * r);
      i == 0 ? flash.moveTo(p.dx, p.dy) : flash.lineTo(p.dx, p.dy);
    }
    flash.close();
    _shape(canvas, flash, Toon.orange, 1.2);
    // Propeller: a spinning blur on the nose.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(51, 28), width: 4, height: 20),
      _fill(Toon.inkLight.withValues(alpha: 0.25)),
    );
    canvas.drawCircle(const Offset(51, 28), 2.2, _fill(Toon.inkLight));
    canvas.restore();
    // Speed lines trailing off the back.
    final speed = _ink(1.6)..color = Toon.inkLight.withValues(alpha: 0.45);
    for (final (y, len) in [(22.0, 8.0), (29.0, 12.0), (36.0, 7.0)]) {
      canvas.drawLine(Offset(13, y), Offset(13 - len, y), speed);
    }
  }

  @override
  bool shouldRepaint(_PlanePainter old) => false;
}
