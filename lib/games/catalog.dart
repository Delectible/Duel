import 'dart:math';

import 'package:flutter/material.dart';

import '../core/account/stake.dart';
import '../core/cards/card_view.dart';
import 'package:duel_engine/cards.dart';
import '../core/online/party.dart';
import '../core/session/play_setup.dart';
import '../core/theme/toon.dart';
import '../core/help/home_guide.dart';
import 'crazy_eights/at_home.dart';
import 'crazy_eights/ui/eights_screen.dart';
import 'package:duel_engine/blitz/blitz.dart';

import 'blitz/at_home.dart';
import 'blitz/ui/blitz_screen.dart';
import 'four_in_a_row/at_home.dart';
import 'four_in_a_row/ui/row_screen.dart';
import 'go_fish/at_home.dart';
import 'go_fish/ui/fish_screen.dart';
import 'poker/at_home.dart';
import 'poker/ui/poker_screen.dart';
import 'spades/at_home.dart';
import 'previews.dart';
import 'spades/ui/spades_screen.dart';

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
    required this.atHome,
    this.open,
    this.playerCounts,
    this.choice,
    this.opponentsFor,
    this.openOnline,
    this.note,
  });

  /// Something about this table size worth knowing up front (Blitz: how
  /// many decks), shown as a chip in the preview.
  final String Function(int players)? note;

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

  /// "Play at home": setup, gameplay and winning with your own cards.
  final HomeGuide atHome;

  /// Opens the game for this setup with its stake (and the [choice]
  /// picked in the preview, if the game has one); null = coming soon.
  final Widget Function(PlaySetup setup, StakeTicket stake, int? choice)? open;

  /// Only these table sizes, when not every count from min to max works
  /// (Spades: 2 or 4).
  final Set<int>? playerCounts;

  /// Something to pick in the preview before playing (Spades: points to
  /// play to).
  final GameChoice? choice;

  /// Opponents for the stake's winnings (teams: only the other team);
  /// default everyone else.
  final int Function(int players)? opponentsFor;

  /// The game with your party, online (null = not online yet). Opened on
  /// every phone when the host starts it.
  final Widget Function(PartyService party)? openOnline;

  int opponents(int players) => opponentsFor?.call(players) ?? players - 1;

  bool get available => open != null;

  bool fits(int players) =>
      players >= minPlayers && players <= maxPlayers && (playerCounts?.contains(players) ?? true);

  /// Length for this table (and choice, scaled from the default).
  int minutesFor(int players, int? picked) {
    final base = minutes(players);
    final c = choice;
    // Only point targets scale the length (on / off choices don't).
    if (c == null || picked == null || !c.showValues) return base;
    return max(1, (base * picked / c.values[c.initial]).round());
  }

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
    final counts = playerCounts;
    if (counts != null && !counts.contains(players)) {
      final list = (counts.toList()..sort()).join(' or ');
      return ('$list players', '$name is for $list players: you have $players. Change the number of bots.');
    }
    if (setup.mode == PlayMode.friends) {
      final party = setup.party;
      if (openOnline == null) {
        return ('Online soon', '$name with friends is coming soon. Switch to Bots to play it now.');
      }
      if (party == null) return ('Offline', 'Playing with friends needs the internet.');
      if (!party.isHost) return ('Host picks', '${party.hostName} picks the game. It starts here by itself.');
    }
    return null;
  }

  String get playersLabel {
    final counts = playerCounts;
    if (counts != null) return '${(counts.toList()..sort()).join(' or ')} players';
    return minPlayers == maxPlayers ? '$minPlayers players' : '$minPlayers–$maxPlayers players';
  }
}

/// One choice made in the preview before a game starts.
class GameChoice {
  const GameChoice({
    required this.label,
    required this.values,
    required this.names,
    this.initial = 0,
    this.info,
    this.showValues = true,
  });

  /// Explained behind an (i) next to the choice.
  final String? info;

  /// Show the number with each name ("Quick 150"); off for on / off choices.
  final bool showValues;

  /// "Play to".
  final String label;
  final List<int> values;

  /// "Quick", "Normal", "Long".
  final List<String> names;
  final int initial;
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
    atHome: holdemAtHome,
    open: (setup, stake, _) => PokerScreen(bots: setup.botCount, difficulty: setup.difficulty, stake: stake),
    openOnline: (party) => PokerScreen.online(party: party),
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
    atHome: eightsAtHome,
    open: (setup, stake, _) => EightsScreen(bots: setup.botCount, difficulty: setup.difficulty, stake: stake),
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
    atHome: fishAtHome,
    open: (setup, stake, _) => FishScreen(bots: setup.botCount, difficulty: setup.difficulty, stake: stake),
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
    atHome: rowAtHome,
    open: (setup, stake, _) => RowScreen(difficulty: setup.difficulty, stake: stake),
    openOnline: (party) => RowScreen.online(party: party),
  ),
  GameInfo(
    id: 'spades',
    name: 'Spades',
    blurb: 'Bid your tricks, spades trump',
    minPlayers: 2,
    maxPlayers: 4,
    color: Toon.teal,
    art: (_) => const _FannedCards(['As', 'Ks']),
    board: (_) => const SpadesPreview(),
    rules: const [
      'Four players: you and a partner (sitting opposite) against two. Two players: each for yourself, and you '
          'draw your cards instead of being dealt them.',
      'Bid how many tricks you think you can win, or Nil: none at all, for a big bonus.',
      "Follow the suit that was led if you can. Spades always win; you can't lead them until one has been played.",
      'Make your bid to score 10 a trick; miss it and lose 10 a trick. Extra tricks are bags: 10 of them cost 100.',
    ],
    // Bot games at 250: ~4 hands of 13 tricks.
    minutes: (players) => players == 2 ? 12 : 14,
    atHome: spadesAtHome,
    playerCounts: const {2, 4},
    choice: const GameChoice(
      label: 'Play to',
      values: [150, 250, 500],
      names: ['Quick', 'Normal', 'Long'],
      initial: 1,
    ),
    opponentsFor: (players) => players == 4 ? 2 : 1,
    open: (setup, stake, target) =>
        SpadesScreen(bots: setup.botCount, difficulty: setup.difficulty, stake: stake, target: target ?? 250),
  ),
  GameInfo(
    id: 'blitz',
    name: 'Blitz',
    blurb: 'Knock down every castle but yours',
    minPlayers: 2,
    maxPlayers: 6,
    color: Toon.red,
    art: (_) => const _FannedCards(['9d', 'As']),
    board: (_) => const BlitzPreview(),
    rules: const [
      'Everyone has a castle: a row of cards, face down except the top. Those are your lives. You also hold 4 cards.',
      'On your turn draw one, then: strike a face-up castle card with the same value, scout (throw a card away to '
          'turn one face up), fortify your own castle, or play a pair to draw two and go again.',
      'Aces in your hand are wild values. Five cards of one colour: BLITZ, knocking down every face-up card in a castle.',
      'Last castle standing wins. 2–4 players use one deck; 5–6 use two, shuffled together.',
    ],
    minutes: (players) => 4 + players * 2,
    atHome: blitzAtHome,
    note: (players) => Blitz.decksFor(players) == 1 ? '1 deck' : '2 decks shuffled together',
    choice: const GameChoice(
      label: 'Wars',
      values: [0, 1],
      names: ['Off', 'On'],
      info: blitzWarsInfo,
      showValues: false,
    ),
    open: (setup, stake, wars) =>
        BlitzScreen(bots: setup.botCount, difficulty: setup.difficulty, stake: stake, wars: wars == 1),
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
