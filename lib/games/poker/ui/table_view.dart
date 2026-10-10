import 'package:flutter/material.dart';

import '../../../core/cards/card_view.dart';
import '../../../core/cards/cards.dart';
import '../../../core/theme/toon.dart';
import '../engine/poker_hand.dart';
import '../../../core/avatars/faces.dart';
import 'hand_chart.dart';
import 'shuffle_deck.dart';
import 'poker_controller.dart';

/// Where each seat sits, as fractions of the table area, clockwise from you
/// at the bottom (action passes to your left, up the left side).
const _spots = <int, List<Offset>>{
  2: [Offset(0.5, 0.85), Offset(0.5, 0.13)],
  3: [Offset(0.5, 0.85), Offset(0.18, 0.2), Offset(0.82, 0.2)],
  4: [Offset(0.5, 0.85), Offset(0.14, 0.29), Offset(0.5, 0.13), Offset(0.86, 0.29)],
  5: [Offset(0.5, 0.85), Offset(0.14, 0.65), Offset(0.22, 0.17), Offset(0.78, 0.17), Offset(0.86, 0.65)],
  6: [
    Offset(0.5, 0.85), Offset(0.14, 0.65), Offset(0.14, 0.29), //
    Offset(0.5, 0.13), Offset(0.86, 0.29), Offset(0.86, 0.65),
  ],
};

const _center = Offset(0.5, 0.47);
const _potSpot = Offset(0.5, 0.34);

/// The table: felt, seats, board, bets and pot.
class TableView extends StatelessWidget {
  const TableView({super.key, required this.c});

  final PokerController c;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        final seats = c.personas.length;
        final spots = _spots[seats]!;
        Offset px(Offset f) => Offset(f.dx * size.width, f.dy * size.height);
        Offset betSpot(int seat) => Offset.lerp(spots[seat], _center, seat == 0 ? 0.36 : 0.42)!;

        final h = c.hand;
        final boardCard = (size.width * 0.12).clamp(36.0, 56.0);
        final children = <Widget>[Positioned.fill(child: CustomPaint(painter: _FeltPainter()))];

        // Your deal: the deck to shuffle.
        if (c.phase == TablePhase.shuffle) {
          children.add(
            _At(
              px(_center),
              child: ShuffleDeck(shuffles: c.shuffles, onShuffle: c.shuffleDeck, cardWidth: boardCard),
            ),
          );
        }

        // Board and pot.
        if (h != null) {
          final winning = c.phase == TablePhase.payout ? c.winningCards() : const <PlayingCard>{};
          children.add(
            _At(
              px(_center),
              child: _Board(cards: h.board, hand: c.handNumber, winning: winning, width: boardCard),
            ),
          );
          final pot = h.collectedPot;
          if (pot > 0 && c.phase != TablePhase.payout) {
            children.add(
              _At(
                px(_potSpot),
                child: _ChipPile(amount: pot, label: 'Pot '),
              ),
            );
          }
        }

        // Seats.
        for (var s = 0; s < seats; s++) {
          children.add(
            _At(
              px(spots[s]),
              child: s == 0 ? _YourSeat(c: c) : _BotSeat(c: c, seat: s, cardsAbove: _cardsAbove(spots[s])),
            ),
          );
        }

        if (h != null) {
          // Bets in front of the players; collected into the pot.
          for (var s = 0; s < seats; s++) {
            final p = c.handPlayer(s);
            if (p == null || p.bet == 0 || c.phase == TablePhase.payout) continue;
            final from = px(betSpot(s));
            if (c.phase == TablePhase.collecting) {
              children.add(
                _Fly(
                  key: ValueKey('collect${c.handNumber}-${h.street}-$s'),
                  from: from,
                  to: px(_potSpot),
                  amount: p.bet,
                ),
              );
            } else {
              children.add(_At(from, child: _ChipPile(amount: p.bet)));
            }
          }
          // Pots flying to their winners.
          final r = h.result;
          if (r != null && c.phase == TablePhase.payout) {
            for (final (k, pot) in r.pots.indexed) {
              final share = pot.amount ~/ pot.winners.length;
              for (final w in pot.winners) {
                final seat = c.game.handSeats[w];
                children.add(
                  _Fly(
                    key: ValueKey('pay${c.handNumber}-$k-$w'),
                    from: px(_potSpot),
                    to: px(Offset.lerp(spots[seat], _center, 0.2)!),
                    amount: share,
                  ),
                );
              }
            }
            // Just under the board, narrow enough to clear the side seats.
            final lines = c.resultLines();
            if (lines.isNotEmpty) {
              children.add(
                Positioned(
                  left: 0,
                  right: 0,
                  top: px(_center).dy + boardCard * 0.7 + 12,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: size.width * 0.5),
                      child: _ResultNote(lines: lines),
                    ),
                  ),
                ),
              );
            }
          }
        }

        // "Blinds up!" notice.
        children.add(
          Positioned(
            left: 0,
            right: 0,
            top: size.height * 0.22,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: c.banner == null || c.phase != TablePhase.dealing
                    ? const SizedBox.shrink()
                    : ToonBox(
                        key: ValueKey(c.banner),
                        color: Toon.yellow,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Text(c.banner!, style: Toon.text(17, weight: FontWeight.w700)),
                      ),
              ),
            ),
          ),
        );

        return Stack(clipBehavior: Clip.none, children: children);
      },
    );
  }
}

