import 'dart:math';

import '../difficulty.dart';
import 'bank.dart';

/// How a bot plays the bank.
enum BankStyle {
  /// Banks early and often.
  chicken,

  /// Waits for a decent bank.
  steady,

  /// Rides it as long as it dares.
  daredevil,
}

/// Decides after each roll whether to bank. Each round it picks a target
/// (from its style, plus some luck), then shifts it by the scores: behind
/// the leader with few rounds left it pushes harder, ahead it plays safe.
/// Hard bots also bank when they'd lock up a win, and stay in to beat the
/// others when everyone else has banked.
class BankBot {
  BankBot({required this.me, required this.style, required this.difficulty, Random? rng})
    : _rng = rng ?? Random();

  final int me;
  final BankStyle style;
  final Difficulty difficulty;
  final Random _rng;

  int _round = 0;
  double _target = 0;

  double _base() => switch (style) {
    BankStyle.chicken => 110,
    BankStyle.steady => 180,
    BankStyle.daredevil => 320,
  };

  /// Should it bank now? Only asked while it's still in and can bank.
  bool wantsToBank(BankGame g) {
    if (!g.canBank(me)) return false;
    if (g.round != _round) {
      _round = g.round;
      // Luck of the round: a bit lower or higher.
      _target = _base() * (0.7 + _rng.nextDouble() * 0.7);
    }
    // Never bank on the safe rolls unless it's a lot already.
    if (g.safe && g.bank < _target * 0.9) return false;
    final leader = [
      for (var p = 0; p < g.players; p++)
        if (p != me) g.scores[p],
    ].fold(0, max);
    final gap = leader - g.scores[me];
    final left = g.rounds - g.round + 1;
    var target = _target;
    if (difficulty != Difficulty.easy) {
      if (gap > 0) target += gap / left * (difficulty == Difficulty.hard ? 0.9 : 0.5);
      if (gap < 0) target *= 0.85;
    }
    final others = [
      for (final p in g.stillIn)
        if (p != me) p,
    ];
    if (difficulty == Difficulty.hard) {
      // The last round: bank the moment it puts us top.
      if (left == 1 && g.scores[me] + g.bank > leader && (others.isEmpty || gap > 0)) return true;
      // Alone in the round and behind: keep going until it's worth it.
      if (others.isEmpty && left == 1 && g.scores[me] + g.bank <= leader) return false;
    }
    // Each roll past the safe ones, a little more nervous.
    final nerves = max(0, g.rolls - bankSafeRolls) * (style == BankStyle.daredevil ? 0.02 : 0.05);
    target *= (1 - nerves).clamp(0.4, 1.0);
    // Easy bots wobble.
    if (difficulty == Difficulty.easy) target *= 0.6 + _rng.nextDouble() * 0.8;
    return g.bank >= target;
  }
}
