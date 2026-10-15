import 'dart:math';

import '../difficulty.dart';
import 'go_fish.dart';

/// A Go Fish bot. It only uses what everyone at the table can see: who
/// asked for what, who handed cards over, lucky catches shown, books.
/// - Easy: asks for a random rank it holds, from a random player.
/// - Normal: remembers the last few asks ("Finn asked for 7s, so Finn has
///   7s") and goes after them.
/// - Hard: remembers everything, including who has said "go fish" to which
///   rank, and goes for the ranks it nearly has a book of.
class FishBot {
  FishBot({required this.me, required this.difficulty, required this.rng});

  final int me;
  final Difficulty difficulty;
  final Random rng;

  var _seen = 0;

  /// Ranks each player is known to hold / known not to hold.
  final Map<int, Set<int>> _has = {};
  final Map<int, Set<int>> _lacks = {};

  /// Normal forgets: only the last few events count.
  int get _memory => difficulty == Difficulty.hard ? 1 << 30 : 8;

  void _learn(GoFish g) {
    if (_seen == 0 || g.events.length - _seen > _memory) {
      _has.clear();
      _lacks.clear();
      _seen = max(0, g.events.length - _memory);
    }
    for (final e in g.events.skip(_seen)) {
      Set<int> has(int p) => _has.putIfAbsent(p, () => {});
      Set<int> lacks(int p) => _lacks.putIfAbsent(p, () => {});
      switch (e) {
        case Asked(:final player, :final target, :final rank, :final given):
          has(player).add(rank);
          lacks(player).remove(rank);
          has(target).remove(rank);
          lacks(target).add(rank);
          if (given > 0) has(player).add(rank);
        case Fished(:final player, :final card, :final lucky):
          // A fresh card could be anything.
          lacks(player).clear();
          if (lucky) has(player).add(card.rank);
        case Booked(:final rank):
          for (final s in _has.values) {
            s.remove(rank);
          }
        case SatOut() || GameEnded():
          break;
      }
    }
    _seen = g.events.length;
  }

  /// (target, rank) to ask for.
  (int, int) decide(GoFish g) {
    final ranks = g.askable(me).toList()..shuffle(rng);
    final targets = g.targets(me)..shuffle(rng);
    if (difficulty == Difficulty.easy) return (targets.first, ranks.first);
    _learn(g);

    // Someone is known to hold a rank I have: ask them (most copies first).
    ranks.sort((a, b) => g.count(me, b).compareTo(g.count(me, a)));
    for (final r in ranks) {
      for (final t in targets) {
        if (_has[t]?.contains(r) ?? false) return (t, r);
      }
    }
    // Otherwise the rank I hold most of, from whoever isn't known to lack
    // it (Hard: the biggest hand, more likely to have it).
    final rank = difficulty == Difficulty.hard ? ranks.first : ranks[rng.nextInt(ranks.length)];
    final options = targets.where((t) => !(_lacks[t]?.contains(rank) ?? false)).toList();
    final pool = options.isEmpty ? targets : options;
    if (difficulty == Difficulty.hard) {
      pool.sort((a, b) => g.hands[b].length.compareTo(g.hands[a].length));
    }
    return (pool.first, rank);
  }
}
