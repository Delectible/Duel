import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/cards/card_view.dart';
import '../../../core/cards/cards.dart';
import '../../../core/help/game_guide.dart';
import '../../../core/session/difficulty.dart';
import '../../../core/theme/toon.dart';
import '../../../core/account/account.dart';
import '../../../core/account/stake.dart';
import '../../../core/avatars/faces.dart';
import '../../../core/table/table_bits.dart';
import '../engine/crazy_eights.dart';
import 'eights_controller.dart';

/// Stages of a Crazy Eights game for the "How to play" sheet.
const eightsGuide = [
  GuideStage(
    'deal',
    'The deal',
    'Everyone gets 7 cards (5 each with 3 or 4 players). One card is turned up to start the pile in the middle.',
    icon: Icons.style_rounded,
  ),
  GuideStage(
    'turn',
    'Your turn',
    "Play one card that matches the top of the pile: the same suit (hearts on hearts) or the same number "
        '(a 7 on a 7). Cards you can play are lifted up; tap one to play it.',
    icon: Icons.touch_app_rounded,
  ),
  GuideStage(
    'draw',
    "Can't match?",
    "Tap the deck to draw one card. If it fits you can play it straight away, or keep it. If it doesn't, "
        'your turn ends. You may also draw when you could play, to save your cards.',
    icon: Icons.add_card_rounded,
  ),
  GuideStage(
    'eight',
    'Eights are wild',
    'An 8 goes on anything. Play one and pick the suit the next player has to follow. Saving them for when '
        "you're stuck is a good idea.",
    icon: Icons.auto_awesome_rounded,
  ),
  GuideStage(
    'win',
    'Winning',
    'First to play their last card wins. "Last card!" shows over anyone down to one. If the deck runs out '
        'the pile is shuffled back in.',
    icon: Icons.emoji_events_rounded,
  ),
];

/// Crazy Eights against [bots] bots (1-3).
class EightsScreen extends StatefulWidget {
  const EightsScreen({
    super.key,
    required this.bots,
    required this.difficulty,
    this.pace = 1,
    this.seed,
    this.stake,
  });

  final int bots;
  final Difficulty difficulty;
  final double pace;
  final int? seed;

  /// The stake taken when you hit Play! (null: a free game).
  final StakeTicket? stake;

  @override
  State<EightsScreen> createState() => _EightsScreenState();
}

class _EightsScreenState extends State<EightsScreen> {
  late final Account _account = AccountScope.maybeRead(context) ?? Account();
  late StakeTicket _ticket =
      widget.stake ??
      StakeTicket(
        account: _account,
        gameId: 'crazy8',
        stake: 0,
        opponents: widget.bots,
        difficulty: widget.difficulty,
      );
  late final EightsController _c = EightsController(
    bots: widget.bots,
    difficulty: widget.difficulty,
    pace: widget.pace,
    rng: widget.seed == null ? null : Random(widget.seed),
    you: _account.persona,
  )..addListener(_settle);

