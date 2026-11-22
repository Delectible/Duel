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
/// yellow, a deck riffles, Duel's ghost rises out of it (the app icon's
/// ghost: scanlines, RGB split, spade glints winking), "Duel" bounces in,
/// and a line of table chatter shows, until start-up is done; then it all
/// fades away. Up at least [minimum], at most [maximum].
class LaunchCurtain extends StatefulWidget {
  const LaunchCurtain({
    super.key,
    required this.child,
    this.minimum = const Duration(milliseconds: 1300),
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
  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
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

  /// The ghost's RGB split: the icon's 5, with a jolt now and then.
  static double _split(double loop) {
    final jolt = (loop > 0.62 && loop < 0.68) || (loop > 0.71 && loop < 0.74);
    return jolt ? 11 : 5 + sin(loop * 2 * pi) * 1.2;
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
                    // 0–0.35 riffle, 0.25–0.75 the ghost rises, 0.65–0.85
                    // its glints pop, 0.55–1 title in.
                    final riffle = t < 0.35 ? sin(t / 0.35 * pi * 3) : 0.0;
                    final rise = Curves.easeOutBack.transform(((t - 0.25) / 0.5).clamp(0.0, 1.0));
                    final pop = Curves.elasticOut.transform(((t - 0.65) / 0.35).clamp(0.0, 1.0));
                    // Glints wink every loop once they're in.
                    final wink = 1 + 0.5 * max(0.0, sin((loop - 0.1) * 2 * pi * 2) - 0.6) / 0.4;
                    final bob = sin(loop * 2 * pi) * 4 * rise;
                    final title = Curves.elasticOut.transform(((t - 0.55) / 0.45).clamp(0.0, 1.0));
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 240,
                            height: 236,
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                // The ghost comes up from behind the deck
                                // (clipped at its top edge).
                                Positioned.fill(
                                  bottom: 92,
                                  child: ClipRect(
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Transform.translate(
                                        offset: Offset(0, (1 - rise) * 140 - 10 + bob),
                                        child: GhostMark(
                                          key: const Key('launch ghost'),
                                          size: 128,
                                          split: _split(loop),
                                          glint: pop * wink,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                for (var i = 0; i < 4; i++)
                                  Transform.translate(
                                    offset: Offset(riffle * (i.isEven ? 7 : -7), -i * 2.0),
                                    child: Transform.rotate(
                                      angle: (i - 1.5) * 0.03 + riffle * (i.isEven ? 0.06 : -0.06),
                                      child: CardView(card: _back, width: 64, faceUp: false),
                                    ),
                                  ),
                              ],
                            ),
                          ),
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
                            opacity: ((t - 0.7) / 0.3).clamp(0.0, 1.0),
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
