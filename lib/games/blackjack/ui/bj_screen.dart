import 'dart:math';

import 'package:duel_engine/blackjack/blackjack.dart';
import 'package:duel_engine/cards.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:flutter/material.dart';

import '../../../core/account/account.dart';
import '../../../core/account/stake.dart';
import '../../../core/cards/card_view.dart';
import '../../../core/help/game_guide.dart';
import '../../../core/table/felts.dart';
import '../../../core/table/table_bits.dart';
import '../../../core/theme/toon.dart';
import '../../poker/ui/chips.dart';
import 'bj_controller.dart';
import 'bj_tables.dart';

const blackjackGuide = [
  GuideStage(
    'bet',
    'Bet',
    'Tap the chips to build your bet (it comes straight off your balance), then Deal. Your last bet stays put for '
        'next time.',
    icon: Icons.toll_rounded,
  ),
  GuideStage(
    'play',
    'Hit or stand',
    'Get closer to 21 than the dealer without going over. Face cards are 10, an Ace 1 or 11 ("soft" while it\'s '
        'counting 11). Hit for a card, Stand to stop.',
    icon: Icons.touch_app_rounded,
  ),
  GuideStage(
    'double',
    'Double and split',
    'On your first two cards: Double puts in the same again for exactly one more card. Two cards of the same '
        'value can Split into two hands, each with its own bet (up to four hands; split Aces get one card each).',
    icon: Icons.call_split_rounded,
  ),
  GuideStage(
    'dealer',
    'The dealer',
    'The dealer has no choices: turns over the hole card, draws to 17 and stands on all 17s. With an Ace or a 10 '
        'showing, the dealer checks for blackjack first.',
    icon: Icons.person_rounded,
  ),
  GuideStage(
    'paid',
    'Getting paid',
    'Beat the dealer: win your bet. Same total: push, bet back. Blackjack (an Ace and a 10 first up) pays 3 to 2. '
        'Bust and you lose straight away, even if the dealer busts later.',
    icon: Icons.payments_rounded,
  ),
];

/// One blackjack table: you, bots and the dealer, as long as you like.
class BjScreen extends StatefulWidget {
  const BjScreen({
    super.key,
    required this.table,
    required this.bots,
    required this.difficulty,
    this.pace = 1,
    this.seed,
  });

  final BjTable table;
  final int bots;
  final Difficulty difficulty;
  final double pace;
  final int? seed;

  @override
  State<BjScreen> createState() => _BjScreenState();
}

class _BjScreenState extends State<BjScreen> {
  late final Account _account = AccountScope.maybeRead(context) ?? Account();
  late final BjController _c = BjController(
    table: widget.table,
    bots: widget.bots,
    difficulty: widget.difficulty,
    account: _account,
    pace: widget.pace,
    rng: widget.seed == null ? null : Random(widget.seed),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String? _stage() => switch (_c.phase) {
    BjPhase.betting => 'bet',
    BjPhase.dealing || BjPhase.playing => _c.moves.contains(BjMove.split) ? 'double' : 'play',
    BjPhase.dealer => 'dealer',
    BjPhase.paid => 'paid',
  };

  Future<void> _leave() async {
    if (_c.midHand &&
        !await askToon(
          context,
          title: 'Leave mid-hand?',
          body: 'Your ${_account.money(_c.round!.staked(_c.youSeat))} on the table stays there.',
        )) {
      return;
    }
    if (mounted) Navigator.of(context).pop();
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
          listenable: Listenable.merge([_c, _account]),
          builder: (context, _) => GameLayout(
            top: GameTopBar(
              title: 'Blackjack',
              subtitle: '${widget.table.name} · bets ${chips(widget.table.min)}–${chips(widget.table.max)}',
              onLeave: _leave,
              guide: blackjackGuide,
              stage: _stage,
            ),
            commentary: CommentaryStrip(
              text: _c.commentary(),
              yourMove: _c.yourTurn || _c.phase == BjPhase.betting,
            ),
            table: _Table(c: _c),
            controls: _Controls(c: _c),
          ),
        ),
      ),
    ),
  );
}

