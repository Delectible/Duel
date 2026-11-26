import 'dart:math';

import 'package:flutter/material.dart';

import '../core/cards/card_view.dart';
import 'package:duel_engine/cards.dart';
import '../core/theme/toon.dart';
import '../core/avatars/faces.dart';
import 'bank/dice.dart';
import 'farkle/ui/farkle_screen.dart' show Tray;
import 'liars/ui/liars_screen.dart' show LiarsCup, Tavern, FlatDie;

/// Sample boards for the game previews: a still picture of each game in
/// play, drawn with the same pieces as the games.

List<PlayingCard> _cards(String s) => PlayingCard.parseAll(s);

/// A fan of cards, face up or down.
class _Fan extends StatelessWidget {
  const _Fan(this.cards, {required this.width, this.faceUp = true, this.spread = 0.55, this.tilt = 0.12});

  final List<PlayingCard> cards;
  final double width;
  final bool faceUp;
  final double spread;
  final double tilt;

  @override
  Widget build(BuildContext context) {
    final n = cards.length;
    return SizedBox(
      width: width * (1 + spread * (n - 1)) + width * 0.3,
      height: width * 1.4 + width * 0.3,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < n; i++)
            Transform.translate(
              offset: Offset((i - (n - 1) / 2) * width * spread, ((i - (n - 1) / 2).abs()) * width * 0.06),
              child: Transform.rotate(
                angle: (i - (n - 1) / 2) * tilt,
                child: CardView(card: cards[i], width: width, faceUp: faceUp),
              ),
            ),
        ],
      ),
    );
  }
}

/// Green felt panel the samples sit on.
class _Felt extends StatelessWidget {
  const _Felt({required this.child, this.oval = false});

  final Widget child;
  final bool oval;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Toon.felt,
      borderRadius: BorderRadius.circular(oval ? 200 : 18),
      border: Border.all(color: Toon.wood, width: 10),
    ),
    foregroundDecoration: BoxDecoration(
      borderRadius: BorderRadius.circular(oval ? 200 : 18),
      border: Border.all(color: Toon.ink, width: 2.5),
    ),
    child: child,
  );
}

class HoldemPreview extends StatelessWidget {
  const HoldemPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final bots = Persona.bots(3, Random(4));
    return _Felt(
      oval: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [for (final b in bots) Face(b, size: 38)],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final c in _cards('Kh 7d 7c Ks')) ...[
                  CardView(card: c, width: 34),
                  const SizedBox(width: 4),
                ],
                Container(
                  width: 34,
                  height: 34 * 1.4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Toon.ink.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('Pot 640', style: Toon.text(12, color: Colors.white)),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Face.of(Avatar(), size: 36),
                const SizedBox(width: 6),
                _Fan(_cards('Kd Qd'), width: 30, spread: 0.9, tilt: 0.08),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CrazyEightsPreview extends StatelessWidget {
  const CrazyEightsPreview({super.key});

  @override
  Widget build(BuildContext context) => _Felt(
    child: Column(
      children: [
        const SizedBox(height: 4),
        Transform.rotate(angle: pi, child: _Fan(_cards('2c 3c 4c 5c'), width: 26, faceUp: false)),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: EdgeInsets.only(left: i * 2.0, top: i * 2.0),
                    child: const CardView(card: null, width: 38, faceUp: false),
                  ),
              ],
            ),
            const SizedBox(width: 18),
            Transform.rotate(angle: 0.08, child: CardView(card: PlayingCard.parse('8s'), width: 42)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: Toon.box(Toon.card, radius: 12, shadow: 2),
              child: const SuitIcon(Suit.hearts, size: 20),
            ),
          ],
        ),
        const Spacer(),
        _Fan(_cards('8d Jh 4h 9c Qh'), width: 32),
      ],
    ),
  );
}

class GoFishPreview extends StatelessWidget {
  const GoFishPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final rng = Random(3);
    return _Felt(
      child: Stack(
        children: [
          // The pond: face-down cards scattered in the middle.
          for (var i = 0; i < 9; i++)
            Positioned(
              left: 110 + rng.nextDouble() * 120,
              top: 40 + rng.nextDouble() * 50,
              child: Transform.rotate(
                angle: rng.nextDouble() * 2 - 1,
                child: const CardView(card: null, width: 26, faceUp: false),
              ),
            ),
          // A finished book of sevens.
          Positioned(
            left: 10,
            top: 12,
            child: _Fan(_cards('7c 7d 7h 7s'), width: 22, spread: 0.3, tilt: 0.05),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: Toon.box(Toon.card, radius: 12, shadow: 2),
              child: Text('Got any Kings?', style: Toon.text(13)),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 4,
            child: Center(child: _Fan(_cards('Kc Kh 3d 9s 2h'), width: 32)),
          ),
        ],
      ),
    );
  }
}

