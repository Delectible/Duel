import 'dart:math';

import 'package:duel_engine/sunk/sunk.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/toon.dart';
import 'sunk_controller.dart';

/// Sunk's colours: the sea from the shallows to the deep, sand, gold.
abstract final class Deep {
  static const shallow = Color(0xFF2B8FB3);
  static const mid = Color(0xFF16567E);
  static const deep = Color(0xFF0B2747);
  static const sand = Color(0xFFD9B77A);
  static const sandDark = Color(0xFFB08C52);
  static const wreck = Color(0xFF3E2A1E);
  static const gold = Color(0xFFF2C14E);
  static const goldDark = Color(0xFFB8862B);
  static const foam = Color(0xFFE8F7FF);
}

/// The sea: light from above in slow rays, a sandy floor, the wreck lying
/// on its side, weed swaying. [t] (0..1, looping) moves the rays and weed.
class SeaPainter extends CustomPainter {
  SeaPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(22));
    canvas.save();
    canvas.clipRRect(r);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Deep.shallow, Deep.mid, Deep.deep],
          stops: [0, 0.45, 1],
        ).createShader(Offset.zero & size),
    );
    // Light rays, swaying.
    for (var i = 0; i < 5; i++) {
      final x = w * (0.1 + i * 0.22) + sin((t + i * 0.2) * 2 * pi) * w * 0.04;
      final ray = Path()
        ..moveTo(x - w * 0.03, 0)
        ..lineTo(x + w * 0.05, 0)
        ..lineTo(x + w * 0.18, h * 0.85)
        ..lineTo(x + w * 0.02, h * 0.85)
        ..close();
      canvas.drawPath(
        ray,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.13 + 0.05 * sin((t * 2 + i) * pi)),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, w, h * 0.85)),
      );
    }
    // The floor.
    final floor = Path()
      ..moveTo(0, h * 0.86)
      ..quadraticBezierTo(w * 0.25, h * 0.82, w * 0.5, h * 0.86)
      ..quadraticBezierTo(w * 0.78, h * 0.9, w, h * 0.84)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      floor,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Deep.sand, Deep.sandDark],
        ).createShader(Rect.fromLTWH(0, h * 0.82, w, h * 0.18)),
    );
    // The wreck: a hull on its side, a broken mast, a porthole.
    final hx = w * 0.6, hy = h * 0.86;
    final hull = Path()
      ..moveTo(hx - w * 0.3, hy)
      ..quadraticBezierTo(hx - w * 0.28, hy - h * 0.12, hx - w * 0.05, hy - h * 0.13)
      ..lineTo(hx + w * 0.22, hy - h * 0.09)
      ..quadraticBezierTo(hx + w * 0.3, hy - h * 0.04, hx + w * 0.26, hy)
      ..close();
    canvas.drawPath(hull, Paint()..color = Deep.wreck.withValues(alpha: 0.85));
    final plank = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..strokeWidth = 1.5;
    for (var i = 1; i < 4; i++) {
      final y = hy - h * 0.03 * i;
      canvas.drawLine(Offset(hx - w * 0.26 + i * 4, y), Offset(hx + w * 0.24 - i * 6, y - h * 0.01), plank);
    }
    canvas.drawCircle(
      Offset(hx + w * 0.08, hy - h * 0.065),
      w * 0.022,
      Paint()..color = Deep.gold.withValues(alpha: 0.5),
    );
    canvas.drawLine(
      Offset(hx - w * 0.1, hy - h * 0.12),
      Offset(hx - w * 0.2, hy - h * 0.34),
      Paint()
        ..color = Deep.wreck
        ..strokeWidth = w * 0.018
        ..strokeCap = StrokeCap.round,
    );
    // A torn flag on the mast.
    final flag = Path()
      ..moveTo(hx - w * 0.19, hy - h * 0.32)
      ..lineTo(hx - w * 0.09, hy - h * 0.3 + sin(t * 2 * pi) * 4)
      ..lineTo(hx - w * 0.17, hy - h * 0.27)
      ..close();
    canvas.drawPath(flag, Paint()..color = Colors.white.withValues(alpha: 0.35));
    // Weed.
    for (final (x, len) in [(0.06, 0.18), (0.12, 0.12), (0.92, 0.2), (0.86, 0.11), (0.3, 0.09)]) {
      final base = Offset(w * x, h * 0.88);
      final path = Path()..moveTo(base.dx, base.dy);
      for (var k = 1; k <= 4; k++) {
        final y = base.dy - h * len * k / 4;
        path.lineTo(base.dx + sin((t + k * 0.15 + x) * 2 * pi) * 6 * k / 2, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF2E8B57).withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = Toon.outline
        ..color = Toon.ink,
    );
  }

  @override
  bool shouldRepaint(SeaPainter old) => old.t != t;
}