/// Where each of the five seats sits, as fractions of the table (you're
/// seat 2, the bottom middle): bots' cards + faces, and their betting spots.
/// Fixed places, so nothing overlaps however many sit down.
({List<Offset> seats, List<Offset> spots}) _seatPlaces(bool wide) => wide
    ? (
        seats: const [
          Offset(0.12, 0.42),
          Offset(0.27, 0.76),
          Offset.zero,
          Offset(0.73, 0.76),
          Offset(0.88, 0.42),
        ],
        spots: const [
          Offset(0.235, 0.47),
          Offset(0.315, 0.55),
          Offset.zero,
          Offset(0.685, 0.55),
          Offset(0.765, 0.47),
        ],
      )
    : (
        seats: const [
          Offset(0.19, 0.42),
          Offset(0.2, 0.68),
          Offset.zero,
          Offset(0.8, 0.68),
          Offset(0.81, 0.42),
        ],
        spots: const [
          Offset(0.4, 0.43),
          Offset(0.37, 0.575),
          Offset.zero,
          Offset(0.63, 0.575),
          Offset(0.6, 0.43),
        ],
      );

class _Table extends StatelessWidget {
  const _Table({required this.c});

  final BjController c;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final size = Size(box.maxWidth, box.maxHeight);
      final wide = GameLayout.wide(context);
      Offset px(Offset f) => Offset(f.dx * size.width, f.dy * size.height);
      final felt = Felt.forLevel(bjTables.indexOf(c.table).clamp(0, 3), bjTables.length);
      final big = min(size.width * 0.15, size.height * (wide ? 0.16 : 0.1)).clamp(40.0, 62.0);
      final dealerW = big * 1.05;
      final small = big * 0.5;
      final places = _seatPlaces(wide);
      final shoe = Offset(size.width - 46, 44);
      final faceAt = Offset(size.width / 2, 26);
      final dealerAt = Offset(size.width / 2, faceAt.dy + 28 + dealerW * 0.7 + 4);
      final dealerBox = Rect.fromCenter(center: dealerAt, width: dealerW * 2.9, height: dealerW * 1.4 + 12);
      final betSpot = Offset(size.width / 2, size.height - (wide ? 40 : 54));
      final youAt = Offset(size.width / 2, betSpot.dy - 50 - big * 0.7 - 12);
      final yourBox = Rect.fromCenter(
        center: youAt.translate(0, -9),
        width: big * 2.7,
        height: big * 1.4 + 12,
      );
      final seats = [for (final o in places.seats) px(o)];
      final spots = [for (final o in places.spots) px(o)];
      final children = <Widget>[
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _FeltPainter(
                felt: felt,
                dealer: dealerBox,
                you: yourBox,
                bet: betSpot,
                spots: [
                  for (var i = 0; i < spots.length; i++)
                    if (i != c.youSeat) spots[i],
                ],
              ),
            ),
          ),
        ),
        Positioned(right: 26, top: 22, child: _ShoeView(c: c)),
        At(faceAt, child: const _DealerFace()),
        At(
          dealerAt,
          child: _Dealer(c: c, width: dealerW, from: shoe - dealerAt + Offset(dealerW, 0)),
        ),
      ];
      for (var i = 0; i < c.seats.length; i++) {
        if (i == c.youSeat) continue;
        final at = seats[i], spot = spots[i];
        if (c.seats[i].open) continue;
        children.add(
          At(
            at,
            child: _BotSeat(c: c, seat: i, width: small, from: shoe - at),
          ),
        );
        children.add(
          At(
            spot,
            child: _BotBet(c: c, seat: i),
          ),
        );
      }
      children.add(
        At(
          youAt,
          child: _YourCards(c: c, width: big, from: shoe - youAt + Offset(big * 0.5, big * 0.7)),
        ),
      );
      children.add(At(betSpot, child: _YourBet(c: c)));
      // Speech: the dealer's beside the dealer, the bots' above them.
      final said = c.speech[-1];
      if (said != null) {
        children.add(
          Positioned(
            left: size.width / 2 + 60,
            top: 6,
            right: 70,
            child: Align(
              alignment: Alignment.topLeft,
              child: SpeechBubble(said, key: ValueKey('say-1-${c.speechId}')),
            ),
          ),
        );
      }
      for (var i = 0; i < c.seats.length; i++) {
        if (i == c.youSeat) continue;
        final at = seats[i];
        final line = c.speech[i];
        if (line == null) continue;
        final leftSide = at.dx < size.width / 2;
        children.add(
          Positioned(
            top: max(4, at.dy - 70),
            left: leftSide ? max(14, at.dx - 40) : null,
            right: leftSide ? null : max(14, size.width - at.dx - 40),
            child: SpeechBubble(line, key: ValueKey('say$i-${c.speechId}')),
          ),
        );
      }
      // The pop after a round.
      final net = c.lastNet;
      if (c.resultsUp && net != null && c.round!.hands[c.youSeat].isNotEmpty) {
        final bigWin = net >= c.table.min * 4 || c.lastBlackjack && net > 0;
        if (bigWin) {
          children.add(const Positioned.fill(child: IgnorePointer(child: SuitConfetti())));
        }
        children.add(
          Positioned.fill(
            child: IgnorePointer(
              child: _ResultPop(
                key: ValueKey('pop${c.rounds}'),
                text: c.lastBlackjack && net > 0
                    ? 'BLACKJACK! +${c.account.money(net)}'
                    : net > 0
                    ? '+${c.account.money(net)}'
                    : net < 0
                    ? '−${c.account.money(-net)}'
                    : 'Push',
                color: net > 0
                    ? Toon.yellow
                    : net < 0
                    ? Toon.red
                    : Toon.card,
                big: bigWin,
              ),
            ),
          ),
        );
      }
      children.add(At(Offset(size.width - 46, 66), child: _NewShoe(c: c)));
      return GoldCards(
        on: felt.gold,
        child: Stack(clipBehavior: Clip.none, children: children),
      );
    },
  );
}

