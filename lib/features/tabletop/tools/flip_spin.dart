import 'dart:math';

import 'package:duel_engine/cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/account/account.dart';
import '../../../core/cards/card_view.dart';
import '../../../core/sound/sound.dart';
import '../../../core/table/table_bits.dart';
import '../../../core/theme/toon.dart';
import '../scorer/presets.dart';
import 'tool_page.dart';

/// A coin to flip, and a wheel to spin (your own choices on it).
class FlipSpin extends StatefulWidget {
  const FlipSpin({super.key, this.seed, this.wheel = false});

  final int? seed;

  /// Open on the wheel.
  final bool wheel;

  @override
  State<FlipSpin> createState() => _FlipSpinState();
}

class _FlipSpinState extends State<FlipSpin> {
  late var _wheel = widget.wheel;

  @override
  Widget build(BuildContext context) => ToolPage(
    title: _wheel ? 'Spinner' : 'Coin flip',
    subtitle: _wheel ? 'Spin the wheel to pick' : 'Tap the coin (or swipe it up) to flip',
    actions: [
      for (final w in [false, true])
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: ToonButton(
            key: Key(w ? 'show wheel' : 'show coin'),
            color: w == _wheel ? Toon.yellow : Toon.card,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            onPressed: () => setState(() => _wheel = w),
            child: Icon(w ? Icons.donut_large_rounded : Icons.monetization_on_rounded, size: 22),
          ),
        ),
    ],
    child: _wheel ? SpinWheel(seed: widget.seed) : CoinToss(seed: widget.seed),
  );
}

// --- The coin ------------------------------------------------------------------

const _gold = Color(0xFFF2C14E);
const _goldDark = Color(0xFFB8862B);
const _goldDeep = Color(0xFF8A5F18);

/// A coin seen in 3D: turned [angle] about its horizontal axis (0 = its
/// heads face looking straight at you, π = tails), drawn as real layers:
/// the back face, the milled edge in thin slices, the front face, each
/// moved along its depth and turned with perspective, back to front, and
/// shaded by how it faces the light.
class Coin3D extends StatelessWidget {
  const Coin3D({super.key, required this.angle, required this.size, this.spinZ = 0});

  final double angle;
  final double size;

  /// A little turn about the view axis (a wobble in flight).
  final double spinZ;

  static const _slices = 20;

  Matrix4 _at(double z) => Matrix4.identity()
    ..setEntry(3, 2, 0.0016)
    ..rotateZ(spinZ)
    ..rotateX(angle)
    ..translateByDouble(0.0, 0.0, z, 1.0);

  @override
  Widget build(BuildContext context) {
    final t = size * 0.075;
    final front = cos(angle) >= 0;
    // How brightly each face catches the light (from above, a little in front).
    final lightFront = (0.55 + 0.45 * cos(angle + 0.6)).clamp(0.25, 1.0);
    final lightBack = (0.55 + 0.45 * cos(angle + 0.6 - pi)).clamp(0.25, 1.0);
    Widget layer(double z, Widget child) =>
        Transform(alignment: Alignment.center, transform: _at(z), child: child);
    final edge = [
      for (var i = 0; i < _slices; i++)
        layer(
          -t / 2 + t * i / (_slices - 1),
          _Edge(
            size: size,
            shade: 0.55 + 0.45 * sin(pi * i / (_slices - 1)),
            outline: i == 0 || i == _slices - 1,
          ),
        ),
    ];
    final faceUp = layer(-t / 2, _Face(size: size, heads: true, light: lightFront));
    // The back face is turned over so it isn't drawn mirrored.
    final faceDown = layer(
      t / 2,
      Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationX(pi),
        child: _Face(size: size, heads: false, light: lightBack),
      ),
    );
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: front ? [faceDown, ...edge.reversed, faceUp] : [faceUp, ...edge, faceDown],
      ),
    );
  }
}

