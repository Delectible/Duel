import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/account/account.dart';
import '../../../core/account/stake.dart';
import '../../../core/avatars/faces.dart';
import '../../../core/help/game_guide.dart';
import 'package:duel_engine/difficulty.dart';
import '../../../core/table/table_bits.dart';
import '../../../core/theme/toon.dart';
import 'package:duel_engine/four_in_a_row/four_in_a_row.dart';
import 'row_controller.dart';

const rowGuide = [
  GuideStage(
    'turn',
    'Your turn',
    'Tap a column to drop a red disc. It falls to the lowest free space. You and the bot take turns; the '
        'first player swaps each game.',
    icon: Icons.touch_app_rounded,
  ),
  GuideStage(
    'win',
    'Four in a row',
    'Line up four of your discs across, up and down, or diagonally to win.',
    icon: Icons.emoji_events_rounded,
  ),
  GuideStage(
    'block',
    'Watch out',
    "If the bot has three lined up with a free fourth space, block it on your turn. Duel warns you and "
        'marks the column in red; a green mark means you can win there.',
    icon: Icons.warning_amber_rounded,
  ),
  GuideStage(
    'tips',
    'Tips',
    'The middle column is the strongest: more lines go through it. Try to set up two threats at once; they '
        "can only block one. Look out for discs that would give the bot a space to land on.",
    icon: Icons.lightbulb_outline_rounded,
  ),
  GuideStage(
    'end',
    'A draw',
    'If all 42 spaces fill up with no four in a row, it is a draw: a staked game gives your stake back.',
    icon: Icons.handshake_rounded,
  ),
];

/// Four in a Row against one bot.
class RowScreen extends StatefulWidget {
  const RowScreen({super.key, required this.difficulty, this.pace = 1, this.seed, this.stake});

  final Difficulty difficulty;
  final double pace;
  final int? seed;
  final StakeTicket? stake;

  @override
  State<RowScreen> createState() => _RowScreenState();
}

class _RowScreenState extends State<RowScreen> {
  late final Account _account = AccountScope.maybeRead(context) ?? Account();
  late StakeTicket _ticket =
      widget.stake ??
      StakeTicket(
        account: _account,
        gameId: 'connect4',
        stake: 0,
        opponents: 1,
        difficulty: widget.difficulty,
      );
  late final RowController _c = RowController(
    difficulty: widget.difficulty,
    pace: widget.pace,
    rng: widget.seed == null ? null : Random(widget.seed),
    you: _account.persona,
  )..addListener(_settle);

  /// Shown a moment after the last disc lands.
  var _showOver = false;

  void _settle() {
    final g = _c.game;
    if (g.isOver && !_ticket.settled) {
      _ticket.settle(
        g.draw
            ? Outcome.tie
            : g.winner == 0
            ? Outcome.win
            : Outcome.loss,
      );
      HapticFeedback.heavyImpact();
      Future<void>.delayed(Duration(milliseconds: (1600 * widget.pace).round()), () {
        if (mounted) setState(() => _showOver = true);
      });
    }
  }

  void _playAgain() {
    setState(() {
      _ticket = _ticket.again();
      _showOver = false;
    });
    _c.playAgain();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String? _stage() {
    final g = _c.game;
    if (g.isOver) return g.draw ? 'end' : 'win';
    if (_c.yourTurn && (_c.threats.isNotEmpty || _c.yourWins.isNotEmpty)) return 'block';
    return 'turn';
  }

  Future<void> _leave() async {
    if (_c.game.isOver || await confirmLeave(context, _ticket)) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _c,
            builder: (context, _) => Stack(
              children: [
                GameLayout(
                  top: GameTopBar(
                    title: 'Four in a Row',
                    subtitle: 'You vs ${_c.bot.name} · ${widget.difficulty.label}',
                    onLeave: _leave,
                    ticket: _ticket,
                    guide: rowGuide,
                    stage: _stage,
                  ),
                  commentary: CommentaryStrip(
                    text: _c.commentary(),
                    yourMove: _c.yourTurn,
                    leading: _c.threats.isNotEmpty && _c.yourTurn
                        ? const Icon(Icons.warning_amber_rounded, color: Toon.red, size: 30)
                        : _Disc(color: _c.yourTurn ? Toon.red : Toon.yellow, size: 28),
                  ),
                  table: Builder(
                    builder: (context) => GameLayout.wide(context)
                        ? _Board(c: _c)
                        : Column(
                            children: [
                              _botRow(),
                              Expanded(child: _Board(c: _c)),
                            ],
                          ),
                  ),
                  panelExtra: Column(mainAxisSize: MainAxisSize.min, children: [_botRow(), _youRow()]),
                  controls: Builder(
                    builder: (context) => GameLayout.wide(context)
                        ? const SizedBox(height: 8)
                        : Padding(padding: const EdgeInsets.only(bottom: 8), child: _youRow()),
                  ),
                ),
                if (_showOver) Positioned.fill(child: _over(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _botRow() => _Player(
    persona: _c.bot,
    color: Toon.yellow,
    active: _c.thinking,
    label: _c.thinking ? 'Thinking…' : null,
  );

  Widget _youRow() =>
      _Player(persona: _c.you, color: Toon.red, active: _c.yourTurn, label: _c.yourTurn ? 'Your turn' : null);

  Widget _over(BuildContext context) {
    final g = _c.game;
    final won = g.winner == 0;
    return GameOverCard(
      face: g.draw || won ? _c.you : _c.bot,
      title: g.draw ? "It's a draw" : (won ? 'You won!' : '${_c.bot.name} won'),
      subtitle: g.draw
          ? 'The board filled up.'
          : won
          ? 'Four in a row in ${g.moves.length} moves.'
          : 'Four in a row, ${(g.moves.length / 2).ceil()} moves each.',
      ticket: _ticket,
      won: won,
      onAgain: _playAgain,
      onLeave: () => Navigator.of(context).pop(),
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      border: Border.all(color: Toon.ink, width: size * 0.09),
    ),
    child: Center(
      child: Container(
        width: size * 0.55,
        height: size * 0.55,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: size * 0.07),
        ),
      ),
    ),
  );
}

class _Player extends StatelessWidget {
  const _Player({required this.persona, required this.color, required this.active, this.label});

  final Persona persona;
  final Color color;
  final bool active;
  final String? label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: active ? color : Toon.card,
            shape: BoxShape.circle,
            border: Border.all(color: Toon.ink, width: Toon.outline),
          ),
          child: Face(persona, size: 36),
        ),
        const SizedBox(width: 8),
        _Disc(color: color, size: 20),
        const SizedBox(width: 6),
        Text(persona.name, style: Toon.text(16)),
        const Spacer(),
        if (label != null)
          Pop(
            key: ValueKey(label),
            child: Text(label!, style: Toon.text(14, color: Toon.muted)),
          ),
      ],
    ),
  );
}

