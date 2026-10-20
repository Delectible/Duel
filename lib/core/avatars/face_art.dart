part of 'faces.dart';

/// Draws an [Avatar] in a 100 x 100 box: thick ink outlines like the rest
/// of the app, with soft shading and highlights. The face is fitted so the
/// tallest hat and the widest head stay inside the box.
class FacePainter extends CustomPainter {
  FacePainter(this.a, [this.only]);

  final Avatar a;
  final FacePart? only;
  final _dark = Toon.dark;

  static const _hair = {
    Hat.tuft: Color(0xFF7A4A2A),
    Hat.bob: Color(0xFF8A5530),
    Hat.afro: Color(0xFF3D2A20),
    Hat.mohawk: Color(0xFFE0457B),
    Hat.bun: Color(0xFF34282A),
    Hat.spiky: Toon.orange,
  };
  static const _brown = Color(0xFF6A4228);
  static const _gold = Color(0xFFFFD34D);
  static const _tongue = Color(0xFFFF7A8A);
  static const _mouthIn = Color(0xFF8E2F3C);

  /// How far each hat reaches above the head.
  static double _rise(Hat h) => switch (h) {
    Hat.bunny => 40,
    Hat.wizard => 34,
    Hat.party => 32,
    Hat.topHat => 30,
    Hat.chef => 26,
    Hat.propeller => 24,
    Hat.mohawk => 20,
    Hat.bun || Hat.beanie || Hat.viking || Hat.afro => 18,
    Hat.cowboy || Hat.halo || Hat.cat || Hat.fin => 16,
    Hat.crown || Hat.tuft || Hat.spiky || Hat.pirate => 14,
    Hat.horns || Hat.bow || Hat.flower => 10,
    _ => 6,
  };

  /// Half the drawing's width: the head and ears, or a wide hat.
  double get _halfWidth {
    final head = h.width / 2 + 8;
    return switch (a.hat) {
      Hat.afro => h.width / 2 + 20,
      Hat.cowboy || Hat.viking => h.width / 2 + 12,
      Hat.headband || Hat.bandana || Hat.pirate => h.width / 2 + 9,
      _ => head,
    };
  }

  static Rect _head(HeadShape shape) => switch (shape) {
    HeadShape.round => const Rect.fromLTWH(10, 14, 80, 80),
    HeadShape.square => const Rect.fromLTWH(12, 17, 76, 76),
    HeadShape.egg => const Rect.fromLTWH(17, 10, 66, 88),
    HeadShape.wide => const Rect.fromLTWH(4, 22, 92, 72),
    HeadShape.pear => const Rect.fromLTWH(10, 14, 80, 82),
    HeadShape.tall => const Rect.fromLTWH(18, 8, 64, 88),
  };

  static Path _headPath(HeadShape shape) {
    final h = _head(shape);
    return switch (shape) {
      HeadShape.square => RRectPath.of(h, 24),
      HeadShape.tall => RRectPath.of(h, 30),
      HeadShape.pear =>
        Path()
          ..moveTo(50, h.top)
          ..cubicTo(70, h.top, 76, 34, 85, 60)
          ..cubicTo(92, 84, 74, h.bottom, 50, h.bottom)
          ..cubicTo(26, h.bottom, 8, 84, 15, 60)
          ..cubicTo(24, 34, 30, h.top, 50, h.top)
          ..close(),
      _ => Path()..addOval(h),
    };
  }

  late final Rect h = _head(a.shape);
  late final Color skin = a.color.color;
  late final Color shade = Color.lerp(skin, const Color(0xFF3A2030), 0.18)!;
  late Canvas c;

  Paint get _ink => Paint()
    ..color = Toon.ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.5
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint _line(double w, [Color? color]) => _ink
    ..strokeWidth = w
    ..color = color ?? Toon.ink;

  Paint _fill(Color color) => Paint()..color = color;

  /// A filled, outlined shape.
  void blob(Path p, Color color, {double width = 4.5}) {
    c.drawPath(p, _fill(color));
    c.drawPath(p, _line(width));
  }

  /// A filled shape lit from the top left: a darker rim bottom right and a
  /// soft highlight.
  void shaded(Path p, Color color, {double width = 4.5, bool shine = true}) {
    final b = p.getBounds();
    c
      ..save()
      ..clipPath(p)
      ..drawPath(p, _fill(Color.lerp(color, const Color(0xFF2A1830), 0.2)!))
      ..drawPath(p.shift(Offset(-b.width * 0.06, -b.height * 0.08)), _fill(color));
    if (shine && b.width > 10) {
      c.drawOval(
        Rect.fromLTWH(b.left + b.width * 0.16, b.top + b.height * 0.1, b.width * 0.24, b.height * 0.14),
        _fill(Colors.white.withValues(alpha: 0.32)),
      );
    }
    c
      ..restore()
      ..drawPath(p, _line(width));
  }

  Path _oval(Offset center, double w, double hgt) =>
      Path()..addOval(Rect.fromCenter(center: center, width: w, height: hgt));

  Path _union(Iterable<Path> paths) => paths.reduce((x, y) => Path.combine(PathOperation.union, x, y));

