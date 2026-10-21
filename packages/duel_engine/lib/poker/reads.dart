import 'dart:math';

import '../cards.dart';
import 'hand_eval.dart';
import 'poker_hand.dart';

/// One action at the table, for the hand history and the reads.
class ActionRecord {
  const ActionRecord(this.seat, this.street, this.label, this.to, this.pot);

  /// Table seat.
  final int seat;
  final Street street;
  final ActionLabel label;

  /// Their bet on this street after the action.
  final int to;

  /// The pot before it.
  final int pot;
}

/// A finished hand, for the hand history.
class HandRecord {
  HandRecord({
    required this.number,
    required this.actions,
    required this.board,
    required this.holes,
    required this.shown,
    required this.won,
    required this.pot,
    this.winningHand,
  });

  final int number;
  final List<ActionRecord> actions;
  final List<PlayingCard> board;

  /// Every seat's two cards (the history only shows yours and shown ones).
  final Map<int, List<PlayingCard>> holes;

  /// Seats whose cards were turned up.
  final Set<int> shown;

  /// Seat -> chips won.
  final Map<int, int> won;
  final int pot;

  /// "Two pair, Kings and Sevens", when it went to a showdown.
  final String? winningHand;
}

/// What the table has seen one player do this game. Everything here is
/// public (what anyone at a real table could note down) except the bluff
/// wins, which only the app's end-of-game summary uses.
class PlayerReads {
  int hands = 0;

  /// Put chips in before the flop by choice / raised before the flop.
  int vpip = 0, pfr = 0, threeBets = 0;

  int bets = 0, raises = 0, calls = 0, checks = 0, folds = 0;

  /// As the pre-flop raiser, first in on the flop: chances / bets.
  int cbetChances = 0, cbets = 0;

  /// Faced a bet after the flop / folded to it.
  int facedBets = 0, foldsToBet = 0;

  int showdowns = 0, showdownsWon = 0;

  /// Showdowns after betting the last street / of those, weak hands.
  int aggressiveShowdowns = 0, bluffsShown = 0;

  /// Sizing seen at showdowns: big bets (70%+ of the pot) and how many of
  /// them were strong; the same for small ones.
  int bigBetsShown = 0, bigBetsStrong = 0, smallBetsShown = 0, smallBetsStrong = 0;

  int allIns = 0, handsWon = 0, biggestPot = 0, chipsWon = 0;

  /// Sizing (for tips): first raises before the flop and their size in big
  /// blinds; bets after the flop and their size as a share of the pot.
  int opens = 0, sizedBets = 0;
  double openBlinds = 0, betShare = 0;

  /// Called the big blind before the flop with nobody raising yet.
  int limps = 0;

  /// Times they went on tilt (lost a big pot).
  int tilts = 0;

  /// Private: pots won without a showdown holding very little.
  int bluffWins = 0, bestBluff = 0;

  /// Mood: 0 calm, 1 steaming. Rises after losing a big pot, cools a
  /// little every hand.
  double tilt = 0;

  double get vpipRate => hands == 0 ? 0 : vpip / hands;
  double get pfrRate => hands == 0 ? 0 : pfr / hands;

  /// Bets and raises per call (2+ is aggressive, under 1 passive).
  double get aggression => (bets + raises) / max(1, calls);
  double get cbetRate => cbetChances == 0 ? 0 : cbets / cbetChances;
  double get foldToBetRate => facedBets == 0 ? 0 : foldsToBet / facedBets;
  double get showdownWinRate => showdowns == 0 ? 0 : showdownsWon / showdowns;

  /// Of the times they bet the river and were seen, how often it was a bluff.
  double get bluffRate => aggressiveShowdowns == 0 ? 0 : bluffsShown / aggressiveShowdowns;
}

/// The table's memory for a whole game: everyone's reads plus the last few
/// hands. The table feeds it every action ([observe], before it's applied)
/// and every result ([endHand]); bots read it to adapt, the app to show
/// stats. Seats are table seats (not hand indexes).
class TableReads {
  TableReads(int seats) : players = [for (var i = 0; i < seats; i++) PlayerReads()];

  final List<PlayerReads> players;

  /// The latest hands, newest last.
  final List<HandRecord> history = [];
  static const keep = 20;

  final _actions = <ActionRecord>[];

  /// This hand: who raised last before the flop.
  int? preflopAggressor;

  /// This hand: the last bet or raise (seat and street).
  int? aggressor;
  Street? aggressorStreet;

