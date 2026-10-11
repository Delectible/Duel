import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/account/account.dart';
import '../../../core/account/stake.dart';
import '../../../core/avatars/faces.dart';
import '../../../core/cards/card_view.dart';
import '../../../core/cards/cards.dart';
import '../../../core/help/game_guide.dart';
import '../../../core/session/difficulty.dart';
import '../../../core/table/table_bits.dart';
import '../../../core/theme/toon.dart';
import '../engine/go_fish.dart';
import 'fish_controller.dart';

const fishGuide = [
  GuideStage(
    'deal',
    'The deal',
    'Everyone gets 7 cards (5 each with 4 or more players). The rest are spread face down in the middle: '
        'the pond.',
    icon: Icons.style_rounded,
  ),
  GuideStage(
    'ask',
    'Your turn: ask',
    'Tap a rank you hold (say a 7), then tap a player to ask them for 7s. You can only ask for ranks you '
        'already have. If they have any, they hand them all over and you go again.',
    icon: Icons.record_voice_over_rounded,
  ),
  GuideStage(
    'fish',
    'Go fish!',
    "If they don't have any, they say \"Go fish!\": tap the pond to draw a card. If it's the rank you asked "
        'for, you go again; if not, the turn passes.',
    icon: Icons.phishing_rounded,
  ),
  GuideStage(
    'books',
    'Books',
    'All four of a rank make a book: they go down in front of you straight away. Run out of cards? You draw '
        'one from the pond on your turn.',
    icon: Icons.collections_bookmark_rounded,
  ),
  GuideStage(
    'tips',
    'Listen in',
    'Someone who asks for Kings has a King. Ask them for it later. Someone who said "Go fish" to 5s has none, '
        'until they draw again.',
    icon: Icons.hearing_rounded,
  ),
  GuideStage(
    'end',
    'Winning',
    'When all 13 books are made, whoever has the most wins. A tie for most is a tie: stakes go back.',
    icon: Icons.emoji_events_rounded,
  ),
];