  @override
  void paint(Canvas canvas, Size size) {
    c = canvas;
    c.scale(size.width / 100);
    switch (only) {
      case FacePart.color:
        shaded(_oval(const Offset(50, 50), 72, 72), skin);
        return;
      case FacePart.hat:
        if (a.hat == Hat.none) return;
        _fit(h.top - _rise(a.hat), h.top + 26, zoom: 1.4);
        _hatBehind();
        _hatFront();
        return;
      case FacePart.eyes:
        _zoom(const Offset(50, 46), 1.9);
      case FacePart.nose:
        _zoom(const Offset(50, 57), 2.4);
      case FacePart.mouth:
        _zoom(const Offset(50, 69), 2);
      case FacePart.shape || FacePart.extra || null:
        final bottom = a.extra == Extra.beard ? h.bottom + 6 : h.bottom;
        _fit(h.top - (only == FacePart.shape ? 0 : _rise(a.hat)), bottom);
    }
    final face = only != FacePart.shape;
    if (face) _hatBehind();
    _ears();
    shaded(_headPath(a.shape), skin);
    if (!face) return;
    _extraUnder();
    if (a.extra != Extra.shades) _eyes();
    _nose();
    _mouth();
    _extraOver();
    _hatFront();
  }

  /// Fits the band [top]..[bottom] into the box (centred, never larger
  /// than [zoom]).
  void _fit(double top, double bottom, {double zoom = 0.92}) {
    final s = min(min(zoom, 94 / (bottom - top)), 47 / _halfWidth);
    final y = 3 + (94 - (bottom - top) * s) / 2;
    c
      ..translate(50, y)
      ..scale(s)
      ..translate(-50, -top);
  }

  /// A close-up around [at], clipped to the box.
  void _zoom(Offset at, double s) {
    c
      ..clipRect(const Rect.fromLTWH(0, 0, 100, 100))
      ..translate(50, 50)
      ..scale(s)
      ..translate(-at.dx, -at.dy);
  }

  // --- Head ------------------------------------------------------------------

  double get _earY => h.center.dy + 4;

  ({double left, double right}) get _earX => switch (a.shape) {
    HeadShape.egg => (left: h.left + 3, right: h.right - 3),
    HeadShape.tall => (left: h.left + 1, right: h.right - 1),
    HeadShape.pear => (left: 14, right: 86),
    _ => (left: h.left + 2, right: h.right - 2),
  };

  void _ears() {
    if (a.hat == Hat.headphones) return; // under the cups
    for (final x in [_earX.left, _earX.right]) {
      shaded(_oval(Offset(x, _earY), 15, 19), skin, shine: false);
      final inner = x < 50 ? x + 1 : x - 1;
      c.drawArc(
        Rect.fromCenter(center: Offset(inner, _earY), width: 7, height: 10),
        -pi / 2,
        pi,
        false,
        _line(2.5, shade),
      );
    }
  }

  // --- Eyes ------------------------------------------------------------------

  static const _l = Offset(36, 47), _r = Offset(64, 47);

  void _roundEye(
    Offset e, {
    double w = 16,
    double hg = 20,
    Offset look = const Offset(1, 2),
    double pupil = 5,
  }) {
    blob(_oval(e, w, hg), Colors.white, width: 3.5);
    c
      ..drawCircle(e + look, pupil, _fill(Toon.inkLight))
      ..drawCircle(e + look + const Offset(2, -2.4), pupil * 0.34, _fill(Colors.white));
  }

  void _closed(Offset e, {bool up = false}) {
    c.drawPath(
      Path()
        ..moveTo(e.dx - 7, e.dy + (up ? 3 : 0))
        ..quadraticBezierTo(e.dx, e.dy + (up ? -7 : 7), e.dx + 7, e.dy + (up ? 3 : 0)),
      _line(4),
    );
  }

  void _brows({required bool angry}) {
    for (final (e, side) in [(_l, -1.0), (_r, 1.0)]) {
      final outer = Offset(e.dx + side * 9, e.dy - (angry ? 17 : 13));
      final inner = Offset(e.dx - side * 5, e.dy - (angry ? 12 : 18));
      c.drawLine(outer, inner, _line(4.5));
    }
  }

  Path _heart(Offset at, double s) => Path()
    ..moveTo(at.dx, at.dy + s * 0.45)
    ..cubicTo(at.dx - s * 0.95, at.dy - s * 0.1, at.dx - s * 0.45, at.dy - s * 0.8, at.dx, at.dy - s * 0.25)
    ..cubicTo(at.dx + s * 0.45, at.dy - s * 0.8, at.dx + s * 0.95, at.dy - s * 0.1, at.dx, at.dy + s * 0.45)
    ..close();

