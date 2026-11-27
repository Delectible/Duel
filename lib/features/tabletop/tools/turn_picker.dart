import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/sound/sound.dart';
import '../../../core/theme/toon.dart';
import '../scorer/presets.dart';
import 'tool_page.dart';

/// Who goes first: everyone puts a finger on the screen; once they've all
/// held still for a moment the circles spin round and one is picked (or,
/// in Order, every finger gets its number). Lift every finger to go again.
class TurnPicker extends StatefulWidget {
  const TurnPicker({super.key, this.seed});

  final int? seed;

  @override
  State<TurnPicker> createState() => _TurnPickerState();
}

enum _Mode { one, order }

class _TurnPickerState extends State<TurnPicker> with TickerProviderStateMixin {
  late final Random _rng = Random(widget.seed);
  final Map<int, Offset> _fingers = {};
  final Map<int, int> _colors = {};
  var _mode = _Mode.one;

  /// Counting down to the pick (restarts when a finger comes or goes).
  Timer? _wait;
  late final AnimationController _count = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  /// The pick: the winning finger, or every finger's place.
  int? _winner;
  Map<int, int>? _order;
  bool get _picked => _winner != null || _order != null;

  @override
  void dispose() {
    _wait?.cancel();
    _count.dispose();
    _pulse.dispose();
    _reveal.dispose();
    super.dispose();
  }

  void _restart() {
    _wait?.cancel();
    _count.reset();
    if (_picked) return;
    if (_fingers.length >= 2) {
      _count.forward();
      _wait = Timer(_count.duration!, _pick);
    }
  }

  void _pick() {
    if (!mounted || _fingers.length < 2) return;
    final ids = _fingers.keys.toList()..shuffle(_rng);
    setState(() {
      if (_mode == _Mode.one) {
        _winner = ids.first;
      } else {
        _order = {for (final (i, id) in ids.indexed) id: i + 1};
      }
    });
    HapticFeedback.heavyImpact();
    Sound.play(Sfx.winSmall);
    _reveal.forward(from: 0);
  }

  void _down(PointerDownEvent e) {
    if (_picked) return;
    setState(() {
      _fingers[e.pointer] = e.localPosition;
      final used = _colors.values.toSet();
      _colors[e.pointer] = List.generate(
        scoreColors.length,
        (i) => i,
      ).firstWhere((i) => !used.contains(i), orElse: () => 0);
    });
    Sound.play(Sfx.tap, gain: 0.5);
    HapticFeedback.selectionClick();
    _restart();
  }

  void _move(PointerMoveEvent e) {
    if (!_fingers.containsKey(e.pointer)) return;
    setState(() => _fingers[e.pointer] = e.localPosition);
  }

  void _up(PointerEvent e) {
    if (!_fingers.containsKey(e.pointer)) return;
    setState(() {
      if (!_picked || _fingers.length == 1) {
        _fingers.remove(e.pointer);
        _colors.remove(e.pointer);
      } else {
        // Picked: the circles stay until everyone lets go.
        _fingers.remove(e.pointer);
      }
      if (_fingers.isEmpty) {
        _winner = null;
        _order = null;
        _colors.clear();
        _reveal.reset();
      }
    });
    _restart();
  }

  @override
  Widget build(BuildContext context) => ToolPage(
    title: 'Who\'s first?',
    subtitle: _mode == _Mode.one
        ? 'Everyone put a finger on the screen'
        : 'Everyone put a finger down for the order',
    background: const Color(0xFF1B1B2F),
    actions: [
      for (final m in _Mode.values)
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: ToonButton(
            key: Key('mode ${m.name}'),
            color: m == _mode ? Toon.yellow : Toon.card,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            onPressed: () => setState(() => _mode = m),
            child: Text(
              m == _Mode.one ? 'One' : 'Order',
              style: TextStyle(color: m == _mode ? Toon.inkLight : null),
            ),
          ),
        ),
    ],
    child: Listener(
      key: const Key('touch area'),
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: AnimatedBuilder(
        animation: Listenable.merge([_count, _pulse, _reveal]),
        builder: (context, _) => CustomPaint(
          painter: _FingersPainter(
            fingers: _fingers,
            colors: _colors,
            count: _count.value,
            pulse: _pulse.value,
            reveal: Curves.easeOutBack.transform(_reveal.value),
            winner: _winner,
            order: _order,
          ),
          child: Center(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _fingers.isEmpty ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.touch_app_rounded, size: 72, color: Colors.white54),
                    const SizedBox(height: 10),
                    Text(
                      'Two or more fingers,\nthen hold still',
                      textAlign: TextAlign.center,
                      style: Toon.text(20, weight: FontWeight.w700, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _FingersPainter extends CustomPainter {
  _FingersPainter({
    required this.fingers,
    required this.colors,
    required this.count,
    required this.pulse,
    required this.reveal,
    required this.winner,
    required this.order,
  });

  final Map<int, Offset> fingers;
  final Map<int, int> colors;
  final double count, pulse, reveal;
  final int? winner;
  final Map<int, int>? order;

  @override
  void paint(Canvas canvas, Size size) {
    final base = min(size.width, size.height) * 0.13;
    // The winner's colour floods the screen.
    if (winner != null && reveal > 0) {
      final at = fingers[winner] ?? size.center(Offset.zero);
      canvas.drawCircle(
        at,
        size.longestSide * 1.2 * reveal.clamp(0.0, 1.0),
        Paint()..color = scoreColor(colors[winner] ?? 0).withValues(alpha: 0.35),
      );
    }
    for (final MapEntry(key: id, value: at) in fingers.entries) {
      final color = scoreColor(colors[id] ?? 0);
      final lost = winner != null && id != winner;
      final won = winner == id;
      final r = base * (won ? 1 + 0.5 * reveal : (lost ? 1 - 0.5 * reveal : 1));
      final alpha = lost ? (1 - reveal).clamp(0.2, 1.0) : 1.0;
      // A soft halo that breathes, a ring, and a filled middle.
      canvas.drawCircle(
        at,
        r * (1.25 + 0.15 * sin(pulse * 2 * pi)),
        Paint()..color = color.withValues(alpha: 0.25 * alpha),
      );
      canvas.drawCircle(at, r, Paint()..color = color.withValues(alpha: alpha));
      canvas.drawCircle(
        at,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = Colors.white.withValues(alpha: 0.9 * alpha),
      );
      // The countdown: an arc filling round each circle.
      if (count > 0 && winner == null && order == null) {
        canvas.drawArc(
          Rect.fromCircle(center: at, radius: r + 10),
          -pi / 2,
          2 * pi * count,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round
            ..color = Colors.white,
        );
      }
      final place = order?[id];
      if (place != null || won) {
        final tp = TextPainter(
          text: won
              ? TextSpan(
                  text: String.fromCharCode(Icons.star_rounded.codePoint),
                  style: TextStyle(
                    fontFamily: Icons.star_rounded.fontFamily,
                    package: Icons.star_rounded.fontPackage,
                    fontSize: r * 1.1,
                    color: Toon.on(color),
                  ),
                )
              : TextSpan(
                  text: '$place',
                  style: Toon.text(r * 0.9, weight: FontWeight.w700, color: Toon.on(color)),
                ),
          textDirection: TextDirection.ltr,
        )..layout();
        canvas.save();
        canvas.translate(at.dx, at.dy);
        canvas.scale(order != null ? reveal.clamp(0.0, 1.2) : 1);
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_FingersPainter old) => true;
}
