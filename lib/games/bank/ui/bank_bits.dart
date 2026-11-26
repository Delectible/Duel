import 'dart:math';

import 'package:duel_engine/bank/bank.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/toon.dart';
import '../dice.dart';

/// How long the dice take to land.
const diceRollMs = 1300;

/// Two dice thrown onto the table when [roll] changes: they fly up from
/// the bottom (where you swiped) on an arc, tumbling end over end in 3D,
/// land with a thud, skid a little on a bounce and settle on [a] and [b].
/// Doubles glow as they land.
class RollingDice extends StatelessWidget {
  const RollingDice({
    super.key,
    required this.a,
    required this.b,
    required this.roll,
    this.size = 80,
    this.color,
  });

  final int a, b;

  /// Bumped on every roll (restarts the throw).
  final int roll;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final w = size * 2.6, h = size * 1.9;
    return SizedBox(
      width: w,
      height: h,
      child: TweenAnimationBuilder<double>(
        key: ValueKey('roll$roll'),
        tween: Tween(begin: roll == 0 ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: diceRollMs),
        builder: (context, t, _) {
          final ms = t * diceRollMs;
          final landed = t >= 1;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (final k in [0, 1]) ..._die(k, k == 0 ? a : b, ms, landed, w, h),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _die(int k, int value, double ms, bool landed, double w, double h) {
    final rng = Random(roll * 97 + k * 13);
    // Where it settles, and how it's turned there.
    // Always turned enough to show a side.
    final yaw = (k == 0 ? -1 : 1) * (0.32 + rng.nextDouble() * 0.4);
    final rest = Offset(
      w / 2 + (k == 0 ? -size * 0.62 : size * 0.62) + (rng.nextDouble() - 0.5) * size * 0.15,
      h - size * 0.6 + (rng.nextDouble() - 0.5) * size * 0.12,
    );
    final rested = Turn.yaw(yaw) * faceUp(value);
    // It tumbles about a roughly horizontal axis (rolling away from you),
    // whole turns plus a bit, slowing as it settles.
    final axisAngle = (k == 0 ? 0.3 : -0.3) + (rng.nextDouble() - 0.5) * 0.8;
    final axis = (cos(axisAngle), sin(axisAngle), 0.0);
    final spins = (3 + rng.nextInt(2)) * 2 * pi;
    // Each die lands a little apart in time.
    final land = 760.0 + k * 80;
    final start = Offset(w / 2 + (k == 0 ? -size * 0.3 : size * 0.3), h + size * 1.8);
    Offset at;
    double lift, spin;
    if (landed) {
      at = rest;
      lift = 0;
      spin = 0;
    } else if (ms < land) {
      // In the air: up from below on an arc, tumbling.
      final u = ms / land;
      final e = Curves.easeOutCubic.transform(u);
      at = Offset.lerp(start, rest - Offset(0, size * 0.25), e)! - Offset(0, sin(u * pi) * size * 1.2);
      lift = sin(u * pi) * 0.8 + (1 - u) * 0.4;
      spin = spins * (1 - e) + 0.9;
    } else {
      // Down: one low bounce, a skid forward, rocking to a stop.
      final v = ((ms - land) / (diceRollMs - land)).clamp(0.0, 1.0);
      final bounce = v < 0.55 ? sin(v / 0.55 * pi) * size * 0.28 : 0.0;
      final skid = Curves.easeOutCubic.transform(v);
      at = Offset.lerp(rest - Offset(0, size * 0.25), rest, skid)! - Offset(0, bounce);
      lift = bounce / size;
      spin = 0.9 * (1 - Curves.easeOutBack.transform(v));
    }
    final turn = spin == 0 ? rested : Turn.about(axis, spin) * rested;
    final glow = landed && a == b;
    return [
      // Its shadow on the felt while it's up, smaller the higher it is.
      // (On the table the die's own shadow does.)
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
      Positioned(
        left: at.dx - size / 2,
        top: at.dy - size / 2 - lift * size * 0.3,
        child: Container(
          decoration: glow
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(size * 0.3),
                  boxShadow: [
                    BoxShadow(color: Toon.yellow.withValues(alpha: 0.75), blurRadius: 20, spreadRadius: 2),
                  ],
                )
              : null,
          child: RepaintBoundary(
            child: CustomPaint(size: Size.square(size), painter: CubePainter(turn, color ?? Toon.cardFace)),
          ),
        ),
      ),
    ];
  }
}

/// Swipe up (or tap) to roll: wraps the dice area, says so with a hint
/// that bobs while [enabled].
class SwipeToRoll extends StatelessWidget {
  const SwipeToRoll({super.key, required this.enabled, required this.onRoll, required this.child, this.hint});

  final bool enabled;
  final VoidCallback onRoll;
  final Widget child;

  /// Under the dice while you can roll ("Swipe up to roll").
  final String? hint;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: enabled ? onRoll : null,
    onVerticalDragEnd: enabled
        ? (d) {
            if ((d.primaryVelocity ?? 0) < -150) onRoll();
          }
        : null,
    child: Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        child,
        if (enabled && hint != null) Positioned(bottom: -4, child: IgnorePointer(child: SwipeHint(hint!))),
      ],
    ),
  );
}