/// The blue board: tap a column to drop. The newest disc falls in and
/// bounces; winning discs pulse with a line through them; green / red
/// markers over columns where you can win / must block.
class _Board extends StatelessWidget {
  const _Board({required this.c});

  final RowController c;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = min(box.maxWidth - 28, (box.maxHeight - 40) * 7 / 6.3);
        final cell = width / 7;
        final g = c.game;
        final last = g.moves.isEmpty ? null : g.moves.last;
        final lastRow = last == null ? null : g.height(last) - 1;
        final wins = c.yourTurn ? c.yourWins.toSet() : <int>{};
        final danger = c.yourTurn ? c.threats.toSet() : <int>{};
        return Center(
          child: SizedBox(
            width: width,
            height: cell * 6 + 40,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Column markers.
                for (var col = 0; col < 7; col++)
                  if (wins.contains(col) || danger.contains(col))
                    Positioned(
                      left: col * cell,
                      top: 0,
                      width: cell,
                      height: 34,
                      child: Pop(
                        key: ValueKey('mark$col-${g.moves.length}'),
                        child: Icon(
                          wins.contains(col) ? Icons.star_rounded : Icons.arrow_downward_rounded,
                          color: wins.contains(col) ? Toon.green : Toon.red,
                          size: 30,
                        ),
                      ),
                    ),
                Positioned(
                  left: 0,
                  top: 36,
                  width: width,
                  height: cell * 6 + 4,
                  child: Container(
                    decoration: Toon.box(Toon.blue, radius: 16, shadow: 5),
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        for (var col = 0; col < 7; col++)
                          for (var row = 0; row < 6; row++)
                            Positioned(
                              left: col * cell + cell * 0.08 - 2,
                              top: (5 - row) * cell + cell * 0.08 - 1,
                              child: _cell(g, col, row, cell, isLast: col == last && row == lastRow),
                            ),
                        if (g.winningLine.isNotEmpty)
                          Positioned.fill(
                            child: IgnorePointer(child: CustomPaint(painter: _WinLine(g.winningLine, cell))),
                          ),
                        // Tap targets, one per column.
                        Row(
                          children: [
                            for (var col = 0; col < 7; col++)
                              Expanded(
                                child: GestureDetector(
                                  key: Key('col $col'),
                                  behavior: HitTestBehavior.opaque,
                                  onTap: c.yourTurn && g.canDrop(col)
                                      ? () {
                                          HapticFeedback.lightImpact();
                                          c.drop(col);
                                        }
                                      : null,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _cell(FourInARow g, int col, int row, double cell, {required bool isLast}) {
    final d = cell * 0.84;
    final v = g.board[col][row];
    final hole = Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Toon.paper,
        border: Border.all(color: Toon.ink, width: 2),
      ),
    );
    if (v < 0) return hole;
    final winning = g.winningLine.contains((col, row));
    Widget disc = _Disc(color: v == 0 ? Toon.red : Toon.yellow, size: d);
    if (winning) disc = _Glow(child: disc);
    if (isLast) {
      // Falls from above the board and bounces into its hole.
      final fall = (6 - row) * cell;
      disc = TweenAnimationBuilder<double>(
        key: ValueKey('drop${g.moves.length}'),
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 260 + (6 - row) * 55),
        curve: Curves.bounceOut,
        builder: (context, t, child) => Transform.translate(offset: Offset(0, -fall * (1 - t)), child: child),
        child: disc,
      );
    }
    return Stack(children: [hole, disc]);
  }
}

class _Glow extends StatefulWidget {
  const _Glow({required this.child});

  final Widget child;

  @override
  State<_Glow> createState() => _GlowState();
}

class _GlowState extends State<_Glow> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: Tween(begin: 0.92, end: 1.08).animate(_a), child: widget.child);
}

class _WinLine extends CustomPainter {
  _WinLine(this.cells, this.cell);

  final List<(int, int)> cells;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    Offset center((int, int) c) => Offset(c.$1 * cell + cell / 2, (5 - c.$2) * cell + cell / 2);
    final a = center(cells.first), b = center(cells.last);
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = Toon.inkLight
        ..strokeWidth = cell * 0.22
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = Colors.white
        ..strokeWidth = cell * 0.1
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_WinLine old) => old.cells != cells;
}
