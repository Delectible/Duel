import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/ghost_mark.dart';
import '../theme/toon.dart';

/// The pattern printed on a card back.
enum BackPattern { lattice, stripes, dots, stars, ghosts, diamonds }

/// Card backs from the store: every face-down card in every game wears the
/// one you pick (black tables keep their gold ones).
enum CardBack {
  classic('Classic red', Toon.red, BackPattern.lattice, Toon.cardFace),
  navy('Navy', Color(0xFF2F5FB3), BackPattern.lattice, Toon.cardFace),
  stripes('Mint stripes', Color(0xFF2FA36B), BackPattern.stripes, Toon.cardFace),
  polka('Polka', Color(0xFF9B6BFF), BackPattern.dots, Toon.cardFace),
  stars('Starry night', Color(0xFF23264A), BackPattern.stars, Toon.yellow),
  ghost('Ghosts', Color(0xFF17171D), BackPattern.ghosts, Colors.white),
  royal('Royal', Color(0xFF6E1F2E), BackPattern.diamonds, Color(0xFFD9A93A));

  const CardBack(this.label, this.color, this.pattern, this.ink);

  final String label;
  final Color color;
  final BackPattern pattern;
  final Color ink;

  /// What face-down cards wear now (the account sets it).
  static CardBack chosen = classic;
}

/// Table felts from the store: the card games' tables (Crazy Eights, Go
/// Fish, Spades, Goofspiel, Blitz) wear the one you pick. Casino tables
/// keep their stake colours.
enum TableFelt {
  classic('Classic green', Color(0xFF3DA35D), Color(0xFFB0703A)),
  ocean('Ocean', Color(0xFF2C7FB8), Color(0xFF6B4A2E)),
  berry('Berry', Color(0xFFB0344A), Color(0xFF4A2A22)),
  teal('Lagoon', Color(0xFF1E9C94), Color(0xFF8A5A32)),
  desert('Saloon', Color(0xFFC07A3C), Color(0xFF5A3A1E)),
  plum('Plum', Color(0xFF7A4FB5), Color(0xFF3E2A1E)),
  midnight('Midnight', Color(0xFF262A44), Color(0xFF15151B));

  const TableFelt(this.label, this.felt, this.rail);

  final String label;
  final Color felt, rail;

  /// What the card tables wear now (the account sets it).
  static TableFelt get chosen => _chosen;
  static TableFelt _chosen = classic;
  static set chosen(TableFelt f) {
    _chosen = f;
    Toon.useFelt(f.felt, f.rail);
  }
}

/// A card back's pattern, inside its border.
class BackPatternPainter extends CustomPainter {
  BackPatternPainter(this.back, {this.gold = false});

  final CardBack back;
  final bool gold;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final ink = (gold ? const Color(0xFFD9A93A) : back.ink).withValues(alpha: 0.4);
    final paint = Paint()..color = ink;
    switch (gold ? BackPattern.lattice : back.pattern) {
      case BackPattern.lattice:
        paint.strokeWidth = w * 0.08;
        final step = w / 3;
        for (var x = -h; x < w + h; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x + h, h), paint);
          canvas.drawLine(Offset(x + h, 0), Offset(x, h), paint);
        }
      case BackPattern.stripes:
        paint.strokeWidth = w * 0.12;
        for (var x = -h; x < w + h; x += w / 2.5) {
          canvas.drawLine(Offset(x, 0), Offset(x + h, h), paint);
        }
      case BackPattern.dots:
        final r = w * 0.09, step = w / 3;
        for (var y = step / 2, row = 0; y < h + r; y += step * 0.8, row++) {
          for (var x = row.isEven ? step / 2 : 0.0; x < w + r; x += step) {
            canvas.drawCircle(Offset(x, y), r, paint);
          }
        }
      case BackPattern.stars:
        final rng = Random(7);
        paint.color = back.ink.withValues(alpha: 0.85);
        for (var i = 0; i < 9; i++) {
          final c = Offset(rng.nextDouble() * w, rng.nextDouble() * h);
          _star(canvas, c, w * (0.05 + rng.nextDouble() * 0.06), paint);
        }
        canvas.drawCircle(
          Offset(w * 0.68, h * 0.25),
          w * 0.13,
          Paint()..color = back.ink.withValues(alpha: 0.9),
        );
        canvas.drawCircle(Offset(w * 0.74, h * 0.21), w * 0.12, Paint()..color = back.color);
      case BackPattern.ghosts:
        final body = GhostPainter.body();
        final s = w * 0.36 / 112;
        for (final (i, c) in [
          Offset(w * 0.28, h * 0.25),
          Offset(w * 0.72, h * 0.5),
          Offset(w * 0.3, h * 0.78),
        ].indexed) {
          canvas.save();
          canvas.translate(c.dx, c.dy);
          canvas.rotate(i.isEven ? -0.2 : 0.2);
          canvas.scale(s);
          canvas.translate(-96, -100);
          canvas.drawPath(body, Paint()..color = back.ink.withValues(alpha: 0.75));
          final eye = Paint()..color = back.color;
          canvas.drawOval(Rect.fromCenter(center: const Offset(72, 94), width: 20, height: 28), eye);
          canvas.drawOval(Rect.fromCenter(center: const Offset(108, 94), width: 20, height: 28), eye);
          canvas.restore();
        }
      case BackPattern.diamonds:
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1, w * 0.03)
          ..color = back.ink.withValues(alpha: 0.8);
        final c = Offset(w / 2, h / 2);
        for (final k in [0.42, 0.28, 0.14]) {
          canvas.drawPath(
            Path()..addPolygon([
              c + Offset(0, -h * k),
              c + Offset(w * k, 0),
              c + Offset(0, h * k),
              c + Offset(-w * k, 0),
            ], true),
            paint,
          );
        }
    }
  }

  static void _star(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final d = i.isEven ? r : r * 0.45;
      final p = c + Offset(cos(a) * d, sin(a) * d);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), paint);
  }

  @override
  bool shouldRepaint(BackPatternPainter old) => old.back != back || old.gold != gold;
}
