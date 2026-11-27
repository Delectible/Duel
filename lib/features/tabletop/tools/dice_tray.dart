import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/sound/sound.dart';
import '../../../core/theme/toon.dart';
import '../../../games/bank/dice.dart';
import '../../../games/bank/thrown_dice.dart';
import '../../../games/bank/ui/bank_bits.dart';
import 'tool_page.dart';

/// Real dice when yours have gone missing: up to eight, thrown onto a felt
/// tray the way Bank! and Farkle throw them (swipe up or tap). Tap a die to
/// set it aside (it stays put while you roll the rest); the total and the
/// last few rolls show above.
class DiceTray extends StatefulWidget {
  const DiceTray({super.key, this.seed});

  final int? seed;

  @override
  State<DiceTray> createState() => _DiceTrayState();
}

class _DiceTrayState extends State<DiceTray> {
  late final Random _rng = Random(widget.seed);
  var _count = 2;
  List<int> _tray = [];

  /// Dice of this throw set aside (tray indices), and dice set aside
  /// before it.
  final Set<int> _held = {};
  final List<int> _kept = [];
  var _rollId = 0;
  var _landing = false;
  final List<List<int>> _history = [];

  int get _rolling => _count - _kept.length - _held.length;

  /// Everything set aside: before, and from this throw.
  List<int> get _aside => [..._kept, for (final i in _held) _tray[i]];

  void _roll() {
    if (_rolling <= 0 || _landing) return;
    setState(() {
      _kept.addAll([for (final i in _held) _tray[i]]);
      _held.clear();
      _tray = [for (var i = 0; i < _count - _kept.length; i++) 1 + _rng.nextInt(6)];
      _rollId++;
      _landing = true;
    });
    Sound.play(Sfx.shuffle);
    Future<void>.delayed(const Duration(milliseconds: throwMs + 40), () {
      if (!mounted) return;
      Sound.play(Sfx.drop);
      setState(() {
        _landing = false;
        _history.insert(0, [..._kept, ..._tray]);
        if (_history.length > 8) _history.removeLast();
      });
    });
  }

  void _keep(int i) {
    if (_landing) return;
    setState(() => _held.add(i));
    Sound.play(Sfx.place, gain: 0.5);
  }

  /// Back from the side: a die from this throw goes back where it lay; one
  /// from before rolls again next time.
  void _unkeep(int i) {
    if (_landing) return;
    setState(() {
      if (i < _kept.length) {
        _kept.removeAt(i);
      } else {
        _held.remove(_held.elementAt(i - _kept.length));
      }
    });
    Sound.play(Sfx.tap, gain: 0.5);
  }

  void _setCount(int n) {
    setState(() {
      _count = n.clamp(1, 8);
      _tray = [];
      _kept.clear();
      _held.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = [..._kept, ..._tray].fold(0, (a, b) => a + b);
    final aside = _aside;
    final shown = !_landing && (_tray.isNotEmpty || _kept.isNotEmpty);
    return ToolPage(
      title: 'Dice tray',
      subtitle: 'Swipe up to roll · tap a die to set it aside',
      actions: [
        ToonButton(
          color: Toon.card,
          padding: const EdgeInsets.all(8),
          onPressed: _count > 1 ? () => _setCount(_count - 1) : null,
          child: const Icon(Icons.remove_rounded, size: 18),
        ),
        SizedBox(
          width: 52,
          child: Column(
            children: [
              Text(
                '$_count',
                textAlign: TextAlign.center,
                style: Toon.text(20, weight: FontWeight.w700),
              ),
              Text(_count == 1 ? 'die' : 'dice', style: Toon.text(11, color: Toon.muted)),
            ],
          ),
        ),
        ToonButton(
          key: const Key('more dice'),
          color: Toon.card,
          padding: const EdgeInsets.all(8),
          onPressed: _count < 8 ? () => _setCount(_count + 1) : null,
          child: const Icon(Icons.add_rounded, size: 18),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          children: [
            // The total, and the rolls before.
            SizedBox(
              height: 64,
              child: Row(
                children: [
                  AnimatedOpacity(
                    opacity: shown ? 1 : 0.3,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: Toon.box(Toon.yellow, radius: 14, shadow: 2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            shown ? '$total' : '–',
                            key: const Key('dice total'),
                            style: Toon.text(28, weight: FontWeight.w700, color: Toon.inkLight),
                          ),
                          Text('total', style: Toon.text(11, color: Toon.inkLight)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final (i, r) in _history.indexed.skip(shown ? 1 : 0))
                            Opacity(
                              opacity: max(0.35, 1 - i * 0.12),
                              child: Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: Toon.box(Toon.card, radius: 10, shadow: 0),
                                child: Text(
                                  '${r.fold(0, (a, b) => a + b)}',
                                  style: Toon.text(15, weight: FontWeight.w700),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Set aside.
            SizedBox(
              height: 52,
              child: aside.isEmpty
                  ? Center(
                      child: Text('Tap a die to set it aside', style: Toon.text(13, color: Toon.muted)),
                    )
                  : Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final (i, d) in aside.indexed)
                            GestureDetector(
                              key: Key('kept $i'),
                              onTap: () => _unkeep(i),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(color: Toon.yellow.withValues(alpha: 0.8), blurRadius: 10),
                                    ],
                                  ),
                                  child: Die(d, size: 40),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF6B4423),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Toon.ink, width: Toon.outline),
                ),
                padding: const EdgeInsets.all(9),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const RadialGradient(
                      colors: [Color(0xFF8A2B3A), Color(0xFF55182A)],
                      radius: 0.95,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final area = Size(box.maxWidth, box.maxHeight);
                      final size = min(
                        box.maxWidth / 4.4,
                        box.maxHeight / (_rolling > 3 ? 3.6 : 2.4),
                      ).clamp(36.0, 92.0);
                      return SwipeToRoll(
                        key: const Key('roll'),
                        enabled: !_landing && _rolling > 0,
                        onRoll: _roll,
                        hint: _tray.isEmpty ? 'Swipe up to roll' : null,
                        child: Stack(
                          children: [
                            SizedBox.fromSize(size: area),
                            if (_tray.isNotEmpty)
                              ThrownDice(
                                values: _tray,
                                roll: _rollId,
                                size: size,
                                area: area,
                                hidden: _held,
                                onTap: _landing ? null : _keep,
                              ),
                            if (_rolling == 0)
                              Center(
                                child: Text(
                                  'All set aside: tap one to roll it again',
                                  textAlign: TextAlign.center,
                                  style: Toon.text(16, weight: FontWeight.w600, color: Colors.white70),
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
          ],
        ),
      ),
    );
  }
}
