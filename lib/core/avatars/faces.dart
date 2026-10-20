import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/toon.dart';

/// A bot's personality look (poker maps it to a play style). Your own face
/// is an [Avatar] you build in the profile.
enum Look { headband, cap, shades, fin, spiky }

/// Face colours. The first [Avatar.choices] are yours to pick; the rest are
/// the bots' (unlocks later).
enum AvatarColor {
  sun(Toon.yellow),
  mint(Color(0xFF8DE4B5)),
  lilac(Color(0xFFC9B6FF)),
  tan(Color(0xFFC68B59)),
  peach(Color(0xFFFFB38A)),
  stone(Color(0xFFB8B3A8)),
  sky(Color(0xFF7FB8E8)),
  pink(Color(0xFFFF9EC4));

  const AvatarColor(this.color);

  final Color color;
}

enum HeadShape { round, square, egg, wide }

enum Expression { smile, grin, cool, wild, freckles }

enum Hat { headband, cap, crown, none, fin, spiky }

/// A face put together from parts: colour, head shape, expression, hat.
@immutable
class Avatar {
  const Avatar({
    this.color = AvatarColor.sun,
    this.shape = HeadShape.round,
    this.face = Expression.smile,
    this.hat = Hat.headband,
  });

  /// How many of each part you can pick (the rest unlock later).
  static const choices = 4;

  final AvatarColor color;
  final HeadShape shape;
  final Expression face;
  final Hat hat;

  Avatar copyWith({AvatarColor? color, HeadShape? shape, Expression? face, Hat? hat}) => Avatar(
    color: color ?? this.color,
    shape: shape ?? this.shape,
    face: face ?? this.face,
    hat: hat ?? this.hat,
  );

  Map<String, String> toJson() => {
    'color': color.name,
    'shape': shape.name,
    'face': face.name,
    'hat': hat.name,
  };

  static Avatar fromJson(Map<String, dynamic> j) => Avatar(
    color: AvatarColor.values.asNameMap()[j['color']] ?? AvatarColor.sun,
    shape: HeadShape.values.asNameMap()[j['shape']] ?? HeadShape.round,
    face: Expression.values.asNameMap()[j['face']] ?? Expression.smile,
    hat: Hat.values.asNameMap()[j['hat']] ?? Hat.headband,
  );

  @override
  bool operator ==(Object other) =>
      other is Avatar &&
      other.color == color &&
      other.shape == shape &&
      other.face == face &&
      other.hat == hat;

  @override
  int get hashCode => Object.hash(color, shape, face, hat);

  @override
  String toString() => 'Avatar(${color.name}, ${shape.name}, ${face.name}, ${hat.name})';
}

/// Who sits in a seat: a name and a face.
class Persona {
  const Persona({required this.name, required this.look, required this.avatar});

  const Persona.you({this.name = 'You', this.avatar = const Avatar()}) : look = Look.headband;

  final String name;
  final Look look;
  final Avatar avatar;

  Color get skin => avatar.color.color;

  static const _faces = {
    Look.cap: Avatar(color: AvatarColor.peach, face: Expression.freckles, hat: Hat.cap),
    Look.shades: Avatar(color: AvatarColor.stone, face: Expression.cool, hat: Hat.none),
    Look.fin: Avatar(color: AvatarColor.sky, face: Expression.grin, hat: Hat.fin),
    Look.spiky: Avatar(color: AvatarColor.pink, face: Expression.wild, hat: Hat.spiky),
  };

  /// A bot by its look (online: the server keeps the name and look).
  factory Persona.bot(String name, Look look) =>
      Persona(name: name, look: look, avatar: _faces[look] ?? _faces[Look.cap]!);

  /// The bot looks, in the order games map them to personalities (poker:
  /// cap = Rookie, shades = Rock, fin = Shark, spiky = Maniac).
  static const botLooks = [Look.cap, Look.shades, Look.fin, Look.spiky];

