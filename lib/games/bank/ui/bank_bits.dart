import 'dart:math';

import 'package:duel_engine/bank/bank.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/toon.dart';
import '../dice.dart';

/// Two dice that tumble when [roll] changes, then land on [a] and [b].
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

  /// Bumped on every roll (restarts the tumble).
  final int roll;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey('roll$roll'),
    tween: Tween(begin: roll == 0 ? 1 : 0, end: 1),
    duration: const Duration(milliseconds: 750),
    builder: (context, t, _) {
      final rng = Random(roll * 31 + (t * 12).floor());
      final landed = t >= 1;
      final bounce = landed ? 0.0 : sin(t * pi * 3) * (1 - t) * size * 0.35;
      Widget die(int v, int k) => Transform.translate(
        offset: Offset(0, -bounce.abs()),
        child: Die(
          landed ? v : 1 + rng.nextInt(6),
          size: size,
          angle: landed ? (k == 0 ? -0.12 : 0.15) : (1 - t) * (k == 0 ? 6 : -7),
          color: color ?? Toon.cardFace,
        ),
      );
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          die(a, 0),
          SizedBox(width: size * 0.25),
          die(b, 1),
        ],
      );
    },
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
