import 'package:flutter/material.dart';

import '../core/cards/card_view.dart';
import '../core/cards/cards.dart';
import '../core/session/play_setup.dart';
import '../core/theme/toon.dart';
import 'poker/ui/poker_screen.dart';

/// A game on the picker. Adding a game: its folder under lib/games/, plus
/// one entry in [games].
class GameInfo {
  const GameInfo({
    required this.id,
    required this.name,
    required this.blurb,
    required this.minPlayers,
    required this.maxPlayers,
    required this.color,
    required this.art,
    this.open,
  });

  final String id;
  final String name;
  final String blurb;
  final int minPlayers;
  final int maxPlayers;
  final Color color;
  final WidgetBuilder art;

  /// Opens the game for this setup; null = coming soon.
  final Widget Function(PlaySetup setup)? open;

  bool get available => open != null;

  bool fits(int players) => players >= minPlayers && players <= maxPlayers;

  String get playersLabel =>
      minPlayers == maxPlayers ? '$minPlayers players' : '$minPlayers–$maxPlayers players';
}

final games = <GameInfo>[
  GameInfo(
    id: 'holdem',
    name: "Texas Hold'em",
    blurb: 'Sit & Go poker',
    minPlayers: 2,
    maxPlayers: 6,
    color: Toon.green,
    art: (_) => const _FannedCards(['As', 'Ah']),
    open: (setup) => PokerScreen(bots: setup.botCount, difficulty: setup.difficulty),
  ),
  GameInfo(
    id: 'crazy8',
    name: 'Crazy Eights',
    blurb: 'Match the suit or rank',
    minPlayers: 2,
    maxPlayers: 4,
    color: Toon.orange,
    art: (_) => const _FannedCards(['8h', '8c']),
  ),
  GameInfo(
    id: 'gofish',
    name: 'Go Fish',
    blurb: 'Got any sevens?',
    minPlayers: 2,
    maxPlayers: 6,
    color: Toon.blue,
    art: (_) => const _FannedCards(['7d', '7s']),
  ),
  GameInfo(
    id: 'connect4',
    name: 'Four in a Row',
    blurb: 'Drop discs, line up four',
    minPlayers: 2,
    maxPlayers: 2,
    color: Toon.purple,
    art: (_) => const _Discs(),
  ),
];

class _FannedCards extends StatelessWidget {
  const _FannedCards(this.cards);

  final List<String> cards;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 76,
    height: 64,
    child: Stack(
      alignment: Alignment.center,
      children: [
        for (var i = 0; i < cards.length; i++)
          Transform.translate(
            offset: Offset((i - 0.5) * 18, 0),
            child: Transform.rotate(
              angle: (i - 0.5) * 0.35,
              child: CardView(card: PlayingCard.parse(cards[i]), width: 40),
            ),
          ),
      ],
    ),
  );
}

class _Discs extends StatelessWidget {
  const _Discs();

  @override
  Widget build(BuildContext context) {
    const pattern = [
      [0, 0, 0, 0],
      [0, 2, 0, 0],
      [1, 2, 1, 0],
      [2, 1, 1, 1],
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: Toon.box(Toon.blue, radius: 8, shadow: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in pattern)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final cell in row)
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const [Toon.paper, Toon.red, Toon.yellow][cell],
                      border: Border.all(color: Toon.ink, width: 1.5),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