  /// Names bots are given at random.
  static const botNames = [
    'Pip', 'Bean', 'Tad', 'Dot', 'Boulder', 'Slate', 'Rocky', 'Flint', //
    'Finn', 'Reef', 'Marlin', 'Gill', 'Blaze', 'Zap', 'Turbo', 'Bonkers', //
    'Ace', 'Biscuit', 'Bingo', 'Blossom', 'Bramble', 'Buster', 'Button', 'Cactus', //
    'Clover', 'Cocoa', 'Comet', 'Cosmo', 'Crumpet', 'Dash', 'Dizzy', 'Domino', //
    'Dusty', 'Echo', 'Ember', 'Fizz', 'Flapjack', 'Fudge', 'Gizmo', 'Goose', //
    'Gumbo', 'Hazel', 'Honey', 'Iggy', 'Indigo', 'Jazz', 'Jellybean', 'Jinx', //
    'Juniper', 'Kiwi', 'Koko', 'Lark', 'Lemon', 'Lolly', 'Lucky', 'Mango', //
    'Maple', 'Marbles', 'Mochi', 'Moxie', 'Muffin', 'Nacho', 'Nugget', 'Noodle', //
    'Olive', 'Onyx', 'Otto', 'Pebble', 'Pepper', 'Pickle', 'Pixel', 'Plum', //
    'Pogo', 'Popcorn', 'Pretzel', 'Puddle', 'Quill', 'Rascal', 'Razzle', 'Ripley', //
    'Rosie', 'Rusty', 'Saffron', 'Sage', 'Scout', 'Shadow', 'Skipper', 'Smudge', //
    'Sprout', 'Sparky', 'Squid', 'Sunny', 'Taffy', 'Tango', 'Tinsel', 'Toffee', //
    'Trixie', 'Truffle', 'Tumble', 'Twiggy', 'Velvet', 'Waffles', 'Whisper', 'Widget', //
    'Willow', 'Wobble', 'Yeti', 'Yoyo', 'Ziggy', 'Zinnia', 'Zest', 'Bubbles', //
    'Chip', 'Duke', 'Lady Luck', 'Mittens', 'Sly', 'Snapper', 'Doc', 'Lulu', //
  ];

  /// [count] bots with random names and faces, no name twice. Each also
  /// gets a look (a hidden personality some games use), mixed round.
  static List<Persona> bots(int count, Random rng) {
    final looks = [...botLooks]..shuffle(rng);
    final names = [...botNames]..shuffle(rng);
    const hats = [Hat.cap, Hat.none, Hat.fin, Hat.spiky, Hat.headband];
    return [
      for (var i = 0; i < count; i++)
        Persona(
          name: names[i],
          look: looks[i % looks.length],
          avatar: Avatar(
            color: AvatarColor.values[rng.nextInt(AvatarColor.values.length)],
            shape: HeadShape.values[rng.nextInt(HeadShape.values.length)],
            face: Expression.values[rng.nextInt(Expression.values.length)],
            hat: hats[rng.nextInt(hats.length)],
          ),
        ),
    ];
  }
}

/// One part of a face, for the face builder.
enum FacePart { color, shape, face, hat }

/// A cartoon face, drawn from its [Avatar] parts.
class Face extends StatelessWidget {
  Face(Persona persona, {super.key, required this.size}) : avatar = persona.avatar, only = null;

  const Face.of(this.avatar, {super.key, required this.size}) : only = null;

  /// Just one part of [avatar] (a colour swatch, a bare head, the eyes and
  /// mouth, or the hat), centred.
  const Face.part(this.avatar, FacePart part, {super.key, required this.size}) : only = part;

  final Avatar avatar;
  final double size;
  final FacePart? only;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _FacePainter(avatar, only));
}

class _FacePainter extends CustomPainter {
  _FacePainter(this.a, [this.only]);

  final Avatar a;
  final FacePart? only;

  static Rect _head(HeadShape shape) => switch (shape) {
    HeadShape.round => const Rect.fromLTWH(10, 14, 80, 80),
    HeadShape.square => const Rect.fromLTWH(12, 17, 76, 76),
    HeadShape.egg => const Rect.fromLTWH(17, 11, 66, 87),
    HeadShape.wide => const Rect.fromLTWH(3, 22, 94, 72),
  };

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

    final h = _head(a.shape);
    final top = h.top;
    final all = only == null;

    switch (only) {
      case FacePart.color:
        blob(Path()..addOval(const Rect.fromLTWH(14, 14, 72, 72)), a.color.color);
        return;
      case FacePart.face:
        canvas.translate(0, -14); // eyes and mouth, centred
      case FacePart.hat:
        canvas
          ..translate(50, 50) // the hat, centred and a bit bigger
          ..scale(1.3)
          ..translate(-50, -(top + 6));
      case FacePart.shape || null:
        break;
    }

