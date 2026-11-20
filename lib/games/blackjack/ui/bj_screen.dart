import 'dart:math';

import 'package:duel_engine/blackjack/blackjack.dart';
import 'package:duel_engine/cards.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:flutter/material.dart';

import '../../../core/account/account.dart';
import '../../../core/cards/card_view.dart';
import '../../../core/help/game_guide.dart';
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
    if (_c.midHand) {
      final staked = _c.round!.staked(_c.youSeat);
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Leave mid-hand?'),
          content: Text('Your ${_account.money(staked)} on the table stays there.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave')),
          ],
        ),
      );
      if (ok != true) return;
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
            top: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  ToonButton(
                    key: const Key('leave'),
                    color: Toon.card,
                    padding: const EdgeInsets.all(8),
                    tooltip: 'Leave table',
                    onPressed: _leave,
                    child: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Blackjack', style: Toon.text(18, weight: FontWeight.w700)),
                        Text(
                          '${widget.table.name} · bets ${chips(widget.table.min)}–${chips(widget.table.max)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Toon.text(14, weight: FontWeight.w500, color: Toon.muted),
                        ),
                      ],
                    ),
                  ),
                  GuideButton(title: 'Blackjack', stages: blackjackGuide, current: _stage),
                ],
              ),
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

/// Where the bots sit: around the table's sides, playing in order towards
/// you at the bottom and on round the other side.
List<Offset> _botSpots(int left, int right, {bool wide = false}) {
  // On its side the table is short: seats spread along it instead.
  const w = <int, List<Offset>>{
    0: [],
    1: [Offset(0.12, 0.5)],
    2: [Offset(0.13, 0.36), Offset(0.13, 0.74)],
    3: [Offset(0.13, 0.36), Offset(0.13, 0.74), Offset(0.3, 0.74)],
  };
  final l = wide
      ? w
      : const <int, List<Offset>>{
          0: [],
          1: [Offset(0.16, 0.6)],
          2: [Offset(0.16, 0.42), Offset(0.16, 0.7)],
          3: [Offset(0.15, 0.36), Offset(0.15, 0.6), Offset(0.24, 0.84)],
        };
  final rs = [for (final o in l[right]!.reversed) Offset(1 - o.dx, o.dy)];
  return [...l[left]!, ...rs];
}

class _Table extends StatelessWidget {
  const _Table({required this.c});

