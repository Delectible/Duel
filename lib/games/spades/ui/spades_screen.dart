import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/account/account.dart';
import '../../../core/account/stake.dart';
import '../../../core/avatars/faces.dart';
import '../../../core/cards/card_view.dart';
import '../../../core/cards/cards.dart';
import '../../../core/help/game_guide.dart';
import '../../../core/session/difficulty.dart';
import '../../../core/table/table_bits.dart';
import '../../../core/theme/toon.dart';
import '../engine/spades.dart';
import 'spades_controller.dart';

/// How to play Spades, by stage (the ? button).
const spadesGuide = [
  GuideStage(
    'deal',
    'The deal',
    'Four players: everyone gets 13 cards. You and your partner sit opposite each other and play as a team '
        'against the other two.',
    icon: Icons.style_rounded,
  ),
  GuideStage(
    'draw',
    'Two players: drawing',
    'With two players nobody deals. Take turns looking at the top card of the pile: keep it, or pass it and take '
        'the next card instead (whichever you don\'t take is thrown away). Do this until you both have 13. Spades '
        'and high cards are worth keeping.',
    icon: Icons.layers_rounded,
  ),
  GuideStage(
    'bid',
    'Bidding',
    'Say how many tricks you think you can win. Aces, Kings and spades win tricks. Partners add their bids '
        'together. Or bid Nil: win no tricks at all for 100 points (lose 100 if you take one).',
    icon: Icons.record_voice_over_rounded,
  ),
  GuideStage(
    'play',
    'Playing tricks',
    'Each player plays one card; the four (or two) cards are a trick. Follow the suit that was led if you can. '
        'If you can\'t, play anything: a spade wins it. The highest spade takes the trick, otherwise the highest '
        'card of the suit led. You can\'t lead spades until one has been played. The winner leads next.',
    icon: Icons.touch_app_rounded,
  ),
  GuideStage(
    'score',
    'Scoring',
    'Make your bid: 10 points for each trick you bid, plus 1 for each extra trick (a "bag"). Collect 10 bags and '
        'lose 100. Miss your bid: lose 10 for each trick you bid. First to the target (150, 250 or 500) wins. Fall '
        'to -200 and you lose.',
    icon: Icons.emoji_events_rounded,
  ),
];

/// Spades against bots: two-handed (1 bot) or partners (3 bots, the one
/// opposite is your partner).
class SpadesScreen extends StatefulWidget {
  const SpadesScreen({
    super.key,
    required this.bots,
    required this.difficulty,
    this.target = 250,
    this.pace = 1,
    this.seed,
    this.stake,
  }) : assert(bots == 1 || bots == 3);

  final int bots;
  final Difficulty difficulty;
  final int target;
  final double pace;
  final int? seed;
  final StakeTicket? stake;

  @override
  State<SpadesScreen> createState() => _SpadesScreenState();
}

class _SpadesScreenState extends State<SpadesScreen> {
  late final Account _account = AccountScope.maybeRead(context) ?? Account();
  late StakeTicket _ticket =
      widget.stake ??
      StakeTicket(
        account: _account,
        gameId: 'spades',
        stake: 0,
        opponents: widget.bots == 3 ? 2 : 1,
        difficulty: widget.difficulty,
      );
  late final SpadesController _c = SpadesController(
    bots: widget.bots,
    difficulty: widget.difficulty,
    target: widget.target,
    pace: widget.pace,
    rng: widget.seed == null ? null : Random(widget.seed),
    you: _account.persona,
  )..addListener(_settle);

  void _settle() {
    final g = _c.game;
    if (g.isOver && !_ticket.settled) {
      _ticket.settle(g.winner == 0 ? Outcome.win : Outcome.loss);
      HapticFeedback.heavyImpact();
    }
  }

  void _playAgain() {
    setState(() => _ticket = _ticket.again());
    _c.playAgain();
  }

