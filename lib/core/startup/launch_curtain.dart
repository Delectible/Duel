import 'dart:async';
import 'dart:math';

import 'package:duel_engine/cards.dart';
import 'package:flutter/material.dart';

import '../cards/card_view.dart';
import '../theme/ghost_mark.dart';
import '../theme/toon.dart';

/// What start-up is still doing: the curtain stays up until it's done (so
/// the first taps aren't swallowed by a busy app).
abstract final class Startup {
  static var _pending = 0;
  static var _started = false;

  /// Runs [work] while the curtain waits for it (never longer than
  /// [limit]: whatever is slower finishes behind the app).
  static void track(Future<void> work, {Duration limit = const Duration(seconds: 4)}) {
    _started = true;
    _pending++;
    unawaited(work.timeout(limit).then((_) {}, onError: (Object _) {}).whenComplete(() => _pending--));
  }

  static bool get ready => _pending == 0;

  /// Tests and screens built on their own have no start-up to wait for.
  static bool get tracking => _started;
}

/// The launch screen carried on into the app (as Darkroom does): on Duel's
/// yellow, a deck riffles, Duel's ghost (the app icon's: scanlines, RGB
/// split) peeks out from behind it, looks about, then winds up and swooshes
/// out in front, gathering speed as he loops round, cards
/// spilling from under him into a gently bobbing fan as he flies off,
/// then "Duel" bounces in,
/// and a line of table chatter shows, until start-up is done; then it all
/// fades away. Up at least [minimum], at most [maximum].
class LaunchCurtain extends StatefulWidget {
  const LaunchCurtain({
    super.key,
    required this.child,
    this.minimum = const Duration(milliseconds: 2600),
    this.maximum = const Duration(seconds: 5),
  });

  final Widget child;
  final Duration minimum, maximum;

  static const lines = [
    'Shuffling the deck',
    'Teaching the bots to bluff',
    'Counting the chips (twice)',
    'Dusting off the felt',
    'Finding the missing ace',
    'Waking up the dealer',
    'Hiding the jokers',
    'Polishing the poker face',
    'Stacking the castles',
    'Warming up the lucky dice',
    'Asking the fish to go fish',
    'Ironing the tablecloth',
    'Untangling the card sleeves',
    'Practising the riffle',
    'Letting the bots stretch',
  ];

  @override
  State<LaunchCurtain> createState() => _LaunchCurtainState();
}

