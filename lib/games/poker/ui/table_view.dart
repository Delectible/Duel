import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/cards/card_view.dart';
import 'package:duel_engine/cards.dart';
import '../../../core/table/table_bits.dart';
import '../../../core/theme/toon.dart';
import 'package:duel_engine/poker/poker_hand.dart';
import '../../../core/account/account.dart';
import '../../../core/avatars/faces.dart';
import 'hand_chart.dart';
import 'shuffle_deck.dart';
import 'chips.dart';
import 'poker_controller.dart';
import 'table_stats.dart';

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
        // On a phone on its side the table is short: smaller board cards a
        // little higher up, and bots show their cards beside them.
        final wide = GameLayout.wide(context);
        final center = wide ? const Offset(0.5, 0.43) : _center;
        // In front of each player: further in for side seats, whose name
        // plates stick out towards the middle.
        Offset betSpot(int seat) {
          final side = (spots[seat].dx - 0.5).abs() > 0.2;
          return Offset.lerp(spots[seat], center, seat == 0 ? 0.36 : (side ? 0.52 : 0.42))!;
        }

        final h = c.hand;
        final boardCard = min(size.width * 0.12, wide ? size.height * 0.13 : 56.0).clamp(36.0, 56.0);
        final potAt = wide ? px(center) - Offset(0, boardCard * 0.7 + 16) : px(_potSpot);
        final children = <Widget>[Positioned.fill(child: CustomPaint(painter: _FeltPainter()))];

        // Your deal: the deck to shuffle.
        if (c.phase == TablePhase.shuffle) {
          children.add(
            _At(
              key: const ValueKey('shuffle deck'),
              px(wide ? const Offset(0.5, 0.56) : center),
              child: ShuffleDeck(shuffles: c.shuffles, onShuffle: c.shuffleDeck, cardWidth: boardCard),
            ),
          );
        }

        // Board and pot.
        if (h != null) {
          final winning = c.phase == TablePhase.payout ? c.winningCards() : const <PlayingCard>{};
          children.add(
            _At(
              key: const ValueKey('board'),
              px(center),
              child: _Board(cards: h.board, hand: c.handNumber, winning: winning, width: boardCard),
            ),
          );
          final pot = h.collectedPot;
          if (pot > 0 && c.phase != TablePhase.payout) {
            children.add(
              _At(
                key: const ValueKey('pot'),
                potAt,
                child: ChipPile(amount: pot, label: 'Pot ', stacks: 3, perStack: 5),
              ),
            );
          }
        }

        // The deal: from the dealer, one card at a time round the table
        // (starting on the dealer's left), twice.
        _Deal? dealFor(int s) {
          final i = c.handIndex(s);
          if (h == null || i == null) return null;
          final n = h.players.length;
          final dealer = px(Offset.lerp(spots[c.game.handSeats[h.button]], center, 0.35)!);
          final order = (i - h.button - 1) % n;
          // Where this seat's (first) card lands, from the seat's centre.
          final card = s == 0 ? const Offset(-2, -19) : const Offset(30, -17);
          return _Deal(
            from: dealer - (px(spots[s]) + card),
            delays: [for (var k = 0; k < 2; k++) (k * n + order) * PokerController.dealGap],
            hand: c.handNumber,
          );
        }

        // Seats.
        for (var s = 0; s < seats; s++) {
          children.add(
            _At(
              // Keyed: things before the seats (the pot, banners) come and
              // go, and the seats must keep their animations' state.
              key: ValueKey('seat $s'),
              px(spots[s]),
              child: s == 0
                  ? _YourSeat(c: c, deal: dealFor(0))
                  : _BotSeat(
                      c: c,
                      seat: s,
                      deal: dealFor(s),
                      // Folded cards slide off to the middle.
                      muck: px(center) - (px(spots[s]) + const Offset(30, -17)),
                      // On its side the table is short: seats along the top
                      // and up the sides show them beside (towards the
                      // middle), on screen and clear of the board.
                      cards: wide && spots[s].dy < 0.5
                          ? (spots[s].dx > 0.5 ? _CardsAt.left : _CardsAt.right)
                          : (_cardsAbove(spots[s]) ? _CardsAt.above : _CardsAt.below),
                    ),
            ),
          );
        }

        // Table talk, on its own layer (never faded with a folded seat):
        // beside the avatar along the top, above it down the sides,
        // leaning inwards so it stays on screen.
        for (final MapEntry(key: s, value: said) in c.talk.entries) {
          final spot = spots[s];
          final at = px(spot);
          final top = spot.dy <= 0.2;
          final lean = spot.dx < 0.35 ? 0.0 : (spot.dx > 0.65 ? -1.0 : -0.5);
          children.add(
            Positioned(
              left: top ? at.dx + 36 : at.dx + (lean == 0 ? -40 : (lean < -0.9 ? 40 : 0)),
              top: top ? at.dy - 46 : at.dy - 78,
              child: FractionalTranslation(
                translation: Offset(top ? 0 : lean, 0),
                child: IgnorePointer(child: SpeechBubble(said.text, key: ValueKey('talk${said.id}'))),
              ),
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
                  to: potAt,
                  amount: p.bet,
                ),
              );
            } else {
              // Pushed out from the player's seat each time they put more in.
              children.add(
                _Fly(
                  key: ValueKey('bet${c.handNumber}-${h.street}-$s-${p.bet}'),
                  from: Offset.lerp(px(spots[s]), from, 0.15)!,
                  to: from,
                  amount: p.bet,
                  duration: 380,
                  fade: true,
                ),
              );
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
                    from: potAt,
                    // Into the winner's stack (which counts up), then gone.
                    // (onto the avatar: your seat's middle is your cards).
                    to: px(spots[seat]) + (seat == 0 ? const Offset(-91, -25) : const Offset(0, -18)),
                    amount: share,
                    duration: 1100,
                    stacks: 2,
                    vanish: true,
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
                  top: px(center).dy + boardCard * 0.7 + 12,
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

        // All in: a banner under the board while it runs out.
        if (c.odds.isNotEmpty && c.phase != TablePhase.payout) {
          children.add(
            Positioned(
              key: const ValueKey('all in'),
              left: 0,
              right: 0,
              // Under the board, where the result goes later.
              top: px(center).dy + boardCard * 0.7 + 14,
              child: const Center(child: _AllInBanner()),
            ),
          );
        }

        // A big pot: the splash and a shower of chips.
        if (c.phase == TablePhase.payout && c.bigWin != null) {
          children.add(
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRect(child: _ChipShower(key: ValueKey('shower${c.handNumber}'))),
              ),
            ),
          );
          children.add(
            Positioned(
              left: 0,
              right: 0,
              top: px(center).dy - boardCard * 0.7 - 70,
              child: Center(
                child: _BigWin(
                  key: ValueKey('big${c.handNumber}'),
                  title: c.bigWin!,
                  who: c.bigWinSeat == 0 ? null : c.personas[c.bigWinSeat!].name,
                ),
              ),
            ),
          );
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

