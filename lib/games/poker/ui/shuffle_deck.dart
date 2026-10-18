import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/cards/card_view.dart';
import '../../../core/theme/toon.dart';

/// The deck on the table when it's your deal. Tap or swipe it to riffle:
/// it splits into two halves that lean apart, then the cards fall back
/// together alternately from each side.
class ShuffleDeck extends StatefulWidget {
  const ShuffleDeck({super.key, required this.shuffles, required this.onShuffle, this.cardWidth = 54});

  final int shuffles;
  final VoidCallback onShuffle;
  final double cardWidth;

  @override
  State<ShuffleDeck> createState() => _ShuffleDeckState();
}

class _ShuffleDeckState extends State<ShuffleDeck> with SingleTickerProviderStateMixin {
  static const _cards = 12;
  late final _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
  var _midBuzz = false;

  @override
  void initState() {
    super.initState();
    _a.addListener(() {
      // A second buzz as the halves riffle back in.
      if (!_midBuzz && _a.value > 0.45) {
        _midBuzz = true;
        HapticFeedback.selectionClick();
      }
    });
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  void _shuffle() {
    if (_a.isAnimating) return;
    HapticFeedback.lightImpact();
    _midBuzz = false;
    widget.onShuffle();
    _a.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.cardWidth;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Your deal!',
          style: Toon.text(22, weight: FontWeight.w700, color: Colors.white),
        ),
        const SizedBox(height: 2),
        // Gets cheeky if you keep going.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Text(
            switch (widget.shuffles) {
              0 => 'Tap or swipe the deck to shuffle',
              < 10 => 'Shuffled ×${widget.shuffles}. Again, or deal',
              < 20 => 'Shuffled ×${widget.shuffles}. Not random enough for you?',
              < 30 => 'Shuffled ×${widget.shuffles}. The cards are getting dizzy…',
              _ => 'Shuffled ×${widget.shuffles}. They\'re shuffled. Promise.',
            },
            textAlign: TextAlign.center,
            style: Toon.text(15, weight: FontWeight.w500, color: Colors.white),
          ),
        ),
        const SizedBox(height: 14),
        Semantics(
          button: true,
          label: 'Shuffle the deck',
          child: GestureDetector(
            key: const Key('deck'),
            behavior: HitTestBehavior.opaque,
            onTap: _shuffle,
            onHorizontalDragEnd: (_) => _shuffle(),
            child: SizedBox(
              width: w * 3.2,
              height: w * 1.4 + 40,
              child: AnimatedBuilder(
                animation: _a,
                builder: (context, _) => Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [for (var i = 0; i < _cards; i++) _card(i, w)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Card [i] (0 = bottom). Even cards go to the left half, odd to the
  /// right; on the way back each lands a moment after the one below it.
  Widget _card(int i, double w) {
    final t = _a.value;
    final left = i.isEven;
    final side = left ? -1.0 : 1.0;
    // Split: 0..0.4, riffle back: 0.4..1, staggered from the bottom up.
    final split = Curves.easeOut.transform((t / 0.4).clamp(0, 1));
    final land = Curves.easeIn.transform(((t - 0.4 - i * 0.025) / 0.3).clamp(0, 1));
    final apart = split * (1 - land);
    final dx = side * apart * w * 0.85;
    final lift = sin(apart * pi / 2) * 10;
    final angle = side * apart * 0.28;
    final stackY = -i * 1.2;
    return Transform.translate(
      offset: Offset(dx, stackY - lift),
      child: Transform.rotate(
        angle: angle,
        child: CardView(card: null, width: w, faceUp: false),
      ),
    );
  }
}
