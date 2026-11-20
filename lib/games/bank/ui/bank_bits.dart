import 'dart:math';

import 'package:duel_engine/bank/bank.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/toon.dart';
import '../dice.dart';

/// How long the dice take to land.
const diceRollMs = 1150;

/// Two dice thrown onto the table when [roll] changes: they fly in on an
/// arc from below, tumbling end over end (faces flickering, shadows
/// shrinking as they rise), slam down with a squash and a puff of dust,
/// bounce once and settle on [a] and [b]. Doubles glow as they land.
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
              if (!landed && ms > 700 && ms < 1000) ..._dust(ms, w, h),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _die(int k, int value, double ms, bool landed, double w, double h) {
    final rng = Random(roll * 97 + k * 13 + (ms / 70).floor());
    // Each die lands a little apart in time.
    final land = 700.0 + k * 70;
    final rest = Offset(w / 2 + (k == 0 ? -size * 0.62 : size * 0.62), h - size * 0.62);
    final start = Offset(k == 0 ? -size * 1.2 : w + size * 1.2, h + size * 1.6);
    Offset at;
    double angle, sx = 1, sy = 1, lift;
    int face;
    if (ms < land) {
      // In the air: an arc in, spinning down, end over end.
      final u = ms / land;
      final e = Curves.easeOutQuad.transform(u);
      at = Offset.lerp(start, rest, e)! - Offset(0, sin(u * pi) * size * 1.5);
      angle = (1 - e) * (k == 0 ? 9 : -10);
      final tumble = cos(u * pi * 7 + k);
      sy = 0.55 + 0.45 * tumble.abs();
      sx = 1.08 - 0.08 * tumble.abs();
      lift = sin(u * pi);
      face = 1 + rng.nextInt(6);
    } else {
      final v = ((ms - land) / (diceRollMs - land)).clamp(0.0, 1.0);
      // Slam, squash, one bounce, settle.
      final bounce = v < 0.25 ? 0.0 : sin((v - 0.25) / 0.75 * pi) * (1 - v) * size * 0.35;
      at = rest - Offset(0, bounce);
      final squash = v < 0.18 ? sin(v / 0.18 * pi) * 0.22 : 0.0;
      sx = 1 + squash;
      sy = 1 - squash;
      angle = (k == 0 ? -0.14 : 0.16) + (1 - v) * (k == 0 ? -0.4 : 0.35);
      lift = bounce / size;
      face = value;
    }
    if (landed) {
      at = rest;
      angle = k == 0 ? -0.14 : 0.16;
      sx = sy = 1;
      lift = 0;
      face = value;
    }
    final glow = landed && a == b;
    return [
      // Its shadow on the felt, smaller and fainter the higher it is.
      Positioned(
        left: at.dx - size * 0.5 * (1 - lift * 0.4),
        top: rest.dy + size * 0.42,
        child: Opacity(
          opacity: (0.35 - lift * 0.2).clamp(0.05, 0.35),
          child: Container(
            width: size * (1 - lift * 0.4),
            height: size * 0.22,
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(size)),
          ),
        ),
      ),
      Positioned(
        left: at.dx - size / 2,
        top: at.dy - size / 2,
        child: Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.diagonal3Values(sx, sy, 1),
          child: Container(
            decoration: glow
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(size * 0.2),
                    boxShadow: [
                      BoxShadow(color: Toon.yellow.withValues(alpha: 0.8), blurRadius: 18, spreadRadius: 4),
                    ],
                  )
                : null,
            child: Die(face, size: size, angle: angle, color: color ?? Toon.cardFace),
          ),
        ),
      ),
    ];
  }

  /// A puff of dust where they hit.
  List<Widget> _dust(double ms, double w, double h) {
    final u = ((ms - 700) / 300).clamp(0.0, 1.0);
    final rng = Random(roll);
    return [
      for (var i = 0; i < 10; i++)
        () {
          final ang = pi + rng.nextDouble() * pi;
          final d = size * (0.6 + u * (0.7 + rng.nextDouble() * 0.6));
          final c = Offset(w / 2 + (i.isEven ? -1 : 1) * size * 0.6, h - size * 0.2);
          final p = c + Offset(cos(ang) * d, sin(ang) * d * 0.35);
          final r = size * 0.09 * (1 - u * 0.5);
          return Positioned(
            left: p.dx - r,
            top: p.dy - r,
            child: Opacity(
              opacity: (1 - u) * 0.7,
              child: Container(
                width: r * 2,
                height: r * 2,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
            ),
          );
        }(),
    ];
  }
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
