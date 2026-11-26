import 'dart:math';

import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/liars/liars.dart';
import 'package:flutter/material.dart';

import '../../../core/account/account.dart';
import '../../../core/account/stake.dart';
import '../../../core/help/game_guide.dart';
import '../../../core/online/online_link.dart';
import '../../../core/table/table_bits.dart';
import '../../../core/theme/toon.dart';
import '../../bank/dice.dart';
import 'liars_controller.dart';

const liarsGuide = [
  GuideStage(
    'shake',
    'Shake',
    'Everyone has dice under a cup. Each round, all cups are shaken; you see your own dice and nobody else\'s.',
    icon: Icons.local_drink_rounded,
  ),
  GuideStage(
    'bid',
    'Bidding',
    'In turn, guess how many dice on the WHOLE table show a face: "three 5s" means at least three dice showing 5, '
        'counting every cup. Each bid must go up: more dice, or the same number on a higher face. Ones are wild: they '
        'count as every face.',
    icon: Icons.record_voice_over_rounded,
  ),
  GuideStage(
    'call',
    'Liar!',
    'Think the last bid is too high? Call Liar! Every cup comes up and the dice are counted. If there are fewer '
        'than bid, the bidder loses a die; if there are enough, you do.',
    icon: Icons.campaign_rounded,
  ),
  GuideStage(
    'spot',
    'Spot on',
    'Think the bid is exactly right? Call Spot on: if you\'re right you win a die back (up to where you started); '
        'if not, you lose one.',
    icon: Icons.gps_fixed_rounded,
  ),
  GuideStage(
    'end',
    'Winning',
    'Out of dice, out of the game. The last player with dice under their cup wins. Whoever lost a die starts the '
        'next round.',
    icon: Icons.emoji_events_rounded,
  ),
];

/// The tavern's colours: a candle-lit table whatever the app's theme.
abstract final class Tavern {
  static const wood = Color(0xFF3A2416);
  static const woodLight = Color(0xFF5A3A22);
  static const cloth = Color(0xFF7A2E24);
  static const clothDark = Color(0xFF4E1B16);
  static const candle = Color(0xFFFFC75A);
  static const brass = Color(0xFFD9A441);
  static const cups = [
    Color(0xFF8B5A2B),
    Color(0xFF2F5D62),
    Color(0xFF6D3B6E),
    Color(0xFF3F6B35),
    Color(0xFF8A3B2E),
    Color(0xFF3D4A7A),
  ];
}

/// Liar's Dice against bots, or with your party.
class LiarsScreen extends StatefulWidget {
  const LiarsScreen({
    super.key,
    this.bots = 3,
    this.difficulty = Difficulty.normal,
    this.rules = const LiarsRules(),
    this.pace = 1,
    this.seed,
    this.stake,
  }) : link = null;

  LiarsScreen.online({super.key, required OnlineLink this.link, required StakeTicket this.stake})
    : bots = link.n - 1,
      difficulty = Difficulty.normal,
      rules = const LiarsRules(),
      pace = 1,
      seed = null;

  final OnlineLink? link;
  final int bots;
  final Difficulty difficulty;
  final LiarsRules rules;
  final double pace;
  final int? seed;
  final StakeTicket? stake;

  @override
  State<LiarsScreen> createState() => _LiarsScreenState();
}

class _LiarsScreenState extends State<LiarsScreen> {
  late final Account _account = AccountScope.maybeRead(context) ?? Account();
  late StakeTicket _ticket =
      widget.stake ??
      StakeTicket(
        account: _account,
        gameId: 'liars',
        stake: 0,
        opponents: widget.bots,
        difficulty: widget.difficulty,
      );
  late final LiarsController _c = LiarsController(
    bots: widget.bots,
    difficulty: widget.difficulty,
    rules: widget.rules,
    pace: widget.pace,
    rng: widget.seed == null ? null : Random(widget.seed),
    you: _account.persona,
    link: widget.link,
  )..addListener(_settle);