/// Where a bot's turned-up cards go: above / below it upright, beside it
/// (towards the middle) in landscape.
enum _CardsAt { above, below, left, right }

/// Centres [child] on [at].
class _At extends StatelessWidget {
  const _At(this.at, {super.key, required this.child});

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
  const _Fly({
    super.key,
    required this.from,
    required this.to,
    required this.amount,
    this.duration = 450,
    this.fade = false,
    this.vanish = false,
    this.stacks = 1,
  });

  final Offset from;
  final Offset to;
  final int amount;
  final int duration;

  /// Fade in on the way (chips pushed out from under a seat).
  final bool fade;

  /// Shrink away on arrival (won chips going into a stack), so they never
  /// sit on top of anyone's cards.
  final bool vanish;
  final int stacks;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: duration),
    curve: Curves.easeOutCubic,
    builder: (context, t, child) => _At(
      Offset.lerp(from, to, t)!,
      child: vanish && t > 0.75
          ? Opacity(
              opacity: ((1 - t) / 0.25).clamp(0.0, 1.0),
              child: Transform.scale(scale: 0.6 + 0.4 * (1 - t) / 0.25, child: child),
            )
          : Opacity(opacity: fade ? min(1, t * 2.5) : 1, child: child),
    ),
    child: ChipPile(amount: amount, stacks: stacks),
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

/// How a seat's two cards are dealt: from where (relative to the first
/// card's spot) and when each goes out.
class _Deal {
  const _Deal({required this.from, required this.delays, required this.hand});

  final Offset from;
  final List<int> delays;
  final int hand;
}

