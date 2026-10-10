import 'dart:math';

import '../../../core/cards/cards.dart';
import 'hand_eval.dart';

enum Street { preflop, flop, turn, river, showdown }

enum MoveKind { fold, check, call, raise }

/// A player's decision. For [MoveKind.raise], [amount] is the total the
/// player's bet this street goes up to ("raise to"); a bet into an unopened
/// street is a raise from 0.
class Move {
  const Move.fold() : kind = MoveKind.fold, amount = 0;
  const Move.check() : kind = MoveKind.check, amount = 0;
  const Move.call() : kind = MoveKind.call, amount = 0;
  const Move.raiseTo(this.amount) : kind = MoveKind.raise;

  final MoveKind kind;
  final int amount;

  @override
  String toString() => kind == MoveKind.raise ? 'raise to $amount' : kind.name;
}

/// What a player just did, for the seat's speech bubble.
enum ActionLabel { smallBlind, bigBlind, fold, check, call, bet, raise, allIn }

class LastAction {
  const LastAction(this.label, this.amount);

  final ActionLabel label;

  /// Chips the bet stands at after the action (0 for fold / check).
  final int amount;
}

/// One player in a hand. [seat] is the table seat (clockwise).
class HandPlayer {
  HandPlayer({required this.seat, required this.stack}) : startStack = stack;

  final int seat;
  final int startStack;
  int stack;

  /// Chips put in on the current street.
  int bet = 0;

  /// Chips put in this hand, all streets.
  int committed = 0;

  bool folded = false;
  final List<PlayingCard> hole = [];
  bool _acted = false;
  int _lastActSeq = -1;
  LastAction? lastAction;

  bool get allIn => !folded && stack == 0;

  /// Still has decisions to make this hand.
  bool get canAct => !folded && stack > 0;

  void _pay(int chips) {
    assert(chips >= 0 && chips <= stack);
    stack -= chips;
    bet += chips;
    committed += chips;
  }
}

/// What the player to act may do.
class LegalMoves {
  const LegalMoves({
    required this.canCheck,
    required this.callAmount,
    required this.canRaise,
    required this.minRaiseTo,
    required this.maxRaiseTo,
    required this.isBet,
  });

  final bool canCheck;

  /// Chips needed to call (capped at the stack: calling for less is all-in).
  final int callAmount;

  final bool canRaise;
  final int minRaiseTo;

  /// All-in.
  final int maxRaiseTo;

  /// Nobody has bet this street yet, so a raise is called a bet.
  final bool isBet;
}

/// One pot (main or side) and who took it.
class PotResult {
  const PotResult({required this.amount, required this.eligible, required this.winners, this.hand});

  final int amount;
  final List<int> eligible;

  /// Indexes into [PokerHand.players].
  final List<int> winners;

  /// The winning hand at a showdown, null when everyone else folded or only
  /// one player could win it (an uncalled bet coming back).
  final HandValue? hand;
}

class HandResult {
  const HandResult({required this.pots, required this.shown, required this.winnings});

  final List<PotResult> pots;

  /// Hands that went to showdown, by player index.
  final Map<int, HandValue> shown;

  /// Chips each player got back from the pots, by player index.
  final Map<int, int> winnings;

  bool get showdown => shown.isNotEmpty;
}

/// One hand of no-limit Texas Hold'em.
///
/// Usage: create, then while [result] is null: if [toAct] is set, [apply] that
/// player's move; else (betting round over) call [nextStreet]. The caller
/// paces the steps (dealing animations, bots thinking).
class PokerHand {
  PokerHand({
    required List<HandPlayer> players,
    required this.button,
    required this.smallBlind,
    required this.bigBlind,
    required Random rng,
    Deck? deck,
  }) : players = List.unmodifiable(players),
       _deck = deck ?? Deck.shuffled(rng) {
    assert(players.length >= 2 && players.length <= 10);
    assert(players.every((p) => p.stack > 0));
    _start();
  }

  /// Players in seat order (clockwise).
  final List<HandPlayer> players;

  /// Index of the dealer button in [players].
  final int button;
  final int smallBlind;
  final int bigBlind;
  final Deck _deck;

  late final int smallBlindIndex;
  late final int bigBlindIndex;

  Street street = Street.preflop;
  final List<PlayingCard> board = [];

  /// The bet to match this street.
  int currentBet = 0;