/// Dot, the dealer, at the head of the table.
class _DealerFace extends StatelessWidget {
  const _DealerFace();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      FaceRing(BjController.dealer, size: 44),
      const SizedBox(width: 6),
      const NamePlate('Dot', line: 'Dealer'),
    ],
  );
}

/// A bot's chips in its betting spot.
class _BotBet extends StatelessWidget {
  const _BotBet({required this.c, required this.seat});

  final BjController c;
  final int seat;

  @override
  Widget build(BuildContext context) {
    final r = c.round;
    final staked = r == null || c.phase == BjPhase.betting || r.hands[seat].isEmpty ? 0 : r.staked(seat);
    return SizedBox(
      width: 40,
      height: 34,
      child: staked == 0
          ? null
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: ChipPile(amount: staked, perStack: 4),
            ),
    );
  }
}

/// The shoe: how many decks, and how far through it the dealer is (the
/// cut card's the line), for counting.
class _ShoeView extends StatelessWidget {
  const _ShoeView({required this.c});

  final BjController c;

  @override
  Widget build(BuildContext context) {
    final left = c.shoe.left / (shoeDecks * 52);
    return Column(
      key: const Key('shoe'),
      children: [
        SizedBox(
          width: 40,
          height: 44,
          child: Stack(
            children: [
              for (var i = 0; i < 4; i++)
                Positioned(
                  left: i * 2.0,
                  top: i * 1.5,
                  child: const CardView(card: null, width: 28, faceUp: false),
                ),
            ],
          ),
        ),
        Text(
          '$shoeDecks decks',
          style: Toon.text(11, weight: FontWeight.w700, color: Colors.white),
        ),
        const SizedBox(height: 2),
        // Cards left in the shoe.
        Container(
          width: 40,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(3),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: left.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(color: Toon.yellow, borderRadius: BorderRadius.circular(3)),
            ),
          ),
        ),
        Text('${c.shoe.decksLeft.toStringAsFixed(1)} left', style: Toon.text(10, color: Colors.white70)),
      ],
    );
  }
}

