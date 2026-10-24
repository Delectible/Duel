import 'dart:math';

import 'package:duel_engine/blitz/blitz.dart' hide PassTurn;
import 'package:duel_engine/blitz/blitz_bot.dart';
import 'package:duel_engine/cards.dart';
import 'package:duel_engine/crazy_eights/crazy_eights.dart';
import 'package:duel_engine/crazy_eights/eights_bot.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/go_fish/fish_bot.dart';
import 'package:duel_engine/go_fish/go_fish.dart';
import 'package:duel_engine/spades/spades.dart';
import 'package:duel_engine/spades/spades_bot.dart';

import 'games.dart';
import 'store.dart';

/// A card game played from a seeded shuffle and a log of moves: the state
/// is the seed, the dealer, the seating [order] (engine position -> match
/// seat) and every move so far, and the table is rebuilt by replaying them
/// through the shared engine. Phones get the same (public) state and
/// rebuild the same table, each showing only its own hand.
abstract class SeededCardGame<G> extends OnlineGame {
  const SeededCardGame();

  /// A fresh engine for [state] (before any moves).
  G deal(Doc state, Random rng);

  /// Plays [move] for engine position [pos]; throws [MoveError] if it
  /// isn't allowed.
  void apply(G g, int pos, Doc move);

  /// Engine position to move, or null when it's over.
  int? toMove(G g);

  /// Winning engine position (null: a draw), once it's over.
  int? winner(G g);
  bool isOver(G g);

  Doc bot(G g, int pos, Difficulty difficulty, Random rng);

  /// Anything to do before the next move (Spades: deal the next hand).
  void settle(G g) {}

  Doc extraStart(int players, Random rng, Doc options) => const {};

  @override
  Doc start(
    int players,
    Random rng, {
    required int first,
    required Set<int> humans,
    Doc options = const {},
  }) => {
    'seed': rng.nextInt(1 << 31),
    'n': players,
    'dealer': (first + players - 1) % players,
    'order': [for (var i = 0; i < players; i++) i],
    'humans': (humans.toList()..sort()),
    'options': options,
    'moves': <Doc>[],
    ...extraStart(players, rng, options),
  };

  List<int>? order(Doc state) => (state['order'] as List?)?.cast<int>();

  /// The table so far (null while there's no seating yet).
  G? replay(Doc state) {
    final o = order(state);
    if (o == null) return null;
    final g = deal(state, Random(state['seed']! as int));
    for (final m in (state['moves']! as List).cast<Map<Object?, Object?>>()) {
      settle(g);
      apply(g, m['p']! as int, m.cast<String, Object?>());
    }
    settle(g);
    return g;
  }

  @override
  int? turn(Doc state) {
    final g = replay(state);
    if (g == null || isOver(g)) return null;
    final p = toMove(g);
    return p == null ? null : order(state)![p];
  }

  @override
  Doc play(Doc state, int seat, Doc move) {
    final g = replay(state);
    if (g == null || isOver(g)) throw const MoveError('The game is over');
    final pos = order(state)!.indexOf(seat);
    if (toMove(g) != pos) throw const MoveError('Not your turn');
    final clean = {...move, 'p': pos}..remove('tempo');
    apply(g, pos, clean);
    return {
      ...state,
      'moves': [...(state['moves']! as List), clean],
    };
  }

  @override
  Result? result(Doc state) {
    final g = replay(state);
    if (g == null || !isOver(g)) return null;
    final w = winner(g);
    return w == null ? const Result(draw: true) : Result(winner: order(state)![w]);
  }

  @override
  Doc botMove(Doc state, int seat, Doc bot, Random rng) {
    final g = replay(state)!;
    final difficulty = Difficulty.values.asNameMap()[bot['difficulty']] ?? Difficulty.normal;
    return this.bot(g, order(state)!.indexOf(seat), difficulty, rng);
  }

  @override
  Doc autoMove(Doc state, int seat, Random rng) => botMove(state, seat, const {'difficulty': 'easy'}, rng);

  @override
  Doc? leave(Doc state, int seat) => state;

  @override
  Doc public(Doc state) => {...state}..remove('wants');

  /// About a second a move for phones to show it.
  @override
  Duration show(Doc before, Doc after) {
    final a = (before['moves'] as List?)?.length ?? 0;
    final b = (after['moves'] as List?)?.length ?? 0;
    return Duration(milliseconds: min(60000, (b - a) * 1200));
  }

  static PlayingCard card(Object? s) {
    try {
      return PlayingCard.parse('$s');
    } on Object {
      throw const MoveError('No such card');
    }
  }

  static T check<T>(T Function() f) {
    try {
      return f();
    } on MoveError {
      rethrow;
    } on Object {
      throw const MoveError("That move isn't allowed now");
    }
  }
}

/// Crazy Eights: {kind: play, card, suit?} / {kind: draw} / {kind: pass}.
class EightsGame extends SeededCardGame<CrazyEights> {
  const EightsGame();

  @override
  String get id => 'crazy8';
  @override
  int get minPlayers => 2;
  @override
  int get maxPlayers => 4;

