import 'dart:math';

/// The first three rolls of a round are safe: a 7 adds this.
const bankSafeSeven = 70;
const bankSafeRolls = 3;

/// What a roll did.
enum BankRollKind {
  /// Added its total.
  add,

  /// A 7 in the safe rolls: +70.
  safeSeven,

  /// Doubles after the safe rolls: the bank doubled.
  doubled,

  /// A 7 after the safe rolls: the round's over, the bank is lost.
  bust,
}

class BankRoll {
  const BankRoll(
    this.a,
    this.b,
    this.kind, {
    required this.before,
    required this.after,
    required this.number,
  });

  final int a, b;
  final BankRollKind kind;

  /// The bank before and after.
  final int before, after;

  /// 1 = the round's first roll.
  final int number;

  int get sum => a + b;
  bool get doubles => a == b;
}

/// Bank!: rounds of rolling two dice into a shared bank. Anyone can bank
/// at any time to take the bank's total and sit out the rest of the round.
/// After the third roll, a 7 ends the round (unbanked players get nothing)
/// and doubles double the bank. Highest score after the last round wins.
class BankGame {
  BankGame({required this.players, required this.rounds, int firstRoller = 0})
    : assert(players >= 1),
      scores = List.filled(players, 0),
      banked = List.filled(players, false),
      bankedAt = List.filled(players, null),
      roller = firstRoller % players;

  final int players;
  final int rounds;
  final List<int> scores;

  /// Banked this round.
  final List<bool> banked;

  /// What each player banked this round.
  final List<int?> bankedAt;

  /// 1-based.
  int round = 1;

  /// The bank this round.
  int bank = 0;

  /// Rolls this round so far.
  int rolls = 0;

  /// Who rolls next.
  int roller;

  bool roundOver = false;
  bool get isOver => roundOver && round >= rounds;

  /// The last roll (this round), if any.
  BankRoll? last;

  /// Every roll ever, for stats and the story.
  final List<BankRoll> history = [];

  bool get safe => rolls < bankSafeRolls;

  /// Still in (not banked) this round.
  Iterable<int> get stillIn sync* {
    for (var p = 0; p < players; p++) {
      if (!banked[p]) yield p;
    }
  }

  /// Can [p] bank right now? (after at least one roll, while in).
  bool canBank(int p) => !roundOver && !banked[p] && rolls > 0 && bank > 0;

  void bankFor(int p) {
    if (!canBank(p)) throw StateError('$p can\'t bank now');
    banked[p] = true;
    bankedAt[p] = bank;
    scores[p] += bank;
    if (stillIn.isEmpty) {
      roundOver = true;
    } else if (banked[roller]) {
      _nextRoller();
    }
  }

  void _nextRoller() {
    for (var i = 1; i <= players; i++) {
      final p = (roller + i) % players;
      if (!banked[p]) {
        roller = p;
        return;
      }
    }
  }

  /// The roller rolls [a] and [b] (1-6 each).
  BankRoll roll(int a, int b) {
    if (roundOver) throw StateError('Round over');
    final sum = a + b, before = bank;
    rolls++;
    final BankRollKind kind;
    if (rolls <= bankSafeRolls) {
      kind = sum == 7 ? BankRollKind.safeSeven : BankRollKind.add;
      bank += sum == 7 ? bankSafeSeven : sum;
    } else if (sum == 7) {
      kind = BankRollKind.bust;
      bank = 0;
      roundOver = true;
    } else if (a == b) {
      kind = BankRollKind.doubled;
      bank *= 2;
    } else {
      kind = BankRollKind.add;
      bank += sum;
    }
    final r = BankRoll(a, b, kind, before: before, after: bank, number: rolls);
    last = r;
    history.add(r);
    if (!roundOver) _nextRoller();
    return r;
  }

  /// Starts the next round (the dice move on one from who started this one).
  void nextRound() {
    if (!roundOver || isOver) throw StateError('Not yet');
    round++;
    bank = 0;
    rolls = 0;
    last = null;
    roundOver = false;
    for (var p = 0; p < players; p++) {
      banked[p] = false;
      bankedAt[p] = null;
    }
    roller = (round - 1) % players;
  }

  List<int> get winners {
    final top = scores.reduce(max);
    return [
      for (var p = 0; p < players; p++)
        if (scores[p] == top) p,
    ];
  }

  /// Places (0 = first), ties sharing.
  int placeOf(int p) => scores.where((s) => s > scores[p]).length;
}