  Future<void> _leave() async {
    if (_c.stage == SpadesStage.over || await confirmLeave(context, _ticket)) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  String? _stage() => switch (_c.stage) {
    SpadesStage.dealing => 'deal',
    SpadesStage.drawing => 'draw',
    SpadesStage.bidding => 'bid',
    SpadesStage.playing || SpadesStage.trickDone => 'play',
    SpadesStage.handOver || SpadesStage.over => 'score',
  };

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vs = widget.bots == 3 ? 'You + partner vs 2 bots' : 'You vs 1 bot';
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
                    title: 'Spades',
                    subtitle: '$vs · to ${widget.target} · ${widget.difficulty.label}',
                    onLeave: _leave,
                    ticket: _ticket,
                    guide: spadesGuide,
                    stage: _stage,
                  ),
                  commentary: CommentaryStrip(
                    text: _c.commentary(),
                    yourMove: _c.yourDraw || _c.yourBidTurn || _c.yourPlay,
                    leading: _Scores(c: _c),
                  ),
                  table: _Table(c: _c),
                  controls: _Controls(c: _c),
                ),
                if (_c.stage == SpadesStage.handOver) Positioned.fill(child: _HandResult(c: _c)),
                if (_c.stage == SpadesStage.over) Positioned.fill(child: _over(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _over(BuildContext context) {
    final g = _c.game;
    final won = g.winner == 0;
    return GameOverCard(
      face: won ? _c.personas[0] : _c.personas[1],
      title: won ? 'You won!' : '${_c.teamName(1)} won',
      subtitle:
          'Final score ${g.scores[0]} to ${g.scores[1]}, after ${g.handNumber} '
          'hand${g.handNumber == 1 ? '' : 's'}.',
      ticket: _ticket,
      won: won,
      onAgain: _playAgain,
      onLeave: () => Navigator.of(context).pop(),
    );
  }
}

/// Us / them scores, in the commentary strip.
class _Scores extends StatelessWidget {
  const _Scores({required this.c});

  final SpadesController c;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    Widget line(String who, int score) => Text(
      '$who $score',
      maxLines: 1,
      style: Toon.text(11, weight: FontWeight.w700, color: Toon.inkLight),
    );
    return Container(
      key: const Key('scores'),
      constraints: const BoxConstraints(minWidth: 58),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: Toon.box(Toon.cardFace, radius: 10, shadow: 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line(c.teams ? 'Us' : 'You', g.scores[0]),
          line(c.teams ? 'Them' : c.personas[1].name, g.scores[1]),
        ],
      ),
    );
  }
}

/// Where the opponents sit (fractions of the table), by seat 1..3.
const _spots = <int, List<Offset>>{
  2: [Offset(0.5, 0.14)],
  4: [Offset(0.13, 0.42), Offset(0.5, 0.14), Offset(0.87, 0.42)],
};
const _spotsWide = <int, List<Offset>>{
  2: [Offset(0.5, 0.17)],
  4: [Offset(0.1, 0.46), Offset(0.5, 0.17), Offset(0.9, 0.46)],
};

class _Table extends StatelessWidget {
  const _Table({required this.c});

  final SpadesController c;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        final wide = GameLayout.wide(context);
        final g = c.game;
        final card = min(size.width * 0.15, size.height * (wide ? 0.14 : 0.13)).clamp(42.0, 64.0);
        final handHeight = card * 1.4 + 24;
        // Seats never poke out above the table.
        Offset px(Offset f) => Offset(f.dx * size.width, max(f.dy * size.height, 80.0));
        final spots = (wide ? _spotsWide : _spots)[g.players]!;
        // The trick sits midway between the top seat and your hand, as
        // spread out as the room allows.
        final trickCard = card * 0.85;
        final seatBottom = px(spots[g.players == 4 ? 1 : 0]).dy + 64;
        final handTop = size.height - handHeight - 22;
        final gap = handTop - seatBottom;
        final center = Offset(size.width / 2, seatBottom + gap / 2);
        final reach = min(trickCard * 1.4 * 0.5, max(0.0, (gap - trickCard * 1.4) / 2 - 4));
        Offset seat(int p) =>
            p == 0 ? Offset(size.width / 2, size.height - handHeight / 2) : px(spots[p - 1]);
        // Where each player's card lands in the trick: towards them.
        Offset slot(int p) {
          final dx = card * 0.8, dy = reach;
          if (g.players == 2) return center + Offset(0, p == 0 ? dy : -dy);
          return center + [Offset(0, dy), Offset(-dx, 0), Offset(0, -dy), Offset(dx, 0)][p];
        }

        final children = <Widget>[const Positioned.fill(child: FeltPanel())];

        for (var p = 1; p < g.players; p++) {
          children.add(
            At(
              px(spots[p - 1]),
              child: _Seat(c: c, player: p),
            ),
          );
        }

