import 'package:duel_engine/scoreboard/scoreboard.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/toon.dart';

/// The players' colours on a scoreboard.
const scoreColors = [
  Color(0xFFE5484D),
  Color(0xFF3E8EF7),
  Color(0xFF30A46C),
  Color(0xFFF5A524),
  Color(0xFF8E4EC6),
  Color(0xFFE93D82),
  Color(0xFF12A594),
  Color(0xFFF76B15),
  Color(0xFF5B5BD6),
  Color(0xFF8D6E4C),
  Color(0xFF697177),
  Color(0xFFBDEE63),
];

Color scoreColor(int i) => scoreColors[i % scoreColors.length];

/// A one-tap score for a game's special moment: [self] to the player
/// tapped, [others] to everyone else ("Shot the moon": 0 / +26).
class QuickScore {
  const QuickScore(this.label, {this.self = 0, this.others = 0, this.icon = Icons.bolt_rounded});
  final String label;
  final int self, others;
  final IconData icon;
}

/// A ready-made scoreboard for a game: its rules for winning, its steps,
/// counter or rounds, its teams, its special scores, and (Spades) a
/// calculator for the round.
class ScorePreset {
  const ScorePreset({
    required this.id,
    required this.name,
    required this.blurb,
    required this.icon,
    this.start = 0,
    this.target,
    this.lowWins = false,
    this.steps = const [1, 5, 10],
    this.mode = ScoreMode.counter,
    this.rounds,
    this.teams,
    this.quick = const [],
    this.calculator,
    this.gameId,
    this.tip,
  });

  final String id, name, blurb;
  final IconData icon;
  final int start;
  final int? target;
  final bool lowWins;
  final List<int> steps;
  final ScoreMode mode;
  final int? rounds;

  /// Team names to start with (partner games), else players.
  final List<String>? teams;
  final List<QuickScore> quick;

  /// A round calculator: 'spades'.
  final String? calculator;

  /// The Duel game it's for (its Play at home guide).
  final String? gameId;

  /// How to score it, in a line.
  final String? tip;

  Map<String, Object?> settings({String? name}) => {
    'name': name ?? this.name,
    'preset': id,
    'start': start,
    'target': target,
    'lowWins': lowWins,
    'steps': steps,
    'mode': mode.name,
    'rounds': rounds,
  };

  static ScorePreset byId(String id) =>
      scorePresets.firstWhere((p) => p.id == id, orElse: () => scorePresets.first);
}