  void _eyes() {
    for (final (k, e) in [_l, _r].indexed) {
      switch (a.eyes) {
        case Eyes.round || Eyes.angry || Eyes.worried:
          _roundEye(e, pupil: a.eyes == Eyes.round ? 5 : 4.4);
        case Eyes.dots:
          c
            ..drawOval(Rect.fromCenter(center: e, width: 7, height: 10), _fill(Toon.inkLight))
            ..drawCircle(e + const Offset(1.2, -2), 1.3, _fill(Colors.white));
        case Eyes.happy:
          _closed(e, up: true);
        case Eyes.sleepy:
          _roundEye(e + const Offset(0, 2), w: 16, hg: 15, look: const Offset(1, 3), pupil: 4.2);
          c
            ..save()
            ..clipPath(_oval(e + const Offset(0, 2), 16, 15))
            ..drawRect(Rect.fromLTWH(e.dx - 9, e.dy - 7, 18, 8.5), _fill(shade))
            ..restore()
            ..drawLine(e + const Offset(-8, 1.5), e + const Offset(8, 1.5), _line(3.5));
        case Eyes.wide:
          blob(_oval(e, 22, 22), Colors.white, width: 3.5);
          c.drawCircle(e + const Offset(2, 1), 4, _fill(Toon.inkLight));
        case Eyes.wink:
          if (k == 0) {
            _roundEye(e);
          } else {
            _closed(e, up: true);
          }
        case Eyes.shiny:
          blob(_oval(e, 18, 22), Colors.white, width: 3.5);
          c
            ..drawOval(
              Rect.fromCenter(center: e + const Offset(0.5, 2), width: 12, height: 15),
              _fill(Toon.inkLight),
            )
            ..drawCircle(e + const Offset(-1.5, -1.5), 3, _fill(Colors.white))
            ..drawCircle(e + const Offset(3, 5), 1.5, _fill(Colors.white));
        case Eyes.side:
          _roundEye(e, w: 18, hg: 16, look: const Offset(-4, 1));
        case Eyes.big:
          c
            ..drawOval(Rect.fromCenter(center: e, width: 15, height: 19), _fill(Toon.inkLight))
            ..drawCircle(e + const Offset(-2.5, -3.5), 3, _fill(Colors.white))
            ..drawCircle(e + const Offset(3, 3.5), 1.5, _fill(Colors.white));
        case Eyes.closed:
          _closed(e);
        case Eyes.hearts:
          blob(_heart(e, 17), Toon.red, width: 3);
          c.drawCircle(e + const Offset(-3, -3), 1.8, _fill(Colors.white.withValues(alpha: 0.7)));
        case Eyes.dizzy:
          c
            ..drawLine(e + const Offset(-6, -6), e + const Offset(6, 6), _line(4))
            ..drawLine(e + const Offset(6, -6), e + const Offset(-6, 6), _line(4));
      }
    }
    if (a.eyes == Eyes.angry) _brows(angry: true);
    if (a.eyes == Eyes.worried) _brows(angry: false);
  }

  // --- Nose ------------------------------------------------------------------

  void _nose() {
    const n = Offset(50, 58);
    switch (a.nose) {
      case Nose.none:
        break;
      case Nose.button:
        c.drawArc(Rect.fromCenter(center: n, width: 10, height: 8), 0.2, pi - 0.4, false, _line(3.2, shade));
      case Nose.dots:
        c
          ..drawCircle(n + const Offset(-3, 1), 1.7, _fill(Toon.inkLight))
          ..drawCircle(n + const Offset(3, 1), 1.7, _fill(Toon.inkLight));
      case Nose.round:
        shaded(_oval(n, 13, 11), Color.lerp(skin, Toon.red, 0.18)!, width: 3);
      case Nose.clown:
        shaded(_oval(n, 15, 14), Toon.red, width: 3);
      case Nose.pointy:
        c.drawPath(
          Path()
            ..moveTo(49, 49)
            ..quadraticBezierTo(57, 58, 52, 61),
          _line(3.4),
        );
      case Nose.piggy:
        blob(_oval(n, 16, 11), const Color(0xFFFFA3B8), width: 3);
        c
          ..drawOval(Rect.fromCenter(center: n + const Offset(-3, 0), width: 3, height: 4.5), _fill(_mouthIn))
          ..drawOval(Rect.fromCenter(center: n + const Offset(3, 0), width: 3, height: 4.5), _fill(_mouthIn));
    }
  }

  // --- Mouth -----------------------------------------------------------------

