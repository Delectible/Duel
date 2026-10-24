import 'dart:async';
import 'dart:math';

import 'package:duel_engine/blitz/blitz.dart';
import 'package:duel_engine/cards.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/online/online_link.dart';
import '../../../core/account/account.dart';
import '../../../core/account/stake.dart';
import '../../../core/avatars/faces.dart';
import '../../../core/cards/card_view.dart';
import '../../../core/help/game_guide.dart';
import '../../../core/table/table_bits.dart';
import '../../../core/theme/toon.dart';
import 'blitz_controller.dart';

/// Stages of a Blitz game for the "How to play" sheet.
const blitzGuide = [
  GuideStage(
    'deal',
    'Your castle',
    'Everyone gets a castle: a row of 7 cards, face down except the top one. These are your lives. When your top '
        'card goes, the next one turns face up. You also get 4 cards in your hand.',
    icon: Icons.fort_rounded,
  ),
  GuideStage(
    'turn',
    'Your turn',
    'You draw a card (now you have 5), then do one thing with a card (back to 4). Tap a card in your hand to pick '
        'it up: everything it can do lights up. Nothing to hit or scout? Throw one away.',
    icon: Icons.touch_app_rounded,
  ),
  GuideStage(
    'strike',
    'Strike',
    'Match a face-up card in an opponent\'s castle with the same value from your hand (a 9 on a 9). Both go: '
        'they lose a life.',
    icon: Icons.bolt_rounded,
  ),
  GuideStage(
    'scout',
    'Scout',
    'Throw away any card to turn one of an opponent\'s face-down cards face up. Now everyone can aim at it.',
    icon: Icons.visibility_rounded,
  ),
  GuideStage(
    'fortify',
    'Fortify',
    'Match one of your own face-up castle cards: both go, and two new cards join your castle (one face down, one '
        'face up). One life up.',
    icon: Icons.add_moderator_rounded,
  ),
  GuideStage(
    'pair',
    'Pairs',
    'Two cards of the same value in your hand? Throw them away, draw two, and do something else. Once a turn.',
    icon: Icons.content_copy_rounded,
  ),
  GuideStage(
    'aces',
    'Aces are wild',
    'An Ace matches any value, and anything matches an Ace. An Ace can even hit a face-down card. (For a Blitz '
        'an Ace only counts as its own colour.)',
    icon: Icons.auto_awesome_rounded,
  ),
  GuideStage(
    'blitz',
    'BLITZ!',
    'Five cards of one colour (red or black) in your hand: throw them away and knock down every face-up card in one '
        'castle. Then draw five and take another whole turn.',
    icon: Icons.flash_on_rounded,
  ),
  GuideStage(
    'wars',
    'Wars (if on)',
    'When two castles show the same value, they fight at once: the smaller castle keeps its card, the bigger ones '
        'lose theirs. Same size? They all lose it. Nobody loses their last card to a war.',
    icon: Icons.sports_kabaddi_rounded,
  ),
  GuideStage(
    'win',
    'Winning',
    'A castle with no cards left is out. The last castle standing wins.',
    icon: Icons.emoji_events_rounded,
  ),
];

/// What the Wars option means (the preview's (i)).
const blitzWarsInfo =
    'Wars make Blitz faster and wilder. Whenever two or more castles show the same value face up (two 3s, say), '
    'those cards fight straight away: the player with the fewest castle cards keeps theirs and everyone else loses '
    'theirs. If the smallest castles are the same size, they all lose it. A war can turn up new cards and start '
    'another war. Nobody ever loses their last card to a war. Aces don\'t fight.';

/// Blitz against [bots] bots (1-5).
class BlitzScreen extends StatefulWidget {
  const BlitzScreen({
    super.key,
    required this.bots,
    required this.difficulty,
    this.wars = false,
    this.pace = 1,
    this.seed,
    this.stake,
  }) : link = null;

  /// With your party, online (inside an [OnlineGameFrame]).
  BlitzScreen.online({super.key, required OnlineLink this.link, required StakeTicket this.stake})
    : bots = link.n - 1,
      difficulty = Difficulty.normal,
      wars = const [true, 1].contains(link.options['wars']),
      pace = 1,
      seed = null;