/// Bubbles rising through the sea.
class BubblesPainter extends CustomPainter {
  BubblesPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(7);
    for (var i = 0; i < 22; i++) {
      final x0 = rng.nextDouble(),
          speed = 0.5 + rng.nextDouble(),
          r = 2 + rng.nextDouble() * 5,
          phase = rng.nextDouble();
      final y = 1 - ((t * speed + phase) % 1);
      final x = x0 + sin((y * 6 + phase) * pi) * 0.012;
      final o = Offset(x * size.width, y * size.height * 0.95);
      canvas.drawCircle(
        o,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Colors.white.withValues(alpha: 0.35 * (0.3 + y)),
      );
      canvas.drawCircle(
        o.translate(-r * 0.35, -r * 0.35),
        r * 0.25,
        Paint()..color = Colors.white.withValues(alpha: 0.4 * y),
      );
    }
  }

  @override
  bool shouldRepaint(BubblesPainter old) => old.t != t;
}

/// Captain Boo: Duel's ghost, keeper of the wreck, in his captain's hat.
/// He bobs, looks toward [lookX] (-1 left .. 1 right), and acts out his
/// [mood]: laughing (he shakes), spooking (he swells, eyes wide and dark),
/// sulking (he droops), cheering (he bounces).
class CaptainBoo extends StatelessWidget {
  const CaptainBoo({
    super.key,
    required this.size,
    required this.t,
    this.mood = GhostMood.idle,
    this.lookX = 0,
  });

  final double size;
  final double t;
  final GhostMood mood;
  final double lookX;

  @override
  Widget build(BuildContext context) {
    final bob = sin(t * 2 * pi) * size * 0.04;
    final shake = mood == GhostMood.laughing ? sin(t * 2 * pi * 9) * size * 0.03 : 0.0;
    final hop = mood == GhostMood.cheering ? -sin(t * 2 * pi * 3).abs() * size * 0.08 : 0.0;
    final scale = mood == GhostMood.spooking ? 1.25 : (mood == GhostMood.sulking ? 0.92 : 1.0);
    return Transform.translate(
      offset: Offset(shake, bob + hop),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        child: CustomPaint(size: Size.square(size), painter: _BooPainter(t, mood, lookX)),
      ),
    );
  }
}