  /// Someone went out: you win only if it was you.
  void _settle() {
    if (_c.phase == EightsPhase.over && !_ticket.settled) {
      _ticket.settle(_c.game.winner == 0 ? Outcome.win : Outcome.loss);
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
    if (c.phase == EightsPhase.dealing) return 'deal';
    if (c.phase == EightsPhase.over) return 'win';
    if (c.phase == EightsPhase.pickSuit || c.game.top.rank == 8) return 'eight';
    if (c.yourTurn && c.yourPlayable.isEmpty) return 'draw';
    return 'turn';
  }

  Future<void> _leave() async {
    if (_c.phase == EightsPhase.over || await confirmLeave(context, _ticket)) {
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
                    title: 'Crazy Eights',
                    subtitle:
                        'You + ${widget.bots} ${widget.bots == 1 ? 'bot' : 'bots'} · ${widget.difficulty.label}',
                    onLeave: _leave,
                    ticket: _ticket,
                    guide: eightsGuide,
                    stage: _stage,
                  ),
                  commentary: _Commentary(c: _c),
                  table: _Table(c: _c),
                  controls: _Actions(c: _c),
                ),
                if (_c.phase == EightsPhase.over)
                  Positioned.fill(
                    child: _GameOver(
                      c: _c,
                      ticket: _ticket,
                      onAgain: _playAgain,
                      onLeave: () => Navigator.of(context).pop(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What just happened and what you can do, in one line, with the suit to
/// follow.
class _Commentary extends StatelessWidget {
  const _Commentary({required this.c});

  final EightsController c;

  @override
  Widget build(BuildContext context) => CommentaryStrip(
    text: c.commentary(),
    yourMove: c.yourTurn,
    leading: Tooltip(
      message: 'Suit to follow: ${suitName(c.game.suit)}',
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: Toon.box(Toon.cardFace, radius: 17, shadow: 0),
        child: SuitIcon(c.game.suit, size: 20),
      ),
    ),
  );
}

/// Opponent spots (fractions of the table), clockwise from your left.
const _opponentSpots = <int, List<Offset>>{
  1: [Offset(0.5, 0.13)],
  2: [Offset(0.22, 0.16), Offset(0.78, 0.16)],
  3: [Offset(0.13, 0.4), Offset(0.5, 0.12), Offset(0.87, 0.4)],
};

const _deckSpot = Offset(0.34, 0.55);
const _pileSpot = Offset(0.64, 0.55);
const _handSpot = Offset(0.5, 1.02);

class _Table extends StatelessWidget {
  const _Table({required this.c});

  final EightsController c;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        final wide = GameLayout.wide(context);
        // Seats never poke out above the table.
        Offset px(Offset f) => Offset(f.dx * size.width, max(f.dy * size.height, f.dy < 0.9 ? 80.0 : 0));
        final spots = [_handSpot, ..._opponentSpots[c.players - 1]!];
        final g = c.game;
        final card = min(size.width * 0.17, size.height * (wide ? 0.15 : 0.16)).clamp(46.0, 74.0);
        // On its side the piles sit midway between the top seats and your
        // hand.
        final pilesY = wide ? ((144 + size.height - card * 1.4 - 26) / 2 - 10) / size.height : _deckSpot.dy;
        final deckAt = px(Offset(_deckSpot.dx, pilesY));
        final pileAt = px(Offset(_pileSpot.dx, pilesY));
        final canDraw = c.yourTurn && g.canDraw;

        final children = <Widget>[
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
              decoration: BoxDecoration(
                color: Toon.felt,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Toon.wood, width: 10),
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Toon.ink, width: 2.5),
              ),
            ),
          ),
        ];

        // Opponents.
        for (var p = 1; p < c.players; p++) {
          children.add(
            _At(
              px(spots[p]),
              child: _Opponent(c: c, player: p),
            ),
          );
        }

        // Draw pile.
        children.add(
          _At(
            deckAt,
            child: _DrawPile(
              count: g.drawPile.length,
              width: card,
              glow: canDraw,
              onTap: canDraw ? c.draw : null,
            ),
          ),
        );

        // Discard pile: the top card flies in from whoever played it.
        final top = g.discard.length;
        final lastPlay = g.events.whereType<Played>().lastOrNull;
        final from = lastPlay == null ? Offset.zero : px(spots[lastPlay.player]) - pileAt;
        children.add(
          _At(
            pileAt,
            child: _DiscardPile(
              cards: g.discard.length > 3 ? g.discard.sublist(g.discard.length - 3) : g.discard,
              width: card,
              flyFrom: from,
              flyKey: top,
              eight: g.top.rank == 8 ? g.suit : null,
            ),
          ),
        );

        // Cards drawn: a card back flies from the deck to the player.
        for (final (id, p) in c.draws.skip(max(0, c.draws.length - 4))) {
          children.add(
            _Fly(
              key: ValueKey('draw$id'),
              from: deckAt,
              to: px(spots[p]) - (p == 0 ? Offset(0, card * 0.9) : Offset.zero),
              width: card * 0.7,
            ),
          );
        }

        // An eight changed the suit: the new suit pops up big.
        if (lastPlay != null && lastPlay.chose != null) {
          children.add(
            Positioned.fill(
              child: IgnorePointer(
                child: _SuitBurst(key: ValueKey('burst${g.events.length}-$top'), suit: lastPlay.chose!),
              ),
            ),
          );
        }

        // Your hand.
        children.add(
          Positioned(
            left: 0,
            right: 0,
            bottom: 4,
            child: _Hand(c: c, cardWidth: card),
          ),
        );

        return Stack(clipBehavior: Clip.none, children: children);
      },
    );
  }
}

class _At extends StatelessWidget {
  const _At(this.at, {required this.child});

  final Offset at;
  final Widget child;