  final OnlineLink? link;

  final int bots;
  final Difficulty difficulty;
  final bool wars;
  final double pace;
  final int? seed;

  /// The stake taken when you hit Play! (null: a free game).
  final StakeTicket? stake;

  @override
  State<BlitzScreen> createState() => _BlitzScreenState();
}

class _BlitzScreenState extends State<BlitzScreen> {
  late final Account _account = AccountScope.maybeRead(context) ?? Account();
  late StakeTicket _ticket =
      widget.stake ??
      StakeTicket(
        account: _account,
        gameId: 'blitz',
        stake: 0,
        opponents: widget.bots,
        difficulty: widget.difficulty,
      );
  late final BlitzController _c = BlitzController(
    bots: widget.bots,
    difficulty: widget.difficulty,
    wars: widget.wars,
    pace: widget.pace,
    rng: widget.seed == null ? null : Random(widget.seed),
    you: _account.persona,
    link: widget.link,
  )..addListener(_settle);

  /// Win only for the last castle standing.
  void _settle() {
    if (_c.phase == BlitzPhase.over && !_ticket.settled) {
      _ticket.settle(_c.game.winner == 0 ? Outcome.win : Outcome.loss);
      HapticFeedback.heavyImpact();
    }
  }

  void _playAgain() {
    setState(() => _ticket = _ticket.again());
    _c.playAgain();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String? _stage() {
    final c = _c;
    if (c.phase == BlitzPhase.dealing) return 'deal';
    if (c.phase == BlitzPhase.over) return 'win';
    if (c.phase == BlitzPhase.blitzTarget || c.blitzRed != null) return 'blitz';
    if (c.lastWars.isNotEmpty) return 'wars';
    if (c.selected?.rank == 14) return 'aces';
    if (c.pairRank != null) return 'pair';
    return 'turn';
  }

  Future<void> _leave() async {
    final link = widget.link;
    if (link != null) return link.leave(context, _ticket, over: _c.phase == BlitzPhase.over);
    if (_c.phase == BlitzPhase.over || await confirmLeave(context, _ticket)) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final decks = Blitz.decksFor(widget.bots + 1);
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
                    title: 'Blitz',
                    subtitle:
                        '${widget.link != null ? 'With your party${_c.yourTurn ? ' · ${widget.link!.secondsLeft}s' : ''}' : 'You + ${widget.bots} ${widget.bots == 1 ? 'bot' : 'bots'} · ${widget.difficulty.label}'}'
                        ' · $decks deck${decks == 1 ? '' : 's'}${widget.wars ? ' · Wars' : ''}',
                    onLeave: _leave,
                    ticket: _ticket,
                    guide: blitzGuide,
                    stage: _stage,
                  ),
                  commentary: CommentaryStrip(
                    text: _c.commentary(),
                    yourMove: _c.yourTurn,
                    leading: Icon(
                      _c.phase == BlitzPhase.blitzTarget ? Icons.flash_on_rounded : Icons.fort_rounded,
                      size: 28,
                      color: _c.yourTurn ? Toon.inkLight : Toon.fg,
                    ),
                  ),
                  table: _Table(c: _c),
                  controls: _Controls(c: _c),
                ),
                if (_c.phase == BlitzPhase.over) Positioned.fill(child: _over(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _over(BuildContext context) {
    final g = _c.game;
    final place = g.places[0] ?? 1;
    final won = g.winner == 0;
    final order = g.places.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    return GameOverCard(
      face: won ? _c.you : _c.personas[g.winner!],
      title: won ? 'You won!' : 'Out in ${_ordinal(place)}',
      subtitle: [
        for (final e in order) '${_ordinal(e.value)} ${e.key == 0 ? 'You' : _c.personas[e.key].name}',
      ].join('  ·  '),
      ticket: _ticket,
      won: won,
      onAgain: widget.link == null ? _playAgain : widget.link!.rematch,
      againLabel: widget.link?.rematchLabel ?? 'Play again',
      leaveLabel: widget.link == null ? 'Games' : 'Back to party',
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

/// The felt: everyone else's castles (one strip each), then yours with the
/// deck and the discard pile.
class _Table extends StatelessWidget {
  const _Table({required this.c});

  final BlitzController c;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(child: _felt()),
      // A war covers the felt while it's fought.
      if (c.fighting)
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: WarScene(
                key: ValueKey('war ${c.actionId}'),
                wars: c.lastWars,
                personas: c.personas,
                each: c.warTime,
              ),
            ),
          ),
        ),
    ],
  );