class FourInARowPreview extends StatelessWidget {
  const FourInARowPreview({super.key});

  // 0 empty, 1 red, 2 yellow; bottom row last. Red has four diagonally.
  static const _board = [
    [0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 1, 2, 0, 0, 0],
    [0, 1, 2, 2, 0, 0, 0],
    [1, 2, 2, 1, 1, 0, 2],
  ];

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      padding: const EdgeInsets.all(6),
      decoration: Toon.box(Toon.blue, radius: 14, shadow: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in _board)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final cell in row)
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: [Toon.cardFace, Toon.red, Toon.yellow][cell],
                      border: Border.all(color: Toon.ink, width: 2),
                    ),
                  ),
              ],
            ),
        ],
      ),
    ),
  );
}

class SpadesPreview extends StatelessWidget {
  const SpadesPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final bots = Persona.bots(3, Random(7));
    Widget seat(Persona p, String bid) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Face(p, size: 30),
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: Toon.ink.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(bid, style: Toon.text(11, color: Colors.white)),
        ),
      ],
    );
    return _Felt(
      child: Stack(
        children: [
          // Partner opposite, opponents either side; a trick in the middle
          // won by a spade.
          Positioned(top: 8, left: 0, right: 0, child: Center(child: seat(bots[1], 'Bid 4'))),
          Positioned(left: 12, top: 70, child: seat(bots[0], 'Bid 2')),
          Positioned(right: 12, top: 70, child: seat(bots[2], 'Bid 3')),
          Positioned(
            left: 0,
            right: 0,
            top: 62,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (i, c) in _cards('Kh Ah 3s 9h').indexed)
                    Transform.rotate(
                      angle: (i - 1.5) * 0.1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: CardView(card: c, width: 30),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 4,
            child: Center(child: _Fan(_cards('As Qs 7s Kd 5c'), width: 30)),
          ),
        ],
      ),
    );
  }
}

/// Blitz: an opponent's castle with a 9 showing, your castle, and a 9 in
/// your hand about to strike it.
class BlitzPreview extends StatelessWidget {
  const BlitzPreview({super.key});

  @override
  Widget build(BuildContext context) {
    Widget castle(String down, PlayingCard up, double w) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final c in _cards(down))
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: CardView(card: c, width: w, faceUp: false),
          ),
        CardView(card: up, width: w),
      ],
    );
    return _Felt(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Face(Persona.bots(1, Random(3)).single, size: 30),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [BoxShadow(color: Toon.red, spreadRadius: 0)],
                  ),
                  child: castle('2c 3c 4c 5c 6c', const PlayingCard(9, Suit.spades), 26),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                castle('2c 3c 4c 5c', const PlayingCard(12, Suit.hearts), 26),
                const SizedBox(width: 14),
                _Fan(_cards('9d As Kh'), width: 30, spread: 0.6),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A small dark label on the felt ("Prize", "Bid 4").
Widget _tag(String text, {Color? color}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
  decoration: BoxDecoration(
    color: color ?? Toon.inkLight.withValues(alpha: 0.75),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(text, style: Toon.text(12, color: color == null ? Colors.white : Toon.on(color))),
);

/// GOPS: the prize up for grabs, a bot's face-down bid, your clubs to bid with.
class GopsPreview extends StatelessWidget {
  const GopsPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final bot = Persona.bots(1, Random(5)).single;
    return _Felt(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Face(bot, size: 30),
                const SizedBox(width: 8),
                _tag('Won 21'),
                const SizedBox(width: 10),
                const CardView(card: null, width: 26, faceUp: false),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _tag('Prize', color: Toon.yellow),
                    const SizedBox(height: 3),
                    CardView(card: PlayingCard.parse('Qd'), width: 38),
                  ],
                ),
                const SizedBox(width: 14),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _tag('Next: both'),
                    const SizedBox(height: 3),
                    // A tie last time: that prize carries over.
                    Opacity(opacity: 0.85, child: CardView(card: PlayingCard.parse('5d'), width: 28)),
                  ],
                ),
              ],
            ),
            _Fan(_cards('Ac 4c 7c Tc Qc Kc'), width: 28, spread: 0.5, tilt: 0.08),
          ],
        ),
      ),
    );
  }
}

