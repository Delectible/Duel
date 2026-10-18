import 'dart:async';
import 'dart:math';

import 'package:duel_engine/blitz/blitz.dart';
import 'package:duel_engine/cards.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    'You draw a card, then do one thing. Tap a card in your hand to pick it up: everything it can do lights up.',
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
    'An Ace from your hand matches any value and can even hit a face-down card. An Ace in a castle only falls to '
        'another Ace. (For a Blitz '
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
  });

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
                        'You + ${widget.bots} ${widget.bots == 1 ? 'bot' : 'bots'} · ${widget.difficulty.label}'
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
      onAgain: _playAgain,
      onLeave: () => Navigator.of(context).pop(),
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
  Widget build(BuildContext context) => Container(
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
class _Castle extends StatelessWidget {
  const _Castle({required this.c, required this.player, required this.cardWidth});

  final BlitzController c;
  final int player;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final castle = c.game.castles[player];
    return LayoutBuilder(
      builder: (context, box) {
        final n = castle.length;
        final w = cardWidth;
        final step = n <= 1 ? 0.0 : min(w + 4, (box.maxWidth - w) / (n - 1));
        final seen = <String, int>{};
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final (i, cc) in castle.indexed)
              () {
                final id = '${cc.card}${cc.faceUp}';
                final k = seen[id] = (seen[id] ?? 0) + 1;
                // Keyed by the card (not its spot) so cards sliding along
                // don't pop in again; a card turning over does.
                return Positioned(
                  key: ValueKey('slot $player $id $k'),
                  left: i * step,
                  top: (box.maxHeight - w * 1.4) / 2,
                  child: () {
                    final move = c.moveAt(player, i);
                    final ring = switch (move) {
                      Strike() => Toon.red,
                      Scout() => Toon.blue,
                      Fortify() => Toon.green,
                      _ => null,
                    };
                    return GestureDetector(
                      key: Key('castle $player $id $k'),
                      onTap: move == null
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              c.tapCastle(player, i);
                            },
                      child: Pop(
                        key: ValueKey(c.round),
                        child: Container(
                          decoration: ring == null
                              ? null
                              : BoxDecoration(
                                  borderRadius: BorderRadius.circular(w * 0.18),
                                  boxShadow: [BoxShadow(color: ring, blurRadius: 0, spreadRadius: 3)],
                                ),
                          child: CardView(card: cc.card, width: w, faceUp: cc.faceUp),
                        ),
                      ),
                    );
                  }(),
                );
              }(),
          ],
        );
      },
    );
  }
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

/// Your hand (picked-up card raised) and the Pair / Blitz / Pass buttons.
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
                  : Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: buttons),
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