class _Edge extends StatelessWidget {
  const _Edge({required this.size, required this.shade, required this.outline});

  final double size;
  final double shade;
  final bool outline;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _EdgePainter(Color.lerp(_goldDeep, _gold, shade)!, outline: outline),
  );
}

class _EdgePainter extends CustomPainter {
  _EdgePainter(this.color, {required this.outline});
  final Color color;
  final bool outline;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = color);
    // Milling: fine ridges round the rim.
    final ridge = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..strokeWidth = 1.2;
    for (var i = 0; i < 90; i++) {
      final a = i * 2 * pi / 90;
      canvas.drawLine(c + Offset(cos(a), sin(a)) * (r - 2.5), c + Offset(cos(a), sin(a)) * r, ridge);
    }
    if (outline) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Toon.ink.withValues(alpha: 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) => old.color != color || old.outline != outline;
}

/// A face: polished gold with a raised rim, the ghost on heads, a spade on
/// tails, the words round the edge; [light] dims it as it turns away.
class _Face extends StatelessWidget {
  const _Face({required this.size, required this.heads, required this.light});

  final double size;
  final bool heads;
  final double light;

  @override
  Widget build(BuildContext context) {
    final engraved = heads
        ? CustomPaint(size: Size.square(size * 0.5), painter: _GhostPainter(_goldDeep))
        : SuitIcon(Suit.spades, size: size * 0.42, color: _goldDeep, onLight: true);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.35, -0.4),
          radius: 1.0,
          colors: [Color(0xFFFFE9A8), _gold, _goldDark],
          stops: [0, 0.55, 1],
        ),
        border: Border.all(color: Toon.ink, width: 2),
      ),
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: (1 - light) * 0.55),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The raised rim.
          Container(
            margin: EdgeInsets.all(size * 0.06),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _goldDark, width: size * 0.025),
            ),
          ),
          CustomPaint(
            size: Size.square(size),
            painter: _RimWords(heads ? 'HEADS · DUEL · HEADS · DUEL ·' : 'TAILS · DUEL · TAILS · DUEL ·'),
          ),
          // Engraved: a light edge below, the dark cut above.
          Transform.translate(
            offset: Offset(0, size * 0.01),
            child: Opacity(
              opacity: 0.6,
              child: heads
                  ? CustomPaint(
                      size: Size.square(size * 0.5),
                      painter: _GhostPainter(const Color(0xFFFFF1C4)),
                    )
                  : SuitIcon(Suit.spades, size: size * 0.42, color: const Color(0xFFFFF1C4), onLight: true),
            ),
          ),
          engraved,
        ],
      ),
    );
  }
}

/// Duel's ghost, struck into the coin: a dome, a wavy hem, two eyes (the
/// coin's gold showing through) with a spade glint in each.
class _GhostPainter extends CustomPainter {
  _GhostPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final body = Path()
      ..moveTo(w * 0.18, h * 0.92)
      ..lineTo(w * 0.18, h * 0.45)
      ..arcToPoint(Offset(w * 0.82, h * 0.45), radius: Radius.circular(w * 0.32))
      ..lineTo(w * 0.82, h * 0.92);
    // The hem: four scallops.
    for (var i = 0; i < 4; i++) {
      final x0 = w * (0.82 - i * 0.16);
      body.quadraticBezierTo(x0 - w * 0.04, h * 0.8, x0 - w * 0.08, h * 0.86);
      body.quadraticBezierTo(x0 - w * 0.12, h * 0.94, x0 - w * 0.16, h * 0.92);
    }
    body.close();
    final eyes = Path()
      ..addOval(Rect.fromCenter(center: Offset(w * 0.39, h * 0.44), width: w * 0.13, height: h * 0.19))
      ..addOval(Rect.fromCenter(center: Offset(w * 0.61, h * 0.44), width: w * 0.13, height: h * 0.19));
    canvas.drawPath(Path.combine(PathOperation.difference, body, eyes), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_GhostPainter old) => old.color != color;
}

