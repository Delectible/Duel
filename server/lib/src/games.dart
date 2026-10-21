import 'dart:math';

import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/four_in_a_row/four_in_a_row.dart';

import 'card_games.dart';
import 'poker_game.dart';
import 'store.dart';

/// A move the rules don't allow (or that's not this player's turn).
class MoveError implements Exception {
  const MoveError(this.message);
  final String message;

  @override
  String toString() => 'MoveError: $message';
}

/// The result of a finished game: [winner] seat, or a [draw].
class Result {
  const Result({this.winner, this.draw = false});
  final int? winner;
  final bool draw;

  Doc toJson() => {'winner': winner, 'draw': draw};
}

/// One game's rules as the referee sees them: state is plain JSON, rebuilt
/// into the shared engine to check each move. The full state stays on the
/// server; players see [public] (and their own [private] part).
abstract class OnlineGame {
  const OnlineGame();

  String get id;
  int get minPlayers;
  int get maxPlayers;

  /// Table sizes it can be played at, when not every one in range works
  /// (Spades: 2 or 4).
  Set<int>? get counts => null;

  /// A new game for [players] seats; [first] seat starts; [humans] are the
  /// seats people sit in (the rest are bots); [options] are the game's own
  /// (Spades: the target score).
  Doc start(int players, Random rng, {required int first, required Set<int> humans, Doc options = const {}});

  /// Whose turn it is, or null when the game is over.
  int? turn(Doc state);

  /// Applies [move] for [seat]; throws [MoveError] if it isn't allowed.
  Doc play(Doc state, int seat, Doc move);

  Result? result(Doc state);

  /// What to play for a player whose time ran out (or who left).
  Doc autoMove(Doc state, int seat, Random rng);

  /// A bot's move: [bot] is its {name, look, difficulty}.
  Doc botMove(Doc state, int seat, Doc bot, Random rng) => autoMove(state, seat, rng);

  /// What every player may see.
  Doc public(Doc state);

  /// What only [seat] may see (their cards), or null.
  Doc? private(Doc state, int seat) => null;

  /// [seat] left mid-game: the game without them, or null when it can't go
  /// on (two players: the other wins).
  Doc? leave(Doc state, int seat) => null;

  /// [seat] is back (after [leave]).
  Doc rejoin(Doc state, int seat) => state;

  /// How long phones take to show what happened from [before] to [after]
  /// (bots' moves, a new deal): added to the next player's clock.
  Duration show(Doc before, Doc after) => Duration.zero;
}

/// Four in a Row: the state is just who started and the columns played.
class RowGame extends OnlineGame {
  const RowGame();

  @override
  String get id => 'connect4';
  @override
  int get minPlayers => 2;
  @override
  int get maxPlayers => 2;

  static FourInARow _replay(Doc state) {
    final g = FourInARow(first: state['first']! as int);
    for (final m in (state['moves']! as List).cast<int>()) {
      g.drop(m);
    }
    return g;
  }

  @override
  Doc start(
    int players,
    Random rng, {
    required int first,
    required Set<int> humans,
    Doc options = const {},
  }) => {'first': first, 'moves': <int>[]};

  @override
  int? turn(Doc state) {
    final g = _replay(state);
    return g.isOver ? null : g.turn;
  }

  @override
  Doc play(Doc state, int seat, Doc move) {
    final g = _replay(state);
    if (g.isOver) throw const MoveError('The game is over');
    if (g.turn != seat) throw const MoveError('Not your turn');
    final col = move['column'];
    if (col is! int || !g.canDrop(col)) throw const MoveError('That column is full or not on the board');
    return {
      ...state,
      'moves': [...(state['moves']! as List).cast<int>(), col],
    };
  }

  @override
  Result? result(Doc state) {
    final g = _replay(state);
    if (!g.isOver) return null;
    return g.draw ? const Result(draw: true) : Result(winner: g.winner);
  }

  @override
  Doc autoMove(Doc state, int seat, Random rng) {
    // An Easy bot plays for you: legal, not clever.
    final g = _replay(state);
    final bot = RowBot(difficulty: Difficulty.easy, rng: rng, me: seat);
    return {'column': bot.decide(g)};
  }

  @override
  Doc public(Doc state) => state;
}

/// Every game that can be played online, by id.
const onlineGames = <String, OnlineGame>{
  'connect4': RowGame(),
  'holdem': PokerGame(),
  'crazy8': EightsGame(),
  'gofish': FishGame(),
  'spades': SpadesGame(),
};