/// "New shoe" flashes up when the dealer shuffles.
class _NewShoe extends StatelessWidget {
  const _NewShoe({required this.c});

  final BjController c;

  @override
  Widget build(BuildContext context) {
    if (c.shuffles == 0) return const SizedBox();
    return TweenAnimationBuilder<double>(
      key: ValueKey('shoe${c.shuffles}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 3200),
      builder: (context, t, child) {
        final o = t < 0.1 ? t / 0.1 : (t > 0.8 ? (1 - t) / 0.2 : 1.0);
        return Opacity(
          opacity: o.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.8 + 0.2 * Curves.easeOutBack.transform(min(1, t * 6)),
            child: child,
          ),
        );
      },
      child: IgnorePointer(
        child: Container(
          key: const Key('new shoe'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: Toon.box(Toon.yellow, radius: 10, shadow: 2),
          child: Text(
            'New shoe!',
            style: Toon.text(12, weight: FontWeight.w700, color: Toon.on(Toon.yellow)),
          ),
        ),
      ),
    );
  }
}

/// A row of overlapping cards, the newest dealt in.
/// A hand's cards, each dealt from the shoe the way poker deals: spinning
/// across face down, turning over as it lands. The dealer's hole card
/// stays down until it turns.
class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.cards,
    required this.width,
    required this.keyBase,
    required this.from,
    this.hideSecond = false,
    this.dealer = false,
  });

  final List<PlayingCard> cards;
  final double width;
  final String keyBase;

  /// The shoe, from the first card's spot.
  final Offset from;
  final bool hideSecond;
  final bool dealer;

  @override
  Widget build(BuildContext context) {
    final step = width * 0.45;
    return SizedBox(
      width: width + step * max(0, cards.length - 1),
      height: width * 1.4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final (i, card) in cards.indexed)
            Positioned(
              left: i * step,
              child: dealer && i == 1 && !hideSecond
                  ? TurnOver(key: ValueKey('$keyBase-turn-${card.id}'), card: card, width: width)
                  : DealCard(
                      key: ValueKey('$keyBase-$i-${card.id}'),
                      from: from - Offset(i * step, 0),
                      delay: 0,
                      width: width,
                      flip: !(dealer && i == 1),
                      child: CardView(card: card, width: width, faceUp: !(hideSecond && i == 1)),
                    ),
            ),
        ],
      ),
    );
  }
}

Widget _pill(String text, {Color? color, double size = 12}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
  decoration: BoxDecoration(
    color: color ?? Toon.inkLight.withValues(alpha: 0.8),
    borderRadius: BorderRadius.circular(9),
    border: color == null ? null : Border.all(color: Toon.inkLight, width: 1.5),
  ),
  child: Text(
    text,
    style: Toon.text(size, weight: FontWeight.w700, color: color == null ? Colors.white : Toon.on(color)),
  ),
);

class _Dealer extends StatelessWidget {
  const _Dealer({required this.c, required this.width, required this.from});

  final Offset from;

  final BjController c;
  final double width;

  @override
  Widget build(BuildContext context) {
    final cards = c.dealerCards;
    final shownCards = c.holeUp ? cards : cards.take(1).toList();
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: width * 1.4,
          width: width * 2.8,
          child: Center(
            child: cards.isEmpty
                ? null
                : _CardRow(
                    cards: cards,
                    width: width,
                    keyBase: 'd${c.rounds}',
                    from: from,
                    hideSecond: !c.holeUp,
                    dealer: true,
                  ),
          ),
        ),
        if (shownCards.isNotEmpty)
          Positioned(
            bottom: -16,
            child: _pill(
              c.totalLabel(shownCards),
              color: c.holeUp && bjTotal(cards).total > 21 ? Toon.red : null,
              size: 17,
            ),
          ),
      ],
    );
  }
}