/// Side seats in the upper half show turned-up cards above the avatar;
/// the rest below the name plate. Either way clear of the board.
bool _cardsAbove(Offset spot) => spot.dy > 0.2 && spot.dy < 0.5;

/// Centres [child] on [at].
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

/// Chips sliding from [from] to [to] (into the pot, or to a winner).
class _Fly extends StatelessWidget {
  const _Fly({super.key, required this.from, required this.to, required this.amount});

  final Offset from;
  final Offset to;
  final int amount;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<Offset>(
    tween: Tween(begin: from, end: to),
    duration: const Duration(milliseconds: 450),
    curve: Curves.easeInOutCubic,
    builder: (context, at, child) => _At(at, child: child!),
    child: _ChipPile(amount: amount),
  );
}

class _FeltPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final felt = Rect.fromLTRB(size.width * 0.08, size.height * 0.07, size.width * 0.92, size.height * 0.86);
    final r = Radius.circular(felt.width / 2);
    final rail = RRect.fromRectAndRadius(felt.inflate(12), Radius.circular(felt.width / 2 + 12));
    final ink = Paint()
      ..color = Toon.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = Toon.outline;
    canvas.drawRRect(rail.shift(const Offset(0, 6)), Paint()..color = Toon.ink);
    canvas.drawRRect(rail, Paint()..color = Toon.wood);
    canvas.drawRRect(rail, ink);
    final inner = RRect.fromRectAndRadius(felt, r);
    canvas.drawRRect(inner, Paint()..color = Toon.felt);
    // A lighter centre, like a lamp over the table.
    canvas.drawRRect(inner.deflate(felt.width * 0.08), Paint()..color = const Color(0xFF47B067));
    canvas.drawRRect(inner, ink);
    // Betting line.
    canvas.drawRRect(
      inner.deflate(felt.width * 0.16),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_FeltPainter old) => false;
}

class _Board extends StatelessWidget {
  const _Board({required this.cards, required this.hand, required this.winning, required this.width});

  final List<PlayingCard> cards;
  final int hand;
  final Set<PlayingCard> winning;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width * 5 + 6 * 4,
      height: width * 1.4,
      child: Row(
        children: [
          for (var i = 0; i < 5; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            i < cards.length
                ? _FlipIn(
                    key: ValueKey('board$hand-$i'),
                    delay: i < 3 ? i * 90 : 0,
                    child: CardView(
                      card: cards[i],
                      width: width,
                      glow: winning.contains(cards[i]),
                      dim: winning.isNotEmpty && !winning.contains(cards[i]),
                    ),
                  )
                : Container(
                    width: width,
                    height: width * 1.4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(width * 0.14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 2),
                    ),
                  ),
          ],
        ],
      ),
    );
  }
}

/// Turns a card over as it lands (horizontal squash and stretch).
class _FlipIn extends StatelessWidget {
  const _FlipIn({super.key, required this.child, this.delay = 0});

  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) {
    final total = 320 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutBack),
      builder: (context, t, child) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(t.clamp(0.0, 1.2), 1, 1),
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
      child: child,
    );
  }
}

/// Cards sliding in from the middle of the table when dealt.
class _DealIn extends StatelessWidget {
  const _DealIn({super.key, required this.child, required this.from, this.delay = 0});

  final Widget child;
  final Offset from;
  final int delay;