  void _mouth() {
    switch (a.mouth) {
      case Mouth.smile:
        c.drawArc(const Rect.fromLTWH(34, 56, 32, 22), 0.25, pi - 0.5, false, _line(4.5));
      case Mouth.small:
        c.drawArc(const Rect.fromLTWH(42, 62, 16, 12), 0.3, pi - 0.6, false, _line(4));
      case Mouth.flat:
        c.drawLine(const Offset(40, 70), const Offset(60, 69), _line(4.5));
      case Mouth.smirk:
        c.drawPath(
          Path()
            ..moveTo(39, 70)
            ..quadraticBezierTo(53, 74, 63, 64),
          _line(4.5),
        );
      case Mouth.frown:
        c.drawArc(const Rect.fromLTWH(37, 67, 26, 16), pi + 0.35, pi - 0.7, false, _line(4.5));
      case Mouth.grin:
        final grin = Path()
          ..moveTo(30, 63)
          ..quadraticBezierTo(50, 88, 70, 63)
          ..close();
        blob(grin, Colors.white);
        c
          ..save()
          ..clipPath(grin);
        for (var x = 37.0; x < 66; x += 7) {
          c.drawLine(Offset(x, 62), Offset(x, 80), _line(2.2));
        }
        c
          ..drawLine(const Offset(30, 69), const Offset(70, 69), _line(2.2))
          ..restore();
      case Mouth.open:
        final m = Path()
          ..moveTo(31, 62)
          ..quadraticBezierTo(50, 92, 69, 62)
          ..close();
        blob(m, _mouthIn);
        c
          ..save()
          ..clipPath(m)
          ..drawOval(const Rect.fromLTWH(40, 72, 20, 12), _fill(_tongue))
          ..restore();
      case Mouth.laugh:
        final m = Path()
          ..moveTo(32, 62)
          ..lineTo(68, 62)
          ..quadraticBezierTo(68, 86, 50, 86)
          ..quadraticBezierTo(32, 86, 32, 62)
          ..close();
        blob(m, _mouthIn);
        c
          ..save()
          ..clipPath(m)
          ..drawRect(const Rect.fromLTWH(30, 60, 40, 7), _fill(Colors.white))
          ..drawOval(const Rect.fromLTWH(40, 76, 20, 14), _fill(_tongue))
          ..restore()
          ..drawPath(m, _line(4.5));
      case Mouth.tongue:
        final t = Path()
          ..moveTo(46, 70)
          ..lineTo(46, 76)
          ..quadraticBezierTo(51, 84, 56, 76)
          ..lineTo(56, 70)
          ..close();
        blob(t, _tongue, width: 3);
        c
          ..drawLine(const Offset(51, 71), const Offset(51, 77), _line(1.8, _mouthIn))
          ..drawArc(const Rect.fromLTWH(34, 56, 32, 18), 0.25, pi - 0.5, false, _line(4.5));
      case Mouth.oh:
        blob(_oval(const Offset(50, 70), 11, 14), _mouthIn, width: 3.5);
      case Mouth.fangs:
        for (final x in [42.0, 58.0]) {
          blob(
            Path()
              ..moveTo(x - 3, 70)
              ..lineTo(x + 3, 70)
              ..lineTo(x, 78)
              ..close(),
            Colors.white,
            width: 2,
          );
        }
        c.drawPath(
          Path()
            ..moveTo(34, 66)
            ..quadraticBezierTo(50, 76, 66, 66),
          _line(4.5),
        );
      case Mouth.buck:
        for (final x in [44.5, 50.0]) {
          blob(RRectPath.of(Rect.fromLTWH(x, 69, 5.5, 7), 1.5), Colors.white, width: 2);
        }
        c.drawPath(
          Path()
            ..moveTo(36, 66)
            ..quadraticBezierTo(50, 74, 64, 66),
          _line(4.5),
        );
      case Mouth.wavy:
        final w = Path()..moveTo(37, 70);
        for (var i = 0; i < 4; i++) {
          w.quadraticBezierTo(40 + i * 6.5, i.isEven ? 65 : 75, 43.5 + i * 6.5, 70);
        }
        c.drawPath(w, _line(4));
      case Mouth.whistle:
        blob(_oval(const Offset(55, 69), 9, 9), _mouthIn, width: 3.5);
        for (final (x, y) in [(66.0, 62.0), (72.0, 56.0)]) {
          c.drawCircle(Offset(x, y), 1.8, _fill(Toon.inkLight));
        }
    }
  }

  // --- Extras ----------------------------------------------------------------

  void _extraUnder() {
    switch (a.extra) {
      case Extra.freckles:
        for (final o in const [
          Offset(24, 60),
          Offset(29, 65),
          Offset(23, 66),
          Offset(71, 65),
          Offset(76, 60),
          Offset(77, 66),
        ]) {
          c.drawCircle(o, 1.9, _fill(const Color(0xFFC9694A)));
        }
      case Extra.blush || Extra.star || Extra.tear:
        for (final x in [25.0, 75.0]) {
          c.drawOval(
            Rect.fromCenter(center: Offset(x, 63), width: 14, height: 8),
            _fill(Toon.red.withValues(alpha: 0.35)),
          );
        }
      case Extra.beard:
        final l = h.left + 5, r = h.right - 5, b = h.bottom + 5;
        final beard = Path()
          ..moveTo(l, 54)
          ..quadraticBezierTo(l + 2, b - 4, 50, b)
          ..quadraticBezierTo(r - 2, b - 4, r, 54)
          ..quadraticBezierTo(r - 4, 64, 64, 62)
          ..quadraticBezierTo(50, 56, 36, 62)
          ..quadraticBezierTo(l + 4, 64, l, 54)
          ..close();
        shaded(beard, _brown, shine: false);
      case Extra.goatee:
        shaded(
          Path()
            ..moveTo(43, 77)
            ..quadraticBezierTo(50, 74, 57, 77)
            ..quadraticBezierTo(56, 89, 50, 92)
            ..quadraticBezierTo(44, 89, 43, 77)
            ..close(),
          _brown,
          width: 3.5,
          shine: false,
        );
      case Extra.scar:
        const from = Offset(70, 53), to = Offset(78, 70);
        c.drawLine(from, to, _line(2.6, const Color(0xFFB4505A)));
        for (var t = 0.2; t < 1; t += 0.3) {
          final p = Offset.lerp(from, to, t)!;
          c.drawLine(
            p + const Offset(-3.5, 1.5),
            p + const Offset(3.5, -1.5),
            _line(2, const Color(0xFFB4505A)),
          );
        }
      default:
    }
  }