  @override
  CrazyEights deal(Doc state, Random rng) =>
      CrazyEights(players: state['n']! as int, rng: rng, dealer: state['dealer']! as int);

  @override
  void apply(CrazyEights g, int pos, Doc move) => SeededCardGame.check(() {
    switch (move['kind']) {
      case 'play':
        final c = SeededCardGame.card(move['card']);
        if (!g.playable(pos).contains(c)) throw const MoveError("That card doesn't fit");
        final suit = move['suit'] is int ? Suit.values[move['suit']! as int] : null;
        g.play(pos, c, chose: c.rank == 8 ? (suit ?? c.suit) : null);
      case 'draw':
        g.draw(pos);
      case 'pass':
        g.pass(pos);
      default:
        throw const MoveError('Play, draw or pass');
    }
  });

  @override
  int? toMove(CrazyEights g) => g.turn;
  @override
  bool isOver(CrazyEights g) => g.isOver;
  @override
  int? winner(CrazyEights g) => g.winner;

  @override
  Doc bot(CrazyEights g, int pos, Difficulty difficulty, Random rng) =>
      switch (EightsBot(difficulty: difficulty, rng: rng).decide(g, pos)) {
        PlayCard(:final card, :final suit) => {'kind': 'play', 'card': '$card', 'suit': ?suit?.index},
        DrawCard() => {'kind': 'draw'},
        PassTurn() => {'kind': 'pass'},
      };
}

/// Go Fish: {kind: ask, target (engine position), rank} / {kind: fish}.
class FishGame extends SeededCardGame<GoFish> {
  const FishGame();

  @override
  String get id => 'gofish';
  @override
  int get minPlayers => 2;
  @override
  int get maxPlayers => 6;

  @override
  GoFish deal(Doc state, Random rng) =>
      GoFish(players: state['n']! as int, rng: rng, dealer: state['dealer']! as int);

  @override
  void apply(GoFish g, int pos, Doc move) => SeededCardGame.check(() {
    switch (move['kind']) {
      case 'ask':
        final t = move['target'], r = move['rank'];
        if (t is! int || r is! int || g.mustFish) throw const MoveError("That ask isn't allowed");
        if (!g.targets(pos).contains(t) || !g.askable(pos).contains(r)) {
          throw const MoveError("That ask isn't allowed");
        }
        g.ask(pos, t, r);
      case 'fish':
        if (!g.mustFish) throw const MoveError('Ask first');
        g.fish(pos);
      default:
        throw const MoveError('Ask or fish');
    }
  });

  @override
  int? toMove(GoFish g) => g.turn;
  @override
  bool isOver(GoFish g) => g.isOver;
  @override
  int? winner(GoFish g) => g.winners!.length == 1 ? g.winners!.single : null;

  @override
  Doc bot(GoFish g, int pos, Difficulty difficulty, Random rng) {
    if (g.mustFish) return {'kind': 'fish'};
    final (t, r) = FishBot(me: pos, difficulty: difficulty, rng: rng).decide(g);
    return {'kind': 'ask', 'target': t, 'rank': r};
  }
}

/// Spades: four players pick partners first ({kind: partner, want: seat};
/// -1 for no preference), then {kind: draw, keep} (two-handed), {kind:
/// bid, tricks}, {kind: play, card}. The next hand deals by itself.
class SpadesGame extends SeededCardGame<Spades> {
  const SpadesGame();

  @override
  String get id => 'spades';
  @override
  int get minPlayers => 2;
  @override
  int get maxPlayers => 4;

  @override
  Set<int> get counts => const {2, 4};

  @override
  Doc start(int players, Random rng, {required int first, required Set<int> humans, Doc options = const {}}) {
    final s = super.start(players, rng, first: first, humans: humans, options: options);
    if (players != 4) return s;
    // Four: everyone picks a partner first; the seating comes after.
    return {...s, 'order': null, 'wants': <String, Object?>{}};
  }

  @override
  Spades deal(Doc state, Random rng) {
    final target = (state['options'] as Map?)?['target'];
    return Spades(
      players: state['n']! as int,
      target: target is int ? target : 250,
      rng: rng,
      dealer: state['dealer']! as int,
    );
  }

  /// People who still have to pick a partner, in seat order.
  static List<int> _picking(Doc state) {
    final wants = (state['wants'] as Map?) ?? const {};
    final gone = (state['gone'] as List?)?.cast<int>() ?? const [];
    return [
      for (final h in (state['humans']! as List).cast<int>())
        if (!wants.containsKey('$h') && !gone.contains(h)) h,
    ];
  }

  @override
  int? turn(Doc state) {
    if (order(state) == null) {
      final left = _picking(state);
      return left.isEmpty ? null : left.first;
    }
    return super.turn(state);
  }

