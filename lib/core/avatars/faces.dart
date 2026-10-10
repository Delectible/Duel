import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/toon.dart';

/// A face's look: the headband (the default for you), or the bots' cap,
/// shades, shark fin and wild hair. Any player can pick any look.
enum Look { headband, cap, shades, fin, spiky }

/// Who sits in a seat: a name and a face.
class Persona {
  const Persona({required this.name, required this.look, required this.skin});

  const Persona.you({this.name = 'You', this.look = Look.headband, this.skin = Toon.yellow});

  final String name;
  final Look look;
  final Color skin;

  static const _names = {
    Look.cap: ['Pip', 'Bean', 'Tad', 'Dot'],
    Look.shades: ['Boulder', 'Slate', 'Rocky', 'Flint'],
    Look.fin: ['Finn', 'Reef', 'Marlin', 'Gill'],
    Look.spiky: ['Blaze', 'Zap', 'Turbo', 'Bonkers'],
  };

  static const _skins = {
    Look.cap: Color(0xFFFFB38A),
    Look.shades: Color(0xFFB8B3A8),
    Look.fin: Color(0xFF7FB8E8),
    Look.spiky: Color(0xFFFF9EC4),
  };

  /// The bot looks, in the order games map them to personalities (poker:
  /// cap = Rookie, shades = Rock, fin = Shark, spiky = Maniac).
  static const botLooks = [Look.cap, Look.shades, Look.fin, Look.spiky];

  /// [count] bots with a mix of looks and no repeated names.
  static List<Persona> bots(int count, Random rng) {
    final looks = [...botLooks]..shuffle(rng);
    final used = <String>{};
    return [
      for (var i = 0; i < count; i++)
        () {
          final look = looks[i % looks.length];
          final name = (_names[look]!.where((n) => !used.contains(n)).toList()..shuffle(rng)).first;
          used.add(name);
          return Persona(name: name, look: look, skin: _skins[look]!);
        }(),
    ];
  }
}

/// The faces you can pick in your profile.
const avatars = [
  (Look.headband, Toon.yellow),
  (Look.headband, Color(0xFF8DE4B5)),
  (Look.headband, Color(0xFFC9B6FF)),
  (Look.cap, Color(0xFFFFB38A)),
  (Look.shades, Color(0xFFB8B3A8)),
  (Look.fin, Color(0xFF7FB8E8)),
  (Look.spiky, Color(0xFFFF9EC4)),
  (Look.cap, Color(0xFFC68B59)),
];

/// A round cartoon face in its [Look].
class Face extends StatelessWidget {
  const Face(this.persona, {super.key, required this.size});

  final Persona persona;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _FacePainter(persona));
}

class _FacePainter extends CustomPainter {
  _FacePainter(this.p);

  final Persona p;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.scale(s / 100);
    final ink = Paint()
      ..color = Toon.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint();
    final inkFill = Paint()..color = Toon.ink;

    void blob(Path path, Color color) {
      canvas.drawPath(path, fill..color = color);
      canvas.drawPath(path, ink);
    }

    final look = p.look;
    // Behind the head: the shark's fin, the maniac's spiky hair.
    if (look == Look.fin) {
      blob(
        Path()
          ..moveTo(38, 22)
          ..quadraticBezierTo(52, 0, 70, 4)
          ..quadraticBezierTo(60, 14, 62, 26)
          ..close(),
        const Color(0xFF5E9BD1),
      );
    }
    if (look == Look.spiky) {
      final hair = Path()..moveTo(14, 44);
      const spikes = [(18, 8), (34, 30), (42, 2), (54, 28), (66, 4), (72, 30), (88, 12), (86, 44)];
      for (final (x, y) in spikes) {
        hair.lineTo(x.toDouble(), y.toDouble());
      }
      hair.close();
      blob(hair, Toon.orange);
    }

    // Head.
    blob(Path()..addOval(const Rect.fromLTWH(10, 14, 80, 80)), p.skin);

    // Eyes.
    if (look == Look.shades) {
      // Sunglasses.
      final glasses = Path()
        ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(20, 40, 26, 16), const Radius.circular(6)))
        ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(54, 40, 26, 16), const Radius.circular(6)));
      blob(glasses, Toon.ink);
      canvas.drawLine(const Offset(46, 46), const Offset(54, 46), ink);
      canvas.drawLine(
        const Offset(26, 44),
        const Offset(32, 44),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.6)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    } else if (look == Look.spiky) {
      // Wide, wild eyes.
      for (final x in [34.0, 66.0]) {
        blob(Path()..addOval(Rect.fromCircle(center: Offset(x, 46), radius: 11)), Colors.white);
        canvas.drawCircle(Offset(x + 2, 47), 4, inkFill);
      }
    } else {
      for (final x in [36.0, 64.0]) {
        blob(Path()..addOval(Rect.fromCenter(center: Offset(x, 46), width: 16, height: 20)), Colors.white);
        canvas.drawCircle(Offset(x + 1, 48), 5, inkFill);
        canvas.drawCircle(Offset(x + 3, 45), 1.6, Paint()..color = Colors.white);
      }
    }

    // Mouth.
    switch (look) {
      case Look.headband:
        canvas.drawArc(const Rect.fromLTWH(32, 54, 36, 24), 0.2, pi - 0.4, false, ink);
      case Look.cap:
        canvas.drawArc(const Rect.fromLTWH(34, 56, 32, 22), 0.3, pi - 0.6, false, ink);
        final freckle = Paint()..color = const Color(0xFFD9785A);
        for (final o in const [Offset(24, 62), Offset(29, 66), Offset(71, 62), Offset(76, 66)]) {
          canvas.drawCircle(o, 2.2, freckle);
        }
      case Look.shades:
        canvas.drawLine(const Offset(38, 72), const Offset(62, 70), ink);
      case Look.fin:
        final teeth = Path()..moveTo(30, 66);
        for (var i = 0; i < 6; i++) {
          teeth
            ..lineTo(34 + i * 7.0, 74)
            ..lineTo(37.5 + i * 7.0, 66);
        }
        final grin = Path()
          ..moveTo(28, 64)
          ..quadraticBezierTo(50, 86, 72, 64)
          ..close();
        blob(grin, Colors.white);
        canvas.drawPath(teeth, ink..strokeWidth = 3);
        ink.strokeWidth = 5;
      case Look.spiky:
        final grin = Path()
          ..moveTo(30, 62)
          ..quadraticBezierTo(50, 92, 70, 62)
          ..close();
        blob(grin, const Color(0xFF8E2F3C));
        canvas.drawPath(
          Path()
            ..moveTo(40, 79)
            ..quadraticBezierTo(50, 72, 60, 79),
          Paint()..color = Toon.red,
        );
    }

    // On top: the rookie's cap, your headband.
    if (look == Look.cap) {
      blob(
        Path()
          ..moveTo(14, 38)
          ..quadraticBezierTo(16, 8, 50, 8)
          ..quadraticBezierTo(84, 8, 86, 38)
          ..close(),
        Toon.blue,
      );
      blob(RRectPath.of(const Rect.fromLTWH(46, 30, 46, 10), 5), Toon.blue);
    }
    if (look == Look.headband) {
      blob(RRectPath.of(const Rect.fromLTWH(12, 24, 76, 12), 6), Toon.red);
    }
  }

  @override
  bool shouldRepaint(_FacePainter old) => old.p != p;
}

abstract final class RRectPath {
  static Path of(Rect r, double radius) =>
      Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));
}