/// One card dealt: it waits its turn, spins across face down from the
/// dealer and lands; [flip] turns it over once it's down (yours).
class _DealCard extends StatelessWidget {
  const _DealCard({
    super.key,
    required this.child,
    required this.from,
    required this.delay,
    required this.width,
    this.flip = false,
  });

  final Widget child;
  final Offset from;
  final int delay;
  final double width;
  final bool flip;

  static const _flight = 330, _turn = 240;

  @override
  Widget build(BuildContext context) {
    final total = delay + _flight + (flip ? _turn : 0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      builder: (context, t, child) {
        final ms = t * total;
        if (ms < delay) return Opacity(opacity: 0, child: child);
        final fly = Curves.easeOutCubic.transform(((ms - delay) / _flight).clamp(0.0, 1.0));
        if (fly < 1 || flip && ms < delay + _flight + _turn / 2) {
          // In the air (or the first half of turning over): its back.
          final squash = flip && fly >= 1 ? 1 - ((ms - delay - _flight) / (_turn / 2)).clamp(0.0, 1.0) : 1.0;
          return Transform.translate(
            offset: from * (1 - fly),
            child: Transform.rotate(
              angle: (1 - fly) * 2.4,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(max(squash, 0.001), 1, 1),
                child: CardView(card: null, width: width, faceUp: false),
              ),
            ),
          );
        }
        if (!flip || ms >= total) return child!;
        // The second half of turning over: the face opens out.
        final open = ((ms - delay - _flight - _turn / 2) / (_turn / 2)).clamp(0.0, 1.0);
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(max(open, 0.001), 1, 1),
          child: child,
        );
      },
      child: child,
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
        child: Text(
          text,
          style: Toon.text(12, weight: FontWeight.w700, color: Toon.on(color)),
        ),
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
    child: Text(
      'D',
      style: Toon.text(12, weight: FontWeight.w700, color: Toon.inkLight),
    ),
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

/// On the chip leader: a little trophy badge on the avatar.
class _Crown extends StatelessWidget {
  const _Crown();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('chip leader'),
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      color: Toon.yellow,
      shape: BoxShape.circle,
      border: Border.all(color: Toon.ink, width: 2),
    ),
    child: const Icon(Icons.emoji_events_rounded, size: 15, color: Toon.inkLight),
  );
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
        // Stacks count up (and down) as chips arrive and go.
        TweenAnimationBuilder<double>(
          tween: Tween(end: stack.toDouble()),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => Text(
            note ?? chips(v.round()),
            style: Toon.text(13, weight: FontWeight.w700, color: note == null ? Toon.fg : Toon.muted),
          ),
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
  const _BotSeat({required this.c, required this.seat, required this.cards, required this.muck, this.deal});

  final PokerController c;
  final int seat;
  final _CardsAt cards;
  final _Deal? deal;

  /// From the seat's cards to the middle of the table.
  final Offset muck;

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
            // Tap for your read on them.
            Positioned(
              top: 14,
              child: GestureDetector(
                key: Key('read $seat'),
                onTap: () => showReadCard(context, c, seat),
                child: _Avatar(persona: persona, size: 54, acting: c.actingSeat == seat, winner: winner),
              ),
            ),
            if (!out && chipLeader(c) == seat) const Positioned(top: 50, right: 12, child: _Crown()),
            // Face down: tucked beside the avatar. Turned up: above or
            // below, clear of the board.
            if (showCards)
              Positioned(
                key: const ValueKey('cards'),
                top: faceUp
                    ? switch (cards) {
                        _CardsAt.above => -40,
                        _CardsAt.below => 112,
                        _ => 22,
                      }
                    : 26,
                left: faceUp
                    ? switch (cards) {
                        _CardsAt.left => -66,
                        _CardsAt.right => 86,
                        _ => 10,
                      }
                    : 60,
                child: _HoleCards(
                  cards: p.hole,
                  faceUp: faceUp,
                  width: faceUp ? 34 : 22,
                  winning: winning,
                  deal: deal,
                  seat: seat,
                  chance: c.odds[seat],
                ),
              ),
            // Just folded: the cards slide into the middle and vanish.
            if (folded && p!.hole.length == 2)
              Positioned(
                key: const ValueKey('muck'),
                top: 26,
                left: 60,
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey('muck${c.handNumber}-$seat'),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 520),
                    curve: Curves.easeInCubic,
                    builder: (context, t, child) => Opacity(
                      opacity: (1 - t).clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: muck * t,
                        child: Transform.rotate(angle: t * 1.6, child: child),
                      ),
                    ),
                    child: _HoleCards(cards: p.hole, faceUp: false, width: 22, winning: const {}, seat: seat),
                  ),
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
            if (c.actingSeat == seat)
              const Positioned(top: -8, child: _ThinkingDots())
            else if (p?.lastAction != null && c.phase != TablePhase.payout)
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
  const _HoleCards({
    required this.cards,
    required this.faceUp,
    required this.width,
    required this.winning,
    required this.seat,
    this.deal,
    this.chance,
  });

  final List<PlayingCard> cards;
  final bool faceUp;
  final double width;
  final Set<PlayingCard> winning;
  final int seat;
  final _Deal? deal;

  /// All in: this hand's chance to win, shown on the cards.
  final double? chance;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width * (faceUp ? 2.05 : 1.45),
    height: width * 1.4 + 4,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        for (var k = 0; k < 2; k++)
          Positioned(
            left: k * width * (faceUp ? 1.05 : 0.45),
            top: faceUp ? 0 : k * 3.0,
            child: _dealt(
              k,
              Transform.rotate(
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
          ),
        if (faceUp && chance != null)
          Positioned(left: 0, right: 0, bottom: -14, child: Center(child: _ChanceBadge(chance!))),
      ],
    ),
  );
}

