import 'dart:math';

import '../difficulty.dart';
import 'liars.dart';

/// How a bot plays its cup.
enum LiarsStyle {
  /// Bids what it can see; calls early.
  cautious,

  /// Pushes the bid up and dares you to call.
  bold,

  /// Bids faces it hasn't got, to send you the wrong way.
  bluffer,
}

/// A bot's turn: a raise, or a call.
class LiarsMove {
  LiarsMove.raise(LiarsBid this.bid) : call = null;
  LiarsMove.call(LiarsCall this.call) : bid = null;

  final LiarsBid? bid;
  final LiarsCall? call;

  /// How long it seems to think (0..1 of its range): bots give themselves
  /// away a little (Easy ones a lot) by taking longer when they bluff.
  double tempo = 0.5;

  Map<String, Object?> toJson() => bid != null
      ? {'kind': 'bid', ...bid!.toJson(), 'tempo': (tempo * 100).round()}
      : {'kind': call!.name, 'tempo': (tempo * 100).round()};
}

/// What a bot remembers of each player: how often their bids held up when
/// called. A liar's bids count for less.
class LiarsReads {
  LiarsReads(int players) : held = List.filled(players, 0), caught = List.filled(players, 0);

  final List<int> held, caught;

  /// How far to trust [p]'s bids (0.3 .. 1).
  double trust(int p) {
    final n = held[p] + caught[p];
    if (n == 0) return 0.75;
    return (0.3 + 0.7 * (held[p] + 1) / (n + 2)).clamp(0.3, 1.0);
  }

  void saw(LiarsReveal r) {
    if (r.call != LiarsCall.liar) return;
    if (r.bidStood) {
      held[r.bidder]++;
    } else {
      caught[r.bidder]++;
    }
  }

  Map<String, Object?> toJson() => {'held': held, 'caught': caught};
  static LiarsReads fromJson(Map<Object?, Object?>? j, int players) {
    final r = LiarsReads(players);
    if (j == null) return r;
    for (final (i, v) in ((j['held'] as List?) ?? const []).indexed) {
      if (i < players) r.held[i] = v as int;
    }
    for (final (i, v) in ((j['caught'] as List?) ?? const []).indexed) {
      if (i < players) r.caught[i] = v as int;
    }
    return r;
  }
}

/// Decides a bot's turn from what it can know: its own cup, how many dice
/// are out, and the bids so far. Normal and Hard bots read the others'
/// bids as hints about their cups (trusting liars less); Hard bots also
/// call "spot on" when the odds are there and bluff with a plan. Easy bots
/// guess, and give away their bluffs by thinking longer.
class LiarsBot {
  LiarsBot({required this.me, required this.difficulty, required this.style, Random? rng, LiarsReads? reads})
    : _rng = rng ?? Random(),
      reads = reads ?? LiarsReads(8);

  final int me;
  final Difficulty difficulty;
  final LiarsStyle style;
  final LiarsReads reads;
  final Random _rng;

  /// The chance [b] is true as this bot sees it, using the others' bids as
  /// hints (Normal and Hard).
  double believe(LiarsGame g, LiarsBid b, {bool exact = false}) {
    final unknown = g.totalDice - g.counts[me];
    var need = b.count - g.mine(me, b.face);
    var hidden = unknown;
    if (difficulty != Difficulty.easy) {
      // Someone who bid this face probably holds some: count part of a
      // die per bid, more for players whose bids have stood up.
      final hinted = <int, double>{};
      for (final (p, bid) in g.bids) {
        if (p == me || bid.face != b.face) continue;
        hinted[p] = max(hinted[p] ?? 0, reads.trust(p) * (difficulty == Difficulty.hard ? 1.1 : 0.7));
      }
      final assumed = hinted.values.fold(0.0, (a, b) => a + b).floor();
      need -= assumed;
      hidden -= assumed;
    }
    final p = g.faceChance(b.face);
    if (exact) return LiarsGame.exactly(need, max(0, hidden), p);
    return LiarsGame.atLeast(need, max(0, hidden), p);
  }