  void _settle() {
    if (_c.phase == LiarsPhase.over && !_ticket.settled) {
      _ticket.settle(_c.game.winner == 0 ? Outcome.win : Outcome.loss);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    final link = widget.link;
    if (link != null) return link.leave(context, _ticket, over: _c.phase == LiarsPhase.over);
    if (_c.phase == LiarsPhase.over || await confirmLeave(context, _ticket)) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  String? _stage() => switch (_c.phase) {
    LiarsPhase.shaking => 'shake',
    LiarsPhase.bidding => _c.game.bid == null ? 'bid' : 'call',
    LiarsPhase.reveal => _c.game.reveal?.call == LiarsCall.spotOn ? 'spot' : 'call',
    LiarsPhase.over => 'end',
  };

  @override
  Widget build(BuildContext context) => PopScope(
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
                  title: 'Liar\'s Dice',
                  subtitle: widget.link != null
                      ? 'With your party${_c.yourTurn ? ' · ${widget.link!.secondsLeft}s' : ''}'
                      : 'You + ${widget.bots} ${widget.bots == 1 ? 'bot' : 'bots'} · ${widget.difficulty.label}',
                  onLeave: _leave,
                  ticket: _ticket,
                  guide: liarsGuide,
                  stage: _stage,
                ),
                commentary: CommentaryStrip(
                  text: _c.commentary(),
                  yourMove: _c.yourTurn,
                  leading: _DiceLeft(c: _c),
                ),
                table: _Table(c: _c),
                controls: _Controls(c: _c),
              ),
              if (_c.phase == LiarsPhase.over) Positioned.fill(child: _over(context)),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _over(BuildContext context) {
    final g = _c.game;
    final w = g.winner ?? 0;
    final won = w == 0;
    final place = g.outOrder.reversed.toList().indexOf(0) + 1;
    return GameOverCard(
      face: _c.personas[w],
      title: won ? 'Last cup standing!' : '${_c.personas[w].name} won',
      subtitle: won
          ? 'You out-bluffed ${g.players - 1 == 1 ? 'them' : 'all ${g.players - 1}'}.'
          : 'You came ${_ordinal(place)} of ${g.players}.',
      ticket: _ticket,
      won: won,
      onAgain: widget.link == null
          ? () {
              setState(() => _ticket = _ticket.again());
              _c.playAgain();
            }
          : widget.link!.rematch,
      againLabel: widget.link?.rematchLabel ?? 'Play again',
      leaveLabel: widget.link == null ? 'Back' : 'Back to party',
      onLeave: widget.link == null ? () => Navigator.of(context).pop() : _leave,
    );
  }
}

String _ordinal(int n) => switch (n) {
  1 => '1st',
  2 => '2nd',
  3 => '3rd',
  _ => '${n}th',
};

/// How many dice are out on the table (the number every bid is out of).
class _DiceLeft extends StatelessWidget {
  const _DiceLeft({required this.c});

  final LiarsController c;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 52),
    padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
    decoration: Toon.box(Toon.cardFace, radius: 10, shadow: 0),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${c.game.totalDice}',
          style: Toon.text(20, weight: FontWeight.w700, color: Toon.inkLight),
        ),
        Text('dice', style: Toon.text(10, color: Toon.inkLight)),
      ],
    ),
  );
}

// --- The table -------------------------------------------------------------------

class _Table extends StatelessWidget {
  const _Table({required this.c});

  final LiarsController c;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final size = Size(box.maxWidth, box.maxHeight);
      final wide = GameLayout.wide(context);
      final others = [for (var p = 1; p < c.players; p++) p];
      // The others round the top of the table, you at the bottom.
      final n = others.length;
      // Four or more: two staggered rows, so neighbours never overlap.
      final zigzag = n >= 4 && !wide;
      final cupW =
          (zigzag
                  ? min(size.width * 2 / n / 1.95, size.height * 0.15)
                  : min(size.width / max(3, n + 0.6), size.height * 0.2))
              .clamp(40.0, 78.0);
      final seatH = cupW * 0.98 + 66;
      Offset seatAt(int i) {
        if (zigzag) {
          final x = size.width * (i + 0.5) / n;
          final top = cupW * 0.95 + 14;
          return Offset(x, i.isOdd ? top : top + seatH * 0.62);
        }
        final t = n == 1 ? 0.5 : i / (n - 1);
        final a = pi * (0.92 - t * 0.84);
        final cy = size.height * (wide ? 0.44 : 0.36);
        final rx = size.width * (wide ? 0.4 : 0.37);
        // The seat at the top stays on the table.
        final ry = max(0.0, min(size.height * (wide ? 0.34 : 0.3), cy - cupW * 0.95 - 16));
        return Offset(size.width / 2 + cos(a) * rx, cy - sin(a) * ry);
      }