  Widget _felt() => Container(
    margin: const EdgeInsets.fromLTRB(10, 4, 10, 4),
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
    decoration: BoxDecoration(
      color: Toon.felt,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Toon.wood, width: 8),
    ),
    foregroundDecoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Toon.ink, width: 2.5),
    ),
    child: LayoutBuilder(
      builder: (context, box) {
        final others = c.players - 1;
        // On its side with a full table, the others sit in two columns.
        final columns = GameLayout.wide(context) && others >= 3 ? 2 : 1;
        final rows = (others / columns).ceil();
        // Your strip takes about a third; the rest share what's left.
        final mine = (box.maxHeight * 0.3).clamp(78.0, 132.0);
        final strip = ((box.maxHeight - mine - 6) / rows).clamp(40.0, 96.0);
        return Column(
          children: [
            for (var r = 0; r < rows; r++)
              SizedBox(
                height: strip,
                child: Row(
                  children: [
                    for (var k = 0; k < columns; k++)
                      Expanded(
                        child: 1 + r * columns + k < c.players
                            ? _Strip(c: c, player: 1 + r * columns + k, height: strip)
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
            const Spacer(),
            SizedBox(
              height: mine,
              child: _Strip(c: c, player: 0, height: mine),
            ),
          ],
        );
      },
    ),
  );
}

/// A war, fought over the felt: the fighters' faces with crossed swords
/// between them clash, then whoever lost a card falls off the bottom of the
/// screen and the rest hold their ground. Several wars play one after
/// another, [each] long.
class WarScene extends StatefulWidget {
  const WarScene({super.key, required this.wars, required this.personas, required this.each});

  final List<War> wars;
  final List<Persona> personas;
  final Duration each;

  @override
  State<WarScene> createState() => _WarSceneState();
}

class _WarSceneState extends State<WarScene> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: widget.each * max(1, widget.wars.length),
  )..forward();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (context, _) {
      final n = max(1, widget.wars.length);
      final at = (_a.value * n).clamp(0.0, n - 0.0001);
      final war = widget.wars[at.floor()];
      return _war(war, at - at.floor());
    },
  );

  /// One war at time [t] (0..1): in, clash, fall, out.
  Widget _war(War war, double t) {
    double span(double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);
    final enter = Curves.easeOutBack.transform(span(0, 0.18));
    final clash = span(0.18, 0.42);
    final fall = Curves.easeIn.transform(span(0.5, 0.85));
    final fade = 1 - span(0.88, 1);
    final shake = clash > 0 && clash < 1 ? sin(clash * pi * 10) * 4 * (1 - clash) : 0.0;
    final name = '${rankWord(war.rank)}s';
    final nobody = war.losers.isEmpty;
    return Opacity(
      opacity: fade,
      child: Container(
        color: Colors.black.withValues(alpha: 0.72 * min(1, span(0, 0.08) * 1.5)),
        child: LayoutBuilder(
          builder: (context, box) {
            final count = war.fighters.length;
            // Two face off; more stand in a ring round one pair of swords.
            final ring = min(box.maxWidth - 16, 340.0);
            final face = (ring * (count == 2 ? 0.26 : (count <= 4 ? 0.2 : 0.16))).clamp(28.0, 72.0);
            final drop = box.maxHeight;
            // Short felts (on its side) shrink the whole scene to fit.
            return Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: box.maxWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.scale(
                        scale: enter,
                        child: Text(
                          'WAR!',
                          style: Toon.text(40, weight: FontWeight.w800, color: Toon.yellow),
                        ),
                      ),
                      Opacity(
                        opacity: span(0.1, 0.2),
                        child: Text('over $name', style: Toon.text(18, color: Colors.white)),
                      ),
                      SizedBox(height: face * 0.5),
                      Transform.translate(
                        offset: Offset(shake, 0),
                        child: _ring(war, face, enter, clash, fall, drop),
                      ),
                      SizedBox(height: face * 0.4),
                      Opacity(
                        opacity: span(0.55, 0.65),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            nobody ? 'Nobody falls: last cards are safe.' : _verdict(war),
                            textAlign: TextAlign.center,
                            style: Toon.text(15, weight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// The fighters round the swords: two side by side, more in a ring
  /// (starting on the left), each sliding in from outside.
  Widget _ring(War war, double face, double enter, double clash, double fall, double drop) {
    final count = war.fighters.length;
    final w = face * 1.7, h = face + 52;
    final swords = face * (count == 2 ? 0.9 : 1.2);
    final width = count == 2 ? 2 * w + swords + 16 : 2 * w + 2 * swords;
    final height = count == 2 ? h : width;
    final r = count == 2 ? (w + swords) / 2 + 8 : width / 2 - max(w, h) / 2;
    final centre = Offset(width / 2, height / 2);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: centre.dx - swords / 2,
            top: centre.dy - swords / 2 - (count == 2 ? 14 : 0),
            child: _Swords(size: swords, t: clash, enter: enter * (1 - fall)),
          ),
          for (var i = 0; i < count; i++)
            () {
              final a = pi + i * 2 * pi / count;
              final at = centre + Offset(cos(a), sin(a)) * r * (1 + (1 - enter) * 1.5);
              return Positioned(
                left: at.dx - w / 2,
                top: at.dy - h / 2,
                width: w,
                height: h,
                child: _fighter(war, war.fighters[i], face, i, fall, drop),
              );
            }(),
        ],
      ),
    );
  }

  String _who(int p) => p == 0 ? 'You' : widget.personas[p].name;

  String _verdict(War war) {
    final lost = war.losers.map(_who).toList();
    final names = lost.length == 1
        ? lost.single
        : '${lost.sublist(0, lost.length - 1).join(', ')} and ${lost.last}';
    final card = '${rankWord(war.rank)}${war.losers.length == 1 ? '' : 's'}';
    final kept = war.fighters.where((p) => !war.losers.contains(p)).map(_who).toList();
    final verb = lost.length == 1 && lost.single != 'You' ? 'loses' : 'lose';
    return '$names $verb ${lost.length == 1 ? 'a' : 'their'} $card'
        '${kept.isEmpty ? '!' : '. ${kept.join(' and ')} ${kept.length == 1 && kept.single != 'You' ? 'holds' : 'hold'} on.'}';
  }

  Widget _fighter(War war, int p, double size, int i, double fall, double drop) {
    final lost = war.losers.contains(p);
    // The losers tumble off the bottom.
    final side = i.isEven ? -1 : 1;
    final dy = lost ? fall * drop * 1.5 : 0.0;
    final spin = lost ? fall * side * 1.2 : 0.0;
    return Transform.translate(
      offset: Offset(0, dy),
      child: Transform.rotate(
        angle: spin,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: lost && fall > 0 ? Toon.red : Toon.cardFace,
                shape: BoxShape.circle,
                border: Border.all(color: Toon.ink, width: 2.5),
              ),
              child: Face(widget.personas[p], size: size),
            ),
            const SizedBox(height: 4),
            Text(
              _who(p),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Toon.text(13, color: Colors.white),
            ),
            SizedBox(
              height: 22,
              child: lost && fall > 0
                  ? Text(
                      '-1',
                      style: Toon.text(16, weight: FontWeight.w800, color: Toon.red),
                    )
                  : (fall > 0 ? const Icon(Icons.shield_rounded, size: 20, color: Toon.yellow) : null),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two swords crossing: they swing in from apart and clash (a spark at the
/// peak of [t]).
class _Swords extends StatelessWidget {
  const _Swords({required this.size, required this.t, required this.enter});

  final double size;
  final double t;
  final double enter;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: enter.clamp(0.0, 1.0),
    child: CustomPaint(size: Size(size, size), painter: _SwordsPainter(t)),
  );
}

class _SwordsPainter extends CustomPainter {
  _SwordsPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    // Apart (0.9 rad from crossed) swinging in, a knock back at mid-clash.
    final swing = t < 0.3 ? 0.9 * (1 - t / 0.3) : sin((t - 0.3) / 0.7 * pi * 3) * 0.15 * (1 - t);
    for (final dir in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(dir * (pi / 4 + swing));
      _sword(canvas, r);
      canvas.restore();
    }
    // Spark where the blades meet.
    if (t > 0.25 && t < 0.75) {
      final k = 1 - ((t - 0.5).abs() / 0.25);
      final spark = Paint()..color = Toon.yellow.withValues(alpha: k);
      for (var i = 0; i < 8; i++) {
        final a = i * pi / 4;
        canvas.drawLine(
          c + Offset(cos(a), sin(a)) * r * 0.12,
          c + Offset(cos(a), sin(a)) * r * (0.12 + 0.35 * k),
          spark
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  /// One sword pointing up, hilt at the bottom, centred on the origin.
  void _sword(Canvas canvas, double r) {
    final ink = Paint()
      ..color = Toon.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    final blade = Path()
      ..moveTo(0, -r)
      ..lineTo(r * 0.11, -r * 0.8)
      ..lineTo(r * 0.11, r * 0.45)
      ..lineTo(-r * 0.11, r * 0.45)
      ..lineTo(-r * 0.11, -r * 0.8)
      ..close();
    canvas.drawPath(blade, Paint()..color = const Color(0xFFDDE3EA));
    canvas.drawPath(blade, ink);
    final guard = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, r * 0.5), width: r * 0.62, height: r * 0.13),
      Radius.circular(r * 0.06),
    );
    canvas.drawRRect(guard, Paint()..color = Toon.yellow);
    canvas.drawRRect(guard, ink);
    final grip = Rect.fromLTRB(-r * 0.07, r * 0.56, r * 0.07, r * 0.88);
    canvas.drawRect(grip, Paint()..color = Toon.wood);
    canvas.drawRect(grip, ink);
    canvas.drawCircle(Offset(0, r * 0.94), r * 0.08, Paint()..color = Toon.yellow);
    canvas.drawCircle(Offset(0, r * 0.94), r * 0.08, ink);
  }

  @override
  bool shouldRepaint(_SwordsPainter old) => old.t != t;
}

/// One player: their face (name, cards in hand) and their castle.
class _Strip extends StatelessWidget {
  const _Strip({required this.c, required this.player, required this.height});

  final BlitzController c;
  final int player;
  final double height;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    final out = g.isOut(player) && g.winner != player; // the winner keeps their castle
    final me = player == 0;
    final acting = !c.game.isOver && g.turn == player && c.phase != BlitzPhase.dealing;
    final target = c.blitzable(player);
    final face = min(height * 0.5, 40.0);
    final card = ((height - 8) / 1.4).clamp(22.0, me ? 62.0 : 52.0);
    final whoWidth = max(face + 16, 58.0);
    final Widget who = SizedBox(
      width: whoWidth,
      // Shrinks to fit the shortest strips (six at a table, on its side).
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: target ? Toon.yellow : (acting ? Toon.yellow : Toon.card),
                shape: BoxShape.circle,
                border: Border.all(color: Toon.ink, width: 2),
              ),
              child: Face(c.personas[player], size: face),
            ),
            Text(
              me ? 'You' : c.personas[player].name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Toon.text(12, color: Colors.white),
            ),
            if (!me && !out && height >= 56)
              Text(
                '${g.hands[player].length} in hand',
                maxLines: 1,
                style: Toon.text(10, weight: FontWeight.w500, color: Colors.white70),
              ),
          ],
        ),
      ),
    );
    final last = c.lastAction;
    final bubble = last == null
        ? null
        : switch (last) {
            Struck(:final target) when target == player => '-1',
            Blitzed(:final target, :final knocked) when target == player => '-$knocked',
            Fortified() when last.player == player => '+1',
            Struck() when last.player == player => 'Strike!',
            Scouted() when last.player == player => 'Scout',
            Paired() when last.player == player => 'Pair!',
            Blitzed() when last.player == player => 'BLITZ!',
            _ => null,
          };
    final row = Row(
      children: [
        who,
        const SizedBox(width: 6),
        Expanded(
          child: out
              ? Center(
                  child: Text(
                    'Out (${_ordinal(g.places[player]!)})',
                    style: Toon.text(15, color: Colors.white70),
                  ),
                )
              : _Castle(c: c, player: player, cardWidth: card),
        ),
        if (me) ...[const SizedBox(width: 6), _Piles(c: c, width: min(card * 0.8, 40))],
      ],
    );
    return GestureDetector(
      key: Key('strip $player'),
      behavior: HitTestBehavior.opaque,
      onTap: target ? () => c.blitzAt(player) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: target
              ? Toon.yellow.withValues(alpha: 0.35)
              : (me ? Colors.black.withValues(alpha: 0.12) : Colors.transparent),
          borderRadius: BorderRadius.circular(14),
          border: target ? Border.all(color: Toon.yellow, width: 2.5) : null,
        ),
        child: Opacity(
          opacity: out ? 0.5 : 1,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: row),
              // Over the player's face (never their castle), gone after a moment.
              if (bubble != null)
                Positioned(
                  left: 0,
                  top: 0,
                  width: whoWidth,
                  child: IgnorePointer(
                    child: _Fleeting(
                      key: ValueKey('bubble ${c.actionId} $player'),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SpeechBubble(
                          bubble,
                          color: bubble.startsWith('-')
                              ? Toon.red
                              : (bubble == 'BLITZ!' ? Toon.yellow : null),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows [child], then fades it out after a few seconds.
class _Fleeting extends StatefulWidget {
  const _Fleeting({super.key, required this.child});

  final Widget child;

  @override
  State<_Fleeting> createState() => _FleetingState();
}

class _FleetingState extends State<_Fleeting> {
  var _shown = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2500), () => setState(() => _shown = false));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: _shown ? 1 : 0,
    duration: const Duration(milliseconds: 400),
    child: widget.child,
  );
}

/// A castle: its cards side by side (overlapping when there are many),
/// the top card last. With a card picked up, what it can do lights up.
///
/// Nothing pops: a card that goes lifts off and fades while the row slides
/// together, a new card drops in, and a card turning over flips.
class _Castle extends StatefulWidget {
  const _Castle({required this.c, required this.player, required this.cardWidth});

  final BlitzController c;
  final int player;
  final double cardWidth;

  @override
  State<_Castle> createState() => _CastleState();
}

/// One card on show: [left] is set by the layout (and kept while leaving).
class _Slot {
  _Slot(this.key, this.card, {this.fresh = false});

  final String key;
  CastleCard card;

  /// Arrived mid-game (drops in) rather than dealt (pops in).
  final bool fresh;
  bool leaving = false;
  double left = 0;
}

class _CastleState extends State<_Castle> {
  static const _slide = Duration(milliseconds: 320);
  static const _leave = Duration(milliseconds: 420);

  var _slots = <_Slot>[];
  int? _round;

  /// Matches the shown cards to the castle: by card (the second of two
  /// equal cards, with two decks, by order), keeping leaving ones in place.
  void _sync() {
    final castle = widget.c.castle(widget.player);
    final seen = <String, int>{};
    final keys = [
      for (final cc in castle) '${cc.card} ${seen['${cc.card}'] = (seen['${cc.card}'] ?? 0) + 1}',
    ];
    if (_round != widget.c.round) {
      // A new game: dealt in with a pop, nothing to animate away.
      _round = widget.c.round;
      _slots = [for (final (i, cc) in castle.indexed) _Slot(keys[i], cc)];
      return;
    }
    final old = {for (final s in _slots) s.key: s};
    final next = <_Slot>[];
    for (final (i, cc) in castle.indexed) {
      final s = old.remove(keys[i]);
      if (s == null || s.leaving) {
        next.add(_Slot(keys[i], cc, fresh: true));
      } else {
        next.add(s..card = cc);
      }
    }
    // The ones gone: stay where they were (drawn first, under the rest).
    final going = [for (final s in old.values) s..leaving = true];
    _slots = [...going, ...next];
  }

  @override
  Widget build(BuildContext context) {
    _sync();
    final player = widget.player;
    return LayoutBuilder(
      builder: (context, box) {
        final staying = _slots.where((s) => !s.leaving).toList();
        final n = staying.length;
        final w = widget.cardWidth;
        final h = w * 1.4;
        final step = n <= 1 ? 0.0 : min(w + 4, (box.maxWidth - w) / (n - 1));
        final top = (box.maxHeight - h) / 2;
        for (final (i, s) in staying.indexed) {
          s.left = i * step;
        }
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final s in _slots)
              if (s.leaving)
                Positioned(
                  key: ValueKey('slot $player ${s.key}'),
                  left: s.left,
                  top: top,
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: _leave,
                      curve: Curves.easeIn,
                      onEnd: () {
                        if (mounted) setState(() => _slots.remove(s));
                      },
                      builder: (context, t, child) => Opacity(
                        opacity: 1 - t,
                        child: Transform.translate(
                          offset: Offset(0, -h * 0.6 * t),
                          child: Transform.rotate(
                            angle: 0.35 * t,
                            child: Transform.scale(scale: 1 - 0.3 * t, child: child),
                          ),
                        ),
                      ),
                      child: CardView(card: s.card.card, width: w, faceUp: s.card.faceUp),
                    ),
                  ),
                )
              else
                AnimatedPositioned(
                  key: ValueKey('slot $player ${s.key}'),
                  duration: _slide,
                  curve: Curves.easeOutCubic,
                  left: s.left,
                  top: top,
                  child: _card(s, staying.indexOf(s), w, h),
                ),
          ],
        );
      },
    );
  }

  Widget _card(_Slot s, int i, double w, double h) {
    final c = widget.c;
    final player = widget.player;
    final move = c.moveAt(player, i);
    final ring = switch (move) {
      Strike() => Toon.red,
      Scout() => Toon.blue,
      Fortify() => Toon.green,
      _ => null,
    };
    Widget card = Container(
      decoration: ring == null
          ? null
          : BoxDecoration(
              borderRadius: BorderRadius.circular(w * 0.18),
              boxShadow: [BoxShadow(color: ring, blurRadius: 0, spreadRadius: 3)],
            ),
      child: _Flip(card: s.card, width: w),
    );
    if (s.fresh) {
      // Dropped in from above.
      card = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: _slide,
        curve: Curves.easeOutBack,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, -h * 0.5 * (1 - t)), child: child),
        ),
        child: card,
      );
    } else {
      card = Pop(key: ValueKey(c.round), child: card);
    }
    return GestureDetector(
      key: Key('castle $player ${s.key} ${s.card.faceUp}'),
      onTap: move == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              c.tapCastle(player, i);
            },
      child: card,
    );
  }
}