const scorePresets = [
  ScorePreset(
    id: 'free',
    name: 'Counter',
    blurb: 'Tap to count anything',
    icon: Icons.exposure_plus_1_rounded,
  ),
  ScorePreset(
    id: 'rounds',
    name: 'Round by round',
    blurb: 'Everyone\'s score each round, in a table',
    icon: Icons.table_rows_rounded,
    mode: ScoreMode.rounds,
  ),
  ScorePreset(
    id: 'life',
    name: 'Life counter',
    blurb: 'Start at 20 and count down',
    icon: Icons.favorite_rounded,
    start: 20,
    steps: [1, 5],
  ),
  ScorePreset(
    id: 'hearts',
    name: 'Hearts',
    blurb: 'Lowest wins; game over at 100',
    icon: Icons.heart_broken_rounded,
    lowWins: true,
    target: 100,
    mode: ScoreMode.rounds,
    steps: [1, 13],
    quick: [QuickScore('Shot the moon', others: 26, icon: Icons.nightlight_round)],
    tip:
        'Each heart is 1, the queen of spades 13: 26 a hand. Took them all? Shoot the moon: everyone else gets 26.',
  ),
  ScorePreset(
    id: 'spades',
    name: 'Spades',
    blurb: 'Teams, bids and bags, to 500',
    icon: Icons.handshake_rounded,
    target: 500,
    mode: ScoreMode.rounds,
    teams: ['Us', 'Them'],
    calculator: 'spades',
    gameId: 'spades',
    tip:
        'Make your bid: 10 a trick, +1 for each extra (a bag). Miss: lose 10 a trick. 10 bags cost 100. Nil: ±100.',
  ),
  ScorePreset(
    id: 'euchre',
    name: 'Euchre',
    blurb: 'Teams, first to 10',
    icon: Icons.groups_2_rounded,
    target: 10,
    steps: [1, 2, 4],
    teams: ['Us', 'Them'],
    quick: [
      QuickScore('Made it', self: 1, icon: Icons.check_rounded),
      QuickScore('March', self: 2, icon: Icons.directions_walk_rounded),
      QuickScore('Euchred them', self: 2, icon: Icons.gpp_bad_rounded),
      QuickScore('Loner', self: 4, icon: Icons.person_rounded),
    ],
    tip: 'Made it: 1. All five tricks (a march): 2. Stopped the other team: 2. A loner march: 4.',
  ),
  ScorePreset(
    id: 'cribbage',
    name: 'Cribbage',
    blurb: 'Peg to 121',
    icon: Icons.linear_scale_rounded,
    target: 121,
    steps: [1, 2, 3, 4, 6],
    quick: [
      QuickScore('Fifteen', self: 2),
      QuickScore('Pair', self: 2),
      QuickScore('Go', self: 1),
      QuickScore('His nobs', self: 1),
    ],
    tip: 'Fifteens and pairs are 2, runs 1 a card, a go 1, his nobs 1, a flush 4 or 5.',
  ),
  ScorePreset(
    id: 'rummy',
    name: 'Rummy',
    blurb: 'Rounds, first to 100',
    icon: Icons.style_rounded,
    target: 100,
    mode: ScoreMode.rounds,
    tip: 'Whoever goes out scores the cards left in everyone else\'s hands.',
  ),
  ScorePreset(
    id: 'crazy8',
    name: 'Crazy Eights',
    blurb: 'Cards left count against you; 100 and you\'re out',
    icon: Icons.filter_8_rounded,
    lowWins: true,
    target: 100,
    mode: ScoreMode.rounds,
    gameId: 'crazy8',
    tip: 'Cards left in your hand: 8s are 50, faces 10, aces 1, the rest their number.',
  ),
  ScorePreset(
    id: 'gofish',
    name: 'Go Fish',
    blurb: 'Count the books',
    icon: Icons.phishing_rounded,
    steps: [1],
    gameId: 'gofish',
    tip: 'One point a book of four. 13 books in all.',
  ),
  ScorePreset(
    id: 'golf',
    name: 'Golf',
    blurb: 'Nine holes, lowest wins',
    icon: Icons.golf_course_rounded,
    lowWins: true,
    mode: ScoreMode.rounds,
    rounds: 9,
    tip: 'Add up your cards each hole: lowest after nine wins.',
  ),
  ScorePreset(
    id: 'farkle',
    name: 'Farkle',
    blurb: 'Dice, to 10,000',
    icon: Icons.casino_rounded,
    target: 10000,
    steps: [50, 100, 500],
    gameId: 'farkle',
    quick: [
      QuickScore('Three pairs', self: 1500),
      QuickScore('Straight', self: 1500),
      QuickScore('Three 1s', self: 1000),
    ],
    tip: '1 = 100, 5 = 50, three of a kind = face × 100 (1s: 1000), straight or three pairs 1500.',
  ),
  ScorePreset(
    id: 'bank',
    name: 'Bank!',
    blurb: 'Rounds of banked dice',
    icon: Icons.savings_rounded,
    mode: ScoreMode.rounds,
    rounds: 15,
    gameId: 'bank',
  ),
  ScorePreset(
    id: 'yacht',
    name: 'Yacht',
    blurb: 'Five dice, 12 boxes to fill',
    icon: Icons.sailing_rounded,
    mode: ScoreMode.rounds,
    rounds: 12,
    tip:
        'One box a turn: ones to sixes, full house, four of a kind, straights (30 / 30), choice, yacht (50).',
  ),
];

/// What the Spades calculator works out for a team's round: points and
/// bags from a bid, the tricks taken and nil.
({int points, String note}) spadesRound({
  required int bid,
  required int tricks,
  required int bagsBefore,
  bool nil = false,
  bool blindNil = false,
}) {
  var points = 0;
  final notes = <String>[];
  if (nil || blindNil) {
    final worth = blindNil ? 200 : 100;
    points += tricks == 0 ? worth : -worth;
    notes.add('${blindNil ? 'Blind nil' : 'Nil'} ${tricks == 0 ? 'made' : 'broken'}');
    return (points: points, note: notes.join(', '));
  }
  if (tricks >= bid) {
    final bags = tricks - bid;
    points += bid * 10 + bags;
    var total = bagsBefore + bags;
    notes.add('Bid $bid, took $tricks');
    if (total >= 10) {
      points -= 100;
      total -= 10;
      notes.add('10 bags: −100');
    }
  } else {
    points -= bid * 10;
    notes.add('Bid $bid, took $tricks: set');
  }
  return (points: points, note: notes.join(', '));
}

/// The ink colour that reads on a player's colour.
Color onScoreColor(Color c) => Toon.on(c);
