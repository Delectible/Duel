import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/toon.dart';
import 'dice.dart';

/// How long a throw takes to land.
const throwMs = 1300;

/// Any number of dice thrown onto a tray when [roll] changes, the same
/// throw as Bank!'s pair: up from the bottom on an arc, tumbling in 3D, a
/// bounce, a skid, settling on [values] where they land (scattered, never
/// on top of each other). Tap one to pick it ([onTap]); [picked] ones lift
/// and glow; [faded] ones are dimmed (they don't score).
class ThrownDice extends StatelessWidget {
  const ThrownDice({
    super.key,
    required this.values,
    required this.roll,
    required this.size,
    required this.area,
    this.picked = const {},
    this.faded = const {},
    this.hidden = const {},
    this.onTap,
    this.color,
  });

  final List<int> values;
  final int roll;
  final double size;

  /// The tray they land in.
  final Size area;
  final Set<int> picked;
  final Set<int> faded;

  /// Dice taken off the tray (set aside elsewhere): not drawn, the rest
  /// stay where they landed.
  final Set<int> hidden;
  final ValueChanged<int>? onTap;
  final Color? color;

  /// Where each die comes to rest: a loose grid (3 across), jittered by the
  /// roll so no two throws look alike.
  List<(Offset, double)> _rests() {
    final n = values.length;
    final cols = min(3, max(1, n));
    final rows = (n / cols).ceil();
    final cw = area.width / cols, rh = min(area.height / max(rows, 1), size * 1.7);
    final top = (area.height - rh * rows) / 2;
    final rng = Random(roll * 131 + n);
    return [
      for (var i = 0; i < n; i++)
        () {
          final r = i ~/ cols, c = i % cols;
          final inRow = min(cols, n - r * cols);
          final x0 = (area.width - cw * inRow) / 2;
          return (
            Offset(
              x0 + cw * (c + 0.5) + (rng.nextDouble() - 0.5) * (cw - size * 1.15).clamp(0, cw) * 0.6,
              top + rh * (r + 0.5) + (rng.nextDouble() - 0.5) * (rh - size * 1.1).clamp(0, rh) * 0.6,
            ),
            (rng.nextDouble() - 0.5) * 0.9,
          );
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final rests = _rests();
    return SizedBox.fromSize(
      size: area,
      child: TweenAnimationBuilder<double>(
        key: ValueKey('throw$roll'),
        tween: Tween(begin: roll == 0 ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: throwMs),
        builder: (context, t, _) {
          final ms = t * throwMs;
          return Stack(
            clipBehavior: Clip.none,
            children: [for (var k = 0; k < values.length; k++) ..._die(k, ms, t >= 1, rests[k])],
          );
        },
      ),
    );
  }

  List<Widget> _die(int k, double ms, bool landed, (Offset, double) restAt) {
    final rng = Random(roll * 97 + k * 13);
    final (rest, yaw) = restAt;
    final rested = Turn.yaw(yaw) * faceUp(values[k]);
    final axisAngle = (k.isEven ? 0.3 : -0.3) + (rng.nextDouble() - 0.5) * 0.8;
    final axis = (cos(axisAngle), sin(axisAngle), 0.0);
    final spins = (3 + rng.nextInt(2)) * 2 * pi;
    final land = 700.0 + k * 45;
    final start = Offset(area.width / 2 + (rng.nextDouble() - 0.5) * size, area.height + size * 1.6);
    Offset at;
    double lift, spin;
    if (landed) {
      at = rest;
      lift = 0;
      spin = 0;
    } else if (ms < land) {
      final u = ms / land;
      final e = Curves.easeOutCubic.transform(u);
      at = Offset.lerp(start, rest - Offset(0, size * 0.25), e)! - Offset(0, sin(u * pi) * size * 1.1);
      lift = sin(u * pi) * 0.8 + (1 - u) * 0.4;
      spin = spins * (1 - e) + 0.9;
    } else {
      final v = ((ms - land) / (throwMs - land)).clamp(0.0, 1.0);
      final bounce = v < 0.55 ? sin(v / 0.55 * pi) * size * 0.25 : 0.0;
      final skid = Curves.easeOutCubic.transform(v);
      at = Offset.lerp(rest - Offset(0, size * 0.25), rest, skid)! - Offset(0, bounce);
      lift = bounce / size;
      spin = 0.9 * (1 - Curves.easeOutBack.transform(v));
    }
    final turn = spin == 0 ? rested : Turn.about(axis, spin) * rested;
    final up = landed && picked.contains(k);
    final dim = landed && faded.contains(k);
    return [
      if (lift > 0.02)
        Positioned(
          left: at.dx - size * 0.45 * (1 - lift * 0.4),
          top: rest.dy + size * 0.2,
          child: Opacity(
            opacity: (0.3 * min(1.0, lift * 4) - lift * 0.15).clamp(0.0, 0.3),
            child: Container(
              width: size * 0.9 * (1 - lift * 0.4),
              height: size * 0.24,
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(size)),
            ),
          ),
        ),
      AnimatedPositioned(
        key: ValueKey('die$k'),
        duration: Duration(milliseconds: landed ? 160 : 0),
        left: at.dx - size / 2,
        top: at.dy - size / 2 - lift * size * 0.3 - (up ? size * 0.18 : 0),
        child: GestureDetector(
          key: Key('die $k'),
          behavior: HitTestBehavior.opaque,
          onTap: landed && onTap != null ? () => onTap!(k) : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: dim ? 0.45 : 1,
            child: Container(
              decoration: up
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(size * 0.3),
                      boxShadow: [
                        BoxShadow(
                          color: Toon.yellow.withValues(alpha: 0.85),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    )
                  : null,
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size.square(size),
                  painter: CubePainter(turn, color ?? Toon.cardFace),
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }
}