/// A hand's result badge.
Widget? _result(BjController c, BjHand h, double size) {
  if (!c.resultsUp || h.result == null) return null;
  final m = c.account.money;
  return switch (h.result!) {
    BjResult.blackjack => _pill('Blackjack +${m(h.net)}', color: Toon.yellow, size: size),
    BjResult.win => _pill('Win +${m(h.net)}', color: Toon.green, size: size),
    BjResult.push => _pill('Push', color: Toon.cardFace, size: size),
    BjResult.lose => _pill('Lose', color: Toon.red, size: size),
    BjResult.bust => _pill('Bust', color: Toon.red, size: size),
  };
}

class _Hands extends StatelessWidget {
  const _Hands({
    required this.c,
    required this.seat,
    required this.width,
    required this.from,
    this.big = false,
  });

  final Offset from;

  /// Yours: bigger totals.
  final bool big;

  final BjController c;
  final int seat;
  final double width;

  @override
  Widget build(BuildContext context) {
    final r = c.round;
    if (r == null || r.hands[seat].isEmpty) return SizedBox(height: width * 1.4 + 18);
    final hands = r.hands[seat];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, h) in hands.indexed)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hands.length > 1 ? 3 : 0),
            child: Builder(
              builder: (context) {
                final cards = i < c.shown[seat].length ? c.cardsShown(seat, i) : <PlayingCard>[];
                final active = c.phase == BjPhase.playing && r.turn == (seat, i);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: active ? Toon.yellow : Colors.transparent, width: 2.5),
                      ),
                      child: SizedBox(
                        height: width * 1.4,
                        child: cards.isEmpty
                            ? SizedBox(width: width)
                            : _CardRow(
                                cards: cards,
                                width: width,
                                keyBase: 's${c.rounds}-$seat-$i',
                                from: from,
                              ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    _result(c, h, big ? 17 : 13) ??
                        (cards.isEmpty
                            ? SizedBox(height: big ? 26 : 20)
                            : _pill(
                                '${c.totalLabel(cards, fromSplit: h.fromSplit)}${h.doubled ? ' ×2' : ''}',
                                color: bjTotal(cards).total > 21 ? Toon.red : null,
                                size: big ? 18 : 14,
                              )),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

class _BotSeat extends StatelessWidget {
  const _BotSeat({required this.c, required this.seat, required this.width, required this.from});

  final Offset from;

  final BjController c;
  final int seat;
  final double width;

  @override
  Widget build(BuildContext context) {
    final s = c.seats[seat];
    return SizedBox(
      width: 100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: _Hands(c: c, seat: seat, width: width, from: from),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaceRing(
                s.persona,
                size: 24,
                color: c.phase == BjPhase.playing && c.round?.turn?.$1 == seat ? Toon.orange : null,
              ),
              const SizedBox(width: 4),
              Flexible(child: NamePlate(s.persona.name, line: chips(s.chips))),
            ],
          ),
        ],
      ),
    );
  }
}

/// Your cards, big, above your betting circle (last round's stay up
/// while you bet).
class _YourCards extends StatelessWidget {
  const _YourCards({required this.c, required this.width, required this.from});

  final BjController c;
  final double width;
  final Offset from;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 60),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: _Hands(c: c, seat: c.youSeat, width: width, from: from, big: true),
    ),
  );
}

/// Your chips in the betting circle painted on the felt.
class _YourBet extends StatelessWidget {
  const _YourBet({required this.c});

  final BjController c;