  @override
  Widget build(BuildContext context) => Positioned(
    left: at.dx,
    top: at.dy,
    child: FractionalTranslation(translation: const Offset(-0.5, -0.5), child: child),
  );
}

/// A card back flying from the deck, fading as it lands.
class _Fly extends StatelessWidget {
  const _Fly({super.key, required this.from, required this.to, required this.width});

  final Offset from;
  final Offset to;
  final double width;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 450),
    curve: Curves.easeInOutCubic,
    builder: (context, t, child) => _At(
      Offset.lerp(from, to, t)!,
      child: Opacity(
        opacity: t < 0.85 ? 1 : (1 - t) / 0.15,
        child: Transform.rotate(angle: t * 0.6, child: child),
      ),
    ),
    child: IgnorePointer(child: CardView(card: null, width: width, faceUp: false)),
  );
}

class _DrawPile extends StatelessWidget {
  const _DrawPile({required this.count, required this.width, required this.glow, this.onTap});

  final int count;
  final double width;
  final bool glow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final layers = min(count, 4);
    return Semantics(
      button: onTap != null,
      label: 'Draw pile, $count cards',
      child: GestureDetector(
        key: const Key('draw pile'),
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: width + 8,
              height: width * 1.4 + 8,
              child: count == 0
                  ? Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(width * 0.14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                      ),
                    )
                  : Stack(
                      children: [
                        for (var i = 0; i < layers; i++)
                          Positioned(
                            left: i * 2.0,
                            top: (layers - 1 - i) * 2.0,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(width * 0.14),
                                boxShadow: [
                                  if (glow && i == layers - 1)
                                    const BoxShadow(color: Toon.yellow, spreadRadius: 4),
                                ],
                              ),
                              child: CardView(card: null, width: width, faceUp: false),
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: glow ? Toon.yellow : Toon.ink.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                glow ? 'Tap to draw' : '$count left',
                style: Toon.text(12, color: glow ? Toon.ink : Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscardPile extends StatelessWidget {
  const _DiscardPile({
    required this.cards,
    required this.width,
    required this.flyFrom,
    required this.flyKey,
    required this.eight,
  });

  final List<PlayingCard> cards;
  final double width;
  final Offset flyFrom;
  final int flyKey;

  /// After an eight: the suit that was named.
  final Suit? eight;

  // A fixed little tilt per card so the pile looks tossed, not stacked.
  static double _tilt(PlayingCard c) => ((c.id * 37) % 11 - 5) / 40;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: width * 1.5,
          height: width * 1.4 + 12,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < cards.length - 1; i++)
                Transform.rotate(
                  angle: _tilt(cards[i]),
                  child: CardView(card: cards[i], width: width),
                ),
              if (cards.isNotEmpty)
                TweenAnimationBuilder<double>(
                  key: ValueKey(flyKey),
                  tween: Tween(begin: flyKey <= 1 ? 1 : 0, end: 1),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => Transform.translate(
                    offset: flyFrom * (1 - t),
                    child: Transform.rotate(
                      angle: _tilt(cards.last) + (1 - t) * 1.2,
                      child: Transform.scale(scale: 1 + 0.15 * sin(t * pi), child: child),
                    ),
                  ),
                  child: CardView(card: cards.last, width: width),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: eight != null ? Toon.yellow : Toon.ink.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: eight == null
              ? Text('Pile', style: Toon.text(12, color: Colors.white))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Now ', style: Toon.text(12)),
                    SuitIcon(eight!, size: 13),
                    Text(' ${suitName(eight!)}', style: Toon.text(12)),
                  ],
                ),
        ),
      ],
    );
  }
}

/// The named suit, big, popping up over the table and fading.
class _SuitBurst extends StatelessWidget {
  const _SuitBurst({super.key, required this.suit});

  final Suit suit;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 1300),
    builder: (context, t, _) {
      if (t >= 1) return const SizedBox.shrink();
      final grow = Curves.elasticOut.transform((t / 0.5).clamp(0, 1));
      final fade = t < 0.7 ? 1.0 : (1 - t) / 0.3;
      return Center(
        child: Opacity(
          opacity: fade,
          child: Transform.scale(
            scale: 0.3 + 1.0 * grow,
            child: Container(
              width: 120,
              height: 120,
              alignment: Alignment.center,
              decoration: Toon.box(Toon.card, radius: 60, shadow: 5),
              child: SuitIcon(suit, size: 72),
            ),
          ),
        ),
      );
    },
  );
}

class _Opponent extends StatelessWidget {
  const _Opponent({required this.c, required this.player});