  /// This hand, per seat: their last bet or raise (street, chips put in by
  /// it, the pot before it).
  final _lastBet = <int, ({Street street, int put, int pot})>{};
  final _vpip = <int>{};
  final _cbetTaken = <int>{};

  /// This hand's actions so far.
  List<ActionRecord> get actions => List.unmodifiable(_actions);

  /// [seat]'s actions this hand.
  Iterable<ActionRecord> actionsOf(int seat) => _actions.where((a) => a.seat == seat);

  /// A new hand: [seats] maps hand index -> table seat.
  void startHand(PokerHand h, List<int> seats) {
    _ended = null;
    _actions.clear();
    _lastBet.clear();
    _vpip.clear();
    _cbetTaken.clear();
    preflopAggressor = aggressor = null;
    aggressorStreet = null;
    for (final s in seats) {
      players[s].hands++;
    }
  }

  /// [m] is about to be played by whoever is to act.
  void observe(PokerHand h, List<int> seats, Move m) {
    final i = h.toAct;
    if (i == null) return;
    final seat = seats[i];
    final p = h.players[i];
    final r = players[seat];
    final legal = h.legalMoves();
    final pot = h.pot;
    final street = h.street;
    final kind = m.kind == MoveKind.call && legal.canCheck ? MoveKind.check : m.kind;
    final to = switch (kind) {
      MoveKind.raise => m.amount.clamp(legal.minRaiseTo, legal.maxRaiseTo),
      MoveKind.call => p.bet + legal.callAmount,
      _ => p.bet,
    };
    final allIn = to >= p.bet + p.stack && kind != MoveKind.fold && kind != MoveKind.check;
    final label = switch (kind) {
      MoveKind.fold => ActionLabel.fold,
      MoveKind.check => ActionLabel.check,
      _ when allIn => ActionLabel.allIn,
      MoveKind.call => ActionLabel.call,
      MoveKind.raise => legal.isBet ? ActionLabel.bet : ActionLabel.raise,
    };
    final aggressive = kind == MoveKind.raise;

    if (street == Street.preflop) {
      if ((kind == MoveKind.call || aggressive) && _vpip.add(seat)) r.vpip++;
      if (kind == MoveKind.call && preflopAggressor == null && legal.callAmount > 0) r.limps++;
      if (aggressive) {
        if (preflopAggressor == null) {
          r.pfr++;
          if (!allIn) {
            r.opens++;
            r.openBlinds += to / h.bigBlind;
          }
        } else {
          r.threeBets++;
        }
        preflopAggressor = seat;
      }
    } else {
      // The pre-flop raiser's first chance on the flop, nobody in yet.
      if (street == Street.flop && seat == preflopAggressor && legal.isBet && _cbetTaken.add(seat)) {
        r.cbetChances++;
        if (aggressive) r.cbets++;
      }
      if (aggressive && legal.isBet && !allIn && pot > 0) {
        r.sizedBets++;
        r.betShare += (to - p.bet) / pot;
      }
      if (!legal.canCheck) {
        r.facedBets++;
        if (kind == MoveKind.fold) r.foldsToBet++;
      }
    }
    switch (kind) {
      case MoveKind.fold:
        r.folds++;
      case MoveKind.check:
        r.checks++;
      case MoveKind.call:
        r.calls++;
      case MoveKind.raise:
        if (legal.isBet) {
          r.bets++;
        } else {
          r.raises++;
        }
    }
    if (allIn) r.allIns++;
    if (aggressive) {
      aggressor = seat;
      aggressorStreet = street;
      _lastBet[seat] = (street: street, put: to - p.bet, pot: pot);
    }
    _actions.add(ActionRecord(seat, street, label, to, pot));
  }

  /// The hand that just ended (until the next starts), for [reveal].
  PokerHand? _ended;
  Street? _lastStreet;