      final plaqueTop = zigzag
          ? cupW * 0.95 + 14 + seatH * 0.62 + seatH - cupW * 0.95 + 4
          : size.height * (wide ? 0.4 : 0.44);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(
            child: RepaintBoundary(child: CustomPaint(painter: _TablePainter())),
          ),
          for (final (i, p) in others.indexed)
            Positioned(
              left: (seatAt(i).dx - cupW * 0.95).clamp(0.0, max(0.0, size.width - cupW * 1.9)),
              top: seatAt(i).dy - cupW * 0.95,
              width: cupW * 1.9,
              child: _Seat(c: c, p: p, cup: cupW),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: plaqueTop,
            child: Center(child: _BidPlaque(c: c)),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 6,
            child: Center(
              child: _YourCup(c: c, width: min(size.width * 0.86, 330)),
            ),
          ),
        ],
      );
    },
  );
}

/// The table: dark wood, a red cloth, candlelight in the middle.
class _TablePainter extends CustomPainter {
  const _TablePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(22));
    canvas.drawRRect(r, Paint()..color = Tavern.wood);
    // Wood grain.
    final grain = Paint()
      ..color = Tavern.woodLight.withValues(alpha: 0.35)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (var y = 6.0; y < size.height; y += 9) {
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += 24) {
        path.lineTo(x, y + sin((x + y * 3) / 40) * 2);
      }
      canvas.drawPath(path, grain);
    }
    final cloth = RRect.fromRectAndRadius(
      Rect.fromLTWH(12, 12, size.width - 24, size.height - 24),
      const Radius.circular(18),
    );
    canvas.drawRRect(
      cloth,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.1),
          radius: 0.95,
          colors: [Tavern.cloth, Tavern.clothDark],
        ).createShader(cloth.outerRect),
    );
    // Candlelight pooling on the cloth.
    canvas.drawRRect(
      cloth,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.05),
          radius: 0.6,
          colors: [Tavern.candle.withValues(alpha: 0.22), Tavern.candle.withValues(alpha: 0)],
        ).createShader(cloth.outerRect),
    );
    // Brass studs round the cloth's edge.
    final stud = Paint()..color = Tavern.brass;
    for (var x = 30.0; x < size.width - 20; x += 34) {
      canvas.drawCircle(Offset(x, 12), 2.4, stud);
      canvas.drawCircle(Offset(x, size.height - 12), 2.4, stud);
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
  bool shouldRepaint(_TablePainter old) => false;
}

/// Which dice light up in the reveal: the ones that count, in seat order,
/// up to how many have been counted.
Set<(int, int)> _lit(LiarsController c) {
  final r = c.game.reveal;
  if (r == null || c.phase != LiarsPhase.reveal) return const {};
  final lit = <(int, int)>{};
  for (var p = 0; p < r.dice.length; p++) {
    for (final (i, d) in r.dice[p].indexed) {
      final match = d == r.bid.face || (c.rulesNow.onesWild && d == 1 && r.bid.face != 1);
      if (match && lit.length < c.counted) lit.add((p, i));
    }
  }
  return lit;
}

/// Someone else at the table: their face, their cup (how many dice under
/// it), what they said; in a reveal, the cup's up and their dice show.
class _Seat extends StatelessWidget {
  const _Seat({required this.c, required this.p, required this.cup});