        // Two-handed draw: the pile, and the card you're offered.
        if (c.stage == SpadesStage.drawing) {
          children.add(
            At(
              center,
              child: _Stock(c: c, width: card),
            ),
          );
        }

        // The trick: cards fly in from their player; when it's won they
        // fly to the winner.
        final shown = c.lastTrick?.cards ?? g.trick;
        final winner = c.lastTrick?.player;
        for (final (p, playing) in shown) {
          final key = 't${c.round}-${playing.id}';
          if (c.sweeping && winner != null) {
            children.add(
              _Flying(
                key: ValueKey('$key-sweep'),
                from: slot(p),
                to: seat(winner),
                fade: true,
                child: CardView(card: playing, width: trickCard),
              ),
            );
          } else {
            children.add(
              _Flying(
                key: ValueKey(key),
                from: seat(p),
                to: slot(p),
                child: CardView(
                  card: playing,
                  width: trickCard,
                  glow: c.stage == SpadesStage.trickDone && p == winner,
                ),
              ),
            );
          }
        }

        // Your bid and tricks, and the hand.
        children.add(
          Positioned(
            left: 14,
            bottom: handHeight + 2,
            child: _YourTag(c: c),
          ),
        );
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

/// A card sliding from [from] to [to] (fading if [fade]).
class _Flying extends StatelessWidget {
  const _Flying({super.key, required this.from, required this.to, required this.child, this.fade = false});

  final Offset from;
  final Offset to;
  final Widget child;
  final bool fade;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: fade ? 420 : 320),
    curve: Curves.easeOutCubic,
    builder: (context, t, child) => At(
      Offset.lerp(from, to, t)!,
      child: Opacity(opacity: fade ? (1 - t) : 1, child: child),
    ),
    child: IgnorePointer(child: child),
  );
}

/// An opponent (or partner): cards, face, name, bid and tricks.
class _Seat extends StatelessWidget {
  const _Seat({required this.c, required this.player});

  final SpadesController c;
  final int player;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    final n = g.hands[player].length;
    final shown = min(n, 7);
    final turn =
        g.turn == player &&
        const [SpadesStage.drawing, SpadesStage.bidding, SpadesStage.playing].contains(c.stage);
    final partner = c.teams && player == 2;
    final won = c.lastTrick?.player == player && c.stage == SpadesStage.trickDone;
    return SizedBox(
      width: 112,
      height: 128,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
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
                      offset: Offset((i - (shown - 1) / 2) * 8, ((i - (shown - 1) / 2).abs()) * 1.5),
                      child: Transform.rotate(
                        angle: (i - (shown - 1) / 2) * 0.12,
                        child: DealIn(
                          key: ValueKey('o${c.round}-$player-$i'),
                          delay: i * 80 + player * 30,
                          from: const Offset(0, 80),
                          child: const CardView(card: null, width: 22, faceUp: false),
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
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: won ? Toon.green : (turn ? Toon.yellow : Toon.card),
                shape: BoxShape.circle,
                border: Border.all(color: Toon.ink, width: Toon.outline),
                boxShadow: [BoxShadow(color: Toon.ink, offset: const Offset(0, 3))],
              ),
              child: Face(c.personas[player], size: 44),
            ),
          ),
          if (partner)
            Positioned(
              top: 18,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: Toon.box(Toon.blue, radius: 7, shadow: 0),
                child: Text(
                  'Partner',
                  style: Toon.text(10, weight: FontWeight.w700, color: Toon.on(Toon.blue)),
                ),
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
                  Text(_bidLine(c, player), style: Toon.text(11, weight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Bid 3 · won 1", "Nil · won 0", "Bidding…".
String _bidLine(SpadesController c, int p) {
  final g = c.game;
  final b = g.bids[p];
  if (c.stage == SpadesStage.drawing) {
    final n = g.hands[p].length;
    return '$n card${n == 1 ? '' : 's'}';
  }
  if (b == null) return c.stage == SpadesStage.bidding && g.turn == p ? 'Bidding…' : 'Bid —';
  return '${b == 0 ? 'Nil' : 'Bid $b'} · won ${g.tricksWon[p]}';
}

/// Your bid and tricks, just above your hand.
class _YourTag extends StatelessWidget {
  const _YourTag({required this.c});

  final SpadesController c;

  @override
  Widget build(BuildContext context) {
    final won = c.lastTrick?.player == 0 && c.stage == SpadesStage.trickDone;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: Toon.box(won ? Toon.green : Toon.card, radius: 10, shadow: 2),
      child: Text(
        'You · ${_bidLine(c, 0)}',
        key: const Key('your tag'),
        style: Toon.text(12, weight: FontWeight.w700, color: Toon.on(won ? Toon.green : Toon.card)),
      ),
    );
  }
}

/// Two-handed draw: the face-down pile and, on your turn, the card on top.
class _Stock extends StatelessWidget {
  const _Stock({required this.c, required this.width});

  final SpadesController c;
  final double width;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    final offered = c.yourDraw ? g.offered : null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Transform.translate(
                  offset: const Offset(3, 3),
                  child: CardView(card: null, width: width, faceUp: false),
                ),
                CardView(card: null, width: width, faceUp: false),
              ],
            ),
            const SizedBox(height: 4),
            _Label('${g.stock.length} left'),
          ],
        ),
        if (offered != null) ...[
          const SizedBox(width: 18),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Pop(
                key: ValueKey('offer${offered.id}-${g.stock.length}'),
                child: CardView(key: const Key('offered'), card: offered, width: width * 1.15, glow: true),
              ),
              const SizedBox(height: 4),
              const _Label('Keep it?'),
            ],
          ),
        ],
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: Toon.inkLight.withValues(alpha: 0.75),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(text, style: Toon.text(12, color: Colors.white)),
  );
}

