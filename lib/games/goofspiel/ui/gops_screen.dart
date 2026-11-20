import 'dart:math';

import 'package:duel_engine/cards.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/goofspiel/goofspiel.dart';
import 'package:flutter/material.dart';

import '../../../core/account/account.dart';
import '../../../core/account/stake.dart';
import '../../../core/cards/card_view.dart';
import '../../../core/help/game_guide.dart';
import '../../../core/table/table_bits.dart';
import '../../../core/theme/toon.dart';
import 'gops_controller.dart';

const goofspielGuide = [
  GuideStage(
    'deal',
    'The cards',
    'The 13 diamonds are the prizes, shuffled face down. You bid with the clubs, Ace to King; each bot has a '
        'suit of its own.',
    icon: Icons.style_rounded,
  ),
  GuideStage(
    'bid',
    'Bid',
    'A prize turns up. Tap a card to lift it, then Bid. Nobody sees bids until everyone is in. Ace is worth 1, '
        'Jack 11, Queen 12, King 13, for prizes and bids alike.',
    icon: Icons.touch_app_rounded,
  ),
  GuideStage(
    'reveal',
    'The reveal',
    'All bids turn over together. The highest takes the prize. Every card bids once, so a King spent on a 2 is '
        'a King gone.',
    icon: Icons.visibility_rounded,
  ),
  GuideStage(
    'tie',
    'Ties',
    'A tie for the highest bid: nobody wins, the prize stays, and the next one joins it. Whoever wins next takes '
        'them all. A tie on the last prize: it\'s thrown away.',
    icon: Icons.call_split_rounded,
  ),
  GuideStage(
    'tips',
    'Think ahead',
    'Remember what everyone has played. When your highest card left beats all of theirs, a big prize is yours '
        'for the taking. Let small prizes go cheaply.',
    icon: Icons.psychology_rounded,
  ),
  GuideStage(
    'end',
    'Winning',
    'After all 13 prizes, the most points wins (91 in all). A tie for most is a tie: stakes go back.',
    icon: Icons.emoji_events_rounded,
  ),
];

/// Goofspiel against 1 or 2 bots.
class GopsScreen extends StatefulWidget {
  const GopsScreen({
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
  State<GopsScreen> createState() => _GopsScreenState();
}

class _GopsScreenState extends State<GopsScreen> {
  late final Account _account = AccountScope.maybeRead(context) ?? Account();
  late StakeTicket _ticket =
      widget.stake ??
      StakeTicket(
        account: _account,
        gameId: 'gops',
        stake: 0,
        opponents: widget.bots,
        difficulty: widget.difficulty,
      );
  late final GopsController _c = GopsController(
    bots: widget.bots,
    difficulty: widget.difficulty,
    pace: widget.pace,
    rng: widget.seed == null ? null : Random(widget.seed),
    you: _account.persona,
  )..addListener(_settle);

  void _settle() {
    if (_c.phase == GopsPhase.over && !_ticket.settled) {
      final w = _c.game.winners;
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

  String? _stage() => switch (_c.phase) {
    GopsPhase.dealing => 'deal',
    GopsPhase.over => 'end',
    GopsPhase.revealing => 'reveal',
    GopsPhase.bidding when _c.shown?.winner == null && _c.game.pot.length > 1 => 'tie',
    GopsPhase.bidding => 'bid',
  };

  Future<void> _leave() async {
    if (_c.phase == GopsPhase.over || await confirmLeave(context, _ticket)) {
      if (mounted) Navigator.of(context).pop();
    }
  }

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
                  title: 'Goofspiel',
                  subtitle:
                      'You + ${widget.bots} ${widget.bots == 1 ? 'bot' : 'bots'} · ${widget.difficulty.label}',
                  onLeave: _leave,
                  ticket: _ticket,
                  guide: goofspielGuide,
                  stage: _stage,
                ),
                commentary: CommentaryStrip(
                  text: _c.commentary(),
                  yourMove: _c.canBid,
                  leading: _Score(points: _c.game.scores[0]),
                ),
                table: _Table(c: _c),
                controls: _Actions(c: _c),
              ),
              if (_c.phase == GopsPhase.over) Positioned.fill(child: _over(context)),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _over(BuildContext context) {
    final g = _c.game;
    final w = g.winners;
    final tie = w.length > 1;
    final won = w.contains(0) && !tie;
    final mine = g.scores[0], top = g.scores[w.first];
    final others = [for (var p = 1; p < g.players; p++) '${_c.personas[p].name} ${g.scores[p]}'].join(', ');
    return GameOverCard(
      face: _c.personas[w.contains(0) ? 0 : w.first],
      title: tie
          ? (w.contains(0) ? "It's a tie!" : 'A tie')
          : (won ? 'You won!' : '${_c.personas[w.first].name} won'),
      subtitle: won
          ? 'You took $mine of 91 points. $others.'
          : tie
          ? '$top points each${w.contains(0) ? ': your stake comes back.' : '. You took $mine.'}'
          : '$top points to your $mine.',
      ticket: _ticket,
      won: won,
      onAgain: _playAgain,
      onLeave: () => Navigator.of(context).pop(),
    );
  }
}

class _Score extends StatelessWidget {
  const _Score({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) => Container(
    width: 46,
    padding: const EdgeInsets.symmetric(vertical: 3),
    decoration: Toon.box(Toon.cardFace, radius: 10, shadow: 0),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$points',
          style: Toon.text(18, weight: FontWeight.w700, color: Toon.inkLight),
        ),
        Text('points', style: Toon.text(10, color: Toon.inkLight)),
      ],
    ),
  );
}