  /// Size of the last full raise this street (a raise must be at least this).
  int minRaise = 0;

  /// Index of the player to act, or null when the betting round is over.
  int? toAct;

  HandResult? result;

  var _seq = 0;
  var _lastFullRaiseSeq = 0;

  bool get headsUp => players.length == 2;

  /// Everything in the middle, current-street bets included.
  int get pot => players.fold(0, (s, p) => s + p.committed);

  /// Pot not counting bets still in front of the players this street.
  int get collectedPot => players.fold(0, (s, p) => s + p.committed - p.bet);

  int get _contenders => players.where((p) => !p.folded).length;

  /// Betting's over with two or more players in and at most one who could
  /// still bet: the hands are turned up and the board runs out.
  bool get isAllInRunout =>
      result == null && toAct == null && _contenders >= 2 && players.where((p) => p.canAct).length <= 1;

  int _next(int i) => (i + 1) % players.length;

  void _start() {
    if (headsUp) {
      // Heads-up: the button posts the small blind and acts first preflop.
      smallBlindIndex = button;
      bigBlindIndex = _next(button);
    } else {
      smallBlindIndex = _next(button);
      bigBlindIndex = _next(smallBlindIndex);
    }
    for (var round = 0; round < 2; round++) {
      for (var k = 1; k <= players.length; k++) {
        players[(button + k) % players.length].hole.add(_deck.draw());
      }
    }
    _post(smallBlindIndex, smallBlind, ActionLabel.smallBlind);
    _post(bigBlindIndex, bigBlind, ActionLabel.bigBlind);
    currentBet = bigBlind;
    minRaise = bigBlind;
    toAct = _firstToAct(_next(bigBlindIndex));
  }

  void _post(int i, int amount, ActionLabel label) {
    final p = players[i];
    p._pay(min(amount, p.stack));
    p.lastAction = LastAction(label, p.bet);
  }

  bool _needsAction(HandPlayer p) => p.canAct && (!p._acted || p.bet < currentBet);

  /// The first player from [from] (inclusive, clockwise) who has to act, or
  /// null when the betting round is complete.
  int? _firstToAct(int from) {
    final able = players.where((p) => p.canAct).toList();
    // Only one player can still bet and nothing to call: no decision left.
    if (able.length <= 1 && (able.isEmpty || able.first.bet >= currentBet)) return null;
    for (var k = 0; k < players.length; k++) {
      final i = (from + k) % players.length;
      if (_needsAction(players[i])) return i;
    }
    return null;
  }

  LegalMoves legalMoves() {
    final i = toAct;
    if (i == null) throw StateError('Nobody to act');
    final p = players[i];
    final toCall = min(currentBet - p.bet, p.stack);
    final maxTo = p.bet + p.stack;
    // A raise needs chips beyond the call, someone left who could call it,
    // and the right to raise (not re-opened by an incomplete all-in).
    final othersCanAct = players.any((o) => o != p && o.canAct);
    final mayRaise = !p._acted || p._lastActSeq < _lastFullRaiseSeq;
    final canRaise = p.stack > toCall && othersCanAct && mayRaise;
    return LegalMoves(
      canCheck: p.bet >= currentBet,
      callAmount: toCall,
      canRaise: canRaise,
      minRaiseTo: min(currentBet + minRaise, maxTo),
      maxRaiseTo: maxTo,
      isBet: currentBet == 0,
    );
  }

  void apply(Move move) {
    final i = toAct;
    if (i == null) throw StateError('Nobody to act');
    final p = players[i];
    final legal = legalMoves();
    switch (move.kind) {
      case MoveKind.fold:
        p.folded = true;
        p.lastAction = const LastAction(ActionLabel.fold, 0);
      case MoveKind.check:
        if (!legal.canCheck) throw ArgumentError('Cannot check facing a bet');
        p.lastAction = const LastAction(ActionLabel.check, 0);
      case MoveKind.call:
        if (legal.canCheck) {
          p.lastAction = const LastAction(ActionLabel.check, 0);
        } else {
          p._pay(legal.callAmount);
          p.lastAction = LastAction(p.allIn ? ActionLabel.allIn : ActionLabel.call, p.bet);
        }
      case MoveKind.raise:
        if (!legal.canRaise) throw ArgumentError('Cannot raise now');
        final to = move.amount.clamp(legal.minRaiseTo, legal.maxRaiseTo);
        final raiseBy = to - currentBet;
        p._pay(to - p.bet);
        if (raiseBy >= minRaise) {
          minRaise = raiseBy;
          _lastFullRaiseSeq = _seq + 1;
        }
        final wasBet = currentBet == 0;
        currentBet = max(currentBet, to);
        p.lastAction = LastAction(
          p.allIn ? ActionLabel.allIn : (wasBet ? ActionLabel.bet : ActionLabel.raise),
          p.bet,
        );
    }
    p._acted = true;
    p._lastActSeq = ++_seq;

    if (_contenders == 1) {
      toAct = null;
      _finish();
      return;
    }
    toAct = _firstToAct(_next(i));
  }

