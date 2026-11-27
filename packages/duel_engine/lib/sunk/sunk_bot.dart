import 'dart:math';

import '../difficulty.dart';
import 'sunk.dart';

/// How a bot dives.
enum SunkStyle {
  /// Comes up early with a small bag.
  cautious,

  /// Weighs it up.
  steady,

  /// Stays down far too long.
  greedy,
}

/// A bot's choice.
class SunkChoice {
  const SunkChoice.draw() : kind = 'draw', target = null, take = null;
  const SunkChoice.surface() : kind = 'surface', target = null, take = null;
  const SunkChoice.aim(int this.target) : kind = 'aim', take = null;
  const SunkChoice.chart({required bool this.take}) : kind = 'chart', target = null;

  final String kind;
  final int? target;
  final bool? take;

  Map<String, Object?> toJson() => {'kind': kind, 'target': ?target, 'take': ?take};
}

/// Plays Sunk: draws while what it stands to gain beats what it risks
/// (Normal and Hard count the sea; Easy guesses from the bag's size),
/// pushes harder when behind and near the end, aims Hooks and Cut Lines
/// at whoever hurts most, and reads Maps.
class SunkBot {
  SunkBot({required this.me, required this.difficulty, required this.style, Random? rng})
    : _rng = rng ?? Random();

  final int me;
  final Difficulty difficulty;
  final SunkStyle style;
  final Random _rng;

  double get _nerve => switch (style) {
    SunkStyle.cautious => 0.8,
    SunkStyle.steady => 1.0,
    SunkStyle.greedy => 1.3,
  };

  /// The chance the next card busts us, as this bot sees it.
  double _risk(SunkGame g) {
    if (g.air[me] > 0) return 0;
    if (difficulty == Difficulty.easy) {
      // A rough guess: about one card in eight per treasure held.
      return (g.bags[me].length * 0.11).clamp(0.0, 0.9);
    }
    return g.bustChance(me);
  }

  /// What a safe draw adds, on average (Hard knows what's left).
  double _gain(SunkGame g) {
    if (difficulty != Difficulty.hard) return 4.0;
    final left = g.unseen();
    var sum = 0.0, n = 0;
    left.forEach((id, count) {
      if (count <= 0 || !id.startsWith('t')) return;
      final v = int.parse(id.substring(1));
      if (g.holds(me, v)) return;
      sum += v * count;
      n += count;
    });
    return n == 0 ? 0 : sum / n;
  }

  bool wantsToDraw(SunkGame g) {
    final bag = g.worth(me);
    if (bag == 0) return true;
    final risk = _risk(g);
    var gain = _gain(g);
    // Close to five different (the haul bonus) or a run: the next card's worth more.
    final kinds = {for (final c in g.bags[me]) c.value}.length;
    if (kinds == sunkHaulSize - 1) gain += sunkHaulBonus * 0.8;
    if (!g.hasRun(me) && kinds >= 2) gain += 2;
    final leader = [
      for (var q = 0; q < g.players; q++)
        if (q != me) g.scores[q],
    ].fold(0, max);
    var nerve = _nerve;
    if (difficulty != Difficulty.easy) {
      final behind = leader - g.scores[me];
      // Someone's about to win: dive deep.
      if (leader >= g.target * 0.85 && behind > 0) nerve *= 1.5;
      if (behind > 40) nerve *= 1.15;
      // We'd win by surfacing now.
      if (g.scores[me] + bag >= g.target && g.scores[me] + bag > leader) return false;
    }
    if (difficulty == Difficulty.easy) nerve *= 0.7 + _rng.nextDouble() * 0.7;
    // Draw if what we'd add beats what we'd lose.
    return (1 - risk) * gain * nerve > risk * bag;
  }

  SunkChoice decide(SunkGame g) {
    switch (g.pending) {
      case SunkKind.hook || SunkKind.cut:
        final ts = g.targets;
        // The one with the most to lose (Easy: anyone), the leader first.
        final pick = difficulty == Difficulty.easy
            ? ts[_rng.nextInt(ts.length)]
            : (ts..sort((a, b) => (g.worth(b) + g.scores[b] ~/ 4).compareTo(g.worth(a) + g.scores[a] ~/ 4)))
                  .first;
        return SunkChoice.aim(pick);
      case SunkKind.map:
        final c = g.peeked;
        if (c == null) return const SunkChoice.chart(take: false);
        final bad = c.isTreasure && g.holds(me, c.value) && g.air[me] == 0;
        return SunkChoice.chart(take: !bad);
      default:
        return wantsToDraw(g) ? const SunkChoice.draw() : const SunkChoice.surface();
    }
  }

  /// How long it seems to think (0..1): longer on close calls.
  double tempo(SunkGame g) {
    final r = g.bustChance(me);
    return (0.3 + (0.5 - (r - 0.25).abs()) * 0.8 + _rng.nextDouble() * 0.2).clamp(0.0, 1.0);
  }
}

/// Plays one move for whoever's turn it is.
void sunkPlay(SunkGame g, SunkChoice c) {
  final p = g.turn;
  switch (c.kind) {
    case 'draw':
      g.draw(p);
    case 'surface':
      g.surface(p);
    case 'aim':
      g.aim(p, c.target!);
    case 'chart':
      g.chart(p, take: c.take!);
  }
}