/// A castle card that flips over (squeezes to an edge and back) when it
/// turns face up.
class _Flip extends StatelessWidget {
  const _Flip({required this.card, required this.width});

  final CastleCard card;
  final double width;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 360),
    // The old face shrinks to an edge in the first half (its animation
    // runs backwards); the new one opens out in the second.
    transitionBuilder: (child, a) => AnimatedBuilder(
      animation: a,
      child: child,
      builder: (context, child) {
        final v = ((a.value - 0.5) * 2).clamp(0.0, 1.0);
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(max(v, 0.001), 1, 1),
          child: Opacity(opacity: v > 0 ? 1 : 0, child: child),
        );
      },
    ),
    child: CardView(key: ValueKey(card.faceUp), card: card.card, width: width, faceUp: card.faceUp),
  );
}

/// The deck (with how many are left) and the discard pile.
class _Piles extends StatelessWidget {
  const _Piles({required this.c, required this.width});

  final BlitzController c;
  final double width;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            CardView(card: null, width: width, faceUp: false),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: Toon.box(Toon.cardFace, radius: 6, shadow: 0),
              child: Text('${g.drawPile.length}', style: Toon.text(11, color: Toon.inkLight)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text('deck', style: Toon.text(10, color: Colors.white70)),
      ],
    );
  }
}

