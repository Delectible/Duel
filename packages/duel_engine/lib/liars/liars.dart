import 'dart:math';

/// A bid: at least [count] dice showing [face] among everyone's cups.
class LiarsBid {
  const LiarsBid(this.count, this.face);

  final int count, face;

  Map<String, Object?> toJson() => {'count': count, 'face': face};
  static LiarsBid fromJson(Map<Object?, Object?> j) => LiarsBid(j['count']! as int, j['face']! as int);

  @override
  bool operator ==(Object other) => other is LiarsBid && other.count == count && other.face == face;
  @override
  int get hashCode => Object.hash(count, face);
  @override
  String toString() => '$count × $face';
}

/// House rules.
class LiarsRules {
  const LiarsRules({this.dice = 5, this.onesWild = true, this.spotOn = true});

  /// Dice each player starts with.
  final int dice;

  /// Ones count as every face (and can't be bid on themselves).
  final bool onesWild;

  /// "Spot on": call the bid exactly right to win a die back.
  final bool spotOn;

  Map<String, Object?> toJson() => {'dice': dice, 'onesWild': onesWild, 'spotOn': spotOn};
  static LiarsRules fromJson(Map<Object?, Object?>? j) => j == null
      ? const LiarsRules()
      : LiarsRules(
          dice: (j['dice'] as int? ?? 5).clamp(1, 6),
          onesWild: j['onesWild'] as bool? ?? true,
          spotOn: j['spotOn'] as bool? ?? true,
        );

  /// The faces you can bid on.
  int get lowFace => onesWild ? 2 : 1;
}

/// How a round ended.
enum LiarsCall { liar, spotOn }

/// A round's showdown: who called what on whom, how many there were, and
/// who lost (or, spot on, won back) a die.
class LiarsReveal {
  const LiarsReveal({
    required this.call,
    required this.caller,
    required this.bidder,
    required this.bid,
    required this.found,
    required this.dice,
    required this.loser,
    required this.gainer,
  });

  final LiarsCall call;
  final int caller, bidder;
  final LiarsBid bid;

  /// How many dice matched the bid (wilds included).
  final int found;

  /// Everyone's cups as they were.
  final List<List<int>> dice;

  /// Who lost a die (null: nobody, spot on was right).
  final int? loser;

  /// Who won a die back (spot on).
  final int? gainer;

  bool get bidStood => found >= bid.count;
}

/// What happened, for the table to show.
sealed class LiarsEvent {
  const LiarsEvent();
}

class LiarsRolled extends LiarsEvent {
  const LiarsRolled(this.round, this.starter);
  final int round, starter;
}

class LiarsBidMade extends LiarsEvent {
  const LiarsBidMade(this.player, this.bid);
  final int player;
  final LiarsBid bid;
}

class LiarsCalled extends LiarsEvent {
  const LiarsCalled(this.reveal);
  final LiarsReveal reveal;
}

class LiarsOut extends LiarsEvent {
  const LiarsOut(this.player);
  final int player;
}

/// Liar's Dice: everyone shakes their dice under a cup and looks only at
/// their own. In turn, each raises the bid ("five 4s": at least five dice
/// showing 4 on the whole table) or calls the last bidder a liar. All cups
/// come up: if the bid was short, the bidder loses a die, else the caller
/// does. With [LiarsRules.spotOn], you can instead say the bid is exactly
/// right: get it and you win a die back, miss and you lose one. Out of
/// dice, out of the game; the last with dice wins. The loser of a round
/// starts the next (the next one in if they're out).
class LiarsGame {
  LiarsGame({required this.players, this.rules = const LiarsRules(), int first = 0})
    : counts = List.filled(players, rules.dice),
      dice = List.generate(players, (_) => <int>[]),
      turn = first % players;

  final int players;
  final LiarsRules rules;

  /// Dice each player has left.
  final List<int> counts;

  /// This round's cups (empty until rolled).
  final List<List<int>> dice;

  int turn;
  int round = 0;

  /// The standing bid and who made it.
  LiarsBid? bid;
  int? bidder;

  /// Every bid this round, by whom (bots read them).
  final List<(int, LiarsBid)> bids = [];

  /// The last showdown (until the next roll).
  LiarsReveal? reveal;

  /// Waiting for [roll] (a new round).
  bool get needsRoll => !isOver && (round == 0 || reveal != null);

  final List<LiarsEvent> events = [];

  bool isIn(int p) => counts[p] > 0;
  Iterable<int> get alive sync* {
    for (var p = 0; p < players; p++) {
      if (isIn(p)) yield p;
    }
  }

  bool get isOver => alive.length <= 1;
  int? get winner => isOver ? alive.firstOrNull : null;

  int get totalDice => counts.fold(0, (a, b) => a + b);

  /// Places from the last one out: `[first out, ..., winner]`.
  final List<int> outOrder = [];