  final LiarsController c;
  final int p;
  final double cup;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    final out = !g.isIn(p) && !(c.phase == LiarsPhase.reveal && (g.reveal?.dice[p].isNotEmpty ?? false));
    final turn = g.turn == p && c.phase == LiarsPhase.bidding;
    final said = c.speech[p];
    final reveal = c.phase == LiarsPhase.reveal ? g.reveal : null;
    final lit = _lit(c);
    final cupColor = Tavern.cups[p % Tavern.cups.length];
    return Opacity(
      opacity: out ? 0.45 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: cup * 0.98,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                if (reveal != null)
                  Positioned(
                    bottom: 0,
                    width: cup * 1.9,
                    child: _DiceRow(
                      dice: reveal.dice[p],
                      size: cup * 0.27,
                      lit: {
                        for (final (q, i) in lit)
                          if (q == p) i,
                      },
                    ),
                  ),
                _Cup(
                  color: cupColor,
                  width: cup,
                  lifted: reveal != null,
                  shake: c.phase == LiarsPhase.shaking ? c.shakes : null,
                  lost: c.verdict && c.lostBy == p,
                  gained: c.verdict && c.gainedBy == p,
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaceRing(c.personas[p], size: 30, color: turn ? Tavern.candle : null),
              const SizedBox(width: 4),
              Flexible(child: NamePlate(c.personas[p].name, line: _pips(g.counts[p]), maxWidth: 84)),
            ],
          ),
          SizedBox(
            height: 30,
            child: c.thinking == p
                ? const Padding(padding: EdgeInsets.only(top: 3), child: _Thinking())
                : said != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: SpeechBubble(said, key: ValueKey('say$p-${c.speechId}')),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

/// "●●●○○"-ish: dice left, as a number with a die.
String _pips(int n) => n == 0 ? 'out' : '$n ${n == 1 ? 'die' : 'dice'}';

/// Three dots, bobbing: thinking.
class _Thinking extends StatefulWidget {
  const _Thinking();

  @override
  State<_Thinking> createState() => _ThinkingState();
}

class _ThinkingState extends State<_Thinking> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: Toon.box(Toon.cardFace, radius: 10, shadow: 0),
      child: AnimatedBuilder(
        animation: _a,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Transform.translate(
                offset: Offset(0, -3 * max(0, sin((_a.value - i * 0.18) * 2 * pi))),
                child: Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: const BoxDecoration(color: Toon.inkLight, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// A row of dice; [lit] ones glow (they counted).
class _DiceRow extends StatelessWidget {
  const _DiceRow({required this.dice, required this.size, this.lit = const {}});

  final List<int> dice;
  final double size;
  final Set<int> lit;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    runSpacing: size * 0.08,
    children: [
      for (final (i, d) in dice.indexed)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.04),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: lit.contains(i)
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(size * 0.3),
                    boxShadow: [
                      BoxShadow(color: Tavern.candle.withValues(alpha: 0.9), blurRadius: 12, spreadRadius: 1),
                    ],
                  )
                : null,
            child: AnimatedScale(
              scale: lit.contains(i) ? 1.15 : 1,
              duration: const Duration(milliseconds: 180),
              child: d == 0
                  ? SizedBox.square(dimension: size)
                  : Die(d, size: size, angle: (i * 0.37 + d * 0.21) % 0.6 - 0.3),
            ),
          ),
        ),
    ],
  );
}

/// A leather dice cup, upside down on the table. [lifted] tips it up and
/// away; [shake] (bumped each round) rattles it; a die pops off when
/// [lost] (or on when [gained]).
class _Cup extends StatelessWidget {
  const _Cup({
    required this.color,
    required this.width,
    this.lifted = false,
    this.shake,
    this.lost = false,
    this.gained = false,
  });

  final Color color;
  final double width;
  final bool lifted;
  final int? shake;
  final bool lost, gained;