/// Your hand (picked-up card raised) and the Pair / Blitz / Throw away buttons.
class _Controls extends StatelessWidget {
  const _Controls({required this.c});

  final BlitzController c;

  @override
  Widget build(BuildContext context) {
    final pair = c.pairRank;
    final red = c.blitzRed;
    final buttons = <Widget>[
      if (c.phase == BlitzPhase.blitzTarget)
        ToonButton(
          key: const Key('cancel blitz'),
          color: Toon.card,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          onPressed: c.cancelBlitz,
          child: Text('Not yet', style: Toon.text(15)),
        ),
      if (c.yourTurn && pair != null)
        ToonButton(
          key: const Key('pair'),
          color: Toon.purple,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          onPressed: c.pair,
          child: Text('Pair of ${rankWord(pair)}s', style: Toon.text(15)),
        ),
      if (c.yourTurn && red != null)
        ToonButton(
          key: const Key('blitz'),
          color: Toon.yellow,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          onPressed: c.blitz,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flash_on_rounded, size: 20),
              Text('BLITZ (${red ? 'red' : 'black'})', style: Toon.text(15, weight: FontWeight.w700)),
            ],
          ),
        ),
      if (c.yourTurn && c.mustDiscard)
        ToonButton(
          key: const Key('discard'),
          color: Toon.card,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          onPressed: c.selected == null ? null : c.throwAway,
          child: Text(c.selected == null ? 'Pick a card to throw away' : 'Throw away', style: Toon.text(15)),
        ),
      if (c.yourTurn && c.mustPass)
        ToonButton(
          key: const Key('pass'),
          color: Toon.card,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          onPressed: c.pass,
          child: Text('Pass', style: Toon.text(15)),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 46,
            child: Center(
              child: buttons.isEmpty
                  ? Text(c.yourTurn ? 'Pick up a card' : '', style: Toon.text(14, color: Toon.muted))
                  // One line, shrunk to fit: a second line would sit
                  // on top of your hand.
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final (i, b) in buttons.indexed) ...[if (i > 0) const SizedBox(width: 8), b],
                        ],
                      ),
                    ),
            ),
          ),
          _Hand(c: c),
        ],
      ),
    );
  }
}

class _Hand extends StatelessWidget {
  const _Hand({required this.c});

  final BlitzController c;

  @override
  Widget build(BuildContext context) {
    final hand = c.hand;
    final reds = hand.where((x) => x.suit.isRed).length;
    return LayoutBuilder(
      builder: (context, box) {
        final w = min(64.0, box.maxWidth / 5.2);
        final h = w * 1.4;
        final n = hand.length;
        final step = n <= 1 ? 0.0 : min(w + 4, (box.maxWidth - w) / (n - 1));
        final width = n == 0 ? 0.0 : w + step * (n - 1);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: h + 14,
              width: box.maxWidth,
              child: Center(
                child: SizedBox(
                  width: width,
                  height: h + 14,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final (i, card) in hand.indexed)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 160),
                          left: i * step,
                          top: c.selected == card ? 0 : 12,
                          child: GestureDetector(
                            key: Key('hand $i'),
                            onTap: c.yourTurn ? () => c.select(card) : null,
                            child: CardView(card: card, width: w, glow: c.selected == card),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${hand.length} in hand · $reds red · ${hand.length - reds} black',
              style: Toon.text(12, weight: FontWeight.w500, color: Toon.muted),
            ),
          ],
        );
      },
    );
  }
}