  @override
  Doc play(Doc state, int seat, Doc move) {
    if (order(state) != null) return super.play(state, seat, move);
    if (_picking(state).firstOrNull != seat) throw const MoveError('Not your turn');
    final want = move['want'];
    final wants = {...(state['wants']! as Map), '$seat': want is int && want != seat ? want : -1};
    final next = {...state, 'wants': wants};
    if (_picking(next).isNotEmpty) return next;
    final (o, tossed) = pairUp({
      for (final e in wants.entries) int.parse('${e.key}'): e.value as int,
    }, Random(state['seed']! as int));
    return {...next, 'order': o, 'tossed': tossed};
  }

  /// Seats for two teams from who wants whom: every pairing scores a point
  /// for each person sitting with the one they asked for (so two who want
  /// each other count twice); the best wins, a coin toss between equals.
  /// Engine positions 0 & 2 and 1 & 3 are partners. Also says whether it
  /// came down to a toss.
  static (List<int>, bool) pairUp(Map<int, int> wants, Random rng) {
    const pairings = [((0, 1), (2, 3)), ((0, 2), (1, 3)), ((0, 3), (1, 2))];
    int score(((int, int), (int, int)) p) {
      bool together(int a, int b) =>
          (p.$1.$1 == a && p.$1.$2 == b) ||
          (p.$1.$1 == b && p.$1.$2 == a) ||
          (p.$2.$1 == a && p.$2.$2 == b) ||
          (p.$2.$1 == b && p.$2.$2 == a);
      return wants.entries.where((e) => e.value >= 0 && together(e.key, e.value)).length;
    }

    final best = pairings.map(score).reduce(max);
    final top = pairings.where((p) => score(p) == best).toList();
    final pick = top[rng.nextInt(top.length)];
    final tossed = top.length > 1 && wants.values.any((w) => w >= 0);
    return ([pick.$1.$1, pick.$2.$1, pick.$1.$2, pick.$2.$2], tossed);
  }

  @override
  void apply(Spades g, int pos, Doc move) => SeededCardGame.check(() {
    switch (move['kind']) {
      case 'draw':
        g.draw(pos, keep: move['keep'] == true);
      case 'bid':
        final t = move['tricks'];
        if (t is! int) throw const MoveError('Bid 0 to 13');
        g.bid(pos, t);
      case 'play':
        g.play(pos, SeededCardGame.card(move['card']));
      default:
        throw const MoveError('Draw, bid or play');
    }
  });

  @override
  void settle(Spades g) {
    if (g.phase == SpadesPhase.handOver) g.nextHand();
  }

  @override
  int? toMove(Spades g) => g.turn;
  @override
  bool isOver(Spades g) => g.isOver;
  @override
  int? winner(Spades g) => g.winner;

  @override
  Doc bot(Spades g, int pos, Difficulty difficulty, Random rng) {
    final b = SpadesBot(difficulty: difficulty, rng: rng);
    return switch (g.phase) {
      SpadesPhase.draw => {'kind': 'draw', 'keep': b.keep(g, pos, g.offered!)},
      SpadesPhase.bid => {'kind': 'bid', 'tricks': b.bid(g, pos)},
      _ => {'kind': 'play', 'card': '${b.play(g, pos)}'},
    };
  }

  @override
  Doc autoMove(Doc state, int seat, Random rng) =>
      order(state) == null ? {'kind': 'partner', 'want': -1} : super.autoMove(state, seat, rng);

  @override
  Duration show(Doc before, Doc after) {
    final base = super.show(before, after);
    // A hand ended: time to read the scores.
    int hands(Doc s) => (s['moves'] as List?)?.where((m) => (m as Map)['kind'] == 'play').length ?? 0;
    return base + Duration(milliseconds: (hands(after) ~/ 52 - hands(before) ~/ 52) * 8000);
  }
}

/// Blitz (the house game): moves as `blitzMoveToJson` makes them; targets
/// are engine positions. Option `wars` (on / off). The engine counts from
/// seat 0 (`origin`), so phones turned round deal and fight the same.
class BlitzGame extends SeededCardGame<Blitz> {
  const BlitzGame();

  @override
  String get id => 'blitz';
  @override
  int get minPlayers => 2;
  @override
  int get maxPlayers => 6;

  @override
  Blitz deal(Doc state, Random rng) {
    final n = state['n']! as int;
    return Blitz(
      players: n,
      rng: rng,
      wars: const [true, 1].contains((state['options'] as Map?)?['wars']),
      first: ((state['dealer']! as int) + 1) % n,
    );
  }

  @override
  void apply(Blitz g, int pos, Doc move) {
    final BlitzMove m;
    try {
      m = blitzMoveFromJson(move);
    } on Object {
      throw const MoveError('No such move');
    }
    if (!g.moves(pos).contains(m)) throw const MoveError("That move isn't allowed now");
    SeededCardGame.check(() => g.apply(m));
  }

  @override
  int? toMove(Blitz g) => g.turn;
  @override
  bool isOver(Blitz g) => g.isOver;
  @override
  int? winner(Blitz g) => g.winner;

  @override
  Doc bot(Blitz g, int pos, Difficulty difficulty, Random rng) =>
      blitzMoveToJson(BlitzBot(difficulty: difficulty, rng: rng).decide(g, pos));
}