  final BjController c;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final size = Size(box.maxWidth, box.maxHeight);
      final wide = GameLayout.wide(context);
      Offset px(Offset f) => Offset(f.dx * size.width, f.dy * size.height);
      final left = c.youSeat, right = c.seats.length - 1 - c.youSeat;
      final spots = _botSpots(left, right, wide: wide);
      final big = min(size.width * 0.15, size.height * (wide ? 0.15 : 0.11)).clamp(40.0, 64.0);
      final small = big * 0.62;
      // Where the cards come from, and your betting circle on the felt.
      final shoe = Offset(size.width - 46, 44);
      final dealerAt = px(Offset(0.5, wide ? 0.2 : 0.15));
      final betSpot = Offset(size.width / 2, size.height - (wide ? 52 : 62));
      final youAt = Offset(size.width / 2, betSpot.dy - 72 - big * 0.7);
      final children = <Widget>[
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: _FeltPainter(bet: betSpot)),
          ),
        ),
        // The shoe.
        Positioned(right: 26, top: 22, child: _ShoeView(c: c)),
        At(
          dealerAt,
          child: _Dealer(c: c, width: big * 0.9, from: shoe - dealerAt + Offset(big * 0.9, 0)),
        ),
      ];
      var b = 0;
      for (var i = 0; i < c.seats.length; i++) {
        if (i == c.youSeat) continue;
        children.add(
          At(
            px(spots[b++]),
            child: _BotSeat(
              c: c,
              seat: i,
              width: small,
              from: shoe - px(spots[b - 1]) + const Offset(40, 40),
            ),
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
      // Speech: the dealer's under the dealer, the bots' beside them.
      final said = c.speech[-1];
      if (said != null) {
        final at = dealerAt;
        children.add(
          Positioned(
            left: 0,
            right: 0,
            top: at.dy + big * 0.9 * 0.7 + 34,
            child: Center(child: SpeechBubble(said, key: ValueKey('say-1-${c.speechId}'))),
          ),
        );
      }
      b = 0;
      for (var i = 0; i < c.seats.length; i++) {
        if (i == c.youSeat) continue;
        final f = spots[b++];
        final line = c.speech[i];
        if (line == null) continue;
        final at = px(f);
        children.add(
          Positioned(
            // Above them (over their cards), clear of yours.
            top: max(4, at.dy - (wide ? 70 : 96)),
            left: f.dx < 0.5 ? max(14, at.dx - 40) : null,
            right: f.dx > 0.5 ? max(14, size.width - at.dx - 40) : null,
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
      return Stack(clipBehavior: Clip.none, children: children);
    },
  );
}

class _ShoeView extends StatelessWidget {
  const _ShoeView({required this.c});

  final BjController c;

  @override
  Widget build(BuildContext context) => Column(
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
      Text('Shoe', style: Toon.text(11, color: Colors.white70)),
    ],
  );
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [FaceRing(BjController.dealer, size: 34), const SizedBox(height: 3), _pill('Dealer')],
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: width * 1.4,
              child: cards.isEmpty
                  ? SizedBox(width: width)
                  : _CardRow(
                      cards: cards,
                      width: width,
                      keyBase: 'd${c.rounds}',
                      from: from,
                      hideSecond: !c.holeUp,
                      dealer: true,
                    ),
            ),
            const SizedBox(height: 3),
            if (shownCards.isNotEmpty)
              _pill(c.totalLabel(shownCards), color: c.holeUp && bjTotal(cards).total > 21 ? Toon.red : null),
          ],
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
    final r = c.round;
    final staked = r == null || c.phase == BjPhase.betting
        ? null
        : (r.hands[seat].isEmpty ? null : r.staked(seat));
    return SizedBox(
      width: 120,
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
                size: 26,
                color: c.phase == BjPhase.playing && c.round?.turn?.$1 == seat ? Toon.orange : null,
              ),
              const SizedBox(width: 3),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.persona.name, maxLines: 1, style: Toon.text(11, color: Colors.white)),
                  Text(
                    chips(s.chips),
                    style: Toon.text(11, weight: FontWeight.w700, color: Toon.yellow),
                  ),
                ],
              ),
            ],
          ),
          if (staked != null)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: ChipPile(amount: staked, perStack: 4),
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

/// The table: a wooden rail, felt with a lamp-lit middle (like poker's),
/// the dealer's arc and your betting circle.
class _FeltPainter extends CustomPainter {
  _FeltPainter({required this.bet});

  final Offset bet;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Rect.fromLTRB(6, 4, size.width - 6, size.height - 6);
    final rail = RRect.fromRectAndRadius(outer, const Radius.circular(40));
    final ink = Paint()
      ..color = Toon.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = Toon.outline;
    canvas.drawRRect(rail.shift(const Offset(0, 5)), Paint()..color = Toon.ink);
    canvas.drawRRect(rail, Paint()..color = Toon.wood);
    canvas.drawRRect(rail, ink);
    final felt = rail.deflate(12);
    canvas.drawRRect(felt, Paint()..color = Toon.felt);
    canvas.drawRRect(felt.deflate(size.shortestSide * 0.06), Paint()..color = const Color(0xFF47B067));
    canvas.drawRRect(felt, ink);
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    // The dealer's arc.
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.02),
        width: size.width * 0.78,
        height: size.height * 0.62,
      ),
      0.35,
      pi - 0.7,
      false,
      line,
    );
    // Your betting circle.
    canvas.drawCircle(bet, 34, Paint()..color = Colors.black.withValues(alpha: 0.08));
    canvas.drawCircle(bet, 34, line..color = Colors.white.withValues(alpha: 0.5));
  }

  @override
  bool shouldRepaint(_FeltPainter old) => old.bet != bet;
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
