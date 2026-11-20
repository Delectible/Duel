import 'dart:math';

import '../cards.dart';

/// A card's worth in Goofspiel: Ace 1, 2-10 their number, Jack 11, Queen 12,
/// King 13.
int gopsValue(int rank) => rank == 14 ? 1 : rank;

/// The rank of a card worth [value].
int gopsRank(int value) => value == 1 ? 14 : value;

/// The suit each seat bids with (diamonds are the prizes).
const gopsSuits = [Suit.clubs, Suit.spades, Suit.hearts];

/// One prize played out.
class GopsRound {
  const GopsRound({required this.prizes, required this.bids, required this.winner});

  /// The prize turned up this time, plus any carried over from ties (worth
  /// values, the newest last).
  final List<int> prizes;

  /// Each seat's bid (worth values).
  final List<int> bids;

  /// Who took the prizes; null = a tie, they carry over.
  final int? winner;

  int get worth => prizes.fold(0, (a, b) => a + b);
}

/// Goofspiel (GOPS): the 13 diamonds are bid for, one at a time, by 2 or 3
/// players each holding a full suit. Highest bid wins the prize; ties carry
/// the prize over to the next winner. Most points wins.
class Goofspiel {
  Goofspiel({required this.players, Random? rng, List<int>? prizeOrder})
    : assert(players >= 2 && players <= 3),
      _prizes = prizeOrder ?? ([for (var v = 1; v <= 13; v++) v]..shuffle(rng ?? Random())),
      hands = [
        for (var p = 0; p < players; p++) {for (var v = 1; v <= 13; v++) v},
      ],
      scores = List.filled(players, 0),
      won = [for (var p = 0; p < players; p++) <int>[]],
      _bids = List.filled(players, null) {
    _turnUp();
  }

  final int players;
  final List<int> _prizes;

  /// The values each seat still holds.
  final List<Set<int>> hands;
  final List<int> scores;

  /// Prize values each seat has won.
  final List<List<int>> won;

  final List<int?> _bids;
  final List<GopsRound> history = [];

  /// Prizes on the table now: the one turned up, after any carried over.
  final List<int> pot = [];

  /// Prizes left face down.
  int get prizesLeft => _prizes.length;

  /// Prize values not yet turned up or on the table (unknown order).
  List<int> get unseen => [..._prizes];

  int get potWorth => pot.fold(0, (a, b) => a + b);

  /// The prize just turned up (the last in the pot).
  int? get prize => pot.isEmpty ? null : pot.last;

  bool get isOver => pot.isEmpty && _prizes.isEmpty;

  bool hasBid(int p) => _bids[p] != null;

  bool get allBid => _bids.every((b) => b != null);

  /// Points thrown away by a tie on the last prize.
  int lost = 0;

  void _turnUp() {
    if (_prizes.isNotEmpty) pot.add(_prizes.removeAt(0));
  }

  /// [p] bids [value] (face down until everyone has). Returns the round once
  /// all bids are in, else null.
  GopsRound? bid(int p, int value) {
    if (isOver || _bids[p] != null || !hands[p].contains(value)) {
      throw StateError('Bad bid: $p $value');
    }
    _bids[p] = value;
    if (!allBid) return null;
    final bids = [for (final b in _bids) b!];
    final top = bids.reduce(max);
    final at = [
      for (var i = 0; i < players; i++)
        if (bids[i] == top) i,
    ];
    final winner = at.length == 1 ? at.single : null;
    final round = GopsRound(prizes: [...pot], bids: bids, winner: winner);
    history.add(round);
    for (var i = 0; i < players; i++) {
      hands[i].remove(bids[i]);
      _bids[i] = null;
    }
    if (winner != null) {
      scores[winner] += round.worth;
      won[winner].addAll(pot);
      pot.clear();
    } else if (_prizes.isEmpty) {
      lost += potWorth;
      pot.clear();
    }
    _turnUp();
    return round;
  }

  /// Everyone with the top score (once it's over).
  List<int> get winners {
    final top = scores.reduce(max);
    return [
      for (var i = 0; i < players; i++)
        if (scores[i] == top) i,
    ];
  }
}