  @override
  Widget build(BuildContext context) {
    final r = c.round;
    final betting = c.phase == BjPhase.betting;
    final amount = betting ? c.bet : (r?.staked(c.youSeat) ?? 0);
    return SizedBox(
      key: const Key('your bet'),
      width: 120,
      height: 56,
      child: Center(
        child: amount > 0
            ? ChipPile(amount: amount, stacks: 3, perStack: 5)
            : Text(
                'BET',
                style: Toon.text(14, weight: FontWeight.w700, color: Colors.white70),
              ),
      ),
    );
  }
}

/// The table, shaped like a real one: a straight edge for the dealer and
/// a gentle curve round the players. Printed on the felt: the dealer's
/// card box, a band of suits under it, a betting spot per seat, your card
/// box and betting circle. No rules are printed.
class _FeltPainter extends CustomPainter {
  _FeltPainter({
    required this.felt,
    required this.dealer,
    required this.you,
    required this.bet,
    required this.spots,
  });

  final Felt felt;
  final Rect dealer, you;
  final Offset bet;
  final List<Offset> spots;

  static RRect _shape(Rect r) {
    final ry = min(r.width * 0.42, r.height * 0.42);
    return RRect.fromRectAndCorners(
      r,
      topLeft: const Radius.circular(26),
      topRight: const Radius.circular(26),
      bottomLeft: Radius.elliptical(r.width / 2, ry),
      bottomRight: Radius.elliptical(r.width / 2, ry),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final k = felt;
    final ink = Paint()
      ..color = Toon.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = Toon.outline;
    final outer = Rect.fromLTRB(6, 4, size.width - 6, size.height - 6);
    final rail = _shape(outer);
    canvas.drawRRect(rail.shift(const Offset(0, 5)), Paint()..color = Toon.ink);
    canvas.drawRRect(rail, Paint()..color = k.rail);
    canvas.drawRRect(
      _shape(outer.deflate(4)),
      Paint()
        ..color = (k.gold ? k.line : Colors.white).withValues(alpha: k.gold ? 0.5 : 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = k.gold ? 1.5 : 3,
    );
    canvas.drawRRect(rail, ink);
    final feltRect = outer.deflate(13);
    final top = _shape(feltRect);
    canvas.save();
    canvas.clipRRect(top);
    canvas.drawRRect(top, Paint()..color = k.felt);
    // Lamp light over the middle, brightest at the dealer.
    canvas.drawRRect(
      top,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.35),
          radius: 0.85,
          colors: [k.lit, k.lit.withValues(alpha: 0)],
        ).createShader(feltRect),
    );
    final line = Paint()
      ..color = k.line.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final faint = Paint()
      ..color = k.line.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    // The band under the dealer: two lines with suits between, curving
    // down between the dealer's box and yours, clear of the seats.
    final spanX = min(size.width * 0.42, dealer.width / 2 + 110);
    final low = dealer.bottom + max(30.0, (you.top - dealer.bottom) * 0.32);
    final band = Rect.fromLTRB(
      size.width / 2 - spanX,
      2 * dealer.center.dy - low,
      size.width / 2 + spanX,
      low,
    );
    final band2 = band.deflate(13);
    const from = 0.22, sweep = pi - 0.44;
    canvas.drawArc(band, from, sweep, false, line);
    canvas.drawArc(band2, from, sweep, false, line);
    final mid = band.deflate(6.5);
    const n = 13;
    for (var i = 0; i < n; i++) {
      final a = from + sweep * (i + 0.5) / n;
      final p = Offset(mid.center.dx + cos(a) * mid.width / 2, mid.center.dy + sin(a) * mid.height / 2);
      const s = 7.5;
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(a - pi / 2);
      canvas.drawPath(
        suitPath(Suit.values[i % 4], s).shift(const Offset(-s / 2, -s / 2)),
        Paint()..color = k.line.withValues(alpha: 0.55),
      );
      canvas.restore();
    }
    // The dealer's card box: corners only, like a frame, a diamond each side.
    _corners(canvas, dealer, line, 12);
    for (final dx in [-1, 1]) {
      final c = Offset(dealer.center.dx + dx * (dealer.width / 2 + 14), dealer.center.dy);
      canvas.drawPath(_diamond(c, 6), Paint()..color = k.line.withValues(alpha: 0.5));
    }
    // The bots' betting spots.
    for (final p in spots) {
      canvas.drawCircle(p, 19, Paint()..color = Colors.black.withValues(alpha: 0.1));
      canvas.drawCircle(p, 19, line);
      canvas.drawCircle(p, 15, faint);
    }
    // Your card box and betting circle.
    _corners(canvas, you, line, 12);
    canvas.drawCircle(bet, 34, Paint()..color = Colors.black.withValues(alpha: 0.1));
    canvas.drawCircle(bet, 34, line..strokeWidth = 2.2);
    canvas.drawCircle(bet, 28, faint);
    for (final a in [0.0, pi / 2, pi, pi * 1.5]) {
      canvas.drawPath(
        _diamond(bet + Offset(cos(a), sin(a)) * 34, 4),
        Paint()..color = k.line.withValues(alpha: 0.75),
      );
    }
    canvas.restore();
    canvas.drawRRect(top, ink);
  }