  /// The hand is over ([h.result] set): showdowns, sizing tells, winners,
  /// moods, and the hand goes into the history. [mucked] (hand indexes)
  /// lost a showdown without turning their cards up: nobody learns them.
  void endHand(PokerHand h, List<int> seats, {required int number, Set<int> mucked = const {}}) {
    final result = h.result;
    if (result == null) return;
    _ended = h;
    final total = result.pots.fold(0, (s, p) => s + p.amount);
    for (final p in players) {
      p.tilt *= 0.75;
    }
    _lastStreet = _actions.where((a) => a.label != ActionLabel.fold).lastOrNull?.street;
    for (final e in result.winnings.entries) {
      if (e.value <= 0) continue;
      final r = players[seats[e.key]];
      r.handsWon++;
      r.chipsWon += e.value;
      r.biggestPot = max(r.biggestPot, total);
    }
    if (result.showdown) {
      for (final e in result.shown.entries) {
        final seat = seats[e.key];
        final r = players[seat];
        final won = (result.winnings[e.key] ?? 0) > 0;
        if (!mucked.contains(e.key)) _readShown(seat, e.value, won: won);
        // Lost a big pot: steaming for a while.
        final p = h.players[e.key];
        if (!won && p.committed >= p.startStack * 0.35 && p.committed > 0) {
          r.tilt = min(1.0, r.tilt + (p.committed >= p.startStack * 0.6 ? 0.7 : 0.45));
          r.tilts++;
        }
      }
    } else {
      // Won without a showdown: was it a bluff? (Private: only the summary.)
      for (final e in result.winnings.entries) {
        if (e.value <= 0) continue;
        final seat = seats[e.key];
        final hole = h.players[e.key].hole;
        if (_lastBet[seat] == null || hole.length < 2) continue;
        if (_weak(hole, h.board)) {
          players[seat].bluffWins++;
          players[seat].bestBluff = max(players[seat].bestBluff, total);
        }
      }
    }
    final main = result.pots.first;
    history.add(
      HandRecord(
        number: number,
        actions: List.of(_actions),
        board: List.of(h.board),
        holes: {for (var i = 0; i < h.players.length; i++) seats[i]: List.of(h.players[i].hole)},
        shown: {
          for (final i in result.shown.keys)
            if (!mucked.contains(i)) seats[i],
        },
        won: {
          for (final e in result.winnings.entries)
            if (e.value > 0) seats[e.key]: e.value,
        },
        pot: total,
        winningHand: main.hand?.describe(),
      ),
    );
    while (history.length > keep) {
      history.removeAt(0);
    }
  }

  /// A hand seen at a showdown: how often they get there and win, and what
  /// they bet the last street with (sizing tells, bluffs).
  void _readShown(int seat, HandValue value, {required bool won}) {
    final r = players[seat];
    r.showdowns++;
    if (won) r.showdownsWon++;
    final strong = value.category.index >= HandCategory.twoPair.index;
    final bet = _lastBet[seat];
    if (bet != null && bet.street == _lastStreet) {
      r.aggressiveShowdowns++;
      if (!won && value.category.index <= HandCategory.pair.index) r.bluffsShown++;
      final big = bet.put >= bet.pot * 0.7;
      if (big) {
        r.bigBetsShown++;
        if (strong) r.bigBetsStrong++;
      } else {
        r.smallBetsShown++;
        if (strong) r.smallBetsStrong++;
      }
    }
  }

  static bool _weak(List<PlayingCard> hole, List<PlayingCard> board) => board.length >= 3
      ? evaluateHand([...hole, ...board]).category == HandCategory.highCard
      : hole[0].rank != hole[1].rank && max(hole[0].rank, hole[1].rank) < 12;

  /// After the hand ([endHand]), [i] turned their cards up after all: a
  /// mucked loser, or a winner everyone folded to. A shown bluff gets
  /// noted (the table will call them lighter); a shown monster too.
  void reveal(PokerHand h, List<int> seats, int i) {
    final result = h.result;
    if (result == null || !identical(h, _ended)) return;
    final seat = seats[i];
    final last = history.lastOrNull;
    if (last == null || last.shown.contains(seat)) return;
    last.shown.add(seat);
    final hole = h.players[i].hole;
    if (hole.length < 2) return;
    if (result.showdown) {
      final value = result.shown[i];
      if (value != null) _readShown(seat, value, won: (result.winnings[i] ?? 0) > 0);
      return;
    }
    // Won with everyone folding: a bet they made, and what it was.
    final bet = _lastBet[seat];
    if (bet == null) return;
    final r = players[seat];
    r.aggressiveShowdowns++;
    final weak = _weak(hole, h.board);
    if (weak) r.bluffsShown++;
    if (bet.put >= bet.pot * 0.7) {
      r.bigBetsShown++;
      if (!weak) r.bigBetsStrong++;
    } else {
      r.smallBetsShown++;
      if (!weak) r.smallBetsStrong++;
    }
  }
}