/// Your cards, sorted by suit (spades last) and rank. On your turn the
/// cards you may play lift up.
class _Hand extends StatelessWidget {
  const _Hand({required this.c, required this.cardWidth});

  final SpadesController c;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    const order = [Suit.clubs, Suit.diamonds, Suit.hearts, Suit.spades];
    final hand = [...c.game.hands[0]]
      ..sort(
        (a, b) => a.suit != b.suit
            ? order.indexOf(a.suit).compareTo(order.indexOf(b.suit))
            : a.rank.compareTo(b.rank),
      );
    final playable = c.yourPlayable.toSet();
    final dealing = c.stage == SpadesStage.dealing;
    return LayoutBuilder(
      builder: (context, box) {
        final w = cardWidth;
        final n = hand.length;
        final room = box.maxWidth - 24 - w;
        final step = n <= 1 ? 0.0 : min(w * 0.62, room / (n - 1));
        final total = w + step * (n - 1);
        final left = (box.maxWidth - total) / 2;
        return SizedBox(
          height: w * 1.4 + 20,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final (i, card) in hand.indexed)
                AnimatedPositioned(
                  key: ValueKey('h${card.id}'),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  left: left + i * step,
                  top: playable.contains(card) ? 0 : 16,
                  child: DealIn(
                    key: ValueKey('hd${c.round}-${card.id}'),
                    delay: dealing ? i * 90 : 0,
                    from: const Offset(0, -160),
                    child: GestureDetector(
                      key: ValueKey('card ${card.id}'),
                      onTap: playable.contains(card)
                          ? () {
                              HapticFeedback.selectionClick();
                              c.play(card);
                            }
                          : null,
                      child: CardView(
                        card: card,
                        width: w,
                        glow: playable.contains(card),
                        dim: c.yourPlay && !playable.contains(card),
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

/// Buttons under the table: keep / pass, the bid picker, or whose turn.
class _Controls extends StatelessWidget {
  const _Controls({required this.c});

  final SpadesController c;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    Widget body;
    if (c.yourDraw) {
      body = Row(
        children: [
          Expanded(
            child: ToonButton(
              key: const Key('draw pass'),
              color: Toon.card,
              onPressed: () => c.draw(keep: false),
              child: const FittedBox(child: Text('Pass: take the next', maxLines: 1)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ToonButton(
              key: const Key('draw keep'),
              color: Toon.green,
              onPressed: () => c.draw(keep: true),
              child: const Text('Keep it'),
            ),
          ),
        ],
      );
    } else if (c.yourBidTurn) {
      final partner = g.partner(0);
      final hint = c.yourBid == 0
          ? 'Nil: win no tricks at all for +100 (or -100 if you take one).'
          : partner != null && g.bids[partner] != null
          ? 'Your cards look like about ${c.suggestedBid}. ${c.personas[partner].name} bid '
                '${c.bidWord(g.bids[partner]!)}: together ${c.yourBid + g.bids[partner]!}.'
          : 'Your cards look like about ${c.suggestedBid} tricks.';
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ToonButton(
                key: const Key('bid minus'),
                color: Toon.card,
                padding: const EdgeInsets.all(10),
                repeat: true,
                tooltip: 'Bid fewer',
                onPressed: c.yourBid > 0 ? () => c.setBid(c.yourBid - 1) : null,
                child: const Icon(Icons.remove_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ToonBox(
                  color: Toon.cardFace,
                  shadow: 2,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    c.yourBid == 0 ? 'Nil' : '${c.yourBid}',
                    key: const Key('bid value'),
                    textAlign: TextAlign.center,
                    style: Toon.text(24, weight: FontWeight.w700, color: Toon.inkLight),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ToonButton(
                key: const Key('bid plus'),
                color: Toon.card,
                padding: const EdgeInsets.all(10),
                repeat: true,
                tooltip: 'Bid more',
                onPressed: c.yourBid < 13 ? () => c.setBid(c.yourBid + 1) : null,
                child: const Icon(Icons.add_rounded),
              ),
              const SizedBox(width: 10),
              ToonButton(
                key: const Key('bid'),
                color: Toon.green,
                onPressed: c.bid,
                child: const Text('Bid'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: Toon.text(13, weight: FontWeight.w500, color: Toon.muted),
          ),
        ],
      );
    } else {
      final text = switch (c.stage) {
        SpadesStage.dealing => 'Dealing…',
        SpadesStage.drawing ||
        SpadesStage.bidding ||
        SpadesStage.playing => c.yourPlay ? 'Tap a lifted card to play it' : "${c.name(g.turn)}'s turn",
        SpadesStage.trickDone => '',
        SpadesStage.handOver || SpadesStage.over => '',
      };
      body = SizedBox(
        height: 50,
        child: Center(
          child: Text(text, style: Toon.text(16, color: Toon.muted)),
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

/// Between hands: how each side did, and Next hand.
class _HandResult extends StatelessWidget {
  const _HandResult({required this.c});

  final SpadesController c;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    final scored = g.handEvents.whereType<HandScored>().last;
    String signed(int n) => n >= 0 ? '+$n' : '−${-n}';
    Widget team(TeamResult r) {
      final lines = <String>[
        if (r.bid > 0)
          'Bid ${r.bid}, won ${r.tricks}: ${r.made ? 'made it' : 'missed'} ${signed(r.contractPoints)}',
        for (final (p, made) in r.nils)
          '${c.name(p)} bid Nil: ${made ? 'made it +100' : 'took a trick −100'}',
        if (r.bags > 0) '${r.bags} extra trick${r.bags == 1 ? '' : 's'} (bags) +${r.bags}',
        if (r.bagPenalty < 0) '10 bags piled up ${signed(r.bagPenalty)}',
      ];
      final good = r.total >= 0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ToonBox(
          color: Toon.card,
          shadow: 2,
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(c.teamName(r.team), style: Toon.text(16, weight: FontWeight.w700)),
                  ),
                  Text(
                    signed(r.total),
                    style: Toon.text(16, weight: FontWeight.w700, color: good ? Toon.green : Toon.red),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              for (final l in lines) Text(l, style: Toon.text(13, weight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(
                'Score ${r.score}${_bags(g.bagCount[r.team])}',
                style: Toon.text(14, weight: FontWeight.w700, color: Toon.muted),
              ),
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: Toon.ink.withValues(alpha: 0.5),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Pop(
              child: ToonBox(
                color: Toon.paper,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Hand ${g.handNumber}',
                      textAlign: TextAlign.center,
                      style: Toon.text(24, weight: FontWeight.w700),
                    ),
                    Text(
                      'Playing to ${g.target}',
                      textAlign: TextAlign.center,
                      style: Toon.text(14, weight: FontWeight.w500, color: Toon.muted),
                    ),
                    const SizedBox(height: 12),
                    for (final r in scored.results) team(r),
                    ToonButton(
                      key: const Key('next hand'),
                      color: Toon.green,
                      onPressed: c.nextHand,
                      child: const Text('Next hand'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// " · 1 bag", " · 3 bags", or nothing.
String _bags(int n) => n == 0 ? '' : ' · $n bag${n == 1 ? '' : 's'}';