/// "Swipe up to roll": bobs a few times, then rests.
class SwipeHint extends StatefulWidget {
  const SwipeHint(this.text, {super.key});

  final String text;

  @override
  State<SwipeHint> createState() => SwipeHintState();
}

class SwipeHintState extends State<SwipeHint> with SingleTickerProviderStateMixin {
  // Bobs a few times, then rests (it's still there).
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat(count: 3);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, child) =>
          Transform.translate(offset: Offset(0, -sin(_c.value * pi) * 6), child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.keyboard_double_arrow_up_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 4),
            Text(
              widget.text,
              style: Toon.text(14, weight: FontWeight.w700, color: Colors.white),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The bank's total, counting up (or crashing to zero) when it changes.
class BankTotal extends StatelessWidget {
  const BankTotal({super.key, required this.value, this.size = 44, this.color = Colors.white});

  final int value;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: value.toDouble()),
    duration: const Duration(milliseconds: 600),
    curve: Curves.easeOutCubic,
    builder: (context, v, _) => Text(
      '${v.round()}',
      style: Toon.text(size, weight: FontWeight.w700, color: color),
    ),
  );
}

/// What a roll did, said big: "+70!", "DOUBLED!", "SEVEN! Bank's gone".
(String, Color, bool)? rollReaction(BankRoll r, {int danger = 300}) => switch (r.kind) {
  BankRollKind.safeSeven => ('Lucky 7! +70', Toon.green, false),
  BankRollKind.doubled => (
    r.after >= danger * 2 ? 'DOUBLED! ${r.after}!' : 'Doubles! ×2',
    Toon.yellow,
    r.after >= danger * 2,
  ),
  BankRollKind.bust => (
    r.before >= danger ? 'SEVEN! ${r.before} gone!' : 'Seven! Round over',
    Toon.red,
    r.before >= danger,
  ),
  BankRollKind.add when r.doubles => ('Doubles: +${r.sum}', Toon.blue, false),
  BankRollKind.add => null,
};

/// A word popping over the dice, bigger for the big moments; a seven at
/// high stakes shakes.
class RollPop extends StatelessWidget {
  const RollPop({super.key, required this.text, required this.color, this.big = false, this.shake = false});

  final String text;
  final Color color;
  final bool big;
  final bool shake;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: big ? 2000 : 1400),
    builder: (context, t, _) {
      if (t >= 1) return const SizedBox.shrink();
      final grow = Curves.elasticOut.transform((t / 0.4).clamp(0, 1));
      final dx = shake && t < 0.5 ? sin(t * 60) * 10 * (0.5 - t) * 2 : 0.0;
      return Center(
        child: Opacity(
          opacity: t < 0.8 ? 1 : (1 - t) / 0.2,
          child: Transform.translate(
            offset: Offset(dx, 0),
            child: Transform.rotate(
              angle: big ? -0.05 : 0,
              child: Transform.scale(
                scale: (0.3 + 0.7 * grow) * (big ? 1.5 : 1),
                child: ToonBox(
                  color: color,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    text,
                    style: Toon.text(24, weight: FontWeight.w700, color: Toon.on(color)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// A red flash over everything (a seven at high stakes).
class Flash extends StatelessWidget {
  const Flash({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 0),
      duration: const Duration(milliseconds: 700),
      builder: (context, t, _) => ColoredBox(color: color.withValues(alpha: t)),
    ),
  );
}

/// "Safe: 2 rolls left" / "Danger: a 7 ends it".
Widget safetyChip(BankGame g) {
  final left = bankSafeRolls - g.rolls;
  final safe = left > 0;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: safe ? Toon.green : Toon.red,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Toon.inkLight, width: 2),
    ),
    child: Text(
      safe ? 'Safe · ${left == 1 ? '1 roll' : '$left rolls'} left' : 'Danger · a 7 ends it',
      style: Toon.text(13, weight: FontWeight.w700, color: Toon.on(safe ? Toon.green : Toon.red)),
    ),
  );
}