/// Go Fish against [bots] bots (1-5).
class FishScreen extends StatefulWidget {
  const FishScreen({
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
  final StakeTicket? stake;

  @override
  State<FishScreen> createState() => _FishScreenState();
}

class _FishScreenState extends State<FishScreen> {
  late final Account _account = AccountScope.maybeRead(context) ?? Account();
  late StakeTicket _ticket =
      widget.stake ??
      StakeTicket(
        account: _account,
        gameId: 'gofish',
        stake: 0,
        opponents: widget.bots,
        difficulty: widget.difficulty,
      );
  late final FishController _c = FishController(
    bots: widget.bots,
    difficulty: widget.difficulty,
    pace: widget.pace,
    rng: widget.seed == null ? null : Random(widget.seed),
    you: _account.persona,
  )..addListener(_settle);

  void _settle() {
    if (_c.phase == FishPhase.over && !_ticket.settled) {
      final w = _c.game.winners!;
      _ticket.settle(
        !w.contains(0)
            ? Outcome.loss
            : w.length == 1
            ? Outcome.win
            : Outcome.tie,
      );
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
    if (c.phase == FishPhase.dealing) return 'deal';
    if (c.phase == FishPhase.over) return 'end';
    if (c.game.mustFish) return 'fish';
    if (c.lastBook != null && c.game.events.isNotEmpty && c.game.events.last is Booked) return 'books';
    return 'ask';
  }

  Future<void> _leave() async {
    if (_c.phase == FishPhase.over || await confirmLeave(context, _ticket)) {
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
                    title: 'Go Fish',
                    subtitle:
                        'You + ${widget.bots} ${widget.bots == 1 ? 'bot' : 'bots'} · ${widget.difficulty.label}',
                    onLeave: _leave,
                    ticket: _ticket,
                    guide: fishGuide,
                    stage: _stage,
                  ),
                  commentary: CommentaryStrip(
                    text: _c.commentary(),
                    yourMove: _c.yourTurn,
                    leading: _BooksScore(c: _c),
                  ),
                  table: _Table(c: _c),
                  controls: _Actions(c: _c),
                ),
                if (_c.phase == FishPhase.over) Positioned.fill(child: _over(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _over(BuildContext context) {
    final w = _c.game.winners!;
    final books = _c.game.books[w.first].length;
    final mine = _c.game.books[0].length;
    final tie = w.length > 1;
    final won = w.contains(0) && !tie;
    return GameOverCard(
      face: _c.personas[w.contains(0) ? 0 : w.first],
      title: tie
          ? (w.contains(0) ? "It's a tie!" : 'A tie')
          : (won ? 'You won!' : '${_c.personas[w.first].name} won'),
      subtitle: won
          ? 'You made $books books.'
          : tie
          ? '$books books each${w.contains(0) ? ': your stake comes back.' : '. You made $mine.'}'
          : '$books books to your $mine.',
      ticket: _ticket,
      won: won,
      onAgain: _playAgain,
      onLeave: () => Navigator.of(context).pop(),
    );
  }
}

/// Books so far, you first.
class _BooksScore extends StatelessWidget {
  const _BooksScore({required this.c});

  final FishController c;

  @override
  Widget build(BuildContext context) => Container(
    width: 46,
    padding: const EdgeInsets.symmetric(vertical: 3),
    decoration: Toon.box(Toon.cardFace, radius: 10, shadow: 0),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${c.game.books[0].length}',
          style: Toon.text(18, weight: FontWeight.w700, color: Toon.inkLight),
        ),
        Text('books', style: Toon.text(10, color: Toon.inkLight)),
      ],
    ),
  );
}

const _opponentSpots = <int, List<Offset>>{
  1: [Offset(0.5, 0.15)],
  2: [Offset(0.25, 0.16), Offset(0.75, 0.16)],
  3: [Offset(0.14, 0.4), Offset(0.5, 0.13), Offset(0.86, 0.4)],
  4: [Offset(0.14, 0.46), Offset(0.3, 0.14), Offset(0.7, 0.14), Offset(0.86, 0.46)],
  5: [Offset(0.14, 0.52), Offset(0.17, 0.17), Offset(0.5, 0.11), Offset(0.83, 0.17), Offset(0.86, 0.52)],
};

/// On a phone on its side the table is wide and short: players sit along
/// the top and at the ends.
const _opponentSpotsWide = <int, List<Offset>>{
  1: [Offset(0.5, 0.2)],
  2: [Offset(0.3, 0.2), Offset(0.7, 0.2)],
  3: [Offset(0.12, 0.42), Offset(0.5, 0.2), Offset(0.88, 0.42)],
  4: [Offset(0.11, 0.45), Offset(0.36, 0.2), Offset(0.64, 0.2), Offset(0.89, 0.45)],
  5: [Offset(0.1, 0.5), Offset(0.27, 0.2), Offset(0.5, 0.2), Offset(0.73, 0.2), Offset(0.9, 0.5)],
};

const _pondSpot = Offset(0.5, 0.5);
const _youSpot = Offset(0.5, 0.94);

class _Table extends StatelessWidget {
  const _Table({required this.c});

  final FishController c;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        final wide = GameLayout.wide(context);
        // Seats never poke out above the table.
        Offset px(Offset f) => Offset(f.dx * size.width, max(f.dy * size.height, f.dy < 0.9 ? 80.0 : 0));
        final spots = [_youSpot, ...(wide ? _opponentSpotsWide : _opponentSpots)[c.players - 1]!];
        final pond = wide ? const Offset(0.5, 0.47) : _pondSpot;
        Offset seat(int s) => s < 0 ? px(pond) : px(spots[s]);
        final g = c.game;
        final card = min(size.width * 0.15, size.height * (wide ? 0.14 : 0.15)).clamp(44.0, 66.0);

        final children = <Widget>[
          const Positioned.fill(child: FeltPanel()),
          At(px(pond), child: _Pond(c: c)),
        ];

        for (var p = 1; p < c.players; p++) {
          children.add(
            At(
              px(spots[p]),
              child: _Opponent(c: c, player: p),
            ),
          );
        }
        // Speech bubbles over everyone, kept inside the felt: below players
        // along the top, above the rest, leaning inwards at the edges.
        for (var p = 1; p < c.players; p++) {
          final said = c.speech[p];
          if (said == null || c.phase != FishPhase.playing) continue;
          final at = px(spots[p]), f = spots[p];
          const inset = 22.0, w = 170.0;
          children.add(
            Positioned(
              top: at.dy - 66 + (f.dy < 0.25 ? 128 : -32),
              left: f.dx < 0.3
                  ? max(inset, at.dx - 54)
                  : f.dx > 0.7
                  ? null
                  : (at.dx - w / 2).clamp(inset, max(inset, size.width - w - inset)),
              right: f.dx > 0.7 ? max(inset, size.width - at.dx - 54) : null,
              child: f.dx >= 0.3 && f.dx <= 0.7
                  ? SizedBox(
                      width: w,
                      child: Center(child: SpeechBubble(said, key: ValueKey('say$p-${c.speechId}'))),
                    )
                  : SpeechBubble(said, key: ValueKey('say$p-${c.speechId}')),
            ),
          );
        }

        // Your books, bottom left above your hand.
        if (g.books[0].isNotEmpty) {
          children.add(
            Positioned(
              left: 22,
              bottom: card * 1.4 + 44,
              child: _BookRow(ranks: g.books[0], width: 22),
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

        // What you're saying, over your hand.
        final yours = c.speech[0];
        if (yours != null && c.phase == FishPhase.playing) {
          children.add(
            Positioned(
              left: 0,
              right: 0,
              bottom: card * 1.4 + 70,
              child: Center(
                child: SpeechBubble(yours, key: ValueKey('say0-${c.speechId}'), color: Toon.yellow),
              ),
            ),
          );
        }

        // Cards changing hands.
        for (final f in c.flights) {
          children.add(
            FlyingCards(
              key: ValueKey('fly${f.id}'),
              from: seat(f.from),
              to: seat(f.to) - (f.to == 0 ? Offset(0, card) : Offset.zero),
              cards: f.cards,
              width: card * 0.7,
              faceUp: f.faceUp,
            ),
          );
        }

        // "Book of 7s!"
        final book = c.lastBook;
        if (book != null) {
          children.add(
            Positioned.fill(
              child: IgnorePointer(
                child: _BookPop(
                  key: ValueKey('book${book.player}-${book.rank}-${c.round}'),
                  text:
                      '${book.player == 0 ? 'Your' : "${c.personas[book.player].name}'s"} book: ${rankPlural(book.rank)}!',
                  rank: book.rank,
                ),
              ),
            ),
          );
        }

        return Stack(clipBehavior: Clip.none, children: children);
      },
    );
  }
}

/// Face-down cards scattered in the middle. Glows when you have to fish.
class _Pond extends StatelessWidget {
  const _Pond({required this.c});

  final FishController c;

  @override
  Widget build(BuildContext context) {
    final n = c.game.pond.length;
    final rng = Random(c.round);
    final shown = min(n, 12);
    final glow = c.youMustFish;
    final spots = [
      for (var i = 0; i < 12; i++)
        (dx: rng.nextDouble() * 90 - 45, dy: rng.nextDouble() * 40 - 20, a: rng.nextDouble() * 2 - 1),
    ];
    return GestureDetector(
      key: const Key('pond'),
      onTap: glow ? c.fish : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 150,
            height: 96,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                color: Toon.blue.withValues(alpha: glow ? 0.55 : 0.3),
                borderRadius: BorderRadius.circular(48),
                border: Border.all(
                  color: glow ? Toon.yellow : Colors.white.withValues(alpha: 0.4),
                  width: glow ? 4 : 2,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (var i = 0; i < shown; i++)
                    Transform.translate(
                      offset: Offset(spots[i].dx, spots[i].dy),
                      child: Transform.rotate(
                        angle: spots[i].a,
                        child: const CardView(card: null, width: 26, faceUp: false),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: glow ? Toon.yellow : Toon.inkLight.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              glow ? 'Tap to fish!' : (n == 0 ? 'Pond empty' : 'Pond · $n'),
              style: Toon.text(12, color: glow ? Toon.inkLight : Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookRow extends StatelessWidget {
  const _BookRow({required this.ranks, required this.width});

  final List<int> ranks;
  final double width;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final r in ranks)
        Padding(
          padding: const EdgeInsets.only(right: 3),
          child: Pop(
            child: CardView(card: PlayingCard(r, Suit.spades), width: width),
          ),
        ),
    ],
  );
}

class _BookPop extends StatelessWidget {
  const _BookPop({super.key, required this.text, required this.rank});

  final String text;
  final int rank;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 1500),
    builder: (context, t, _) {
      if (t >= 1) return const SizedBox.shrink();
      final grow = Curves.elasticOut.transform((t / 0.45).clamp(0, 1));
      return Center(
        child: Opacity(
          opacity: t < 0.75 ? 1 : (1 - t) / 0.25,
          child: Transform.scale(
            scale: 0.4 + 0.6 * grow,
            child: ToonBox(
              color: Toon.yellow,
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final s in Suit.values)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: CardView(card: PlayingCard(rank, s), width: 34),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    text,
                    style: Toon.text(18, weight: FontWeight.w700, color: Toon.inkLight),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _Opponent extends StatelessWidget {
  const _Opponent({required this.c, required this.player});

  final FishController c;
  final int player;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    final n = g.hands[player].length;
    final turn = g.turn == player && c.phase == FishPhase.playing && !g.isOver;
    final pickable = c.selected != null && c.yourTurn && g.targets(0).contains(player);
    final shown = min(n, 7);
    final ring = pickable ? Toon.yellow : (turn ? Toon.orange : Toon.card);
    return GestureDetector(
      key: Key('ask $player'),
      onTap: pickable ? () => c.askPlayer(player) : null,
      child: SizedBox(
        width: 108,
        height: 132,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: 0,
              child: SizedBox(
                width: 108,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    for (var i = 0; i < shown; i++)
                      Transform.translate(
                        offset: Offset((i - (shown - 1) / 2) * 9, ((i - (shown - 1) / 2).abs()) * 1.5),
                        child: Transform.rotate(
                          angle: (i - (shown - 1) / 2) * 0.12,
                          child: DealIn(
                            key: ValueKey('o${c.round}-$player-$i'),
                            delay: i * 90 + player * 30,
                            child: const CardView(card: null, width: 23, faceUp: false),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 28,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(pickable ? 5 : 3),
                decoration: BoxDecoration(
                  color: ring,
                  shape: BoxShape.circle,
                  border: Border.all(color: Toon.ink, width: Toon.outline),
                  boxShadow: [BoxShadow(color: Toon.ink, offset: const Offset(0, 3))],
                ),
                child: Face(c.personas[player], size: 44),
              ),
            ),
            Positioned(
              top: 86,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: Toon.box(Toon.card, radius: 10, shadow: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c.personas[player].name, style: Toon.text(12)),
                    Text(
                      '$n card${n == 1 ? '' : 's'} · ${g.books[player].length} bk',
                      style: Toon.text(11, weight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            if (pickable)
              Positioned(
                top: 18,
                right: -6,
                child: Pop(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: Toon.box(Toon.yellow, radius: 8, shadow: 2),
                    child: Text(
                      'Ask',
                      style: Toon.text(12, weight: FontWeight.w700, color: Toon.inkLight),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Your cards, sorted by rank. On your turn tap one to ask for its rank;
/// the chosen rank lifts.
class _Hand extends StatelessWidget {
  const _Hand({required this.c, required this.cardWidth});

  final FishController c;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final hand = [...c.game.hands[0]]
      ..sort((a, b) => a.rank != b.rank ? a.rank.compareTo(b.rank) : a.suit.index.compareTo(b.suit.index));
    final canPick = c.yourTurn && !c.game.mustFish;
    return LayoutBuilder(
      builder: (context, box) {
        final w = cardWidth;
        final n = hand.length;
        final room = box.maxWidth - 24 - w;
        final step = n <= 1 ? 0.0 : min(w * 0.7, room / (n - 1));
        final total = w + step * (n - 1);
        final left = (box.maxWidth - total) / 2;
        return SizedBox(
          height: w * 1.4 + 22,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final (i, card) in hand.indexed)
                AnimatedPositioned(
                  key: ValueKey('h${card.id}'),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  left: left + i * step,
                  top: c.selected == card.rank ? 0 : 18,
                  child: DealIn(
                    key: ValueKey('hd${c.round}-${card.id}'),
                    delay: c.phase == FishPhase.dealing ? i * 100 : 0,
                    from: const Offset(0, -160),
                    child: GestureDetector(
                      key: ValueKey('card ${card.id}'),
                      onTap: canPick ? () => c.pick(card.rank) : null,
                      child: CardView(card: card, width: w, glow: c.selected == card.rank),
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

class _Actions extends StatelessWidget {
  const _Actions({required this.c});

  final FishController c;

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (c.youMustFish) {
      body = ToonButton(
        key: const Key('go fish'),
        color: Toon.blue,
        onPressed: c.fish,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(Icons.phishing_rounded), SizedBox(width: 8), Text('Go fish!')],
        ),
      );
    } else if (c.yourTurn && c.selected != null) {
      body = ToonButton(
        key: const Key('cancel ask'),
        color: Toon.card,
        onPressed: () => c.pick(c.selected!),
        child: Text('Not ${rankPlural(c.selected!)} after all'),
      );
    } else {
      body = SizedBox(
        height: 48,
        child: Center(
          child: Text(
            c.phase == FishPhase.dealing
                ? 'Dealing…'
                : c.yourTurn
                ? 'Tap a card to ask for its rank'
                : (c.game.isOver ? '' : "${c.personas[c.game.turn].name}'s turn"),
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