/// A hand's chance to win while all in: green when ahead, red when behind.
class _ChanceBadge extends StatelessWidget {
  const _ChanceBadge(this.chance);

  final double chance;

  @override
  Widget build(BuildContext context) {
    final pct = (chance * 100).round();
    final color = chance >= 0.5 ? Toon.green : (chance >= 0.25 ? Toon.yellow : Toon.red);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: chance),
      duration: const Duration(milliseconds: 500),
      builder: (context, v, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: Toon.box(color, radius: 9, shadow: 2),
        child: Text(
          '${(v * 100).round().clamp(0, 100)}%',
          key: ValueKey('chance $pct'),
          style: Toon.text(13, weight: FontWeight.w800, color: Toon.on(color)),
        ),
      ),
    );
  }
}

extension on _HoleCards {
  Widget _dealt(int k, Widget card) {
    final d = deal;
    if (d == null) return card;
    return _DealCard(
      key: ValueKey('deal${d.hand}-$seat-$k'),
      from: d.from - Offset(k * width * 0.45, 0),
      delay: d.delays[k],
      width: width,
      child: card,
    );
  }
}

/// You, at the bottom: avatar, stack, and your two cards big.
class _YourSeat extends StatelessWidget {
  const _YourSeat({required this.c, this.deal});

  final PokerController c;
  final _Deal? deal;