  final EightsController c;
  final int player;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    final n = g.hands[player].length;
    final turn = g.turn == player && !g.isOver && c.phase != EightsPhase.dealing;
    final shown = min(n, 7);
    return SizedBox(
      width: 112,
      height: 128,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Their cards, face down, fanned behind them.
          Positioned(
            top: 0,
            child: SizedBox(
              width: 112,
              height: 46,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (var i = 0; i < shown; i++)
                    Transform.translate(
                      offset: Offset((i - (shown - 1) / 2) * 9, ((i - (shown - 1) / 2).abs()) * 1.5),
                      child: Transform.rotate(
                        angle: (i - (shown - 1) / 2) * 0.12,
                        child: _DealIn(
                          key: ValueKey('o${c.round}-$player-$i'),
                          delay: i * 90 + player * 30,
                          child: const CardView(card: null, width: 24, faceUp: false),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 30,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: turn ? Toon.yellow : Toon.card,
                shape: BoxShape.circle,
                border: Border.all(color: Toon.ink, width: Toon.outline),
                boxShadow: [BoxShadow(color: Toon.ink, offset: const Offset(0, 3))],
              ),
              child: Face(c.personas[player], size: 46),
            ),
          ),
          Positioned(
            top: 88,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: Toon.box(Toon.card, radius: 10, shadow: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(c.personas[player].name, style: Toon.text(12)),
                  Text('$n card${n == 1 ? '' : 's'}', style: Toon.text(13, weight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          if (n == 1 && !g.isOver)
            Positioned(
              top: 22,
              right: -8,
              child: _Pop(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: Toon.box(Toon.red, radius: 8, shadow: 2),
                  child: Text(
                    'Last card!',
                    style: Toon.text(11, weight: FontWeight.w700, color: Toon.inkLight),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pops in with a bounce.
class _Pop extends StatelessWidget {
  const _Pop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 400),
    curve: Curves.elasticOut,
    builder: (context, t, child) => Transform.scale(scale: t, child: child),
    child: child,
  );
}

/// Slides a dealt card in from the middle of the table.
class _DealIn extends StatelessWidget {
  const _DealIn({super.key, required this.child, this.delay = 0, this.from = const Offset(0, 120)});

  final Widget child;
  final int delay;
  final Offset from;

  @override
  Widget build(BuildContext context) {
    final total = 350 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Transform.translate(
        offset: from * (1 - t),
        child: Opacity(opacity: t, child: child),
      ),
      child: child,
    );
  }
}

/// Your cards, fanned along the bottom. On your turn the ones that fit are
/// lifted and lit; tap one to play it.
class _Hand extends StatelessWidget {
  const _Hand({required this.c, required this.cardWidth});

  final EightsController c;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final hand = [...c.game.hands[0]]
      ..sort((a, b) => a.suit != b.suit ? a.suit.index.compareTo(b.suit.index) : a.rank.compareTo(b.rank));
    final playable = c.yourPlayable.toSet();
    final drawn = c.game.drawn;
    return LayoutBuilder(
      builder: (context, box) {
        final w = cardWidth;
        final n = hand.length;
        final room = box.maxWidth - 24 - w;
        final step = n <= 1 ? 0.0 : min(w * 0.72, room / (n - 1));
        final total = w + step * (n - 1);
        final left = (box.maxWidth - total) / 2;
        return SizedBox(
          height: w * 1.4 + 26,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final (i, card) in hand.indexed)
                AnimatedPositioned(
                  key: ValueKey('h${card.id}'),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  left: left + i * step,
                  top: playable.contains(card) || card == c.pendingEight ? 0 : 20,
                  child: _DealIn(
                    key: ValueKey('hd${c.round}-${card.id}'),
                    delay: c.phase == EightsPhase.dealing ? i * 110 : 0,
                    from: const Offset(0, -160),
                    child: GestureDetector(
                      key: ValueKey('card ${card.id}'),
                      onTap: playable.contains(card) ? () => c.play(card) : null,
                      child: CardView(
                        card: card,
                        width: w,
                        glow: playable.contains(card) || card == drawn || card == c.pendingEight,
                        dim: c.yourTurn && !playable.contains(card),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Buttons under your hand: draw / keep / pick a suit.
class _Actions extends StatelessWidget {
  const _Actions({required this.c});

  final EightsController c;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    Widget body;
    if (c.phase == EightsPhase.pickSuit) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (final s in Suit.values) ...[
                if (s != Suit.values.first) const SizedBox(width: 8),
                Expanded(
                  child: ToonButton(
                    key: Key('suit ${s.name}'),
                    color: Toon.card,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    tooltip: suitName(s),
                    onPressed: () => c.chooseSuit(s),
                    child: SuitIcon(s, size: 34),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: c.cancelEight,
            child: Text('Not the 8 after all', style: Toon.text(14, color: Toon.muted)),
          ),
        ],
      );
    } else if (c.yourTurn && g.drawn != null) {
      body = Row(
        children: [
          Expanded(
            child: ToonButton(
              key: const Key('keep'),
              color: Toon.card,
              onPressed: c.pass,
              child: const Text('Keep it'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ToonButton(
              key: const Key('play drawn'),
              color: Toon.green,
              onPressed: () => c.play(g.drawn!),
              child: const Text('Play it'),
            ),
          ),
        ],
      );
    } else if (c.yourTurn) {
      final stuck = c.yourPlayable.isEmpty;
      body = Row(
        children: [
          Expanded(
            child: ToonButton(
              key: const Key('draw'),
              color: stuck ? Toon.yellow : Toon.card,
              onPressed: g.canDraw ? c.draw : null,
              child: Text(stuck ? 'Draw a card' : 'Draw instead'),
            ),
          ),
          if (stuck && !g.canDraw) ...[
            const SizedBox(width: 10),
            Expanded(
              child: ToonButton(
                key: const Key('pass'),
                color: Toon.yellow,
                onPressed: c.pass,
                child: const Text('Pass'),
              ),
            ),
          ],
        ],
      );
    } else {
      body = SizedBox(
        height: 50,
        child: Center(
          child: Text(
            c.phase == EightsPhase.dealing
                ? 'Dealing…'
                : (g.isOver ? '' : '${c.personas[g.turn].name}\'s turn'),
            style: Toon.text(16, color: Toon.muted),
          ),
        ),
      );
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.bottomCenter,
      child: Padding(padding: const EdgeInsets.fromLTRB(12, 6, 12, 8), child: body),
    );
  }
}

class _GameOver extends StatelessWidget {
  const _GameOver({required this.c, required this.ticket, required this.onAgain, required this.onLeave});

  final EightsController c;
  final StakeTicket ticket;
  final VoidCallback onAgain;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final w = c.game.winner!;
    final won = w == 0;
    return ColoredBox(
      color: Toon.ink.withValues(alpha: 0.5),
      child: Stack(
        children: [
          if (won) const Positioned.fill(child: IgnorePointer(child: _Confetti())),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.7, end: 1),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              builder: (context, s, child) => Transform.scale(scale: s, child: child),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: ToonBox(
                    color: Toon.paper,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Face(c.personas[w], size: 72),
                        const SizedBox(height: 10),
                        Text(
                          won ? 'You won!' : '${c.personas[w].name} won',
                          style: Toon.text(30, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          won
                              ? 'You got rid of every card.'
                              : 'You had ${c.game.hands[0].length} card${c.game.hands[0].length == 1 ? '' : 's'} left.',
                          textAlign: TextAlign.center,
                          style: Toon.text(16, weight: FontWeight.w500),
                        ),
                        const SizedBox(height: 10),
                        StakeResult(ticket),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ToonButton(
                                color: Toon.card,
                                onPressed: onLeave,
                                child: const Text('Games'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ToonButton(
                                key: const Key('again'),
                                color: Toon.green,
                                onPressed: onAgain,
                                child: const Text('Play again'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Suits bursting out from the middle when you win.
class _Confetti extends StatelessWidget {
  const _Confetti();

  @override
  Widget build(BuildContext context) {
    final rng = Random(8);
    final bits = [
      for (var i = 0; i < 24; i++)
        (angle: rng.nextDouble() * 2 * pi, dist: 140 + rng.nextDouble() * 220, suit: Suit.values[i % 4]),
    ];
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1600),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => Stack(
        alignment: Alignment.center,
        children: [
          for (final b in bits)
            Transform.translate(
              offset: Offset(cos(b.angle), sin(b.angle)) * b.dist * t + Offset(0, 120 * t * t),
              child: Opacity(
                opacity: (1 - t).clamp(0, 1),
                child: Transform.rotate(angle: t * 4, child: SuitIcon(b.suit, size: 26)),
              ),
            ),
        ],
      ),
    );
  }
}