  static Path _diamond(Offset c, double r) => Path()
    ..moveTo(c.dx, c.dy - r)
    ..lineTo(c.dx + r * 0.7, c.dy)
    ..lineTo(c.dx, c.dy + r)
    ..lineTo(c.dx - r * 0.7, c.dy)
    ..close();

  static void _corners(Canvas canvas, Rect r, Paint p, double len) {
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(8));
    canvas.drawRRect(rr, Paint()..color = Colors.black.withValues(alpha: 0.07));
    final path = Path();
    for (final (x, y, sx, sy) in [
      (r.left, r.top, 1.0, 1.0),
      (r.right, r.top, -1.0, 1.0),
      (r.left, r.bottom, 1.0, -1.0),
      (r.right, r.bottom, -1.0, -1.0),
    ]) {
      path
        ..moveTo(x, y + sy * len)
        ..lineTo(x, y + sy * 6)
        ..quadraticBezierTo(x, y, x + sx * 6, y)
        ..lineTo(x + sx * len, y);
    }
    canvas.drawPath(path, p..strokeWidth = 2.2);
  }

  @override
  bool shouldRepaint(_FeltPainter old) =>
      old.felt != felt ||
      old.dealer != dealer ||
      old.you != you ||
      old.bet != bet ||
      old.spots.length != spots.length;
}

class _Controls extends StatelessWidget {
  const _Controls({required this.c});

  final BjController c;

