import 'package:flutter/material.dart';

import '../theme/toon.dart';
import 'cards.dart';

const cardRed = Color(0xFFE23B48);
const cardBlack = Toon.inkLight;

/// A suit symbol drawn as a path (Fredoka has no suit glyphs), filling a
/// square of [size].
class SuitIcon extends StatelessWidget {
  const SuitIcon(this.suit, {super.key, required this.size, this.color, this.onLight = false});

  final Suit suit;
  final double size;
  final Color? color;

  /// On a light surface (a card face, a yellow chip): never needs an outline.
  final bool onLight;

  @override
  Widget build(BuildContext context) {
    final fill = color ?? (suit.isRed ? cardRed : cardBlack);
    // Dark suits off the card in dark mode get a light outline so they
    // stand out from dark buttons, the felt and the overlays.
    final outline = !onLight && Toon.dark && fill.computeLuminance() < 0.1;
    return CustomPaint(
      size: Size.square(size),
      painter: _SuitPainter(suit, fill, outline ? Toon.cardFace : null),
    );
  }
}

class _SuitPainter extends CustomPainter {
  _SuitPainter(this.suit, this.color, this.outline);

  final Suit suit;
  final Color color;
  final Color? outline;

  @override
  void paint(Canvas canvas, Size size) {
    final path = suitPath(suit, size.width);
    if (outline != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = outline!
          ..style = PaintingStyle.stroke
          ..strokeWidth = (size.width * 0.14).clamp(1.5, 6.0)
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SuitPainter old) => old.suit != suit || old.color != color || old.outline != outline;
}

/// The suit's outline in a [s] x [s] square.
Path suitPath(Suit suit, double s) {
  Path heart(bool flip) {
    final p = Path()
      ..moveTo(0.5, 0.95)
      ..cubicTo(0.18, 0.72, 0.0, 0.52, 0.04, 0.32)
      ..cubicTo(0.08, 0.1, 0.38, 0.02, 0.5, 0.26)
      ..cubicTo(0.62, 0.02, 0.92, 0.1, 0.96, 0.32)
      ..cubicTo(1.0, 0.52, 0.82, 0.72, 0.5, 0.95)
      ..close();
    return flip
        ? p.transform(
            (Matrix4.identity()
                  ..translateByDouble(0, 1, 0, 1)
                  ..scaleByDouble(1, -1, 1, 1))
                .storage,
          )
        : p;
  }

  final Path unit;
  switch (suit) {
    case Suit.hearts:
      unit = heart(false);
    case Suit.spades:
      unit = Path()
        ..addPath(
          heart(true).transform(
            (Matrix4.identity()
                  ..translateByDouble(0.04, -0.06, 0, 1)
                  ..scaleByDouble(0.92, 0.88, 1, 1))
                .storage,
          ),
          Offset.zero,
        )
        ..addPath(_stem(), Offset.zero);
    case Suit.diamonds:
      unit = Path()
        ..moveTo(0.5, 0.02)
        ..quadraticBezierTo(0.7, 0.3, 0.9, 0.5)
        ..quadraticBezierTo(0.7, 0.7, 0.5, 0.98)
        ..quadraticBezierTo(0.3, 0.7, 0.1, 0.5)
        ..quadraticBezierTo(0.3, 0.3, 0.5, 0.02)
        ..close();
    case Suit.clubs:
      unit = Path()
        ..addOval(Rect.fromCircle(center: const Offset(0.5, 0.27), radius: 0.22))
        ..addOval(Rect.fromCircle(center: const Offset(0.26, 0.56), radius: 0.22))
        ..addOval(Rect.fromCircle(center: const Offset(0.74, 0.56), radius: 0.22))
        ..addRect(const Rect.fromLTRB(0.4, 0.4, 0.6, 0.6))
        ..addPath(_stem(), Offset.zero);
  }
  return unit.transform(Matrix4.diagonal3Values(s, s, 1).storage);
}

Path _stem() => Path()
  ..moveTo(0.5, 0.55)
  ..quadraticBezierTo(0.48, 0.85, 0.3, 0.98)
  ..lineTo(0.7, 0.98)
  ..quadraticBezierTo(0.52, 0.85, 0.5, 0.55)
  ..close();

/// A playing card, [width] wide (height = 1.4 x width). Face down shows the
/// Duel back. [glow] rings it (winning cards), [dim] fades it.
class CardView extends StatelessWidget {
  const CardView({
    super.key,
    required this.card,
    required this.width,
    this.faceUp = true,
    this.glow = false,
    this.dim = false,
  });

  final PlayingCard? card;
  final double width;
  final bool faceUp;
  final bool glow;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final w = width, h = width * 1.4;
    final r = w * 0.14;
    final c = card;
    final border = (w * 0.05).clamp(1.5, 2.5);
    Widget face;
    if (!faceUp || c == null) {
      face = _CardBack(width: w, radius: r, border: border);
    } else {
      final color = c.suit.isRed ? cardRed : cardBlack;
      face = Container(
        decoration: BoxDecoration(
          color: Toon.cardFace,
          borderRadius: BorderRadius.circular(r),
          border: Border.all(color: Toon.inkLight, width: border),
        ),
        child: Stack(
          children: [
            Positioned(
              left: w * 0.1,
              top: w * 0.05,
              child: Column(
                children: [
                  Text(
                    c.rankLabel,
                    style: Toon.text(w * (c.rank == 10 ? 0.36 : 0.42), weight: FontWeight.w700, color: color),
                  ),
                  SuitIcon(c.suit, size: w * 0.24, onLight: true),
                ],
              ),
            ),
            Positioned(
              right: w * 0.08,
              bottom: w * 0.08,
              child: SuitIcon(c.suit, size: w * 0.48, onLight: true),
            ),
          ],
        ),
      );
    }
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: dim ? 0.45 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: w,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r),
          boxShadow: [
            if (glow) const BoxShadow(color: Toon.yellow, spreadRadius: 3),
            BoxShadow(color: Toon.ink.withValues(alpha: 0.35), offset: Offset(0, w * 0.05)),
          ],
        ),
        child: face,
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.width, required this.radius, required this.border});

  final double width;
  final double radius;
  final double border;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Toon.red,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Toon.inkLight, width: border),
    ),
    padding: EdgeInsets.all(width * 0.08),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius * 0.6),
        border: Border.all(color: Toon.cardFace, width: (width * 0.04).clamp(1, 2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius * 0.6),
        child: CustomPaint(painter: _BackPattern(), child: const SizedBox.expand()),
      ),
    ),
  );
}

/// Diagonal criss-cross on the card back.
class _BackPattern extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Toon.cardFace.withValues(alpha: 0.35)
      ..strokeWidth = size.width * 0.08;
    final step = size.width / 3;
    for (var x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
      canvas.drawLine(Offset(x + size.height, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_BackPattern old) => false;
}
