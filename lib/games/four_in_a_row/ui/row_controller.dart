import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/avatars/faces.dart';
import '../../../core/session/difficulty.dart';
import '../engine/four_in_a_row.dart';

/// Runs Four in a Row against one bot. You're red (player 0).
class RowController extends ChangeNotifier {
  RowController({required this.difficulty, Random? rng, this.pace = 1, this.you = const Persona.you()})
    : _rng = rng ?? Random() {
    bot = Persona.bots(1, _rng).single;
    _start(0);
  }

  final Difficulty difficulty;
  final double pace;
  final Persona you;
  final Random _rng;

  late final Persona bot;
  late FourInARow game;
  late RowBot _bot;
  int round = 0;
  bool thinking = false;

  Timer? _timer;
  var _disposed = false;

  bool get yourTurn => !game.isOver && game.turn == 0 && !thinking;

  /// Columns where you'd win now / where the bot would (to block).
  List<int> get yourWins => game.isOver ? const [] : game.winningMoves(0);
  List<int> get threats => game.isOver ? const [] : game.winningMoves(1);

  void _start(int first) {
    game = FourInARow(first: first);
    _bot = RowBot(difficulty: difficulty, rng: _rng);
    round++;
    thinking = false;
    if (first == 1) _botMove();
  }

  /// Next game: whoever didn't start this one goes first.
  void playAgain() {
    _timer?.cancel();
    _start(1 - game.first);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Tap a column.
  void drop(int col) {
    if (!yourTurn || !game.canDrop(col)) return;
    game.drop(col);
    _notify();
    if (!game.isOver) _botMove();
  }

  void _botMove() {
    thinking = true;
    _notify();
    final wait = Duration(milliseconds: ((500 + _rng.nextInt(400)) * pace).round());
    _timer = Timer(wait, () async {
      if (_disposed) return;
      int col;
      if (pace >= 1 && difficulty != Difficulty.easy) {
        // Look-ahead off the UI thread so the board never stutters. Only
        // plain data crosses (a closure from here would drag this
        // controller, timers and all, along and fail to send).
        final job = (
          moves: [...game.moves],
          first: game.first,
          level: difficulty.index,
          seed: _rng.nextInt(1 << 30),
        );
        try {
          col = await Isolate.run(() => _decide(job));
        } on Object {
          col = _bot.decide(game); // thinking here beats never moving
        }
      } else {
        col = _bot.decide(game);
      }
      if (_disposed) return;
      thinking = false;
      game.drop(col);
      _notify();
    });
  }

  String commentary() {
    final g = game;
    if (g.isOver) {
      if (g.draw) return 'The board is full and nobody made four: a draw.';
      return g.winner == 0 ? 'Four in a row! You win.' : '${bot.name} made four in a row.';
    }
    if (thinking) {
      final last = g.moves.isEmpty ? null : 'You dropped in column ${g.moves.last + 1}';
      return last == null ? '${bot.name} goes first and is thinking…' : '$last  ·  ${bot.name} is thinking…';
    }
    final wins = yourWins, danger = threats;
    if (wins.isNotEmpty) return 'You can win right now: column ${wins.first + 1}!';
    if (danger.isNotEmpty) {
      return danger.length > 1
          ? "Watch out: ${bot.name} can win in two places (${danger.map((c) => c + 1).join(' and ')}). Block one!"
          : 'Watch out: ${bot.name} can win in column ${danger.first + 1}. Block it!';
    }
    // On your turn the last move was the bot's.
    final botLast = g.moves.isEmpty ? null : g.moves.last;
    final start = botLast == null ? '' : '${bot.name} dropped in column ${botLast + 1}. ';
    return '${start}Your turn: tap a column to drop a red disc.';
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

/// The bot's move for a position given as plain data (runs in an isolate).
int _decide(({List<int> moves, int first, int level, int seed}) job) {
  final g = FourInARow(first: job.first);
  for (final m in job.moves) {
    g.drop(m);
  }
  return RowBot(difficulty: Difficulty.values[job.level], rng: Random(job.seed)).decide(g);
}