/// Small capitals running round the inside of the rim.
class _RimWords extends CustomPainter {
  _RimWords(this.text);
  final String text;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), r = size.width * 0.36;
    final step = 2 * pi / text.length;
    for (var i = 0; i < text.length; i++) {
      final a = -pi / 2 + i * step;
      final tp = TextPainter(
        text: TextSpan(
          text: text[i],
          style: Toon.text(size.width * 0.055, weight: FontWeight.w700, color: _goldDeep),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(c.dx + cos(a) * r, c.dy + sin(a) * r);
      canvas.rotate(a + pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_RimWords old) => old.text != text;
}

/// Flip a coin: tap (or swipe up) and it's thumbed into the air on a high
/// arc, tumbling end over end, its shadow shrinking on the table as it
/// rises; it lands, rocks on its rim and settles flat, heads or tails. A
/// tally of the flips so far underneath.
class CoinToss extends StatefulWidget {
  const CoinToss({super.key, this.seed});

  final int? seed;

  @override
  State<CoinToss> createState() => _CoinTossState();
}

class _CoinTossState extends State<CoinToss> with SingleTickerProviderStateMixin {
  late final Random _rng = Random(widget.seed);
  static const _flightMs = 1250, _settleMs = 750;
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _flightMs + _settleMs),
  )..addStatusListener(_done);

  /// Lying on the table: tipped back so the face up shows as an ellipse.
  static const _tilt = -1.05;

  bool _heads = true;
  double _from = _tilt;
  double _spins = 0;
  double _wobbleDir = 1;
  var _landed = true;
  var _thudPlayed = false;
  final List<bool> _results = [];

  double get _rest => _heads ? _tilt : _tilt + pi;

  void _flip() {
    if (_a.isAnimating) return;
    final from = _restNow;
    _heads = _rng.nextBool();
    _from = from;
    // Whole turns (more for a stronger flick), to land just past flat.
    final target = _rest + 0.55;
    final base = ((target - from) % (2 * pi) + 2 * pi) % (2 * pi);
    _spins = base + (6 + _rng.nextInt(3)) * 2 * pi;
    _wobbleDir = _rng.nextBool() ? 1 : -1;
    _landed = false;
    _thudPlayed = false;
    HapticFeedback.lightImpact();
    Sound.play(Sfx.tap);
    _a.forward(from: 0);
  }

  double _restNow = _tilt;

  void _done(AnimationStatus s) {
    if (s != AnimationStatus.completed) return;
    setState(() {
      _landed = true;
      _restNow = _rest;
      _results.insert(0, _heads);
      if (_results.length > 40) _results.removeLast();
    });
    Sound.play(_heads ? Sfx.winSmall : Sfx.place);
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  /// Where the coin is at [ms]: its turn, its height above the table (0..1
  /// of the throw), a wobble about the view axis.
  (double angle, double lift, double spinZ, double bounce) _pose(double ms) {
    if (_landed && !_a.isAnimating) return (_restNow, 0, 0, 0);
    if (ms < _flightMs) {
      final u = ms / _flightMs;
      final turn = Curves.easeOutCubic.transform(u);
      return (_from + _spins * turn, sin(u * pi), sin(u * pi * 3) * 0.12 * (1 - u), 0);
    }
    // Down: it rocks on its rim, less and less, and lies flat.
    final v = ((ms - _flightMs) / _settleMs).clamp(0.0, 1.0);
    if (!_thudPlayed) {
      _thudPlayed = true;
      Sound.play(Sfx.drop);
      HapticFeedback.mediumImpact();
    }
    final rock = 0.55 * exp(-4.2 * v) * cos(v * pi * 5.5);
    final bounce = v < 0.3 ? sin(v / 0.3 * pi) * 0.08 : 0.0;
    return (_rest + rock, 0, rock * 0.15 * _wobbleDir, bounce);
  }

  @override
  Widget build(BuildContext context) {
    final heads = _results.where((r) => r).length, tails = _results.length - heads;
    return LayoutBuilder(
      builder: (context, box) {
        final size = min(box.maxWidth * 0.5, box.maxHeight * 0.3).clamp(110.0, 220.0);
        final floorY = box.maxHeight * 0.68;
        final rise = box.maxHeight * 0.5;
        return GestureDetector(
          key: const Key('flip'),
          behavior: HitTestBehavior.opaque,
          onTap: _flip,
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) < -150) _flip();
          },
          child: AnimatedBuilder(
            animation: _a,
            builder: (context, _) {
              final (angle, lift, spinZ, bounce) = _pose(_a.value * (_flightMs + _settleMs));
              final y = floorY - lift * rise - bounce * size;
              final scale = 1 + lift * 0.3;
              return Stack(
                children: [
                  // The table.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: floorY - size * 0.1,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Toon.card.withValues(alpha: 0), Toon.card],
                        ),
                      ),
                    ),
                  ),
                  // Its shadow: a soft pool under it, smaller and fainter the higher it goes.
                  Positioned(
                    left: box.maxWidth / 2 - size * 0.42 * (1 - lift * 0.5),
                    top: floorY + size * 0.2,
                    child: Container(
                      width: size * 0.84 * (1 - lift * 0.5),
                      height: size * 0.12 * (1 - lift * 0.5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(size),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.32 * (1 - lift * 0.8)),
                            blurRadius: size * (0.08 + lift * 0.12),
                            spreadRadius: size * 0.01,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: box.maxWidth / 2 - size / 2,
                    top: y - size / 2,
                    child: Transform.scale(
                      scale: scale,
                      child: RepaintBoundary(
                        child: Coin3D(angle: angle, size: size, spinZ: spinZ),
                      ),
                    ),
                  ),
                  // The result, once it's down.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: box.maxHeight * 0.06,
                    child: AnimatedOpacity(
                      opacity: _landed && _results.isNotEmpty ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Center(
                        child: Pop(
                          key: ValueKey(_results.length),
                          child: Text(
                            _results.isEmpty ? '' : (_results.first ? 'Heads!' : 'Tails!'),
                            key: const Key('coin result'),
                            style: Toon.text(44, weight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_results.isEmpty && _landed)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: box.maxHeight * 0.1,
                      child: Text(
                        'Tap to flip',
                        textAlign: TextAlign.center,
                        style: Toon.text(22, weight: FontWeight.w700, color: Toon.muted),
                      ),
                    ),
                  // The tally.
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 12,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _Tally('Heads', heads),
                            const SizedBox(width: 12),
                            _Tally('Tails', tails),
                            if (_results.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              TextButton(
                                onPressed: () => setState(_results.clear),
                                child: const Text('Clear'),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final r in _results.take(20))
                              Container(
                                width: 18,
                                height: 18,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: r ? _gold : _goldDeep,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Toon.ink, width: 1.2),
                                ),
                                child: Text(
                                  r ? 'H' : 'T',
                                  style: Toon.text(
                                    10,
                                    weight: FontWeight.w700,
                                    color: r ? Toon.inkLight : Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _Tally extends StatelessWidget {
  const _Tally(this.label, this.n);
  final String label;
  final int n;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: Toon.box(Toon.card, radius: 12, shadow: 1),
    child: Text('$label $n', style: Toon.text(16, weight: FontWeight.w700)),
  );
}

// --- The wheel ------------------------------------------------------------------

/// A prize wheel with your own choices (kept for next time): flick it or
/// tap Spin; it whirs round, slows, the pointer clicking over each slice,
/// and stops on one.
class SpinWheel extends StatefulWidget {
  const SpinWheel({super.key, this.seed});

  final int? seed;

  @override
  State<SpinWheel> createState() => _SpinWheelState();
}

class _SpinWheelState extends State<SpinWheel> with SingleTickerProviderStateMixin {
  late final Random _rng = Random(widget.seed);
  late final Account? _account = AccountScope.maybeRead(context);
  late final List<String> _choices = _load();
  late final AnimationController _a =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 4600))
        ..addListener(_ticked)
        ..addStatusListener(_done);

  double _from = 0, _to = 0;

  /// Where the wheel rests now (radians).
  double _angle = 0;
  int _lastSlice = -1;

  /// The pointer flicks back as it clicks over a peg.
  double _flick = 0;
  int? _winner;

  List<String> _load() {
    final saved = _account?.toolState('wheel')?['choices'];
    if (saved is List && saved.length >= 2) return [for (final c in saved) '$c'];
    return ['Yes', 'No', 'Maybe', 'Ask again'];
  }

  void _save() => _account?.saveToolState('wheel', {'choices': _choices});

  double get _now => _a.isAnimating || _a.value > 0
      ? _from + (_to - _from) * const Cubic(0.12, 0.9, 0.18, 1).transform(_a.value)
      : _angle;

  /// The slice under the pointer (at the top) for wheel angle [a].
  int _sliceAt(double a) {
    final n = _choices.length;
    final step = 2 * pi / n;
    final p = ((-a) % (2 * pi) + 2 * pi) % (2 * pi);
    return (p / step).floor() % n;
  }

  void _spin([double strength = 1]) {
    if (_a.isAnimating || _choices.length < 2) return;
    _from = _angle;
    _to = _angle + (5 + _rng.nextDouble() * 3) * 2 * pi * strength.clamp(0.7, 1.5);
    _winner = null;
    _lastSlice = _sliceAt(_from);
    Sound.play(Sfx.shuffle, gain: 0.6);
    _a.forward(from: 0);
  }

  void _ticked() {
    final s = _sliceAt(_now);
    if (s != _lastSlice) {
      _lastSlice = s;
      _flick = 1;
      Sound.play(Sfx.tap, gain: 0.35);
    } else {
      _flick *= 0.82;
    }
    setState(() {});
  }

  void _done(AnimationStatus st) {
    if (st != AnimationStatus.completed) return;
    _angle = _to % (2 * pi);
    _from = _to = _angle;
    _a.value = 0;
    setState(() => _winner = _sliceAt(_angle));
    HapticFeedback.heavyImpact();
    Sound.play(Sfx.winSmall);
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  Future<void> _edit() async {
    final text = TextEditingController(text: _choices.join('\n'));
    final r = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Toon.paper,
        title: const Text('The choices'),
        content: TextField(
          key: const Key('wheel choices'),
          controller: text,
          maxLines: 8,
          minLines: 4,
          decoration: const InputDecoration(helperText: 'One per line, 2 to 12'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            key: const Key('wheel save'),
            onPressed: () => Navigator.of(context).pop(text.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (r == null) return;
    final list = [
      for (final l in r.split('\n'))
        if (l.trim().isNotEmpty) l.trim().substring(0, min(18, l.trim().length)),
    ].take(12).toList();
    if (list.length < 2) return;
    setState(() {
      _choices
        ..clear()
        ..addAll(list);
      _winner = null;
    });
    _save();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final wide = box.maxWidth > box.maxHeight;
      final size = min(box.maxWidth * (wide ? 0.5 : 0.9), box.maxHeight * (wide ? 0.9 : 0.66));
      final wheel = GestureDetector(
        key: const Key('wheel'),
        onTap: _spin,
        onPanEnd: (d) => _spin(d.velocity.pixelsPerSecond.distance / 1500),
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: _now,
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size.square(size),
                    painter: _WheelPainter(_choices, winner: _a.isAnimating ? null : _winner),
                  ),
                ),
              ),
              // The hub.
              Container(
                width: size * 0.16,
                height: size * 0.16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(colors: [Color(0xFFFFE9A8), _gold, _goldDark]),
                  border: Border.all(color: Toon.ink, width: 3),
                ),
              ),
              // The pointer at the top, flicking as it clicks over pegs.
              Positioned(
                top: -size * 0.02,
                child: Transform.rotate(
                  angle: -_flick * 0.35,
                  alignment: Alignment.topCenter,
                  child: CustomPaint(size: Size(size * 0.11, size * 0.14), painter: _PointerPainter()),
                ),
              ),
            ],
          ),
        ),
      );
      final side = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 56,
            child: Center(
              child: _winner == null
                  ? Text(
                      _a.isAnimating ? 'Round and round…' : 'Tap or flick the wheel',
                      style: Toon.text(18, weight: FontWeight.w600, color: Toon.muted),
                    )
                  : Pop(
                      key: ValueKey('win $_winner ${_angle.toStringAsFixed(3)}'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: Toon.box(scoreColor(_winner!), radius: 16, shadow: 3),
                        child: Text(
                          _choices[_winner!],
                          key: const Key('wheel result'),
                          style: Toon.text(26, weight: FontWeight.w700, color: Toon.on(scoreColor(_winner!))),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ToonButton(
                key: const Key('edit wheel'),
                color: Toon.card,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                onPressed: _a.isAnimating ? null : _edit,
                child: const Text('Edit choices'),
              ),
              const SizedBox(width: 10),
              ToonButton(
                key: const Key('spin'),
                color: Toon.green,
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                onPressed: _a.isAnimating ? null : _spin,
                child: const Text('Spin'),
              ),
            ],
          ),
        ],
      );
      return Padding(
        padding: const EdgeInsets.all(12),
        child: wide
            ? Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [wheel, side])
            : Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [wheel, side]),
      );
    },
  );
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.choices, {this.winner});

  final List<String> choices;
  final int? winner;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), r = size.width / 2 - 6;
    final n = choices.length;
    final step = 2 * pi / n;
    // Slice i runs clockwise from the top.
    for (var i = 0; i < n; i++) {
      final start = -pi / 2 + i * step;
      final color = scoreColor(i);
      final win = winner == i;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        start,
        step,
        true,
        Paint()..color = winner != null && !win ? Color.lerp(color, Colors.black, 0.35)! : color,
      );
      // The label, along the slice's middle.
      final mid = start + step / 2;
      final tp = TextPainter(
        text: TextSpan(
          text: choices[i],
          style: Toon.text(
            (r * 0.13).clamp(11.0, 22.0) * (n > 8 ? 0.85 : 1),
            weight: FontWeight.w700,
            color: Toon.on(color),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: r * 0.62);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(mid);
      tp.paint(canvas, Offset(r * 0.3, -tp.height / 2));
      canvas.restore();
    }
    // Slice lines, pegs on the rim, the rim.
    final line = Paint()
      ..color = Toon.ink
      ..strokeWidth = 2.5;
    for (var i = 0; i < n; i++) {
      final a = -pi / 2 + i * step;
      canvas.drawLine(c, c + Offset(cos(a), sin(a)) * r, line);
      canvas.drawCircle(c + Offset(cos(a), sin(a)) * (r - 1), 5, Paint()..color = _gold);
      canvas.drawCircle(
        c + Offset(cos(a), sin(a)) * (r - 1),
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Toon.ink,
      );
    }
    canvas.drawCircle(
      c,
      r + 3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = Toon.ink,
    );
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.winner != winner || old.choices != choices;
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(size.width * 0.1, 0)
      ..lineTo(size.width * 0.9, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(p.shift(const Offset(2, 3)), Paint()..color = Colors.black26);
    canvas.drawPath(p, Paint()..color = Toon.red);
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..color = Toon.ink,
    );
  }

  @override
  bool shouldRepaint(_PointerPainter old) => false;
}
