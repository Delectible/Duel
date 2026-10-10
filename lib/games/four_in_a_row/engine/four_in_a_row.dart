import 'dart:math';

import '../../../core/session/difficulty.dart';

/// Four in a Row on the classic 7 x 6 board. Players are 0 (you, red) and
/// 1 (the bot, yellow). Row 0 is the bottom.
class FourInARow {
  FourInARow({this.first = 0}) : turn = first;

  static const cols = 7;
  static const rows = 6;

  /// Who went first.
  final int first;

  /// board[col][row]: -1 empty, else the player.
  final List<List<int>> board = [for (var c = 0; c < cols; c++) List.filled(rows, -1)];

  int turn;
  int? winner;
  bool draw = false;

  /// The four cells that won, as (col, row).
  List<(int, int)> winningLine = const [];

  /// Moves so far, as columns.
  final List<int> moves = [];

  bool get isOver => winner != null || draw;

  int height(int col) {
    final i = board[col].indexOf(-1);
    return i < 0 ? rows : i;
  }

  bool canDrop(int col) => !isOver && col >= 0 && col < cols && height(col) < rows;

  List<int> get openColumns => [
    for (var c = 0; c < cols; c++)
      if (height(c) < rows) c,
  ];

  /// Drops [turn]'s disc in [col]. Returns the row it lands on.
  int drop(int col) {
    if (!canDrop(col)) throw ArgumentError('Column $col is full or the game is over');
    final row = height(col);
    board[col][row] = turn;
    moves.add(col);
    final line = _lineThrough(col, row, turn);
    if (line != null) {
      winner = turn;
      winningLine = line;
    } else if (moves.length == cols * rows) {
      draw = true;
    } else {
      turn = 1 - turn;
    }
    return row;
  }

  List<(int, int)>? _lineThrough(int col, int row, int p) {
    for (final (dc, dr) in const [(1, 0), (0, 1), (1, 1), (1, -1)]) {
      final cells = [(col, row)];
      for (final s in const [1, -1]) {
        var c = col + dc * s, r = row + dr * s;
        while (c >= 0 && c < cols && r >= 0 && r < rows && board[c][r] == p) {
          cells.add((c, r));
          c += dc * s;
          r += dr * s;
        }
      }
      if (cells.length >= 4) {
        cells.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
        return cells.take(4).toList();
      }
    }
    return null;
  }

  /// Columns where [player] would win right now.
  List<int> winningMoves(int player) {
    final out = <int>[];
    for (final c in openColumns) {
      final r = height(c);
      board[c][r] = player;
      if (_lineThrough(c, r, player) != null) out.add(c);
      board[c][r] = -1;
    }
    return out;
  }
}

/// The bot: looks ahead with minimax and alpha-beta pruning.
/// - Easy: 2 moves ahead, often plays something else.
/// - Normal: 4 moves ahead.
/// - Hard: 7 moves ahead with a positional score: very hard to beat.
class RowBot {
  RowBot({required this.difficulty, required this.rng, this.me = 1});

  final Difficulty difficulty;
  final Random rng;
  final int me;

  int get depth => const [2, 4, 7][difficulty.index];

  static const _order = [3, 2, 4, 1, 5, 0, 6]; // centre first prunes more

  int decide(FourInARow game) {
    final open = game.openColumns;
    // Always take a win; always block a loss (even Easy).
    final win = game.winningMoves(me);
    if (win.isNotEmpty) return win.first;
    final block = game.winningMoves(1 - me);
    if (block.isNotEmpty && difficulty != Difficulty.easy) return block.first;
    if (difficulty == Difficulty.easy && rng.nextDouble() < 0.35) {
      return block.isNotEmpty && rng.nextBool() ? block.first : open[rng.nextInt(open.length)];
    }
    final board = [
      for (final col in game.board) [...col],
    ];
    var best = -1 << 40, choice = open.first;
    final scores = <int, int>{};
    for (final c in _order.where(open.contains)) {
      final r = _height(board, c);
      board[c][r] = me;
      final v = _wins(board, c, r, me) ? 1 << 30 : -_search(board, depth - 1, -(1 << 40), 1 << 40, 1 - me);
      board[c][r] = -1;
      scores[c] = v;
      if (v > best) {
        best = v;
        choice = c;
      }
    }
    // Among equally good moves, a little variety.
    final ties = [
      for (final e in scores.entries)
        if (e.value == best) e.key,
    ];
    return ties.length > 1 ? ties[rng.nextInt(ties.length)] : choice;
  }

  /// Negamax with alpha-beta: the score for [p] to move.
  int _search(List<List<int>> b, int depth, int alpha, int beta, int p) {
    var any = false;
    if (depth == 0) return _score(b, p);
    var best = -(1 << 40);
    for (final c in _order) {
      final r = _height(b, c);
      if (r >= FourInARow.rows) continue;
      any = true;
      b[c][r] = p;
      final v = _wins(b, c, r, p) ? (1 << 30) + depth : -_search(b, depth - 1, -beta, -alpha, 1 - p);
      b[c][r] = -1;
      if (v > best) best = v;
      if (best > alpha) alpha = best;
      if (alpha >= beta) break;
    }
    return any ? best : 0; // full board: draw
  }

  static int _height(List<List<int>> b, int c) {
    final i = b[c].indexOf(-1);
    return i < 0 ? FourInARow.rows : i;
  }

  static bool _wins(List<List<int>> b, int col, int row, int p) {
    for (final (dc, dr) in const [(1, 0), (0, 1), (1, 1), (1, -1)]) {
      var n = 1;
      for (final s in const [1, -1]) {
        var c = col + dc * s, r = row + dr * s;
        while (c >= 0 && c < FourInARow.cols && r >= 0 && r < FourInARow.rows && b[c][r] == p) {
          n++;
          c += dc * s;
          r += dr * s;
        }
      }
      if (n >= 4) return true;
    }
    return false;
  }

  /// Position score for [p]: every window of four with only one player's
  /// discs counts (3 in a window is strong), plus the centre column.
  static int _score(List<List<int>> b, int p) {
    var s = 0;
    for (var r = 0; r < FourInARow.rows; r++) {
      if (b[3][r] == p) s += 3;
      if (b[3][r] == 1 - p) s -= 3;
    }
    void window(List<int> cells) {
      var mine = 0, theirs = 0;
      for (final v in cells) {
        if (v == p) mine++;
        if (v == 1 - p) theirs++;
      }
      if (theirs == 0) s += const [0, 1, 4, 20, 1000][mine];
      if (mine == 0) s -= const [0, 1, 4, 24, 1000][theirs];
    }

    for (var c = 0; c < FourInARow.cols; c++) {
      for (var r = 0; r < FourInARow.rows; r++) {
        if (c + 3 < FourInARow.cols) window([for (var k = 0; k < 4; k++) b[c + k][r]]);
        if (r + 3 < FourInARow.rows) window([for (var k = 0; k < 4; k++) b[c][r + k]]);
        if (c + 3 < FourInARow.cols && r + 3 < FourInARow.rows) {
          window([for (var k = 0; k < 4; k++) b[c + k][r + k]]);
        }
        if (c + 3 < FourInARow.cols && r - 3 >= 0) window([for (var k = 0; k < 4; k++) b[c + k][r - k]]);
      }
    }
    return s;
  }
}
