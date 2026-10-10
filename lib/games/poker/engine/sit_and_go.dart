import 'dart:math';

import 'poker_hand.dart';

/// Blind levels shared by every table size; the pace differs (see
/// [SitAndGoConfig]).
const blindLevels = <(int, int)>[
  (10, 20), (15, 30), (25, 50), (40, 80), (60, 120), (100, 200), //
  (150, 300), (200, 400), (300, 600), (500, 1000), (800, 1600), //
  (1200, 2400), (2000, 4000), (3000, 6000), (5000, 10000),
];

/// House rules for a table of [players]: everyone starts with 1,500.
///
/// Heads-up hands come round fast, so the blinds go up every 6 hands (3
/// orbits). Bigger tables go slower, about two orbits a level, so a full
/// table doesn't blind out before anyone has played a real hand. Bots-only
/// runs (tool/poker/simulate.dart) last about 25 hands heads-up and 65
/// six-handed.
class SitAndGoConfig {
  const SitAndGoConfig({required this.startingStack, required this.handsPerLevel});

  factory SitAndGoConfig.forPlayers(int players) => switch (players) {
    2 => const SitAndGoConfig(startingStack: 1500, handsPerLevel: 6),
    3 || 4 => const SitAndGoConfig(startingStack: 1500, handsPerLevel: 8),
    _ => const SitAndGoConfig(startingStack: 1500, handsPerLevel: 10),
  };

  final int startingStack;
  final int handsPerLevel;
}

class TablePlayer {
  TablePlayer({required this.seat, required this.name, required this.stack});

  final int seat;
  final String name;
  int stack;

  /// 1 = winner. Set when the player busts (or wins).
  int? place;
}

/// A single-table tournament: everyone buys in once, blinds rise, last one
/// with chips wins. Seat 0 is the human.
class SitAndGo {
  SitAndGo({required List<String> names, required this.config, required this.rng})
    : players = [
        for (var i = 0; i < names.length; i++)
          TablePlayer(seat: i, name: names[i], stack: config.startingStack),
      ] {
    assert(names.length >= 2 && names.length <= 6);
    buttonSeat = rng.nextInt(players.length);
  }

  final SitAndGoConfig config;
  final List<TablePlayer> players;
  final Random rng;

  late int buttonSeat;

  /// Hands dealt so far.
  int handsPlayed = 0;

  PokerHand? hand;

  /// Table seat of each player in [hand], by hand index.
  List<int> handSeats = const [];

  List<TablePlayer> get active => players.where((p) => p.stack > 0).toList();

  bool get isOver => active.length <= 1;

  int get level => min(handsPlayed ~/ config.handsPerLevel, blindLevels.length - 1);

  (int, int) get blinds => blindLevels[level];

  /// Hands left before the blinds go up (null at the top level).
  int? get handsToNextLevel =>
      level >= blindLevels.length - 1 ? null : config.handsPerLevel - handsPlayed % config.handsPerLevel;

  /// The blinds of the next level, if there is one.
  (int, int)? get nextBlinds => level >= blindLevels.length - 1 ? null : blindLevels[level + 1];

  int _nextActiveSeat(int from) {
    for (var k = 1; k <= players.length; k++) {
      final s = (from + k) % players.length;
      if (players[s].stack > 0) return s;
    }
    throw StateError('No players left');
  }

  /// Moves the button and deals a new hand.
  PokerHand startHand() {
    if (isOver) throw StateError('Tournament is over');
    if (handsPlayed > 0 || players[buttonSeat].stack == 0) buttonSeat = _nextActiveSeat(buttonSeat);
    final seats = [
      for (final p in players)
        if (p.stack > 0) p.seat,
    ];
    handSeats = seats;
    final (sb, bb) = blinds;
    return hand = PokerHand(
      players: [for (final s in seats) HandPlayer(seat: s, stack: players[s].stack)],
      button: seats.indexOf(buttonSeat),
      smallBlind: sb,
      bigBlind: bb,
      rng: rng,
    );
  }

  /// Copies the finished hand's stacks back and places anyone who busted.
  /// Returns the seats that busted this hand.
  List<int> finishHand() {
    final h = hand;
    if (h == null || h.result == null) throw StateError('Hand not finished');
    final before = active.length;
    for (final hp in h.players) {
      players[hp.seat].stack = hp.stack;
    }
    // Players busting in the same hand: whoever started it with more chips
    // finishes higher.
    final busted = [
      for (final hp in h.players)
        if (hp.stack == 0) hp,
    ]..sort((a, b) => a.startStack.compareTo(b.startStack));
    var place = before;
    for (final hp in busted) {
      players[hp.seat].place = place--;
    }
    handsPlayed++;
    hand = null;
    if (isOver) active.single.place = 1;
    return [for (final hp in busted) hp.seat];
  }
}