  @override
  Widget build(BuildContext context) {
    final total = 380 + delay;
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

/// A little stack of chips with the amount.
class _ChipPile extends StatelessWidget {
  const _ChipPile({required this.amount, this.label = ''});

  final int amount;
  final String label;

  static const _colors = [Toon.red, Toon.blue, Toon.inkLight, Toon.green];

  @override
  Widget build(BuildContext context) {
    final count = amount >= 1000 ? 3 : (amount >= 100 ? 2 : 1);
    final color = _colors[(amount.bitLength) % _colors.length];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 14 + count * 4.0,
          child: Stack(
            children: [
              for (var i = 0; i < count; i++)
                Positioned(
                  left: 0,
                  bottom: i * 4.0,
                  child: Container(
                    width: 20,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.all(Radius.elliptical(10, 6)),
                      border: Border.all(color: Toon.ink, width: 2),
                    ),
                    child: Center(
                      child: Container(
                        width: 8,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: Toon.ink.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$label${chips(amount)}', style: Toon.text(13, color: Colors.white)),
        ),
      ],
    );
  }
}

class _ResultNote extends StatelessWidget {
  const _ResultNote({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.6, end: 1),
    duration: const Duration(milliseconds: 350),
    curve: Curves.easeOutBack,
    builder: (context, s, child) => Transform.scale(scale: s, child: child),
    child: ToonBox(
      color: Toon.paper,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [for (final l in lines) Text(l, textAlign: TextAlign.center, style: Toon.text(14))],
      ),
    ),
  );
}

/// The speech bubble for a player's last action.
class _ActionBubble extends StatelessWidget {
  const _ActionBubble(this.action);

  final LastAction action;

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (action.label) {
      ActionLabel.smallBlind => ('SB', Toon.paper),
      ActionLabel.bigBlind => ('BB', Toon.paper),
      ActionLabel.fold => ('Fold', Toon.grey),
      ActionLabel.check => ('Check', Toon.blue),
      ActionLabel.call => ('Call', Toon.green),
      ActionLabel.bet => ('Bet', Toon.orange),
      ActionLabel.raise => ('Raise', Toon.orange),
      ActionLabel.allIn => ('All-in!', Toon.red),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
      child: Container(
        key: ValueKey('$text${action.amount}'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: Toon.box(color, radius: 10, shadow: 2),
        child: Text(text, style: Toon.text(12, weight: FontWeight.w700)),
      ),
    );
  }
}

class _DealerButton extends StatelessWidget {
  const _DealerButton();

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    decoration: Toon.box(Colors.white, radius: 11, shadow: 2),
    alignment: Alignment.center,
    child: Text('D', style: Toon.text(12, weight: FontWeight.w700)),
  );
}

/// Avatar in a ring: yellow and pulsing while it's their turn.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.persona, required this.size, required this.acting, required this.winner});

  final Persona persona;
  final double size;
  final bool acting;
  final bool winner;

  @override
  Widget build(BuildContext context) {
    final ring = acting ? Toon.yellow : (winner ? Toon.green : Toon.card);
    final avatar = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ring,
        shape: BoxShape.circle,
        border: Border.all(color: Toon.ink, width: Toon.outline),
        boxShadow: [BoxShadow(color: Toon.ink, offset: const Offset(0, 3))],
      ),
      child: Face(persona, size: size - 11),
    );
    return acting ? _Pulse(child: avatar) : avatar;
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: Tween(begin: 1.0, end: 1.08).animate(CurvedAnimation(parent: _a, curve: Curves.easeInOut)),
    child: widget.child,
  );
}

class _NamePlate extends StatelessWidget {
  const _NamePlate({required this.name, required this.stack, this.note});

  final String name;
  final int stack;
  final String? note;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: Toon.box(Toon.card, radius: 10, shadow: 2),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name, style: Toon.text(12), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(
          note ?? chips(stack),
          style: Toon.text(13, weight: FontWeight.w700, color: note == null ? Toon.ink : Toon.muted),
        ),
      ],
    ),
  );
}

String _ordinal(int n) => switch (n) {
  1 => '1st',
  2 => '2nd',
  3 => '3rd',
  _ => '${n}th',
};

class _BotSeat extends StatelessWidget {
  const _BotSeat({required this.c, required this.seat, required this.cardsAbove});

  final PokerController c;
  final int seat;
  final bool cardsAbove;

  @override
  Widget build(BuildContext context) {
    final persona = c.personas[seat];
    final p = c.handPlayer(seat);
    final table = c.game.players[seat];
    final out = p == null && table.stack == 0;
    final folded = p?.folded ?? false;
    final r = c.hand?.result;
    final i = c.handIndex(seat);
    final winner = c.phase == TablePhase.payout && r != null && i != null && (r.winnings[i] ?? 0) > 0;
    final showCards = p != null && !folded && p.hole.length == 2;
    final faceUp = c.revealed.contains(seat);
    final winning = c.phase == TablePhase.payout ? c.winningCards() : const <PlayingCard>{};

    return SizedBox(
      width: 92,
      height: 118,
      child: Opacity(
        opacity: out ? 0.4 : (folded ? 0.55 : 1),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: 14,
              child: _Avatar(persona: persona, size: 54, acting: c.actingSeat == seat, winner: winner),
            ),
            // Face down: tucked beside the avatar. Turned up: above or
            // below, clear of the board.
            if (showCards)
              Positioned(
                top: faceUp ? (cardsAbove ? -40 : 112) : 26,
                left: faceUp ? 10 : 60,
                child: _DealIn(
                  key: ValueKey('deal${c.handNumber}-$seat'),
                  from: const Offset(0, 30),
                  delay: seat * 60,
                  child: _HoleCards(cards: p.hole, faceUp: faceUp, width: faceUp ? 34 : 22, winning: winning),
                ),
              ),
            Positioned(
              top: 70,
              child: _NamePlate(
                name: persona.name,
                stack: p?.stack ?? table.stack,
                note: out ? 'Out · ${_ordinal(table.place ?? 0)}' : null,
              ),
            ),
            if (p?.lastAction != null && c.phase != TablePhase.payout)
              Positioned(top: -6, child: _ActionBubble(p!.lastAction!)),
            if (p != null && c.hand!.players[c.hand!.button] == p)
              const Positioned(top: 10, left: 2, child: _DealerButton()),
          ],
        ),
      ),
    );
  }
}