class _BooPainter extends CustomPainter {
  _BooPainter(this.t, this.mood, this.lookX);
  final double t;
  final GhostMood mood;
  final double lookX;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final sulk = mood == GhostMood.sulking;
    // His glow.
    canvas.drawCircle(
      Offset(w / 2, h * 0.55),
      w * 0.5,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: mood == GhostMood.spooking ? 0.35 : 0.18),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(w / 2, h * 0.55), radius: w * 0.5)),
    );
    // The body: a dome and a wavy hem that ripples.
    final body = Path()
      ..moveTo(w * 0.2, h * 0.9)
      ..lineTo(w * 0.2, h * 0.5)
      ..arcToPoint(Offset(w * 0.8, h * 0.5), radius: Radius.circular(w * 0.3))
      ..lineTo(w * 0.8, h * 0.9);
    for (var i = 0; i < 4; i++) {
      final x0 = w * (0.8 - i * 0.15);
      final wob = sin((t * 2 + i * 0.5) * 2 * pi) * h * 0.02;
      body.quadraticBezierTo(x0 - w * 0.0375, h * 0.8 + wob, x0 - w * 0.075, h * 0.86 + wob);
      body.quadraticBezierTo(x0 - w * 0.1125, h * 0.94 - wob, x0 - w * 0.15, h * 0.9);
    }
    body.close();
    canvas.drawPath(
      body.shift(Offset(w * 0.02, h * 0.02)),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
    canvas.drawPath(body, Paint()..color = Colors.white.withValues(alpha: 0.95));
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(2, w * 0.025)
        ..color = Toon.ink,
    );
    // Eyes: looking at whoever's turn it is; wide for a fright, half shut
    // in a sulk, squeezed shut laughing.
    final eyeY = h * 0.5;
    for (final ex in [w * 0.4, w * 0.6]) {
      final c = Offset(ex, eyeY);
      if (mood == GhostMood.laughing) {
        final arc = Path()
          ..moveTo(c.dx - w * 0.05, c.dy + h * 0.01)
          ..quadraticBezierTo(c.dx, c.dy - h * 0.05, c.dx + w * 0.05, c.dy + h * 0.01);
        canvas.drawPath(
          arc,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.03
            ..strokeCap = StrokeCap.round
            ..color = Toon.ink,
        );
        continue;
      }
      final big = mood == GhostMood.spooking ? 1.35 : 1.0;
      canvas.drawOval(
        Rect.fromCenter(center: c, width: w * 0.11 * big, height: h * (sulk ? 0.07 : 0.15) * big),
        Paint()..color = Toon.ink,
      );
      // A glint (a spade, as in the icon), shifted by where he looks.
      if (!sulk) {
        canvas.drawCircle(
          c.translate(lookX * w * 0.02 - w * 0.012, -h * 0.03),
          w * 0.018,
          Paint()..color = Colors.white,
        );
      }
    }
    // Mouth: an O for a Boo, a grin laughing, a wobble sulking.
    final mc = Offset(w / 2, h * 0.66);
    final ink = Paint()
      ..color = Toon.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025
      ..strokeCap = StrokeCap.round;
    switch (mood) {
      case GhostMood.spooking:
        canvas.drawOval(
          Rect.fromCenter(center: mc.translate(0, h * 0.02), width: w * 0.12, height: h * 0.14),
          Paint()..color = Toon.ink,
        );
      case GhostMood.laughing || GhostMood.cheering:
        canvas.drawArc(
          Rect.fromCenter(center: mc, width: w * 0.18, height: h * 0.12),
          0,
          pi,
          true,
          Paint()..color = Toon.ink,
        );
      case GhostMood.sulking:
        canvas.drawPath(
          Path()
            ..moveTo(mc.dx - w * 0.06, mc.dy + h * 0.02)
            ..quadraticBezierTo(mc.dx, mc.dy - h * 0.03, mc.dx + w * 0.06, mc.dy + h * 0.02),
          ink,
        );
      default:
        canvas.drawArc(
          Rect.fromCenter(center: mc, width: w * 0.1, height: h * 0.06),
          0.2,
          pi - 0.4,
          false,
          ink,
        );
    }
    // The captain's hat, cocked: a peaked cap with a gold band and badge.
    canvas.save();
    canvas.translate(w * 0.52, h * 0.24);
    canvas.rotate(-0.16);
    final crown = Path()
      ..moveTo(-w * 0.2, h * 0.02)
      ..quadraticBezierTo(-w * 0.24, -h * 0.13, 0, -h * 0.15)
      ..quadraticBezierTo(w * 0.24, -h * 0.13, w * 0.2, h * 0.02)
      ..close();
    final navy = Paint()..color = const Color(0xFF22263A);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, w * 0.022)
      ..strokeJoin = StrokeJoin.round
      ..color = Toon.ink;
    canvas.drawPath(crown, navy);
    canvas.drawPath(crown, edge);
    // The peak, sticking out over his eyes.
    final peak = Path()
      ..moveTo(-w * 0.22, h * 0.02)
      ..quadraticBezierTo(-w * 0.05, h * 0.09, w * 0.26, h * 0.03)
      ..quadraticBezierTo(w * 0.05, h * 0.0, -w * 0.22, h * 0.02)
      ..close();
    canvas.drawPath(peak, Paint()..color = const Color(0xFF151827));
    canvas.drawPath(peak, edge);
    canvas.drawRect(Rect.fromLTRB(-w * 0.2, -h * 0.025, w * 0.2, h * 0.012), Paint()..color = Deep.gold);
    canvas.drawCircle(Offset(0, -h * 0.075), w * 0.045, Paint()..color = Deep.gold);
    canvas.drawCircle(Offset(0, -h * 0.075), w * 0.045, edge..strokeWidth = max(1, w * 0.014));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BooPainter old) => old.t != t || old.mood != mood || old.lookX != lookX;
}

