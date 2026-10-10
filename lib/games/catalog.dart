import 'package:flutter/material.dart';

import '../core/account/stake.dart';
import '../core/cards/card_view.dart';
import '../core/cards/cards.dart';
import '../core/session/play_setup.dart';
import '../core/theme/toon.dart';
import 'crazy_eights/ui/eights_screen.dart';
import 'four_in_a_row/ui/row_screen.dart';
import 'go_fish/ui/fish_screen.dart';
import 'poker/ui/poker_screen.dart';
import 'previews.dart';

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
    required this.board,
    required this.rules,
    required this.minutes,
    this.open,
  });

  final String id;
  final String name;
  final String blurb;
  final int minPlayers;
  final int maxPlayers;
  final Color color;
  final WidgetBuilder art;

  /// A sample picture of the game in play, for the preview.
  final WidgetBuilder board;

  /// The basics, a few short lines.
  final List<String> rules;

  /// Rough length of a game for this many players.
  final int Function(int players) minutes;

  /// Opens the game for this setup with its stake; null = coming soon.
  final Widget Function(PlaySetup setup, StakeTicket stake)? open;

  bool get available => open != null;

  bool fits(int players) => players >= minPlayers && players <= maxPlayers;

  /// Why it can't start with this setup: (short badge, full sentence), or
  /// null when Play is on.
  (String, String)? blocked(PlaySetup setup) {
    final players = setup.players;
    if (!available) return ('Soon', '$name is coming soon.');
    if (players < minPlayers) {
      return (
        'Needs $minPlayers+',
        setup.mode == PlayMode.friends
            ? 'Needs $minPlayers+ players: invite a friend, or switch to Bots.'
            : 'Needs $minPlayers+ players: add a bot.',
      );
    }
    if (players > maxPlayers) {
      return ('Max $maxPlayers', 'For up to $maxPlayers players: you have $players. Take a bot away.');
    }
    if (setup.mode == PlayMode.friends) {
      return ('Online soon', 'Playing with friends is coming soon. Switch to Bots to play now.');
    }
    return null;
  }

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
    board: (_) => const HoldemPreview(),
    rules: const [
      'Everyone gets two cards of their own. Five shared cards come out in the middle: three (the flop), '
          'then one (the turn), then one more (the river).',
      'Make the best five-card hand from your two and the five shared. Tap your hand to see the rankings.',
      'Each round, check, bet, call, raise or fold. Win the pot with the best hand at the end, or by making '
          'everyone else fold.',
      'Sit & Go: everyone starts with 1,500 chips and the blinds go up as you play. Last one with chips wins.',
    ],
    // Bot-only runs: ~25 hands heads-up to ~65 six-handed; more players,
    // longer hands.
    minutes: (players) => const {2: 10, 3: 15, 4: 20, 5: 30}[players] ?? 35,
    open: (setup, stake) => PokerScreen(bots: setup.botCount, difficulty: setup.difficulty, stake: stake),
  ),
  GameInfo(
    id: 'crazy8',
    name: 'Crazy Eights',
    blurb: 'Match the suit or rank',
    minPlayers: 2,
    maxPlayers: 4,
    color: Toon.orange,
    art: (_) => const _FannedCards(['8h', '8c']),
    board: (_) => const CrazyEightsPreview(),
    rules: const [
      'Play a card that matches the top of the pile by suit or by number.',
      'Eights are wild: play one any time and choose the next suit.',
      "Can't play? Draw a card. First to get rid of all their cards wins.",
    ],
    minutes: (players) => 3 + players * 2,
    open: (setup, stake) => EightsScreen(bots: setup.botCount, difficulty: setup.difficulty, stake: stake),
  ),
  GameInfo(
    id: 'gofish',
    name: 'Go Fish',
    blurb: 'Got any sevens?',
    minPlayers: 2,
    maxPlayers: 6,
    color: Toon.blue,
    art: (_) => const _FannedCards(['7d', '7s']),
    board: (_) => const GoFishPreview(),
    rules: const [
      'On your turn, ask a player for a rank you already hold: "Got any Kings?"',
      'If they have any, they hand them all over and you go again. If not: "Go fish!" Draw from the pond.',
      'Collect all four of a rank to make a book. Most books at the end wins.',
    ],
    minutes: (players) => 5 + players * 2,
    open: (setup, stake) => FishScreen(bots: setup.botCount, difficulty: setup.difficulty, stake: stake),
  ),
  GameInfo(
    id: 'connect4',
    name: 'Four in a Row',
    blurb: 'Drop discs, line up four',
    minPlayers: 2,
    maxPlayers: 2,
    color: Toon.purple,
    art: (_) => const _Discs(),
    board: (_) => const FourInARowPreview(),
    rules: const [
      'Take turns dropping a disc into a column. It falls to the lowest free space.',
      'First to line up four of their colour wins: across, up and down, or diagonally.',
    ],
    minutes: (_) => 5,
    open: (setup, stake) => RowScreen(difficulty: setup.difficulty, stake: stake),
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
                      color: [Toon.cardFace, Toon.red, Toon.yellow][cell],
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
