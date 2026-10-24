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
import '../../../core/online/party.dart';
import '../../../core/sound/sound.dart';
import 'online_row.dart';
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
  const RowScreen({super.key, required this.difficulty, this.pace = 1, this.seed, this.stake}) : party = null;

  /// With your party's friend, online: the referee runs the game.
  const RowScreen.online({super.key, required PartyService this.party})
    : difficulty = Difficulty.normal,
      pace = 1,
      seed = null,
      stake = null;

  final Difficulty difficulty;
  final double pace;
  final int? seed;
  final StakeTicket? stake;
  final PartyService? party;

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
  late final RowTable _c =
      (widget.party != null
            ? OnlineRowController(widget.party!, you: _account.persona)
            : RowController(
                difficulty: widget.difficulty,
                pace: widget.pace,
                rng: widget.seed == null ? null : Random(widget.seed),
                you: _account.persona,
              ))
        ..addListener(_settle);

  OnlineRowController? get _online => _c is OnlineRowController ? _c : null;

  /// The online match the stake is for.
  String? _ticketFor;

  /// Shown a moment after the last disc lands.
  var _showOver = false;

  @override
  void initState() {
    super.initState();
    widget.party?.showing(this, 'connect4');
    WidgetsBinding.instance.addPostFrameCallback((_) => _settle());
  }

  void _settle() {
    final online = _online;
    if (online != null) {
      // Each new match (the first, a rematch): put in its stake.
      final id = online.matchId;
      if (id != null && id != _ticketFor) {
        _ticketFor = id;
        setState(() {
          _showOver = false;
          _ticket = StakeTicket(
            account: _account,
            gameId: 'connect4',
            stake: _account.placeStake(online.stake),
            opponents: 1,
            difficulty: Difficulty.normal,
          );
        });
      }
      final error = online.error;
      if (error != null && mounted) {
        online.error = null;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error)));
      }
    }
    if (_c.over && !_ticket.settled) {
      _ticket.settle(
        _c.draw
            ? Outcome.tie
            : _c.youWon
            ? Outcome.win
            : Outcome.loss,
      );
      HapticFeedback.heavyImpact();
      if (!_c.draw) Sound.later(_c.youWon ? Sfx.winBig : Sfx.loseBig, 500);
      Future<void>.delayed(Duration(milliseconds: (1600 * widget.pace).round()), () {
        if (mounted) setState(() => _showOver = true);
      });
    }
  }

  void _playAgain() {
    final online = _online;
    if (online != null) {
      online.rematch().then((e) {
        if (e != null && mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(e)));
        }
      });
      return;
    }
    setState(() {
      _ticket = _ticket.again();
      _showOver = false;
    });
    (_c as RowController).playAgain();
  }

  @override
  void dispose() {
    widget.party?.hidden(this);
    (_c as ChangeNotifier).dispose();
    super.dispose();
  }

  String? _stage() {
    if (_c.over) return _c.draw ? 'end' : 'win';
    if (_c.yourTurn && (_c.threats.isNotEmpty || _c.yourWins.isNotEmpty)) return 'block';
    return 'turn';
  }

  Future<void> _leave() async {
    final online = _online;
    if (online != null) {
      if (online.live) {
        if (!await confirmLeave(context, _ticket, online: '${_c.bot.name} wins if you go.')) return;
        await online.forfeit();
      }
      // Back to the party: home, still together.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }
    if (_c.over || await confirmLeave(context, _ticket)) {
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
                    subtitle: _online != null
                        ? 'You vs ${_c.bot.name} · Online'
                        : 'You vs ${_c.bot.name} · ${widget.difficulty.label}',
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

  /// Online: seconds left on the turn, for whoever is moving.
  String _clock() {
    final online = _online;
    return online == null ? '' : ' · ${online.secondsLeft}s';
  }

  /// How much of the turn is left (online), for the ring round the face.
  double? _time(bool active) {
    final online = _online;
    if (online == null || !active) return null;
    return online.secondsLeft / 45;
  }

  Widget _botRow() => _Player(
    persona: _c.bot,
    color: Toon.yellow,
    active: _c.thinking,
    time: _time(_c.thinking),
    label: _c.thinking ? (_online != null ? 'Their turn${_clock()}' : 'Thinking…') : null,
  );

  Widget _youRow() {
    final mine = _c.yourTurn || (_online?.live == true && !_c.thinking);
    return _Player(
      persona: _c.you,
      color: Toon.red,
      active: mine,
      time: _time(mine),
      label: mine ? 'Your turn${_clock()}' : null,
    );
  }

  Widget _over(BuildContext context) {
    final g = _c.game;
    final won = _c.youWon;
    final online = _online;
    final name = _c.bot.name;
    final subtitle = switch (online?.reason) {
      'timeout' => won ? '$name ran out of time.' : 'You ran out of time.',
      'forfeit' => won ? '$name gave up.' : 'You gave up.',
      _ =>
        _c.draw
            ? 'The board filled up.'
            : won
            ? 'Four in a row in ${g.moves.length} moves.'
            : 'Four in a row, ${(g.moves.length / 2).ceil()} moves each.',
    };
    return GameOverCard(
      face: _c.draw || won ? _c.you : _c.bot,
      title: _c.draw ? "It's a draw" : (won ? 'You won!' : '$name won'),
      subtitle: subtitle,
      ticket: _ticket,
      won: won,
      onAgain: online == null ? _playAgain : (online.askedRematch || !online.friendHere ? null : _playAgain),
      againLabel: online == null
          ? 'Play again'
          : !online.friendHere
          ? '$name left'
          : online.askedRematch
          ? 'Waiting for $name…'
          : 'Rematch',
      leaveLabel: online == null ? 'Games' : 'Back to party',
      onLeave: online == null ? () => Navigator.of(context).pop() : _leave,
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
  const _Player({required this.persona, required this.color, required this.active, this.label, this.time});

  final Persona persona;
  final Color color;
  final bool active;
  final String? label;

  /// Online: the share of the turn left, drawn as a ring round the face.
  final double? time;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Row(
      children: [
        Stack(
          alignment: Alignment.center,
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
            if (time != null)
              SizedBox(
                width: 52,
                height: 52,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: time!.clamp(0, 1)),
                  duration: const Duration(milliseconds: 900),
                  builder: (context, t, _) => CircularProgressIndicator(
                    value: t,
                    strokeWidth: 4,
                    color: t < 0.25 ? Toon.red : Toon.green,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
          ],
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

  final RowTable c;

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
                // The board in layers, like the real thing: discs sit
                // behind a blue front with holes cut in it, so a dropped
                // disc shows through each hole as it falls past.
                Positioned(
                  left: 0,
                  top: 36,
                  width: width,
                  height: cell * 6 + 4,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(child: CustomPaint(painter: _BoardBack(cell))),
                      for (var col = 0; col < 7; col++)
                        for (var row = 0; row < 6; row++)
                          if (g.board[col][row] >= 0)
                            _disc(g, col, row, cell, isLast: col == last && row == lastRow),
                      Positioned.fill(
                        child: IgnorePointer(child: CustomPaint(painter: _BoardFront(cell))),
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
              ],
            ),
          ),
        );
      },
    );
  }

  /// The disc in [col], [row]; the newest one falls in from above the
  /// board, picking up speed, and settles with a little bounce.
  Widget _disc(FourInARow g, int col, int row, double cell, {required bool isLast}) {
    final d = cell * 0.8;
    final at = _BoardBack.hole(col, row, cell);
    Widget disc = _Disc(color: g.board[col][row] == 0 ? Toon.red : Toon.yellow, size: d);
    if (g.winningLine.contains((col, row))) disc = _Glow(child: disc);
    if (!isLast) {
      return Positioned(left: at.dx - d / 2, top: at.dy - d / 2, child: disc);
    }
    final start = -cell * 0.7;
    final fall = at.dy - start;
    // Time to fall grows with the square root of the distance (gravity),
    // plus the settle.
    final ms = (170 + 95 * sqrt(fall / cell)).round() + 140;
    const land = 0.8;
    return TweenAnimationBuilder<double>(
      key: ValueKey('drop${g.moves.length}'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      builder: (context, t, child) {
        final double y;
        if (t < land) {
          final u = t / land;
          y = start + fall * u * u; // speeding up
        } else {
          final b = (t - land) / (1 - land);
          y = at.dy - cell * 0.14 * sin(pi * b); // a small bounce, then rest
        }
        return Positioned(left: at.dx - d / 2, top: y - d / 2, child: child!);
      },
      child: _DropSound(ms: (ms * land).round(), child: disc),
    );
  }
}

/// The clack when the newest disc lands.
class _DropSound extends StatefulWidget {
  const _DropSound({required this.ms, required this.child});

  final int ms;
  final Widget child;

  @override
  State<_DropSound> createState() => _DropSoundState();
}

class _DropSoundState extends State<_DropSound> {
  @override
  void initState() {
    super.initState();
    Sound.later(Sfx.drop, widget.ms);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Behind the discs: the board's shadow and the dark inside of the holes.
class _BoardBack extends CustomPainter {
  _BoardBack(this.cell);

  final double cell;

  /// Centre of the hole at [col], [row] (row 0 at the bottom).
  static Offset hole(int col, int row, double cell) =>
      Offset(col * cell + cell / 2, (5 - row) * cell + cell / 2 + 2);

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16));
    canvas
      ..drawRRect(r.shift(const Offset(0, 5)), Paint()..color = Toon.ink)
      ..drawRRect(r, Paint()..color = Color.lerp(Toon.paper, Toon.ink, 0.12)!);
  }

  @override
  bool shouldRepaint(_BoardBack old) => old.cell != cell;
}

/// In front of the discs: the blue board with its holes cut out.
class _BoardFront extends CustomPainter {
  _BoardFront(this.cell);

  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16));
    final radius = cell * 0.42;
    final plate = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(r);
    for (var col = 0; col < 7; col++) {
      for (var row = 0; row < 6; row++) {
        plate.addOval(Rect.fromCircle(center: _BoardBack.hole(col, row, cell), radius: radius));
      }
    }
    canvas.drawPath(plate, Paint()..color = Toon.blue);
    // A lighter top edge on each hole, as if the board has some depth.
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Toon.ink;
    final shine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.35);
    for (var col = 0; col < 7; col++) {
      for (var row = 0; row < 6; row++) {
        final c = _BoardBack.hole(col, row, cell);
        canvas
          ..drawCircle(c, radius, rim)
          ..drawArc(Rect.fromCircle(center: c, radius: radius + 2.5), pi * 1.1, pi * 0.8, false, shine);
      }
    }
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = Toon.outline
        ..color = Toon.ink,
    );
  }

  @override
  bool shouldRepaint(_BoardFront old) => old.cell != cell;
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
  Widget build(BuildContext context) => RepaintBoundary(
    child: ScaleTransition(
      scale: Tween(begin: 0.92, end: 1.08).animate(_a),
      child: RepaintBoundary(child: widget.child),
    ),
  );
}

class _WinLine extends CustomPainter {
  _WinLine(this.cells, this.cell);

  final List<(int, int)> cells;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    Offset center((int, int) c) => _BoardBack.hole(c.$1, c.$2, cell);
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