// --- Cards -----------------------------------------------------------------------

/// A Sunk card: a treasure (coins 1-3, pearls 4-5, gems 6-7, the gold idol
/// 8) or a special, on a sea-glass face; or its back (the ghost in a
/// porthole).
class SunkCardView extends StatelessWidget {
  const SunkCardView({super.key, required this.card, this.width = 70, this.glow = false});

  final SunkCard? card;
  final double width;
  final bool glow;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Container(
      decoration: glow
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(width * 0.14),
              boxShadow: [
                BoxShadow(color: Deep.gold.withValues(alpha: 0.8), blurRadius: 16, spreadRadius: 2),
              ],
            )
          : null,
      child: CustomPaint(size: Size(width, width * 1.4), painter: _CardPainter(card)),
    ),
  );
}

Color treasureColor(int v) => switch (v) {
  1 || 2 || 3 => Deep.gold,
  4 || 5 => const Color(0xFFF4EFE6),
  6 => const Color(0xFF2FBF71),
  7 => const Color(0xFFE5484D),
  _ => const Color(0xFFFFD447),
};

String specialName(SunkKind k) => switch (k) {
  SunkKind.air => 'Spare Air',
  SunkKind.boo => 'Boo!',
  SunkKind.hook => 'Hook',
  SunkKind.cut => 'Cut Line',
  SunkKind.map => 'Map',
  SunkKind.treasure => '',
};