  @override
  Widget build(BuildContext context) {
    final m = c.account.money;
    Widget body;
    if (c.phase == BjPhase.betting) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final v in c.table.chips)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ToonButton(
                      key: Key('chip $v'),
                      color: Toon.card,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      onPressed: c.bet + v <= c.maxBet ? () => c.addChip(v) : null,
                      child: Text('+${chips(v)}', style: Toon.text(15, weight: FontWeight.w700)),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ToonButton(
                    key: const Key('max bet'),
                    color: Toon.card,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    onPressed: c.bet < c.maxBet ? c.maxOut : null,
                    child: Text('Max', style: Toon.text(15, weight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ToonButton(
                  key: const Key('clear bet'),
                  color: Toon.card,
                  onPressed: c.bet > 0 ? c.clearBet : null,
                  child: const FittedBox(child: Text('Clear', maxLines: 1)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ToonButton(
                  key: const Key('deal'),
                  color: Toon.green,
                  onPressed: c.canDeal ? c.deal : null,
                  child: FittedBox(child: Text(c.bet > 0 ? 'Deal · ${m(c.bet)}' : 'Deal', maxLines: 1)),
                ),
              ),
            ],
          ),
        ],
      );
    } else if (c.yourTurn) {
      final moves = c.moves;
      Widget move(BjMove mv, String label, Color color) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: ToonButton(
            key: Key(mv.name),
            color: color,
            padding: const EdgeInsets.symmetric(vertical: 12),
            onPressed: moves.contains(mv) ? () => c.act(mv) : null,
            child: FittedBox(child: Text(label, maxLines: 1)),
          ),
        ),
      );
      body = Row(
        children: [
          move(BjMove.hit, 'Hit', Toon.green),
          move(BjMove.stand, 'Stand', Toon.red),
          if (moves.contains(BjMove.double)) move(BjMove.double, 'Double', Toon.yellow),
          if (moves.contains(BjMove.split)) move(BjMove.split, 'Split', Toon.blue),
        ],
      );
    } else {
      body = SizedBox(
        height: 48,
        child: Center(
          child: Text(switch (c.phase) {
            BjPhase.dealing => 'Dealing…',
            BjPhase.dealer => 'Dealer\'s turn…',
            BjPhase.paid => 'Next hand coming up…',
            _ => 'Waiting…',
          }, style: Toon.text(16, color: Toon.muted)),
        ),
      );
    }
    // One height whatever's showing, so the table never changes size.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: SizedBox(
        height: 108,
        child: Align(alignment: Alignment.bottomCenter, child: body),
      ),
    );
  }
}

class _ResultPop extends StatelessWidget {
  const _ResultPop({super.key, required this.text, required this.color, required this.big});

  final String text;
  final Color color;
  final bool big;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 1800),
    builder: (context, t, _) {
      if (t >= 1) return const SizedBox.shrink();
      final grow = Curves.elasticOut.transform((t / 0.4).clamp(0, 1));
      return Align(
        alignment: const Alignment(0, 0.05),
        child: Opacity(
          opacity: t < 0.8 ? 1 : (1 - t) / 0.2,
          child: Transform.scale(
            scale: (0.4 + 0.6 * grow) * (big ? 1.3 : 1),
            child: ToonBox(
              color: color,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                text,
                style: Toon.text(22, weight: FontWeight.w700, color: Toon.on(color)),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Pick a table: the limits, open once your balance covers the max bet.
class BjLobby extends StatelessWidget {
  const BjLobby({super.key, required this.bots, required this.difficulty, this.pace = 1, this.seed});

  final int bots;
  final Difficulty difficulty;
  final double pace;
  final int? seed;

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    final m = account.money;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                ToonButton(
                  color: Toon.card,
                  padding: const EdgeInsets.all(8),
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Blackjack tables', style: Toon.text(24, weight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Bets come straight off your balance (${m(account.balance)}). Stay as long as you like; '
              '$bots ${bots == 1 ? 'bot sits' : 'bots sit'} with you.',
              style: Toon.text(15, weight: FontWeight.w500, color: Toon.muted),
            ),
            const SizedBox(height: 14),
            for (final t in bjTables) ...[
              ToonBox(
                color: Toon.card,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.casino_rounded, color: t.openFor(account.balance) ? Toon.green : Toon.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.name, style: Toon.text(18, weight: FontWeight.w700)),
                          Text(
                            'Bets ${m(t.min)}–${m(t.max)}',
                            style: Toon.text(14, weight: FontWeight.w500, color: Toon.muted),
                          ),
                        ],
                      ),
                    ),
                    if (t.openFor(account.balance))
                      ToonButton(
                        key: Key('sit ${t.min}'),
                        color: Toon.green,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BjScreen(
                              table: t,
                              bots: bots,
                              difficulty: difficulty,
                              pace: pace,
                              seed: seed,
                            ),
                          ),
                        ),
                        child: const Text('Sit'),
                      )
                    else
                      Text(
                        'Opens at\n${m(t.unlock)}',
                        key: Key('locked ${t.min}'),
                        textAlign: TextAlign.right,
                        style: Toon.text(13, weight: FontWeight.w600, color: Toon.muted),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}