  @override
  Widget build(BuildContext context) {
    final p = c.handPlayer(0);
    final table = c.game.players[0];
    final folded = p?.folded ?? false;
    final r = c.hand?.result;
    final winner = c.phase == TablePhase.payout && r != null && (r.winnings[c.handIndex(0) ?? -1] ?? 0) > 0;
    final winning = c.phase == TablePhase.payout ? c.winningCards() : const <PlayingCard>{};
    // Odds and outs off: you're on your own (the chart, but not your hand).
    final helped = AccountScope.maybeRead(context)?.pokerOdds ?? true;
    final name = folded || c.yourHandName() == null ? null : (helped ? c.yourHandName() : 'Hands');

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
                GestureDetector(
                  key: const Key('read 0'),
                  onTap: () => showReadCard(context, c, 0),
                  child: _Avatar(persona: c.personas[0], size: 54, acting: c.yourTurn, winner: winner),
                ),
                const SizedBox(height: 4),
                _NamePlate(name: c.personas[0].name, stack: p?.stack ?? table.stack),
              ],
            ),
          ),
          if (chipLeader(c) == 0) const Positioned(left: 38, top: 52, child: _Crown()),
          if (c.phase == TablePhase.shuffle || (p != null && c.hand!.players[c.hand!.button] == p))
            const Positioned(left: 50, top: 12, child: _DealerButton()),
          if (p?.lastAction != null && c.phase != TablePhase.payout)
            Positioned(left: 4, top: -8, child: _ActionBubble(p!.lastAction!)),
          if (p != null && p.hole.length == 2)
            Positioned(
              // Keyed so the deal plays once, whatever comes and goes beside.
              key: const ValueKey('your cards'),
              left: 84,
              top: 4,
              child: Opacity(
                opacity: folded ? 0.45 : 1,
                child: Row(
                  children: [
                    for (var k = 0; k < 2; k++)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Transform.rotate(
                          angle: k == 0 ? -0.05 : 0.05,
                          child: () {
                            final card = CardView(
                              card: p.hole[k],
                              width: 64,
                              glow: winning.contains(p.hole[k]),
                              dim: winning.isNotEmpty && !winning.contains(p.hole[k]),
                            );
                            final d = deal;
                            if (d == null) return card;
                            return _DealCard(
                              key: ValueKey('deal${d.hand}-0-$k'),
                              from: d.from - Offset(k * 70.0, 0),
                              delay: d.delays[k],
                              width: 64,
                              flip: true,
                              child: card,
                            );
                          }(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          // All in: your chance to win, over your cards.
          if (c.odds[0] case final chance? when !folded && helped)
            Positioned(left: 84, width: 134, top: -16, child: Center(child: _ChanceBadge(chance))),
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
                    final yours = helped ? c.yourHand() : null;
                    showHandChart(
                      context,
                      category: yours?.category,
                      royal: yours?.royal ?? false,
                      cards: yours?.cards ?? const [],
                      name: helped ? name : null,
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

/// "…" in a bubble, the dots rising in turn: this player is thinking.
class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: Toon.box(Toon.cardFace, radius: 10, shadow: 2),
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
  );
}

/// ALL IN! over the board while the cards run out, throbbing.
class _AllInBanner extends StatefulWidget {
  const _AllInBanner();

  @override
  State<_AllInBanner> createState() => _AllInBannerState();
}

class _AllInBannerState extends State<_AllInBanner> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Pop(
    child: ScaleTransition(
      scale: Tween(begin: 0.95, end: 1.06).animate(CurvedAnimation(parent: _a, curve: Curves.easeInOut)),
      child: ToonBox(
        color: Toon.red,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 4),
            Text(
              'ALL IN!',
              style: Toon.text(18, weight: FontWeight.w800, color: Colors.white),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The big-pot splash: slams in, wobbles, says who.
class _BigWin extends StatelessWidget {
  const _BigWin({super.key, required this.title, this.who});

  final String title;
  final String? who;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 900),
    builder: (context, t, child) {
      final slam = Curves.elasticOut.transform(t.clamp(0.0, 1.0));
      return Transform.rotate(
        angle: sin(t * pi * 4) * 0.06 * (1 - t),
        child: Transform.scale(scale: 0.3 + 0.7 * slam, child: child),
      );
    },
    child: ToonBox(
      color: Toon.yellow,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Toon.text(26, weight: FontWeight.w800, color: Toon.inkLight),
          ),
          if (who != null) Text('for $who', style: Toon.text(14, color: Toon.inkLight)),
        ],
      ),
    ),
  );
}

/// Chips raining down over the table, tumbling as they fall.
class _ChipShower extends StatelessWidget {
  const _ChipShower({super.key});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 2600),
    builder: (context, t, _) => CustomPaint(painter: _ShowerPainter(t)),
  );
}

class _ShowerPainter extends CustomPainter {
  _ShowerPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(5);
    final ink = Paint()
      ..color = Toon.inkLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (var i = 0; i < 36; i++) {
      final x = rng.nextDouble() * size.width;
      final start = rng.nextDouble() * 0.45;
      final speed = 0.8 + rng.nextDouble() * 0.6;
      final spin = (rng.nextDouble() - 0.5) * 10;
      final color = chipValues[rng.nextInt(5)].$2;
      final k = ((t - start) / (1 - start)).clamp(0.0, 1.0);
      if (k <= 0 || k >= 1) continue;
      final y = -20 + k * speed * (size.height + 40);
      final c = Offset(x + sin(k * 6 + i) * 12, y);
      // A chip flipping as it falls: its face squashes and opens.
      final w = 18.0, h = 18.0 * (0.25 + 0.75 * cos(k * spin).abs());
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(k * spin * 0.3);
      final face = Rect.fromCenter(center: Offset.zero, width: w, height: h);
      canvas.drawOval(face, Paint()..color = color.withValues(alpha: 1 - k * 0.3));
      canvas.drawOval(
        face.deflate(4).inflate(0),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      canvas.drawOval(face, ink);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ShowerPainter old) => old.t != t;
}
