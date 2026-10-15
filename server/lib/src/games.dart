import 'dart:math';

import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/four_in_a_row/four_in_a_row.dart';

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
/// into the shared engine to check each move. Card games add private
/// state (each player's hand) later.
abstract interface class OnlineGame {
  String get id;
  int get minPlayers;
  int get maxPlayers;

  /// A new game for [players] seats; [first] seat starts.
  Doc start(int players, Random rng, {required int first});

  /// Whose turn it is, or null when the game is over.
  int? turn(Doc state);

  /// Applies [move] for [seat]; throws [MoveError] if it isn't allowed.
  Doc play(Doc state, int seat, Doc move);

  Result? result(Doc state);

  /// What to play for a player whose time ran out.
  Doc autoMove(Doc state, int seat, Random rng);

  /// What every player may see.
  Doc public(Doc state);
}

/// Four in a Row: the state is just who started and the columns played.
class RowGame implements OnlineGame {
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
  Doc start(int players, Random rng, {required int first}) => {'first': first, 'moves': <int>[]};

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
const onlineGames = <String, OnlineGame>{'connect4': RowGame()};