class _LaunchCurtainState extends State<LaunchCurtain> with TickerProviderStateMixin {
  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))
    ..forward();
  late final _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  // The ghost bobs and glitches while start-up finishes.
  late final _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  final String _line = LaunchCurtain.lines[Random().nextInt(LaunchCurtain.lines.length)];
  Timer? _poll;
  var _polls = 0;
  var _up = true;

  static const _tick = Duration(milliseconds: 50);

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(_tick, (_) => _check());
  }

  void _check() {
    final waited = _tick * ++_polls;
    if (waited < widget.minimum) return;
    if (waited < widget.maximum && !Startup.ready) return;
    _poll?.cancel();
    _fade.forward().whenComplete(() {
      _loop.stop();
      if (mounted) setState(() => _up = false);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _intro.dispose();
    _loop.dispose();
    _fade.dispose();
    super.dispose();
  }

  static final _back = PlayingCard.parse('As');

  // Red and black take turns, as in every hand in Duel.
  static final _fan = [
    for (final c in ['As', 'Kh', 'Qc', 'Jd', '10s']) PlayingCard.parse(c),
  ];

  /// The ghost's RGB split: the icon's 5, with a jolt now and then.
  static double _split(double loop) {
    final jolt = (loop > 0.62 && loop < 0.68) || (loop > 0.71 && loop < 0.74);
    return jolt ? 11 : 5 + sin(loop * 2 * pi) * 1.2;
  }

  static Offset _bez(Offset a, Offset b, Offset c, Offset d, double u) {
    final v = 1 - u;
    return a * (v * v * v) + b * (3 * v * v * u) + c * (3 * v * u * u) + d * (u * u * u);
  }

  // Positions from the middle of the scene (deck at (0, 75)).
  static const _start = Offset(0, 40);
  static const _peek = Offset(0, 4);
  static const _risen = Offset(0, -45);
  static const _wide = Offset(-125, 30);
  static const _riseShare = 0.1;

  /// The flight, [g] 0..1, from the peek: up clear of the deck, round to
  /// the left, down in front of the deck (scooping it up), low across the
  /// table and off to the top right.
  static Offset _path(double g) {
    if (g < _riseShare) return Offset.lerp(_peek, _risen, g / _riseShare)!;
    final s = (g - _riseShare) / (1 - _riseShare);
    return s < 0.38
        ? _bez(_risen, const Offset(0, -150), const Offset(-210, -70), _wide, s / 0.38)
        : _bez(
            _wide,
            const Offset(-60, 140),
            const Offset(170, 140),
            const Offset(540, -420),
            (s - 0.38) / 0.62,
          );
  }

  static double _flightSize(double g) => 0.85 + 0.6 * sin(min(g, 0.5) / 0.5 * pi / 2);

  static Offset _fanAt(int i) => Offset((i - 2) * 30.0, 55 - (2 - (i - 2).abs()) * 8.0);

  /// When (flight 0..1) he covers the deck and scoops it up.
  static final double _scoop = () {
    for (var k = 30; k <= 100; k++) {
      if (_path(k / 100).dx >= -25 && _path(k / 100).dy > 40) return k / 100;
    }
    return 0.7;
  }();

  // The beats (of the intro's 2.5 s), timed like a character, not a
  // machine: rise to a peek, look about, a beat of crouch to wind up, then
  // spring off it into a quick swoosh that keeps gathering speed; title.
  static const _rise = (0.03, 0.22), _look = (0.22, 0.46), _windUp = (0.46, 0.55), _fly = (0.55, 0.77);

  static double _phase((double, double) p, double t) => ((t - p.$1) / (p.$2 - p.$1)).clamp(0.0, 1.0);

  /// Flight progress for time [t]: slow off the mark, faster and faster.
  static double _flight(double t) => Curves.easeInQuad.transform(_phase(_fly, t));

  /// The time the flight reaches [g] (for dropping cards on cue).
  static double _timeAt(double g) => _fly.$1 + sqrt(g) * (_fly.$2 - _fly.$1);

  Widget _scene(double t, double loop) {
    final riffle = t < 0.12 ? sin(t / 0.12 * pi * 3) : 0.0;
    final flying = t >= _fly.$1;
    final g = _flight(t);
    final gone = g >= 1;
    Offset at;
    double size, lean = 0, sx = 1, sy = 1;
    if (!flying) {
      // Up from behind the deck, settling with a little bounce; a look
      // left and right; then a dip to wind up.
      final up = const Cubic(0.3, 1.35, 0.6, 1).transform(_phase(_rise, t));
      final look = _phase(_look, t);
      // The crouch eases in and holds a moment at the bottom.
      final dip = Curves.easeOutCubic.transform(_phase(_windUp, t));
      at = Offset.lerp(_start, _peek, up)! + Offset(0, sin(look * pi * 2) * 2 + dip * 11);
      size = 0.35 + 0.5 * up;
      // A glance left, then right, then leaning back the way he'll go.
      lean = sin(look * pi * 2) * 0.14 - dip * 0.12;
      // Squash as he crouches.
      sx = 1 + dip * 0.12;
      sy = 1 - dip * 0.14;
    } else {
      at = _path(g);
      size = _flightSize(g);
      final ahead = _path(min(1, g + 0.02)) - at;
      lean = ahead.dx.sign * 0.28 * min(1, ahead.distance / 8);
      // Springs out of the crouch (a quick stretch), then stretched by
      // speed.
      final spring = sin(min(1.0, g / 0.12) * pi) * 0.18;
      final speed = min(1.0, ahead.distance / 25);
      sx = 1 - speed * 0.08 - spring * 0.5;
      sy = 1 + speed * 0.1 + spring;
    }
    final inFront = flying && g >= _riseShare;
    final split = _split(loop) + (flying && !gone ? 3 + 6 * g : 0);
    final ghost = gone
        ? const SizedBox.shrink()
        : Transform.translate(
            offset: at,
            child: Transform.rotate(
              angle: lean,
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.diagonal3Values(size * sx, size * sy, 1),
                child: GhostMark(key: const Key('launch ghost'), size: 128, split: split),
              ),
            ),
          );

    final cards = <Widget>[];
    for (var i = 0; i < 5; i++) {
      final drop = _scoop + 0.025 + i * 0.045;
      final dropT = _timeAt(min(1, drop));
      final u = ((t - dropT) / 0.17).clamp(0.0, 1.0);
      if (u <= 0) continue;
      final from = _path(drop) + const Offset(0, 45);
      final land = Curves.easeOutBack.transform(u);
      final bob = sin(loop * 2 * pi + i * 0.9) * 3 * u;
      final at = Offset.lerp(from, _fanAt(i), land)! + Offset(0, bob);
      cards.add(
        Transform.translate(
          offset: at,
          child: Transform.rotate(
            angle: (i - 2) * 0.22 * land + (1 - u) * (i.isEven ? 1.2 : -1.2),
            child: CardView(card: _fan[i], width: 64, faceUp: u > 0.45),
          ),
        ),
      );
    }

    return SizedBox(
      width: 260,
      height: 236,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Behind the deck while he rises out of it.
          if (!inFront) ghost,
          // The deck, until he passes in front and scoops it up.
          if (!flying || g < _scoop)
            for (var i = 0; i < 4; i++)
              Transform.translate(
                offset: Offset(riffle * (i.isEven ? 7 : -7), 75 - i * 2.0),
                child: Transform.rotate(
                  angle: (i - 1.5) * 0.03 + riffle * (i.isEven ? 0.06 : -0.06),
                  child: CardView(card: _back, width: 64, faceUp: false),
                ),
              ),
          ...cards,
          if (inFront) ghost,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      if (_up)
        AbsorbPointer(
          child: FadeTransition(
            opacity: ReverseAnimation(CurvedAnimation(parent: _fade, curve: Curves.easeInOut)),
            // Material: it sits above the app's own (no underlined text).
            child: Material(
              key: const Key('launch curtain'),
              color: Toon.yellow,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_intro, _loop]),
                  builder: (context, _) {
                    final t = _intro.value, loop = _loop.value;
                    final title = Curves.elasticOut.transform(((t - 0.7) / 0.3).clamp(0.0, 1.0));
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _scene(t, loop),
                          const SizedBox(height: 18),
                          Transform.scale(
                            scale: title,
                            child: Text(
                              'Duel',
                              style: Toon.text(56, weight: FontWeight.w700, color: Toon.inkLight),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Opacity(
                            opacity: ((t - 0.8) / 0.2).clamp(0.0, 1.0),
                            child: Text(
                              '$_line…',
                              key: const Key('launch line'),
                              style: Toon.text(16, weight: FontWeight.w600, color: Toon.inkLight),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
