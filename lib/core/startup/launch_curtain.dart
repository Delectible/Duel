import 'dart:async';
import 'dart:math';

import 'package:duel_engine/cards.dart';
import 'package:flutter/material.dart';

import '../cards/card_view.dart';
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
/// yellow, a deck riffles and fans out into five cards, "Duel" bounces in,
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
      if (mounted) setState(() => _up = false);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _intro.dispose();
    _fade.dispose();
    super.dispose();
  }

  // Red and black take turns, as in every hand in Duel.
  static final _fan = [
    for (final s in ['As', 'Kh', 'Qc', 'Jd', '10s']) PlayingCard.parse(s),
  ];

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
                  animation: _intro,
                  builder: (context, _) {
                    final t = _intro.value;
                    // 0–0.35 riffle, 0.3–0.8 fan out, 0.55–1 title in.
                    final fan = Curves.easeOutBack.transform(((t - 0.3) / 0.5).clamp(0.0, 1.0));
                    final riffle = t < 0.35 ? sin(t / 0.35 * pi * 3) : 0.0;
                    final title = Curves.elasticOut.transform(((t - 0.55) / 0.45).clamp(0.0, 1.0));
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 240,
                            height: 150,
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                for (final (i, card) in _fan.indexed)
                                  Transform.translate(
                                    offset: Offset(
                                      (i - 2) * 30 * fan + riffle * (i.isEven ? 6 : -6),
                                      -(2 - (i - 2).abs()) * 8.0 * fan,
                                    ),
                                    child: Transform.rotate(
                                      angle: (i - 2) * 0.22 * fan,
                                      alignment: Alignment.bottomCenter,
                                      child: CardView(card: card, width: 64, faceUp: fan > 0.15),
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
