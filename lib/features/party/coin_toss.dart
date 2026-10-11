import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/toon.dart';
import '../../games/catalog.dart';

/// Settles a tied vote: a gold coin with one game on each face flips up,
/// spins, lands with a bounce and shows [winner] (0 = [heads], 1 = [tails]).
/// The result is decided before the toss, so every phone in an online party
/// plays the same toss to the same game.
Future<void> showCoinToss(
  BuildContext context, {
  required GameInfo heads,
  required GameInfo tails,
  required int winner,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Toon.ink.withValues(alpha: 0.6),
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: CoinToss(heads: heads, tails: tails, winner: winner, onDone: () => Navigator.of(context).pop()),
    ),
  );
}

class CoinToss extends StatefulWidget {
  const CoinToss({
    super.key,
    required this.heads,
    required this.tails,
    required this.winner,
    required this.onDone,
    this.spins = 5,
  });

  final GameInfo heads;
  final GameInfo tails;

  /// 0 = heads wins, 1 = tails.
  final int winner;
  final VoidCallback onDone;

  /// Full turns in the air.
  final int spins;

  @override
  State<CoinToss> createState() => _CoinTossState();
}

class _CoinTossState extends State<CoinToss> with SingleTickerProviderStateMixin {
  static const _flight = 0.78; // share of the animation spent in the air
  late final _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  var _landed = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    _a.addListener(() {
      if (!_landed && _a.value >= _flight) {
        _landed = true;
        HapticFeedback.heavyImpact();
        setState(() {});
      }
    });
    _a.forward();
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  GameInfo get _won => widget.winner == 0 ? widget.heads : widget.tails;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final h = box.maxHeight.isFinite ? box.maxHeight : 640.0;
      final w = box.maxWidth.isFinite ? box.maxWidth : 400.0;
      // On its side the words and result sit beside the coin.
      final wide = w > h * 1.15;
      final stageHeight = wide ? (h - 24).clamp(220.0, 420.0) : (h - 190).clamp(220.0, 420.0);
      final coin = (stageHeight * 0.4).clamp(110.0, 170.0);
      final apex = stageHeight - coin - 30;
      final titles = <Widget>[
        Text(
          "It's a tie!",
          style: Toon.text(28, weight: FontWeight.w700, color: Colors.white),
        ),
        Text(
          '${widget.heads.name} or ${widget.tails.name}? A coin toss decides.',
          textAlign: TextAlign.center,
          style: Toon.text(16, weight: FontWeight.w500, color: Colors.white),
        ),
      ];
      final stage = SizedBox(
        height: stageHeight,
        child: AnimatedBuilder(
          animation: _a,
          builder: (context, _) {
            final t = _a.value;
            // Up and down on a parabola, then two little bounces.
            double height;
            if (t < _flight) {
              final f = t / _flight;
              height = 4 * f * (1 - f) * apex;
            } else {
              final b = (t - _flight) / (1 - _flight);
              height = (sin(b * pi * 2).abs() * 22 * (1 - b)).toDouble();
            }
            // Spin about the horizontal axis; ends flat on the winner's face.
            final turns = widget.spins + (widget.winner == 1 ? 0.5 : 0);
            final angle = Curves.easeOut.transform((t / _flight).clamp(0, 1)) * turns * 2 * pi;
            final squash = cos(angle);
            final showingHeads = squash >= 0;
            final tilt = Matrix4.diagonal3Values(1, max(squash.abs(), 0.06), 1);
            final shadow = 1 - height / (apex + 70);
            return Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Shadow on the ground, smaller the higher the coin.
                Positioned(
                  bottom: 20,
                  child: Container(
                    width: coin * 0.8 * shadow,
                    height: 16 * shadow,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35 * shadow),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 28 + height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // The coin's edge shows under the face as it tilts.
                      Transform.translate(
                        offset: Offset(0, 4 + 12 * (1 - squash.abs())),
                        child: Transform(
                          alignment: Alignment.center,
                          transform: tilt,
                          child: _Edge(size: coin),
                        ),
                      ),
                      Transform(
                        alignment: Alignment.center,
                        transform: tilt,
                        child: _Face(
                          game: showingHeads ? widget.heads : widget.tails,
                          side: showingHeads ? 'Heads' : 'Tails',
                          size: coin,
                          edge: squash.abs() < 0.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
      final result = AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: _landed ? 1 : 0,
        child: Column(
          children: [
            ToonBox(
              color: Toon.yellow,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('${_won.name} it is!', style: Toon.text(22, weight: FontWeight.w700)),
            ),
            const SizedBox(height: 10),
            ToonButton(
              key: const Key('coin done'),
              color: Toon.green,
              onPressed: _landed ? widget.onDone : null,
              child: const Text("Let's play"),
            ),
          ],
        ),
      );
      if (wide) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: coin + 60, child: stage),
            const SizedBox(width: 24),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [...titles, const SizedBox(height: 16), result],
              ),
            ),
          ],
        );
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [...titles, const SizedBox(height: 8), stage, result],
      );
    },
  );
}

class _Edge extends StatelessWidget {
  const _Edge({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFFB8761A),
      shape: BoxShape.circle,
      border: Border.all(color: Toon.ink, width: 3),
    ),
  );
}

/// One face of the gold coin: the game's art and name.
class _Face extends StatelessWidget {
  const _Face({required this.game, required this.side, required this.size, required this.edge});

  final GameInfo game;
  final String side;
  final double size;

  /// Seen nearly edge-on: just the rim.
  final bool edge;

  static const _gold = Color(0xFFFFC745);
  static const _goldDark = Color(0xFFE09A1F);

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: _goldDark,
      shape: BoxShape.circle,
      border: Border.all(color: Toon.ink, width: 3),
    ),
    padding: EdgeInsets.all(size * 0.07),
    child: edge
        ? null
        : Container(
            decoration: BoxDecoration(
              color: _gold,
              shape: BoxShape.circle,
              border: Border.all(color: Toon.ink.withValues(alpha: 0.5), width: 2),
            ),
            padding: EdgeInsets.all(size * 0.1),
            // Drawn for the full-size coin and scaled down for smaller ones.
            child: FittedBox(
              child: SizedBox(
                width: 112,
                height: 112,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(side.toUpperCase(), style: Toon.text(11, color: Toon.ink.withValues(alpha: 0.6))),
                    SizedBox(height: 50, child: FittedBox(child: game.art(context))),
                    const SizedBox(height: 4),
                    Text(
                      game.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: Toon.text(14, weight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
  );
}