class _CardPainter extends CustomPainter {
  _CardPainter(this.card);
  final SunkCard? card;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(w * 0.13));
    final c = card;
    canvas.drawRRect(r.shift(const Offset(1.5, 2.5)), Paint()..color = Colors.black.withValues(alpha: 0.25));
    if (c == null) {
      // The back: deep water, a porthole with the ghost peeking.
      canvas.drawRRect(
        r,
        Paint()
          ..shader = const LinearGradient(
            colors: [Deep.mid, Deep.deep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(Offset.zero & size),
      );
      final port = Offset(w / 2, h / 2);
      canvas.drawCircle(port, w * 0.3, Paint()..color = Deep.goldDark);
      canvas.drawCircle(port, w * 0.24, Paint()..color = Deep.shallow);
      _ghost(canvas, port.translate(0, w * 0.04), w * 0.3);
    } else {
      canvas.drawRRect(
        r,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFF7FBFD), Color(0xFFD7EEF6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Offset.zero & size),
      );
      final mid = Offset(w / 2, h * 0.52);
      if (c.isTreasure) {
        _treasure(canvas, mid, w * 0.64, c.value);
        _label(canvas, '${c.value}', Offset(w * 0.17, h * 0.13), w * 0.26, Toon.inkLight);
        _label(
          canvas,
          switch (c.value) {
            <= 3 => 'Coins',
            <= 5 => 'Pearl',
            <= 7 => 'Gem',
            _ => 'Idol',
          },
          Offset(w / 2, h * 0.88),
          w * 0.15,
          Toon.inkLight.withValues(alpha: 0.7),
        );
      } else {
        _special(canvas, mid, w * 0.6, c.kind);
        _label(canvas, specialName(c.kind), Offset(w / 2, h * 0.88), w * 0.16, Toon.inkLight);
      }
    }
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, w * 0.03)
        ..color = Toon.ink,
    );
  }

  static void _label(Canvas canvas, String s, Offset at, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: Toon.text(size, weight: FontWeight.w700, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  static final _ink = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = const Color(0xFF2B2D42);

  static void _treasure(Canvas canvas, Offset c, double s, int v) {
    final color = treasureColor(v);
    if (v <= 3) {
      // A little stack of coins, one per point.
      for (var i = 0; i < v; i++) {
        final o = c.translate((i - (v - 1) / 2) * s * 0.28, (i.isEven ? 0 : -s * 0.12));
        canvas.drawOval(Rect.fromCenter(center: o, width: s * 0.5, height: s * 0.5), Paint()..color = color);
        canvas.drawOval(
          Rect.fromCenter(center: o, width: s * 0.34, height: s * 0.34),
          Paint()..color = Deep.goldDark.withValues(alpha: 0.5),
        );
        canvas.drawOval(Rect.fromCenter(center: o, width: s * 0.5, height: s * 0.5), _ink);
      }
    } else if (v <= 5) {
      // A pearl (two for a 5) in an open shell.
      final shell = Path()
        ..moveTo(c.dx - s * 0.5, c.dy + s * 0.15)
        ..quadraticBezierTo(c.dx, c.dy + s * 0.55, c.dx + s * 0.5, c.dy + s * 0.15)
        ..close();
      canvas.drawPath(shell, Paint()..color = const Color(0xFFF2A6A0));
      canvas.drawPath(shell, _ink);
      for (var i = 0; i < v - 3; i++) {
        final o = c.translate((i - (v - 4) / 2) * s * 0.36, 0);
        canvas.drawCircle(
          o,
          s * 0.2,
          Paint()
            ..shader = const RadialGradient(
              center: Alignment(-0.4, -0.4),
              colors: [Colors.white, Color(0xFFE2DCCF)],
            ).createShader(Rect.fromCircle(center: o, radius: s * 0.2)),
        );
        canvas.drawCircle(o, s * 0.2, _ink);
      }
    } else if (v <= 7) {
      // A cut gem.
      final gem = Path()
        ..moveTo(c.dx - s * 0.4, c.dy - s * 0.12)
        ..lineTo(c.dx - s * 0.22, c.dy - s * 0.32)
        ..lineTo(c.dx + s * 0.22, c.dy - s * 0.32)
        ..lineTo(c.dx + s * 0.4, c.dy - s * 0.12)
        ..lineTo(c.dx, c.dy + s * 0.4)
        ..close();
      canvas.drawPath(gem, Paint()..color = color);
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - s * 0.4, c.dy - s * 0.12)
          ..lineTo(c.dx + s * 0.4, c.dy - s * 0.12)
          ..moveTo(c.dx - s * 0.12, c.dy - s * 0.12)
          ..lineTo(c.dx, c.dy + s * 0.4)
          ..lineTo(c.dx + s * 0.12, c.dy - s * 0.12),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: 0.6),
      );
      canvas.drawPath(gem, _ink);
    } else {
      // The idol: a golden Captain Boo.
      canvas.drawCircle(c, s * 0.48, Paint()..color = color.withValues(alpha: 0.25));
      final body = Path()
        ..moveTo(c.dx - s * 0.28, c.dy + s * 0.35)
        ..lineTo(c.dx - s * 0.28, c.dy - s * 0.02)
        ..arcToPoint(Offset(c.dx + s * 0.28, c.dy - s * 0.02), radius: Radius.circular(s * 0.28))
        ..lineTo(c.dx + s * 0.28, c.dy + s * 0.35)
        ..close();
      canvas.drawPath(body, Paint()..color = color);
      canvas.drawPath(body, _ink);
      for (final ex in [-0.1, 0.1]) {
        canvas.drawOval(
          Rect.fromCenter(center: c.translate(ex * s, -s * 0.02), width: s * 0.09, height: s * 0.14),
          Paint()..color = Deep.goldDark,
        );
      }
      canvas.drawRect(
        Rect.fromCenter(center: c.translate(0, s * 0.42), width: s * 0.7, height: s * 0.12),
        Paint()..color = Deep.goldDark,
      );
    }
  }

  static void _special(Canvas canvas, Offset c, double s, SunkKind k) {
    switch (k) {
      case SunkKind.air:
        // A dive tank with a valve.
        final tank = RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: s * 0.42, height: s * 0.8),
          Radius.circular(s * 0.2),
        );
        canvas.drawRRect(tank, Paint()..color = const Color(0xFFF5A524));
        canvas.drawRRect(tank, _ink);
        canvas.drawRect(
          Rect.fromCenter(center: c.translate(0, -s * 0.46), width: s * 0.12, height: s * 0.1),
          Paint()..color = Colors.grey,
        );
        canvas.drawLine(c.translate(-s * 0.21, -s * 0.05), c.translate(s * 0.21, -s * 0.05), _ink);
      case SunkKind.boo:
        _ghost(canvas, c, s);
      case SunkKind.hook:
        final p = Path()
          ..moveTo(c.dx, c.dy - s * 0.45)
          ..lineTo(c.dx, c.dy + s * 0.15)
          ..arcToPoint(Offset(c.dx - s * 0.3, c.dy + s * 0.15), radius: Radius.circular(s * 0.15))
          ..lineTo(c.dx - s * 0.36, c.dy + s * 0.02);
        canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.08
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFF697177),
        );
        canvas.drawCircle(c.translate(0, -s * 0.45), s * 0.06, _ink);
      case SunkKind.cut:
        // A line, snipped: two ends and a spark.
        final line = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.06
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF8D6E4C);
        canvas.drawLine(c.translate(0, -s * 0.5), c.translate(0, -s * 0.08), line);
        canvas.drawLine(c.translate(s * 0.04, s * 0.08), c.translate(s * 0.04, s * 0.5), line);
        for (var i = 0; i < 6; i++) {
          final a = i * pi / 3;
          canvas.drawLine(
            c.translate(cos(a) * s * 0.08, sin(a) * s * 0.08),
            c.translate(cos(a) * s * 0.18, sin(a) * s * 0.18),
            Paint()
              ..color = const Color(0xFFE5484D)
              ..strokeWidth = 2,
          );
        }
      case SunkKind.map:
        final scroll = RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: s * 0.8, height: s * 0.6),
          Radius.circular(s * 0.06),
        );
        canvas.drawRRect(scroll, Paint()..color = const Color(0xFFE9D3A1));
        canvas.drawRRect(scroll, _ink);
        final x = Paint()
          ..color = const Color(0xFFE5484D)
          ..strokeWidth = s * 0.05
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(c.translate(s * 0.08, -s * 0.02), c.translate(s * 0.22, s * 0.12), x);
        canvas.drawLine(c.translate(s * 0.22, -s * 0.02), c.translate(s * 0.08, s * 0.12), x);
        final dash = Paint()
          ..color = Toon.inkLight
          ..strokeWidth = 1.5;
        for (var i = 0; i < 4; i++) {
          canvas.drawLine(
            c.translate(-s * 0.3 + i * s * 0.09, s * 0.12 - i * s * 0.04),
            c.translate(-s * 0.26 + i * s * 0.09, s * 0.1 - i * s * 0.04),
            dash,
          );
        }
      case SunkKind.treasure:
        break;
    }
  }

  static void _ghost(Canvas canvas, Offset c, double s) {
    final body = Path()
      ..moveTo(c.dx - s * 0.3, c.dy + s * 0.35)
      ..lineTo(c.dx - s * 0.3, c.dy - s * 0.02)
      ..arcToPoint(Offset(c.dx + s * 0.3, c.dy - s * 0.02), radius: Radius.circular(s * 0.3))
      ..lineTo(c.dx + s * 0.3, c.dy + s * 0.35);
    for (var i = 0; i < 3; i++) {
      final x0 = c.dx + s * 0.3 - i * s * 0.2;
      body.quadraticBezierTo(x0 - s * 0.05, c.dy + s * 0.25, x0 - s * 0.1, c.dy + s * 0.32);
      body.quadraticBezierTo(x0 - s * 0.15, c.dy + s * 0.4, x0 - s * 0.2, c.dy + s * 0.35);
    }
    body.close();
    canvas.drawPath(body, Paint()..color = Colors.white);
    canvas.drawPath(body, _ink);
    for (final ex in [-0.1, 0.1]) {
      canvas.drawOval(
        Rect.fromCenter(center: c.translate(ex * s, -s * 0.02), width: s * 0.09, height: s * 0.14),
        Paint()..color = const Color(0xFF2B2D42),
      );
    }
  }

  @override
  bool shouldRepaint(_CardPainter old) => old.card != card;
}

/// A treasure in a bag, small: its colour and its number.
class TreasureToken extends StatelessWidget {
  const TreasureToken(this.value, {super.key, this.size = 26, this.lit = false});

  final int value;
  final double size;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final c = treasureColor(value);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: value >= 6 && value <= 7 ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: value >= 6 && value <= 7 ? BorderRadius.circular(size * 0.25) : null,
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.4),
          colors: [Color.lerp(c, Colors.white, 0.45)!, c],
        ),
        border: Border.all(color: Toon.ink, width: 1.6),
        boxShadow: lit
            ? [BoxShadow(color: Deep.gold.withValues(alpha: 0.9), blurRadius: 8, spreadRadius: 1)]
            : null,
      ),
      child: Text(
        '$value',
        style: Toon.text(size * 0.5, weight: FontWeight.w700, color: Toon.on(c)),
      ),
    );
  }
}