  @override
  Widget build(BuildContext context) {
    final cup = RepaintBoundary(
      child: CustomPaint(size: Size(width, width * 0.95), painter: _CupPainter(color)),
    );
    Widget body = AnimatedSlide(
      offset: lifted ? const Offset(0.0, -0.75) : Offset.zero,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      child: AnimatedRotation(
        turns: lifted ? -0.06 : 0,
        duration: const Duration(milliseconds: 420),
        child: AnimatedOpacity(
          opacity: lifted ? 0.55 : 1,
          duration: const Duration(milliseconds: 420),
          child: cup,
        ),
      ),
    );
    if (shake != null) {
      body = TweenAnimationBuilder<double>(
        key: ValueKey('shake$shake'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1300),
        builder: (context, t, child) {
          final fade = (1 - t) * (1 - t);
          return Transform.translate(
            offset: Offset(sin(t * 40) * 5 * fade, -cos(t * 33).abs() * 7 * fade),
            child: Transform.rotate(angle: sin(t * 36) * 0.16 * fade, child: child),
          );
        },
        child: body,
      );
    }
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        body,
        if (lost || gained)
          TweenAnimationBuilder<double>(
            key: ValueKey('die$lost$gained'),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1100),
            builder: (context, t, child) => Transform.translate(
              offset: Offset(
                width * 0.5 * t,
                (gained ? 1 - t : t) * -width * 0.9 + (gained ? 0 : 1) * sin(t * pi) * -10,
              ),
              child: Opacity(opacity: (gained ? t : 1 - t).clamp(0.0, 1.0), child: child),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Die(
                  gained ? 6 : 1,
                  size: width * 0.34,
                  color: gained ? Toon.cardFace : const Color(0xFFFFB4A8),
                ),
                const SizedBox(width: 2),
                Text(
                  gained ? '+1' : '−1',
                  style: Toon.text(
                    width * 0.28,
                    weight: FontWeight.w700,
                    color: gained ? Toon.green : Toon.red,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CupPainter extends CustomPainter {
  const _CupPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Upside down: a narrow rounded top, flaring to the rim on the table.
    final body = Path()
      ..moveTo(w * 0.22, h * 0.1)
      ..quadraticBezierTo(w * 0.5, -h * 0.02, w * 0.78, h * 0.1)
      ..lineTo(w * 0.95, h * 0.86)
      ..quadraticBezierTo(w * 0.5, h * 1.0, w * 0.05, h * 0.86)
      ..close();
    canvas.drawPath(body.shift(const Offset(2, 3)), Paint()..color = Colors.black.withValues(alpha: 0.3));
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          colors: [Color.lerp(color, Colors.white, 0.18)!, color, Color.lerp(color, Colors.black, 0.35)!],
          stops: const [0, 0.45, 1],
        ).createShader(Offset.zero & size),
    );
    // Two bands, and stitching down the side.
    final band = Paint()..color = Color.lerp(color, Colors.black, 0.45)!;
    for (final y in [0.24, 0.74]) {
      final x0 = w * (0.22 - (y - 0.1) * 0.23), x1 = w - x0;
      canvas.drawRRect(
        RRect.fromLTRBR(x0 - 1, h * y, x1 + 1, h * y + h * 0.07, const Radius.circular(3)),
        band,
      );
    }
    final stitch = Paint()
      ..color = Tavern.brass.withValues(alpha: 0.85)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var y = h * 0.34; y < h * 0.7; y += h * 0.06) {
      canvas.drawLine(Offset(w * 0.5, y), Offset(w * 0.5, y + h * 0.03), stitch);
    }
    // A shine.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.3, h * 0.16)
        ..lineTo(w * 0.36, h * 0.16)
        ..lineTo(w * 0.24, h * 0.8)
        ..lineTo(w * 0.17, h * 0.8)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.14),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = Toon.ink,
    );
  }

  @override
  bool shouldRepaint(_CupPainter old) => old.color != color;
}

/// The standing bid, on a brass plaque in the middle; the round's bids so
/// far under it.
class _BidPlaque extends StatelessWidget {
  const _BidPlaque({required this.c});