PlayingCard _card(int value, Suit suit) => PlayingCard(gopsRank(value), suit);

/// A bid on the table: face down until the reveal, then turned over.
class _Bid extends StatelessWidget {
  const _Bid({required this.card, required this.width, required this.flip, this.win = false});

  final PlayingCard? card;
  final double width;
  final int flip;
  final bool win;

  @override
  Widget build(BuildContext context) {
    final c = card;
    if (c == null) {
      return Pop(child: CardView(card: null, width: width, faceUp: false));
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey('flip$flip-${c.id}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      builder: (context, t, _) {
        final up = t >= 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scaleByDouble((t - 0.5).abs() * 2, 1, 1, 1),
          child: CardView(card: c, width: width, faceUp: up, glow: up && win),
        );
      },
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.c});

  final GopsController c;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final g = c.game;
      final wide = GameLayout.wide(context);
      final size = Size(box.maxWidth, box.maxHeight);
      final card = min(size.width * 0.14, size.height * (wide ? 0.17 : 0.12)).clamp(38.0, 62.0);
      final shown = c.shown;
      PlayingCard? bidOf(int p) {
        if (shown != null) return _card(shown.bids[p], gopsSuits[p]);
        if (c.ready.contains(p)) return null; // face down
        return null;
      }

      Widget? slot(int p) {
        if (shown != null) {
          return _Bid(card: bidOf(p), width: card * 0.9, flip: c.reveals, win: shown.winner == p);
        }
        if (c.ready.contains(p) || (p == 0 && c.yourBid != null)) {
          return _Bid(card: null, width: card * 0.9, flip: c.reveals);
        }
        return null;
      }

      final opponents = [
        for (var p = 1; p < g.players; p++) _Opponent(c: c, player: p, slot: slot(p), cardWidth: card * 0.9),
      ];
      return Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(child: FeltPanel()),
          Positioned(
            top: 10,
            left: 8,
            right: 8,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: opponents),
          ),
          Positioned.fill(
            top: 150,
            bottom: card * 1.4 + 24,
            child: Center(
              child: FittedBox(
                child: _Prize(
                  c: c,
                  width: card * (wide ? 1.25 : 1.6),
                  yourSlot: slot(0),
                  slotWidth: card * (wide ? 0.9 : 1.1),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 4,
            child: _Hand(c: c, cardWidth: card),
          ),
          // Pops: a tie, a big win.
          if (shown != null)
            Positioned.fill(
              child: IgnorePointer(
                child: _RoundPop(
                  key: ValueKey('pop${c.reveals}'),
                  text: shown.winner == null
                      ? 'Tie! ${shown.worth} carries over'
                      : shown.winner == 0
                      ? (shown.worth >= 15 ? 'Big win! +${shown.worth}' : '+${shown.worth}')
                      : '${c.personas[shown.winner!].name} +${shown.worth}',
                  color: shown.winner == null
                      ? Toon.orange
                      : shown.winner == 0
                      ? Toon.yellow
                      : Toon.card,
                  big: shown.worth >= 15,
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// The prize in the middle (carried prizes fanned behind it), the face-down
/// prizes still to come, and your bid in front.
class _Prize extends StatelessWidget {
  const _Prize({required this.c, required this.width, required this.yourSlot, required this.slotWidth});

  final GopsController c;
  final double width;
  final Widget? yourSlot;
  final double slotWidth;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    final pot = c.shown?.prizes ?? g.pot;
    final worth = pot.fold(0, (a, b) => a + b);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Prizes to come.
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: width * 0.6 + 8,
              height: width * 0.6 * 1.4 + 8,
              child: Stack(
                children: [
                  for (var i = 0; i < min(4, g.prizesLeft); i++)
                    Positioned(
                      left: i * 2.0,
                      top: i * 2.0,
                      child: CardView(card: null, width: width * 0.6, faceUp: false),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text('${g.prizesLeft} left', style: Toon.text(11, color: Colors.white)),
          ],
        ),
        const SizedBox(width: 14),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(color: Toon.yellow, borderRadius: BorderRadius.circular(8)),
              child: Text(
                pot.isEmpty ? 'Prize' : 'Prize · $worth',
                style: Toon.text(12, weight: FontWeight.w700, color: Toon.inkLight),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: width + (max(pot.length, 1) - 1) * width * 0.32,
              height: width * 1.4,
              child: Stack(
                children: [
                  for (final (i, v) in pot.indexed)
                    Positioned(
                      left: i * width * 0.32,
                      child: Transform.rotate(
                        angle: (i - pot.length + 1) * 0.08,
                        child: DealIn(
                          key: ValueKey('prize${c.round}-$v'),
                          from: const Offset(-60, 0),
                          child: CardView(card: _card(v, Suit.diamonds), width: width),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),
        // Your bid.
        SizedBox(
          width: slotWidth + 8,
          height: slotWidth * 1.4 + 18,
          child: Column(
            children: [
              Text('You', style: Toon.text(11, color: Colors.white)),
              const SizedBox(height: 2),
              yourSlot ??
                  Container(
                    width: slotWidth,
                    height: slotWidth * 1.4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(slotWidth * 0.14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Opponent extends StatelessWidget {
  const _Opponent({required this.c, required this.player, required this.slot, required this.cardWidth});

  final GopsController c;
  final int player;
  final Widget? slot;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    final said = c.speech[player];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                FaceRing(c.personas[player], size: 38, color: c.ready.contains(player) ? Toon.green : null),
                if (said != null)
                  Positioned(
                    left: 40,
                    top: -4,
                    child: SpeechBubble(said, key: ValueKey('say$player-${c.speechId}')),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: Toon.box(Toon.card, radius: 10, shadow: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(c.personas[player].name, style: Toon.text(12)),
                  Text('${g.scores[player]} pts', style: Toon.text(12, weight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 6),
        SizedBox(width: cardWidth, height: cardWidth * 1.4, child: slot),
      ],
    );
  }
}

/// Your suit, Ace to King. Tap to lift, tap Bid to play it.
class _Hand extends StatelessWidget {
  const _Hand({required this.c, required this.cardWidth});

  final GopsController c;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final hand = c.game.hands[0].toList()..sort();
    return LayoutBuilder(
      builder: (context, box) {
        final w = cardWidth;
        final n = hand.length;
        final room = box.maxWidth - 24 - w;
        final step = n <= 1 ? 0.0 : min(w * 0.72, room / (n - 1));
        final total = w + step * (n - 1);
        final left = (box.maxWidth - total) / 2;
        return SizedBox(
          height: w * 1.4 + 22,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final (i, v) in hand.indexed)
                AnimatedPositioned(
                  key: ValueKey('h$v'),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  left: left + i * step,
                  top: c.selected == v ? 0 : 18,
                  child: DealIn(
                    key: ValueKey('hd${c.round}-$v'),
                    delay: c.phase == GopsPhase.dealing ? i * 70 : 0,
                    from: const Offset(0, -160),
                    child: GestureDetector(
                      key: ValueKey('card $v'),
                      onTap: c.canBid ? () => c.pick(v) : null,
                      child: CardView(
                        card: _card(v, gopsSuits[0]),
                        width: w,
                        glow: c.selected == v,
                        dim: !c.canBid && c.phase == GopsPhase.bidding,
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

class _Actions extends StatelessWidget {
  const _Actions({required this.c});

  final GopsController c;

  @override
  Widget build(BuildContext context) {
    final s = c.selected;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: c.canBid && s != null
          ? ToonButton(
              key: const Key('bid'),
              color: Toon.green,
              onPressed: c.bid,
              child: Text('Bid ${gopsLabel(s)} for ${c.game.potWorth}'),
            )
          : SizedBox(
              height: 48,
              child: Center(
                child: Text(switch (c.phase) {
                  GopsPhase.dealing => 'Dealing…',
                  GopsPhase.bidding when c.canBid => 'Tap a card to bid it',
                  GopsPhase.bidding => 'Waiting for the others…',
                  GopsPhase.revealing => 'Turning the bids over…',
                  GopsPhase.over => '',
                }, style: Toon.text(16, color: Toon.muted)),
              ),
            ),
    );
  }
}

class _RoundPop extends StatelessWidget {
  const _RoundPop({super.key, required this.text, required this.color, required this.big});

  final String text;
  final Color color;
  final bool big;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 1600),
    builder: (context, t, _) {
      // Waits for the flip, then pops.
      if (t < 0.3 || t >= 1) return const SizedBox.shrink();
      final u = (t - 0.3) / 0.7;
      final grow = Curves.elasticOut.transform((u / 0.5).clamp(0, 1));
      return Align(
        alignment: const Alignment(0, 0.35),
        child: Opacity(
          opacity: u < 0.75 ? 1 : (1 - u) / 0.25,
          child: Transform.scale(
            scale: (0.4 + 0.6 * grow) * (big ? 1.25 : 1),
            child: ToonBox(
              color: color,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                text,
                style: Toon.text(20, weight: FontWeight.w700, color: Toon.on(color)),
              ),
            ),
          ),
        ),
      );
    },
  );
}