  /// Deals the next street (or settles the showdown after the river). Only
  /// when the betting round is over.
  void nextStreet() {
    if (toAct != null || result != null) throw StateError('Betting round still open');
    for (final p in players) {
      p.bet = 0;
      p._acted = false;
      if (!p.folded && !p.allIn) p.lastAction = null;
    }
    currentBet = 0;
    minRaise = bigBlind;
    switch (street) {
      case Street.preflop:
        _deck.draw(); // burn
        board.addAll([_deck.draw(), _deck.draw(), _deck.draw()]);
        street = Street.flop;
      case Street.flop:
        _deck.draw();
        board.add(_deck.draw());
        street = Street.turn;
      case Street.turn:
        _deck.draw();
        board.add(_deck.draw());
        street = Street.river;
      case Street.river:
        street = Street.showdown;
        _finish();
        return;
      case Street.showdown:
        throw StateError('Hand is over');
    }
    // After the flop the first player left of the button speaks.
    toAct = _firstToAct(_next(button));
  }

  /// Splits the pots and pays the winners.
  void _finish() {
    final contenders = [
      for (var i = 0; i < players.length; i++)
        if (!players[i].folded) i,
    ];
    final shown = <int, HandValue>{};
    if (contenders.length > 1) {
      street = Street.showdown;
      for (final i in contenders) {
        shown[i] = evaluateHand([...players[i].hole, ...board]);
      }
    }

    // Build pots level by level from what each player put in.
    final levels = {for (final p in players) p.committed}.where((c) => c > 0).toList()..sort();
    final pots = <({int amount, List<int> eligible})>[];
    var prev = 0;
    for (final level in levels) {
      var amount = 0;
      for (final p in players) {
        amount += min(p.committed, level) - min(p.committed, prev);
      }
      final eligible = [
        for (final i in contenders)
          if (players[i].committed >= level) i,
      ];
      if (pots.isEmpty && eligible.isEmpty) {
        pots.add((amount: amount, eligible: contenders));
      } else if (eligible.isEmpty || (pots.isNotEmpty && _sameList(pots.last.eligible, eligible))) {
        // Dead money with nobody left at this level, or the same players as
        // the pot below: one pot.
        final last = pots.removeLast();
        pots.add((amount: last.amount + amount, eligible: last.eligible));
      } else {
        pots.add((amount: amount, eligible: eligible));
      }
      prev = level;
    }

    final winnings = <int, int>{};
    final results = <PotResult>[];
    for (final pot in pots) {
      List<int> winners;
      HandValue? hand;
      if (pot.eligible.length == 1) {
        winners = pot.eligible;
      } else {
        final best = pot.eligible.map((i) => shown[i]!.score).reduce(max);
        winners = [
          for (final i in pot.eligible)
            if (shown[i]!.score == best) i,
        ];
        hand = shown[winners.first];
      }
      // Odd chips go to the first winners left of the button.
      winners.sort((a, b) => _fromButton(a).compareTo(_fromButton(b)));
      final share = pot.amount ~/ winners.length;
      var odd = pot.amount - share * winners.length;
      for (final w in winners) {
        final won = share + (odd-- > 0 ? 1 : 0);
        players[w].stack += won;
        winnings[w] = (winnings[w] ?? 0) + won;
      }
      results.add(PotResult(amount: pot.amount, eligible: pot.eligible, winners: winners, hand: hand));
    }
    result = HandResult(pots: results, shown: shown, winnings: winnings);
    toAct = null;
  }

  int _fromButton(int i) => (i - button - 1) % players.length;

  static bool _sameList(List<int> a, List<int> b) =>
      a.length == b.length && Iterable<int>.generate(a.length).every((k) => a[k] == b[k]);
}