  void _extraOver() {
    switch (a.extra) {
      case Extra.shades:
        final glasses = Path()
          ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(20, 39, 26, 17), const Radius.circular(7)))
          ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(54, 39, 26, 17), const Radius.circular(7)));
        blob(glasses, const Color(0xFF22232E), width: 3.5);
        c
          ..drawLine(const Offset(46, 45), const Offset(54, 45), _line(3.5))
          ..drawLine(
            const Offset(25, 43),
            const Offset(31, 43),
            _line(2.6, Colors.white.withValues(alpha: 0.6)),
          )
          ..drawLine(
            const Offset(59, 43),
            const Offset(65, 43),
            _line(2.6, Colors.white.withValues(alpha: 0.6)),
          );
      case Extra.glasses:
        for (final e in [_l, _r]) {
          c
            ..drawCircle(e, 11.5, _fill(Colors.white.withValues(alpha: 0.18)))
            ..drawCircle(e, 11.5, _line(3.2));
        }
        c.drawLine(const Offset(46, 46), const Offset(54, 46), _line(3.2));
      case Extra.monocle:
        c
          ..drawCircle(_r, 12, _fill(Colors.white.withValues(alpha: 0.2)))
          ..drawCircle(_r, 12, _line(5.5))
          ..drawCircle(_r, 12, _line(2.5, _gold))
          ..drawPath(
            Path()
              ..moveTo(_r.dx + 9, _r.dy + 8)
              ..quadraticBezierTo(80, 72, 74, 88),
            _line(1.6, _gold),
          );
      case Extra.eyepatch:
        c.drawLine(Offset(h.left + 4, 36), Offset(h.right - 4, 30), _line(3));
        blob(_oval(_l + const Offset(0, 1), 22, 20), const Color(0xFF22232E), width: 3);
      case Extra.mustache:
        final m = Path()
          ..moveTo(50, 62)
          ..cubicTo(44, 57, 33, 58, 30, 66)
          ..cubicTo(37, 69, 45, 68, 50, 64)
          ..cubicTo(55, 68, 63, 69, 70, 66)
          ..cubicTo(67, 58, 56, 57, 50, 62)
          ..close();
        shaded(m, _brown, width: 3, shine: false);
      case Extra.bandage:
        c
          ..save()
          ..translate(72, 58)
          ..rotate(-0.55);
        blob(RRectPath.of(const Rect.fromLTWH(-10, -4, 20, 8), 4), const Color(0xFFF2D2AE), width: 2.5);
        c
          ..drawRect(const Rect.fromLTWH(-3.5, -4, 7, 8), _fill(const Color(0xFFE2B98F)))
          ..restore();
      case Extra.earrings:
        for (final x in [_earX.left, _earX.right]) {
          c
            ..drawCircle(Offset(x, _earY + 12), 4, _line(4.5))
            ..drawCircle(Offset(x, _earY + 12), 4, _line(2.2, _gold));
        }
      case Extra.tear:
        blob(
          Path()
            ..moveTo(69, 54)
            ..quadraticBezierTo(74, 62, 72, 65)
            ..quadraticBezierTo(69, 69, 66, 65)
            ..quadraticBezierTo(64, 62, 69, 54)
            ..close(),
          const Color(0xFF7FC8FF),
          width: 2.5,
        );
      case Extra.star:
        blob(_star(const Offset(76, 61), 7, 3.2), _gold, width: 2.5);
      default:
    }
  }

  Path _star(Offset at, double outer, double inner) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final t = -pi / 2 + i * pi / 5;
      final o = at + Offset(cos(t) * r, sin(t) * r);
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }

  // --- Hats and hair -----------------------------------------------------------

  double get t => h.top;

  /// What shows behind the head: back hair, ears and fins.
  void _hatBehind() {
    switch (a.hat) {
      case Hat.fin:
        shaded(
          Path()
            ..moveTo(36, t + 10)
            ..quadraticBezierTo(50, t - 16, 72, t - 12)
            ..quadraticBezierTo(60, t, 64, t + 14)
            ..close(),
          const Color(0xFF5E9BD1),
        );
      case Hat.spiky:
        double x(num v) => h.left + (v - 10) / 80 * h.width;
        final hair = Path()..moveTo(x(14), t + 30);
        const spikes = [(18, -6), (34, 16), (42, -12), (54, 14), (66, -10), (72, 16), (88, -2), (86, 30)];
        for (final (sx, sy) in spikes) {
          hair.lineTo(x(sx), t + sy);
        }
        shaded(hair..close(), _hair[Hat.spiky]!);
      case Hat.afro:
        final puffs = [
          for (var i = 0; i < 9; i++)
            () {
              final ang = pi + i * pi / 8;
              return _oval(Offset(50 + cos(ang) * (h.width / 2 + 4), t + 30 + sin(ang) * 38), 30, 30);
            }(),
          _oval(Offset(50, t + 22), h.width + 6, 50),
        ];
        shaded(_union(puffs), _hair[Hat.afro]!);
      case Hat.bob:
        shaded(
          RRectPath.of(Rect.fromLTRB(h.left - 4, t - 4, h.right + 4, h.center.dy + 22), 26),
          _hair[Hat.bob]!,
        );
      case Hat.bun:
        shaded(_oval(Offset(50, t - 7), 26, 24), _hair[Hat.bun]!);
      case Hat.mohawk:
        final m = Path()..moveTo(38, t + 12);
        const tips = [(40, -14), (46, 2), (50, -20), (54, 2), (60, -14)];
        for (final (x, y) in tips) {
          m.lineTo(x.toDouble(), t + y);
        }
        m
          ..lineTo(62, t + 12)
          ..close();
        shaded(m, _hair[Hat.mohawk]!);
      case Hat.bunny:
        for (final side in [-1.0, 1.0]) {
          c
            ..save()
            ..translate(50 + side * 13, t + 2)
            ..rotate(side * 0.18);
          shaded(_oval(const Offset(0, -18), 16, 44), Colors.white);
          c.drawOval(
            Rect.fromCenter(center: const Offset(0, -17), width: 7, height: 30),
            _fill(const Color(0xFFFFB3C6)),
          );
          c.restore();
        }
      case Hat.cat:
        for (final side in [-1.0, 1.0]) {
          double x(double v) => 50 + side * v;
          final ear = Path()
            ..moveTo(x(h.width / 2 - 8), t + 20)
            ..lineTo(x(h.width / 2 - 2), t - 14)
            ..lineTo(x(10), t + 6)
            ..close();
          shaded(ear, skin, shine: false);
          c.drawPath(
            Path()
              ..moveTo(x(h.width / 2 - 10), t + 14)
              ..lineTo(x(h.width / 2 - 5), t - 4)
              ..lineTo(x(16), t + 6)
              ..close(),
            _fill(const Color(0xFFFFB3C6)),
          );
        }
      default:
    }
  }

  void _hatFront() {
    switch (a.hat) {
      case Hat.headband:
        shaded(RRectPath.of(Rect.fromLTWH(h.left + 3, t + 10, h.width - 6, 12), 6), Toon.red, shine: false);
        blob(
          Path()
            ..moveTo(h.right - 6, t + 14)
            ..lineTo(h.right + 6, t + 6)
            ..lineTo(h.right + 4, t + 18)
            ..close(),
          Toon.red,
          width: 3,
        );
      case Hat.cap:
        shaded(
          Path()
            ..moveTo(h.left + 4, t + 22)
            ..quadraticBezierTo(h.left + 6, t - 8, 50, t - 8)
            ..quadraticBezierTo(h.right - 6, t - 8, h.right - 4, t + 22)
            ..close(),
          Toon.blue,
        );
        blob(RRectPath.of(Rect.fromLTWH(46, t + 14, 48, 10), 5), const Color(0xFF3A7FDB));
        c.drawCircle(Offset(50, t - 7), 3, _fill(Toon.inkLight));
      case Hat.crown:
        final b = t + 12;
        shaded(
          Path()
            ..moveTo(28, b)
            ..lineTo(26, t - 10)
            ..lineTo(39, t + 1)
            ..lineTo(50, t - 14)
            ..lineTo(61, t + 1)
            ..lineTo(74, t - 10)
            ..lineTo(72, b)
            ..close(),
          _gold,
        );
        blob(_oval(Offset(50, t + 4), 8, 8), Toon.red, width: 2.5);
        blob(_oval(Offset(36, t + 6), 5, 5), Toon.teal, width: 2);
        blob(_oval(Offset(64, t + 6), 5, 5), Toon.teal, width: 2);
      case Hat.tuft:
        shaded(
          Path()
            ..moveTo(44, t + 4)
            ..quadraticBezierTo(40, t - 14, 58, t - 12)
            ..quadraticBezierTo(48, t - 6, 56, t + 4)
            ..close(),
          _hair[Hat.tuft]!,
          width: 4,
        );
      case Hat.bob || Hat.bun || Hat.afro:
        final color = _hair[a.hat]!;
        final low = a.hat == Hat.bob ? t + h.height * 0.48 : t + h.height * 0.3;
        final fringe = Path()
          ..moveTo(h.left + 1, low)
          ..quadraticBezierTo(h.left - 1, t - 5, 50, t - 5)
          ..quadraticBezierTo(h.right + 1, t - 5, h.right - 1, low)
          ..quadraticBezierTo(h.right - 10, t + 14, 62, t + 17)
          ..quadraticBezierTo(50, t + 23, 38, t + 15)
          ..quadraticBezierTo(h.left + 10, t + 14, h.left + 1, low)
          ..close();
        shaded(fringe, color);
      case Hat.beanie:
        final cap = Path()
          ..moveTo(h.left + 2, t + 20)
          ..quadraticBezierTo(h.left + 2, t - 12, 50, t - 12)
          ..quadraticBezierTo(h.right - 2, t - 12, h.right - 2, t + 20)
          ..close();
        shaded(cap, Toon.teal);
        c
          ..save()
          ..clipPath(cap);
        for (var x = h.left + 8; x < h.right; x += 8) {
          c.drawLine(Offset(x, t - 14), Offset(x, t + 20), _line(1.6, const Color(0xFF1E9488)));
        }
        c.restore();
        shaded(
          RRectPath.of(Rect.fromLTWH(h.left, t + 12, h.width, 12), 6),
          const Color(0xFF1E9488),
          shine: false,
        );
        shaded(_oval(Offset(50, t - 14), 15, 15), Colors.white);
      case Hat.cowboy:
        const felt = Color(0xFFB0743E);
        shaded(
          Path()
            ..moveTo(32, t + 6)
            ..quadraticBezierTo(30, t - 18, 42, t - 16)
            ..quadraticBezierTo(50, t - 10, 58, t - 16)
            ..quadraticBezierTo(70, t - 18, 68, t + 6)
            ..close(),
          felt,
        );
        c.drawRect(Rect.fromLTWH(32, t - 2, 36, 6), _fill(const Color(0xFF6E4122)));
        shaded(
          Path()
            ..moveTo(h.left - 8, t - 2)
            ..quadraticBezierTo(50, t + 22, h.right + 8, t - 2)
            ..quadraticBezierTo(50, t + 12, h.left - 8, t - 2)
            ..close(),
          felt,
          shine: false,
        );
      case Hat.topHat:
        const black = Color(0xFF2D2A3A);
        shaded(RRectPath.of(Rect.fromLTWH(32, t - 28, 36, 34), 4), black);
        c.drawRect(Rect.fromLTWH(32, t - 2, 36, 6), _fill(Toon.red));
        c.drawRect(Rect.fromLTWH(32, t - 28, 36, 34), _line(4.5));
        shaded(RRectPath.of(Rect.fromLTWH(20, t + 4, 60, 8), 4), black, shine: false);
      case Hat.wizard:
        const purple = Color(0xFF6E52D9);
        shaded(
          Path()
            ..moveTo(28, t + 8)
            ..quadraticBezierTo(42, t - 12, 62, t - 34)
            ..quadraticBezierTo(58, t - 12, 72, t + 8)
            ..close(),
          purple,
        );
        shaded(_oval(Offset(50, t + 8), 66, 14), purple, shine: false);
        blob(_star(Offset(47, t - 4), 5, 2.2), _gold, width: 1.8);
        blob(_star(Offset(58, t - 18), 3.5, 1.6), _gold, width: 1.5);
      case Hat.party:
        final cone = Path()
          ..moveTo(36, t + 8)
          ..lineTo(50, t - 28)
          ..lineTo(64, t + 8)
          ..close();
        c
          ..save()
          ..clipPath(cone)
          ..drawPath(cone, _fill(Toon.purple));
        for (var y = t - 30; y < t + 10; y += 10) {
          c.drawPath(
            Path()
              ..moveTo(30, y + 6)
              ..lineTo(70, y - 2)
              ..lineTo(70, y + 3)
              ..lineTo(30, y + 11)
              ..close(),
            _fill(Toon.yellow),
          );
        }
        c
          ..restore()
          ..drawPath(cone, _line(4.5));
        shaded(_oval(Offset(50, t - 29), 11, 11), Toon.red);
      case Hat.chef:
        final puff = _union([
          _oval(Offset(37, t - 6), 26, 24),
          _oval(Offset(50, t - 13), 30, 28),
          _oval(Offset(63, t - 6), 26, 24),
          RRectPath.of(Rect.fromLTWH(31, t - 6, 38, 18), 3),
        ]);
        shaded(puff, Colors.white);
        c.drawLine(Offset(33, t + 4), Offset(67, t + 4), _line(2.5, Toon.grey));
      case Hat.bow:
        const pink = Color(0xFFFF6FA5);
        c
          ..save()
          ..translate(h.right - 16, t + 6)
          ..rotate(0.3);
        for (final side in [-1.0, 1.0]) {
          shaded(
            Path()
              ..moveTo(0, 0)
              ..lineTo(side * 14, -9)
              ..quadraticBezierTo(side * 18, 0, side * 14, 9)
              ..close(),
            pink,
            width: 3.5,
            shine: false,
          );
        }
        blob(_oval(Offset.zero, 9, 9), pink, width: 3);
        c.restore();
      case Hat.viking:
        const horn = Color(0xFFF2E6C9);
        for (final side in [-1.0, 1.0]) {
          double x(double v) => 50 + side * v;
          shaded(
            Path()
              ..moveTo(x(h.width / 2 - 8), t + 8)
              ..quadraticBezierTo(x(h.width / 2 + 10), t + 2, x(h.width / 2 + 6), t - 18)
              ..quadraticBezierTo(x(h.width / 2 + 2), t - 2, x(h.width / 2 - 14), t)
              ..close(),
            horn,
            width: 4,
            shine: false,
          );
        }
        final helmet = Path()
          ..moveTo(h.left + 4, t + 20)
          ..quadraticBezierTo(h.left + 4, t - 12, 50, t - 12)
          ..quadraticBezierTo(h.right - 4, t - 12, h.right - 4, t + 20)
          ..close();
        shaded(helmet, const Color(0xFFB9C3D1));
        shaded(
          RRectPath.of(Rect.fromLTWH(h.left + 2, t + 12, h.width - 4, 9), 4),
          const Color(0xFF8C97A8),
          shine: false,
        );
        for (var x = h.left + 12; x < h.right - 6; x += 12) {
          c.drawCircle(Offset(x, t + 16.5), 1.6, _fill(Toon.inkLight));
        }
      case Hat.flower:
        final at = Offset(h.right - 16, t + 6);
        for (var i = 0; i < 5; i++) {
          final ang = -pi / 2 + i * 2 * pi / 5;
          blob(_oval(at + Offset(cos(ang) * 7, sin(ang) * 7), 10, 10), const Color(0xFFFF9EC4), width: 2.5);
        }
        blob(_oval(at, 8, 8), _gold, width: 2.5);
      case Hat.propeller:
        final cap = Path()
          ..moveTo(h.left + 6, t + 16)
          ..quadraticBezierTo(h.left + 6, t - 10, 50, t - 10)
          ..quadraticBezierTo(h.right - 6, t - 10, h.right - 6, t + 16)
          ..close();
        c
          ..save()
          ..clipPath(cap);
        const colors = [Toon.red, Toon.yellow, Toon.blue, Toon.green];
        for (var i = 0; i < 4; i++) {
          c.drawRect(
            Rect.fromLTWH(h.left + i * h.width / 4, t - 12, h.width / 4 + 0.5, 30),
            _fill(colors[i]),
          );
        }
        c
          ..restore()
          ..drawPath(cap, _line(4.5))
          ..drawLine(Offset(50, t - 10), Offset(50, t - 20), _line(3.5));
        blob(_oval(Offset(41, t - 21), 18, 6), Toon.red, width: 2.5);
        blob(_oval(Offset(59, t - 21), 18, 6), Toon.blue, width: 2.5);
        blob(_oval(Offset(50, t - 21), 5, 5), _gold, width: 2);
      case Hat.headphones:
        c
          ..drawArc(Rect.fromLTRB(_earX.left, t - 6, _earX.right, _earY + 30), pi, pi, false, _line(10))
          ..drawArc(
            Rect.fromLTRB(_earX.left, t - 6, _earX.right, _earY + 30),
            pi,
            pi,
            false,
            _line(4.5, Toon.purple),
          );
        for (final x in [_earX.left, _earX.right]) {
          shaded(
            RRectPath.of(Rect.fromCenter(center: Offset(x, _earY), width: 15, height: 24), 7),
            Toon.purple,
          );
        }
      case Hat.halo:
        final ring = Rect.fromCenter(center: Offset(50, t - 9), width: 52, height: 13);
        c
          ..drawOval(ring, _line(9))
          ..drawOval(ring, _line(4.5, _gold));
      case Hat.horns:
        for (final side in [-1.0, 1.0]) {
          double x(double v) => 50 + side * v;
          shaded(
            Path()
              ..moveTo(x(12), t + 6)
              ..quadraticBezierTo(x(16), t - 10, x(28), t - 10)
              ..quadraticBezierTo(x(22), t - 2, x(26), t + 8)
              ..close(),
            Toon.red,
            width: 3.5,
            shine: false,
          );
        }
      case Hat.pirate:
        const black = Color(0xFF2D2A3A);
        shaded(
          Path()
            ..moveTo(h.left - 3, t + 14)
            ..quadraticBezierTo(28, t - 14, 50, t - 12)
            ..quadraticBezierTo(72, t - 14, h.right + 3, t + 14)
            ..quadraticBezierTo(50, t + 2, h.left - 3, t + 14)
            ..close(),
          black,
        );
        c
          ..drawCircle(Offset(50, t - 2), 4.5, _fill(Colors.white))
          ..drawCircle(Offset(48.4, t - 2.6), 1.1, _fill(black))
          ..drawCircle(Offset(51.6, t - 2.6), 1.1, _fill(black))
          ..drawLine(Offset(45, t + 4), Offset(55, t + 6), _line(1.6, Colors.white))
          ..drawLine(Offset(55, t + 4), Offset(45, t + 6), _line(1.6, Colors.white));
      case Hat.bandana:
        final cloth = Path()
          ..moveTo(h.left + 2, t + 22)
          ..quadraticBezierTo(h.left + 2, t - 10, 50, t - 10)
          ..quadraticBezierTo(h.right - 2, t - 10, h.right - 2, t + 22)
          ..quadraticBezierTo(50, t + 12, h.left + 2, t + 22)
          ..close();
        shaded(cloth, Toon.red);
        c
          ..save()
          ..clipPath(cloth);
        for (var x = h.left + 8; x < h.right; x += 10) {
          for (var y = t - 6; y < t + 22; y += 9) {
            c.drawCircle(Offset(x + (y % 2), y), 1.7, _fill(Colors.white.withValues(alpha: 0.9)));
          }
        }
        c.restore();
        for (final dy in [-4.0, 6.0]) {
          blob(
            Path()
              ..moveTo(h.right - 6, t + 14)
              ..lineTo(h.right + 8, t + 12 + dy)
              ..lineTo(h.right + 4, t + 20 + dy)
              ..close(),
            Toon.red,
            width: 3,
          );
        }
      case Hat.none || Hat.fin || Hat.spiky || Hat.mohawk || Hat.bunny || Hat.cat:
        break;
    }
  }

  @override
  bool shouldRepaint(FacePainter old) => old.a != a || old.only != only || old._dark != Toon.dark;
}
