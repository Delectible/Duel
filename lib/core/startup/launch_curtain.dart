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
/// split) pops up behind it, swooshes out in front and loops round, cards
/// spilling from under him into a gently bobbing fan as he flies off,
/// then "Duel" bounces in,
/// and a line of table chatter shows, until start-up is done; then it all
/// fades away. Up at least [minimum], at most [maximum].
class LaunchCurtain extends StatefulWidget {
  const LaunchCurtain({
    super.key,
    required this.child,
    this.minimum = const Duration(milliseconds: 2300),
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
  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
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
  static const _deck = Offset(0, 75);
  static const _risen = Offset(0, -45);
  static const _wide = Offset(-125, 30);
  static const _riseShare = 0.24;

  /// The whole flight, [g] 0..1, as one smooth path: up from behind the
  /// deck, on up and round to the left, down in front of the deck
  /// (scooping it up), low across the table and off to the top right.
  static Offset _path(double g) {
    if (g < _riseShare) return Offset.lerp(_deck, _risen, g / _riseShare)!;
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

  /// Small while hidden behind the deck, full size once clear, bigger in
  /// front.
  static double _size(double g) {
    if (g < _riseShare) return 0.35 + 0.65 * Curves.easeOut.transform(g / _riseShare);
    final s = (g - _riseShare) / (1 - _riseShare);
    return 1 + 0.45 * sin(min(s, 0.5) / 0.5 * pi / 2);
  }

  static Offset _fanAt(int i) => Offset((i - 2) * 30.0, 55 - (2 - (i - 2).abs()) * 8.0);

  /// When (flight 0..1) he covers the deck and scoops it up.
  static final double _scoop = () {
    for (var k = 50; k <= 100; k++) {
      if (_path(k / 100).dx >= -25 && _path(k / 100).dy > 40) return k / 100;
    }
    return 0.7;
  }();

  static const _flyFrom = 0.04, _flyTo = 0.8;

  Widget _scene(double t, double loop) {
    // 0–0.12 riffle; 0.04–0.8 the flight, cards trailing out behind him
    // from the moment he scoops the deck.
    final riffle = t < 0.12 ? sin(t / 0.12 * pi * 3) : 0.0;
    final g = Curves.easeInOutSine.transform(((t - _flyFrom) / (_flyTo - _flyFrom)).clamp(0.0, 1.0));
    final gone = g >= 1;
    final inFront = g >= _riseShare;
    final ghostAt = _path(g);
    final ahead = _path(min(1, g + 0.02)) - ghostAt;
    final lean = inFront ? ahead.dx.sign * 0.25 * min(1, ahead.distance / 8) : 0.0;
    final split = _split(loop) + (inFront && !gone ? 5 : 0);
    final ghost = gone
        ? const SizedBox.shrink()
        : Transform.translate(
            offset: ghostAt,
            child: Transform.rotate(
              angle: lean,
              child: Transform.scale(
                scale: _size(g),
                child: GhostMark(key: const Key('launch ghost'), size: 128, split: split),
              ),
            ),
          );

    final cards = <Widget>[];
    for (var i = 0; i < 5; i++) {
      final drop = _scoop + 0.025 + i * 0.045;
      final dropT = _flyFrom + drop * (_flyTo - _flyFrom);
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
          if (g < _scoop)
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
                    final title = Curves.elasticOut.transform(((t - 0.72) / 0.28).clamp(0.0, 1.0));
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