class _HoleCards extends StatelessWidget {
  const _HoleCards({required this.cards, required this.faceUp, required this.width, required this.winning});

  final List<PlayingCard> cards;
  final bool faceUp;
  final double width;
  final Set<PlayingCard> winning;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width * (faceUp ? 2.05 : 1.45),
    height: width * 1.4 + 4,
    child: Stack(
      children: [
        for (var k = 0; k < 2; k++)
          Positioned(
            left: k * width * (faceUp ? 1.05 : 0.45),
            top: faceUp ? 0 : k * 3.0,
            child: Transform.rotate(
              angle: faceUp ? 0 : (k == 0 ? -0.12 : 0.1),
              child: CardView(
                card: cards[k],
                width: width,
                faceUp: faceUp,
                glow: winning.contains(cards[k]),
                dim: winning.isNotEmpty && !winning.contains(cards[k]),
              ),
            ),
          ),
      ],
    ),
  );
}

/// You, at the bottom: avatar, stack, and your two cards big.
class _YourSeat extends StatelessWidget {
  const _YourSeat({required this.c});

  final PokerController c;

  @override
  Widget build(BuildContext context) {
    final p = c.handPlayer(0);
    final table = c.game.players[0];
    final folded = p?.folded ?? false;
    final r = c.hand?.result;
    final winner = c.phase == TablePhase.payout && r != null && (r.winnings[c.handIndex(0) ?? -1] ?? 0) > 0;
    final winning = c.phase == TablePhase.payout ? c.winningCards() : const <PlayingCard>{};
    final name = folded ? null : c.yourHandName();

    return SizedBox(
      width: 236,
      height: 136,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 16,
            child: Column(
              children: [
                _Avatar(persona: c.personas[0], size: 54, acting: c.yourTurn, winner: winner),
                const SizedBox(height: 4),
                _NamePlate(name: c.personas[0].name, stack: p?.stack ?? table.stack),
              ],
            ),
          ),
          if (c.phase == TablePhase.shuffle || (p != null && c.hand!.players[c.hand!.button] == p))
            const Positioned(left: 50, top: 12, child: _DealerButton()),
          if (p?.lastAction != null && c.phase != TablePhase.payout)
            Positioned(left: 4, top: -8, child: _ActionBubble(p!.lastAction!)),
          if (p != null && p.hole.length == 2)
            Positioned(
              left: 84,
              top: 4,
              child: Opacity(
                opacity: folded ? 0.45 : 1,
                child: _DealIn(
                  key: ValueKey('deal${c.handNumber}-0'),
                  from: const Offset(0, -60),
                  child: Row(
                    children: [
                      for (var k = 0; k < 2; k++)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Transform.rotate(
                            angle: k == 0 ? -0.05 : 0.05,
                            child: CardView(
                              card: p.hole[k],
                              width: 64,
                              glow: winning.contains(p.hole[k]),
                              dim: winning.isNotEmpty && !winning.contains(p.hole[k]),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          // Your hand's name: tap for the cheat sheet, your hand outlined.
          if (name != null)
            Positioned(
              left: 66,
              right: -30,
              top: 94,
              child: Center(
                child: ToonButton(
                  key: const Key('hand chart'),
                  color: Toon.yellow,
                  radius: 12,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  tooltip: 'Poker hands',
                  onPressed: () {
                    final yours = c.yourHand();
                    showHandChart(
                      context,
                      category: yours?.category,
                      royal: yours?.royal ?? false,
                      cards: yours?.cards ?? const [],
                      name: name,
                    );
                  },
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.format_list_numbered_rounded, size: 20),
                        const SizedBox(width: 6),
                        Text(name, maxLines: 1, style: Toon.text(16, weight: FontWeight.w700)),
                      ],
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