    // Behind the head: a shark's fin, wild spiky hair.
    if (a.hat == Hat.fin && (all || only == FacePart.hat)) {
      blob(
        Path()
          ..moveTo(38, top + 8)
          ..quadraticBezierTo(52, top - 14, 70, top - 10)
          ..quadraticBezierTo(60, top, 62, top + 12)
          ..close(),
        const Color(0xFF5E9BD1),
      );
    }
    if (a.hat == Hat.spiky && (all || only == FacePart.hat)) {
      double x(num v) => h.left + (v - 10) / 80 * h.width;
      final hair = Path()..moveTo(x(14), top + 30);
      const spikes = [(18, -6), (34, 16), (42, -12), (54, 14), (66, -10), (72, 16), (88, -2), (86, 30)];
      for (final (sx, sy) in spikes) {
        hair.lineTo(x(sx), top + sy);
      }
      hair.close();
      blob(hair, Toon.orange);
    }

    // Head.
    if (all || only == FacePart.shape) {
      blob(switch (a.shape) {
        HeadShape.square => RRectPath.of(h, 22),
        _ => Path()..addOval(h),
      }, a.color.color);
    }
    if (only == FacePart.shape) return;

    // Eyes.
    if (all || only == FacePart.face) _features(canvas, ink, inkFill, blob);

    // On top: the hat.
    if (all || only == FacePart.hat) _hat(canvas, h, blob);
  }

  void _features(Canvas canvas, Paint ink, Paint inkFill, void Function(Path, Color) blob) {
    switch (a.face) {
      case Expression.cool:
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
      case Expression.wild:
        for (final x in [34.0, 66.0]) {
          blob(Path()..addOval(Rect.fromCircle(center: Offset(x, 46), radius: 11)), Colors.white);
          canvas.drawCircle(Offset(x + 2, 47), 4, inkFill);
        }
      case Expression.smile || Expression.grin || Expression.freckles:
        for (final x in [36.0, 64.0]) {
          blob(Path()..addOval(Rect.fromCenter(center: Offset(x, 46), width: 16, height: 20)), Colors.white);
          canvas.drawCircle(Offset(x + 1, 48), 5, inkFill);
          canvas.drawCircle(Offset(x + 3, 45), 1.6, Paint()..color = Colors.white);
        }
    }

    // Mouth.
    switch (a.face) {
      case Expression.smile:
        canvas.drawArc(const Rect.fromLTWH(32, 54, 36, 24), 0.2, pi - 0.4, false, ink);
      case Expression.freckles:
        canvas.drawArc(const Rect.fromLTWH(34, 56, 32, 22), 0.3, pi - 0.6, false, ink);
        final freckle = Paint()..color = const Color(0xFFD9785A);
        for (final o in const [Offset(24, 62), Offset(29, 66), Offset(71, 62), Offset(76, 66)]) {
          canvas.drawCircle(o, 2.2, freckle);
        }
      case Expression.cool:
        canvas.drawLine(const Offset(38, 72), const Offset(62, 70), ink);
      case Expression.grin:
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
      case Expression.wild:
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
  }

  void _hat(Canvas canvas, Rect h, void Function(Path, Color) blob) {
    final top = h.top;
    switch (a.hat) {
      case Hat.cap:
        blob(
          Path()
            ..moveTo(h.left + 4, top + 24)
            ..quadraticBezierTo(h.left + 6, top - 6, 50, top - 6)
            ..quadraticBezierTo(h.right - 6, top - 6, h.right - 4, top + 24)
            ..close(),
          Toon.blue,
        );
        blob(RRectPath.of(Rect.fromLTWH(46, top + 16, 46, 10), 5), Toon.blue);
      case Hat.headband:
        blob(RRectPath.of(Rect.fromLTWH(h.left + 2, top + 10, h.width - 4, 12), 6), Toon.red);
      case Hat.crown:
        final b = top + 12;
        blob(
          Path()
            ..moveTo(28, b)
            ..lineTo(26, top - 8)
            ..lineTo(39, top + 2)
            ..lineTo(50, top - 12)
            ..lineTo(61, top + 2)
            ..lineTo(74, top - 8)
            ..lineTo(72, b)
            ..close(),
          const Color(0xFFFFD34D),
        );
        canvas.drawCircle(Offset(50, top + 4), 4, Paint()..color = Toon.red);
      case Hat.none || Hat.fin || Hat.spiky:
        break;
    }
  }

  @override
  bool shouldRepaint(_FacePainter old) => old.a != a || old.only != only || old._dark != Toon.dark;

  final _dark = Toon.dark;
}

abstract final class RRectPath {
  static Path of(Rect r, double radius) =>
      Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));
}