/// Blackjack: the dealer with one card hidden, two players' hands with
/// their bets, yours on 21.
class BlackjackPreview extends StatelessWidget {
  const BlackjackPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final bot = Persona.bots(1, Random(9)).single;
    Widget hand(String cards, String total, String bet, {Color? glow}) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, c) in _cards(cards).indexed)
              Transform.translate(
                offset: Offset(i * -12.0, 0),
                child: CardView(card: c, width: 30),
              ),
          ],
        ),
        const SizedBox(height: 3),
        _tag(total, color: glow),
        const SizedBox(height: 2),
        Text(bet, style: Toon.text(12, color: Colors.white)),
      ],
    );
    return _Felt(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _tag('Dealer'),
                const SizedBox(width: 8),
                CardView(card: PlayingCard.parse('9s'), width: 30),
                const SizedBox(width: 3),
                const CardView(card: null, width: 30, faceUp: false),
              ],
            ),
            Text('Dealer stands on 17', style: Toon.text(11, color: Colors.white70)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Face(bot, size: 28), const SizedBox(width: 4), hand('8d 5c 4h', '17', 'Bet 50')],
                ),
                hand('As Kh', 'Blackjack!', 'Bet 100', glow: Toon.yellow),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bank!: the dice, the bank's total and the roll count, who's banked.
class BankPreview extends StatelessWidget {
  const BankPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final bots = Persona.bots(3, Random(11));
    Widget player(Persona p, String note, {bool banked = false}) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(opacity: banked ? 0.55 : 1, child: Face(p, size: 28)),
        const SizedBox(height: 2),
        _tag(note, color: banked ? Toon.green : null),
      ],
    );
    return Container(
      decoration: Toon.box(Toon.purple, radius: 18, shadow: 4),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              player(bots[0], 'Banked 140', banked: true),
              player(bots[1], '310'),
              player(bots[2], '95'),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Die(4, size: 40, angle: -0.2),
              const SizedBox(width: 10),
              const Die(4, size: 40, angle: 0.25),
              const SizedBox(width: 16),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'BANK',
                    style: Toon.text(13, weight: FontWeight.w700, color: Colors.white70),
                  ),
                  Text(
                    '480',
                    style: Toon.text(30, weight: FontWeight.w700, color: Colors.white),
                  ),
                  Text('Doubles: x2!', style: Toon.text(12, color: Toon.yellow)),
                ],
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _tag('Round 4 of 15 · Roll 6'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: Toon.box(Toon.yellow, radius: 12, shadow: 2),
                child: Text(
                  'BANK!',
                  style: Toon.text(15, weight: FontWeight.w700, color: Toon.inkLight),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Farkle: the scores, the kept dice, the tray.
class FarklePreview extends StatelessWidget {
  const FarklePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final bots = Persona.bots(2, Random(5));
    Widget player(Persona p, String score) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [Face(p, size: 26), const SizedBox(height: 2), _tag(score)],
    );
    return Container(
      decoration: Toon.box(Tray.wood, radius: 18, shadow: 4),
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: BoxDecoration(color: Tray.felt, borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [player(bots[0], '6,350'), player(bots[1], '8,900')],
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Die(1, size: 34, angle: -0.2), SizedBox(width: 8), Die(1, size: 34, angle: 0.3), SizedBox(width: 8), Die(5, size: 34, angle: 0.1)],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Die(4, size: 26, angle: 0.2),
                const SizedBox(width: 6),
                const Die(2, size: 26, angle: -0.3),
                const SizedBox(width: 6),
                const Die(6, size: 26, angle: 0.1),
                const SizedBox(width: 10),
                _tag('+250', color: Toon.green),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Liar's Dice: cups round the table, the bid on its plaque.
class LiarsPreview extends StatelessWidget {
  const LiarsPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final bots = Persona.bots(3, Random(8));
    Widget seat(Persona p, Color cup, String said) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [LiarsCup(width: 34, color: cup), Face(p, size: 24), const SizedBox(height: 2), _tag(said)],
    );
    return Container(
      decoration: Toon.box(Tavern.cloth, radius: 18, shadow: 4),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              seat(bots[0], Tavern.cups[1], 'Three 4s'),
              seat(bots[1], Tavern.cups[2], 'Four 4s'),
              seat(bots[2], Tavern.cups[3], 'Liar!'),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: Toon.box(Tavern.brass, radius: 10, shadow: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('4 ×', style: Toon.text(22, weight: FontWeight.w700, color: Toon.inkLight)),
                const SizedBox(width: 6),
                const FlatDie(4, size: 26),
              ],
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Die(4, size: 26), Die(1, size: 26), Die(6, size: 26), Die(4, size: 26), Die(2, size: 26)],
          ),
        ],
      ),
    );
  }
}