  double get _callBelow => switch (style) {
    LiarsStyle.cautious => 0.45,
    LiarsStyle.bold => 0.3,
    LiarsStyle.bluffer => 0.38,
  };

  double get _bluffRate => switch (style) {
    LiarsStyle.cautious => 0.05,
    LiarsStyle.bold => 0.15,
    LiarsStyle.bluffer => 0.32,
  };

  double get _noise => switch (difficulty) {
    Difficulty.easy => 0.22,
    Difficulty.normal => 0.08,
    Difficulty.hard => 0.03,
  };

  LiarsMove decide(LiarsGame g) {
    final standing = g.bid;
    double jitter() => (_rng.nextDouble() * 2 - 1) * _noise;
    // Raise: the most believable bid one or two steps up, leaning towards
    // faces in our own cup.
    final options = <(LiarsBid, double)>[];
    for (var face = g.rules.lowFace; face <= 6; face++) {
      final low = g.lowest(face);
      if (low == null) continue;
      for (final b in [low, LiarsBid(low.count + 1, face)]) {
        if (!g.beats(b)) continue;
        options.add((b, believe(g, b) + g.mine(me, face) * 0.02 + jitter()));
      }
    }
    options.sort((a, b) => b.$2.compareTo(a.$2));
    final best = options.isEmpty ? 0.0 : options.first.$2;
    if (standing != null) {
      final odds = believe(g, standing) + jitter();
      // Spot on: only when the count looks just right (it's a gamble).
      if (g.rules.spotOn && g.counts[me] < g.rules.dice && difficulty != Difficulty.easy) {
        final exact = believe(g, standing, exact: true);
        if (exact > (difficulty == Difficulty.hard ? 0.48 : 0.55)) {
          return LiarsMove.call(LiarsCall.spotOn)..tempo = 0.7;
        }
      }
      // Call when the bid is less likely than what we'd say instead
      // (Easy bots just go by a feeling).
      // Calling loses if the bid's true; raising loses if ours is false and
      // gets called. Call when the first is the smaller risk.
      final lean = switch (style) {
        LiarsStyle.cautious => 0.05,
        LiarsStyle.bold => -0.05,
        LiarsStyle.bluffer => 0.0,
      };
      final bar = difficulty == Difficulty.easy ? _callBelow : ((1 - best) + lean + 0.05).clamp(0.2, 0.55);
      if (odds < bar || options.isEmpty) {
        return LiarsMove.call(LiarsCall.liar)..tempo = 0.3 + _rng.nextDouble() * 0.3;
      }
    }
    if (options.isEmpty) return LiarsMove.call(LiarsCall.liar)..tempo = 0.8;
    var (pick, odds) = options.first;
    var bluff = false;
    // A bluff: a face we don't hold that's still plausible, to point the
    // table the wrong way (the bold push the count instead).
    if (_rng.nextDouble() < _bluffRate) {
      final lies = options.where((o) => g.mine(me, o.$1.face) == 0 && o.$2 > 0.3).toList();
      if (lies.isNotEmpty) {
        (pick, odds) = lies[_rng.nextInt(lies.length)];
        bluff = true;
      } else if (style == LiarsStyle.bold) {
        pick = LiarsBid(pick.count + 1, pick.face);
        bluff = g.beats(pick);
        if (!bluff) pick = options.first.$1;
      }
    }
    final tell = switch (difficulty) {
      Difficulty.easy => 0.45,
      Difficulty.normal => 0.2,
      Difficulty.hard => 0.0,
    };
    final tempo = (0.25 + _rng.nextDouble() * 0.4 + (bluff ? tell : 0) + (1 - odds) * 0.15).clamp(0.0, 1.0);
    return LiarsMove.raise(pick)..tempo = tempo;
  }
}