  final LiarsController c;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    final b = g.bid;
    final r = c.phase == LiarsPhase.reveal ? g.reveal : null;
    if (b == null && r == null) {
      return Text(
        c.phase == LiarsPhase.shaking ? 'Shake!' : 'No bid yet',
        style: Toon.text(20, weight: FontWeight.w700, color: Tavern.candle.withValues(alpha: 0.8)),
      );
    }
    final shown = r?.bid ?? b!;
    final history = g.bids.length > 1
        ? g.bids.sublist(max(0, g.bids.length - 5), g.bids.length - 1)
        : const <(int, LiarsBid)>[];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Pop(
          key: ValueKey('bid${g.round}-${g.bids.length}'),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFF2CC6B), Tavern.brass, Color(0xFFA9792A)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Toon.ink, width: Toon.outline),
              boxShadow: const [BoxShadow(color: Colors.black38, offset: Offset(0, 3), blurRadius: 4)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  r != null && c.verdict ? '${r.found} of ${shown.count}' : '${shown.count} ×',
                  style: Toon.text(30, weight: FontWeight.w700, color: Toon.inkLight),
                ),
                const SizedBox(width: 8),
                Die(shown.face, size: 38),
              ],
            ),
          ),
        ),
        if (r != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _Verdict(c: c),
          )
        else if (history.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (p, h) in history)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${p == 0 ? 'You' : c.personas[p].name.split(' ').first} ${h.count}×',
                          style: Toon.text(11, weight: FontWeight.w600, color: Colors.white70),
                        ),
                        const SizedBox(width: 2),
                        FlatDie(h.face, size: 14),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The count as it goes, then who was right.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.c});

  final LiarsController c;

  @override
  Widget build(BuildContext context) {
    final r = c.game.reveal!;
    if (!c.verdict) {
      return Text(
        'Counting… ${c.counted}',
        style: Toon.text(18, weight: FontWeight.w700, color: Colors.white),
      );
    }
    final right = r.call == LiarsCall.liar ? !r.bidStood : r.found == r.bid.count;
    final who = r.caller == 0 ? 'You' : c.personas[r.caller].name;
    final text = switch ((r.call, right)) {
      (LiarsCall.liar, true) => 'Liar caught!',
      (LiarsCall.liar, false) => 'The bid stood!',
      (LiarsCall.spotOn, true) => 'Spot on!',
      (LiarsCall.spotOn, false) => 'Not quite!',
    };
    return Pop(
      key: ValueKey('verdict${c.game.round}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: Toon.box(right ? Toon.green : Toon.red, radius: 12, shadow: 2),
        child: Text(
          '$text  ($who called)',
          style: Toon.text(16, weight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }
}

/// Your cup: shaken each round, then lifted so you can see your dice
/// (tap it to put it down and up again). Out, it says so.
class _YourCup extends StatelessWidget {
  const _YourCup({required this.c, required this.width});

  final LiarsController c;
  final double width;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    final reveal = c.phase == LiarsPhase.reveal ? g.reveal : null;
    final dice = reveal?.dice[0] ?? g.dice[0];
    if (!g.isIn(0) && reveal == null) {
      return Text(
        'You\'re out of dice',
        style: Toon.text(16, weight: FontWeight.w700, color: Colors.white70),
      );
    }
    final lit = {
      for (final (q, i) in _lit(c))
        if (q == 0) i,
    };
    final die = min(width / 7.4, 44.0);
    final cupW = die * 2.3;
    final up = c.peeking || reveal != null;
    return GestureDetector(
      key: const Key('your cup'),
      onTap: c.togglePeek,
      child: SizedBox(
        width: width,
        height: die * 2.6,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              bottom: 4,
              left: 0,
              right: up ? cupW * 0.75 : 0,
              child: AnimatedOpacity(
                opacity: up ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: _DiceRow(dice: dice, size: die, lit: lit),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              bottom: 0,
              left: up ? width - cupW * 0.85 : (width - cupW) / 2,
              child: AnimatedScale(
                scale: up ? 0.6 : 1,
                duration: const Duration(milliseconds: 350),
                child: _Cup(
                  color: Tavern.cups[0],
                  width: cupW,
                  lifted: false,
                  shake: c.phase == LiarsPhase.shaking ? c.shakes : null,
                  lost: c.verdict && c.lostBy == 0,
                  gained: c.verdict && c.gainedBy == 0,
                ),
              ),
            ),
            if (!up && c.phase == LiarsPhase.bidding)
              Positioned(
                top: 0,
                child: Text(
                  'Tap to look',
                  style: Toon.text(12, weight: FontWeight.w600, color: Colors.white70),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- Controls -------------------------------------------------------------------

class _Controls extends StatelessWidget {
  const _Controls({required this.c});

  final LiarsController c;

  @override
  Widget build(BuildContext context) {
    if (!c.yourTurn) {
      final odds = c.odds;
      return SizedBox(
        height: 48,
        child: Center(
          child: Text(
            odds != null && c.phase == LiarsPhase.bidding && c.game.isIn(0)
                ? 'That bid: ${(odds * 100).round()}% likely, from your cup'
                : '',
            style: Toon.text(14, weight: FontWeight.w600, color: Toon.muted),
          ),
        ),
      );
    }
    final g = c.game;
    final odds = c.odds;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The face to bid on.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var f = c.rulesNow.lowFace; f <= 6; f++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Opacity(
                  opacity: c.canFace(f) ? 1 : 0.3,
                  child: GestureDetector(
                    key: Key('face $f'),
                    onTap: c.canFace(f) ? () => c.setFace(f) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: c.pickFace == f ? Toon.yellow : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.pickFace == f ? Toon.ink : Colors.transparent, width: 2),
                      ),
                      child: FlatDie(f, size: 30),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            ToonButton(
              key: const Key('fewer'),
              color: Toon.card,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              onPressed: c.pickCount > 1 ? () => c.setCount(c.pickCount - 1) : null,
              child: const Icon(Icons.remove_rounded, size: 20),
            ),
            const SizedBox(width: 4),
            ToonButton(
              key: const Key('more'),
              color: Toon.card,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              onPressed: c.pickCount < g.totalDice ? () => c.setCount(c.pickCount + 1) : null,
              child: const Icon(Icons.add_rounded, size: 20),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ToonButton(
                key: const Key('bid'),
                color: Toon.green,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                onPressed: c.pickOk ? c.bid : null,
                child: FittedBox(
                  child: Text(
                    'Bid ${bidWords(c.picked).toLowerCase()} · ${(c.pickOdds * 100).round()}%',
                    maxLines: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: ToonButton(
                key: const Key('liar'),
                color: Toon.red,
                padding: const EdgeInsets.symmetric(vertical: 10),
                onPressed: c.canCall ? c.callLiar : null,
                child: FittedBox(
                  child: Text(odds == null ? 'Liar!' : 'Liar! · ${(100 - odds * 100).round()}%', maxLines: 1),
                ),
              ),
            ),
            if (c.rulesNow.spotOn) ...[
              const SizedBox(width: 6),
              Expanded(
                child: ToonButton(
                  key: const Key('spot on'),
                  color: Toon.yellow,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  onPressed: c.canSpotOn ? c.callSpotOn : null,
                  child: const FittedBox(child: Text('Spot on', maxLines: 1)),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// A die seen from straight above: the face only, pips easy to read
/// (pickers and small labels).
class FlatDie extends StatelessWidget {
  const FlatDie(this.value, {super.key, this.size = 24});

  final int value;
  final double size;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(size: Size.square(size), painter: _FlatDiePainter(value)),
  );
}

class _FlatDiePainter extends CustomPainter {
  const _FlatDiePainter(this.value);

  final int value;

  static const _spots = {
    1: [(0.5, 0.5)],
    2: [(0.27, 0.27), (0.73, 0.73)],
    3: [(0.27, 0.27), (0.5, 0.5), (0.73, 0.73)],
    4: [(0.27, 0.27), (0.73, 0.27), (0.27, 0.73), (0.73, 0.73)],
    5: [(0.27, 0.27), (0.73, 0.27), (0.5, 0.5), (0.27, 0.73), (0.73, 0.73)],
    6: [(0.27, 0.25), (0.73, 0.25), (0.27, 0.5), (0.73, 0.5), (0.27, 0.75), (0.73, 0.75)],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(1, 1, s - 2, s - 2), Radius.circular(s * 0.22));
    canvas.drawRRect(r, Paint()..color = Toon.cardFace);
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.2, s * 0.06)
        ..color = Toon.ink,
    );
    final pip = Paint()..color = value == 1 ? Toon.red : Toon.inkLight;
    for (final (x, y) in _spots[value] ?? const <(double, double)>[]) {
      canvas.drawCircle(Offset(x * s, y * s), s * (value == 1 ? 0.13 : 0.095), pip);
    }
  }

  @override
  bool shouldRepaint(_FlatDiePainter old) => old.value != value;
}
