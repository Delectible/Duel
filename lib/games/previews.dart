import 'dart:math';

import 'package:flutter/material.dart';

import '../core/cards/card_view.dart';
import '../core/cards/cards.dart';
import '../core/theme/toon.dart';
import '../core/avatars/faces.dart';

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