  /// Rolls for a new round: [cups] holds each player's dice (an empty list
  /// for those out).
  void roll(List<List<int>> cups) {
    if (!needsRoll) throw StateError('Not between rounds');
    for (var p = 0; p < players; p++) {
      if (cups[p].length != counts[p]) throw StateError('Wrong dice for $p');
      dice[p]
        ..clear()
        ..addAll(cups[p]);
    }
    round++;
    bid = null;
    bidder = null;
    bids.clear();
    reveal = null;
    if (!isIn(turn)) turn = _next(turn);
    events.add(LiarsRolled(round, turn));
  }

  /// A fair roll for everyone still in.
  List<List<int>> rollFor(Random rng) => [
    for (var p = 0; p < players; p++) [for (var i = 0; i < counts[p]; i++) 1 + rng.nextInt(6)],
  ];

  int _next(int p) {
    for (var i = 1; i <= players; i++) {
      final q = (p + i) % players;
      if (isIn(q)) return q;
    }
    return p;
  }

  /// The smallest bids that beat the standing one: one per face, at the
  /// lowest count that's higher.
  bool beats(LiarsBid b) {
    if (b.face < rules.lowFace || b.face > 6 || b.count < 1 || b.count > totalDice) return false;
    final s = bid;
    if (s == null) return true;
    return b.count > s.count || (b.count == s.count && b.face > s.face);
  }

  /// The lowest legal bid on [face].
  LiarsBid? lowest(int face) {
    final s = bid;
    final count = s == null ? 1 : (face > s.face ? s.count : s.count + 1);
    final b = LiarsBid(count, face);
    return beats(b) ? b : null;
  }

  bool get canCall => bid != null && !needsRoll && !isOver;

  void raise(int p, LiarsBid b) {
    if (needsRoll || isOver) throw StateError('No round on');
    if (p != turn) throw StateError('Not your turn');
    if (!beats(b)) throw StateError('That bid does not beat $bid');
    bid = b;
    bidder = p;
    bids.add((p, b));
    events.add(LiarsBidMade(p, b));
    turn = _next(p);
  }

  /// How many dice show [face] (with wilds).
  int countOf(int face) {
    var n = 0;
    for (final cup in dice) {
      for (final d in cup) {
        if (d == face || (rules.onesWild && d == 1 && face != 1)) n++;
      }
    }
    return n;
  }

  /// Calls the standing bid: [call] liar, or spot on.
  LiarsReveal challenge(int p, LiarsCall call) {
    if (!canCall) throw StateError('Nothing to call');
    if (p != turn) throw StateError('Not your turn');
    if (call == LiarsCall.spotOn && !rules.spotOn) throw StateError('Spot on is off');
    final b = bid!, by = bidder!;
    final found = countOf(b.face);
    int? loser, gainer;
    if (call == LiarsCall.liar) {
      loser = found >= b.count ? p : by;
    } else if (found == b.count) {
      if (counts[p] < rules.dice) gainer = p;
    } else {
      loser = p;
    }
    final r = LiarsReveal(
      call: call,
      caller: p,
      bidder: by,
      bid: b,
      found: found,
      dice: [
        for (final c in dice) [...c],
      ],
      loser: loser,
      gainer: gainer,
    );
    reveal = r;
    events.add(LiarsCalled(r));
    if (gainer != null) counts[gainer]++;
    if (loser != null) {
      counts[loser]--;
      if (counts[loser] == 0) {
        outOrder.add(loser);
        events.add(LiarsOut(loser));
        if (isOver) outOrder.add(alive.first);
      }
    }
    // The loser starts the next round (the caller when nobody lost).
    final starter = loser ?? p;
    turn = isIn(starter) ? starter : _next(starter);
    return r;
  }

  /// Chance that at least [need] of [unknown] dice show the face, each with
  /// chance [p].
  static double atLeast(int need, int unknown, double p) {
    if (need <= 0) return 1;
    if (need > unknown) return 0;
    var sum = 0.0;
    for (var k = need; k <= unknown; k++) {
      sum += _choose(unknown, k) * pow(p, k) * pow(1 - p, unknown - k);
    }
    return sum.clamp(0.0, 1.0);
  }

  /// Chance that exactly [need] of [unknown] show it.
  static double exactly(int need, int unknown, double p) {
    if (need < 0 || need > unknown) return 0;
    return _choose(unknown, need) * pow(p, need) * pow(1 - p, unknown - need);
  }

  static double _choose(int n, int k) {
    var r = 1.0;
    for (var i = 1; i <= k; i++) {
      r = r * (n - k + i) / i;
    }
    return r;
  }

  /// The chance one unseen die matches [face].
  double faceChance(int face) => rules.onesWild && face != 1 ? 1 / 3 : 1 / 6;

  /// How many of [p]'s own dice match [face].
  int mine(int p, int face) =>
      dice[p].where((d) => d == face || (rules.onesWild && d == 1 && face != 1)).length;

  /// The odds the standing bid (or [b]) is true, as [p] sees it (their own
  /// cup known, the rest unseen).
  double oddsFor(int p, LiarsBid b) =>
      atLeast(b.count - mine(p, b.face), totalDice - counts[p], faceChance(b.face));
}
