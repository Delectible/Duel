import 'dart:math';

/// What a card in the sea is.
enum SunkKind {
  /// Treasure worth 1..8 (coins, pearls, gems, the idol).
  treasure,

  /// Spare Air: saves you from one bust.
  air,

  /// Boo! The wreck's ghost: every other diver still under draws a card.
  boo,

  /// Hook: steal another diver's best treasure you haven't got.
  hook,

  /// Cut Line: another diver's best treasure sinks back into the sea.
  cut,

  /// Map: peek at the next card, then take it or pass.
  map,
}

class SunkCard {
  const SunkCard(this.kind, [this.value = 0]);

  final SunkKind kind;
  final int value;

  bool get isTreasure => kind == SunkKind.treasure;

  /// Short id: 't5', 'air', 'boo', 'hook', 'cut', 'map'.
  String get id => isTreasure ? 't$value' : kind.name;

  static SunkCard parse(String s) => s.startsWith('t')
      ? SunkCard(SunkKind.treasure, int.parse(s.substring(1)))
      : SunkCard(SunkKind.values.byName(s));

  @override
  bool operator ==(Object o) => o is SunkCard && o.kind == kind && o.value == value;
  @override
  int get hashCode => Object.hash(kind, value);
  @override
  String toString() => id;
}

/// How many of each treasure: the low ones common, the idol rare.
const sunkTreasureCounts = {1: 8, 2: 7, 3: 7, 4: 6, 5: 6, 6: 5, 7: 4, 8: 3};
const sunkSpecialCounts = {
  SunkKind.air: 4,
  SunkKind.boo: 3,
  SunkKind.hook: 3,
  SunkKind.cut: 3,
  SunkKind.map: 3,
};

/// The whole sea, in order (shuffle it).
List<SunkCard> sunkDeck() => [
  for (final e in sunkTreasureCounts.entries)
    for (var i = 0; i < e.value; i++) SunkCard(SunkKind.treasure, e.key),
  for (final e in sunkSpecialCounts.entries)
    for (var i = 0; i < e.value; i++) SunkCard(e.key),
];

/// A run of three in a row in the bag, surfaced: this much more.
const sunkRunBonus = 10;

/// Six different treasures: up you go, with this much more.
const sunkHaulBonus = 20;
const sunkHaulSize = 6;

enum SunkState { diving, surfaced, busted }

/// What happened, for the table to show.
sealed class SunkEvent {
  const SunkEvent(this.player);
  final int player;
}

class SunkDrew extends SunkEvent {
  const SunkDrew(super.player, this.card, {this.forced = false});
  final SunkCard card;

  /// Drawn because of a Boo!.
  final bool forced;
}

class SunkBusted extends SunkEvent {
  const SunkBusted(super.player, this.card, this.lost);
  final SunkCard card;
  final int lost;
}

class SunkSaved extends SunkEvent {
  const SunkSaved(super.player, this.card);
  final SunkCard card;
}

class SunkSurfaced extends SunkEvent {
  const SunkSurfaced(super.player, this.points, {this.run = false, this.haul = false});
  final int points;
  final bool run, haul;
}

class SunkBoo extends SunkEvent {
  const SunkBoo(super.player, this.victims);
  final List<int> victims;
}

class SunkHooked extends SunkEvent {
  const SunkHooked(super.player, this.from, this.card);
  final int from;
  final SunkCard? card;
}

class SunkCut extends SunkEvent {
  const SunkCut(super.player, this.target, this.card);
  final int target;
  final SunkCard? card;
}

class SunkPeeked extends SunkEvent {
  const SunkPeeked(super.player, {required this.took});
  final bool took;
}

class SunkRoundOver extends SunkEvent {
  const SunkRoundOver(super.player, this.round);
  final int round;
}

/// Sunk: rounds of diving to a haunted wreck. On your turn, draw a card
/// from the sea or surface with your bag. A treasure you already hold
/// busts you (your bag's lost) unless you've Spare Air. Five different
/// treasures surface you with a bonus; a run of three in a row adds more.
/// Specials: Boo! (the others still under draw one), Hook (steal another's
/// best treasure you haven't got: careful, it can't bust you, but it
/// fills your bag), Cut Line (another's best treasure sinks), Map (peek,
/// then take it or pass). The round ends when nobody's under; first to
/// the target after a round wins (the most, if several).
///
/// The sea is dealt once and only reshuffled (from what's been played)
/// when it runs out, so what's gone is worth counting.
class SunkGame {
  SunkGame({required this.players, required List<SunkCard> sea, this.target = 120, int first = 0})
    : sea = [...sea],
      scores = List.filled(players, 0),
      bags = List.generate(players, (_) => <SunkCard>[]),
      air = List.filled(players, 0),
      state = List.filled(players, SunkState.diving),
      starter = first % players,
      turn = first % players;

  final int players;
  final int target;

  /// Top of the sea is the last card.
  final List<SunkCard> sea;
  final List<SunkCard> discard = [];

  /// Called to shuffle the discard back in when the sea runs dry.
  void Function(List<SunkCard> cards)? reshuffle;

  /// Online, on a phone: where the next card comes from (the referee's
  /// list of cards drawn so far; null = none was left), instead of [sea].
  SunkCard? Function()? source;

  /// Online, on a phone: the card a Map shows (only the one who drew it
  /// is told), instead of the sea's top.
  SunkCard? Function()? peekAt;

  /// Every card taken from the sea, in order (null: there was none left).
  final List<SunkCard?> taken = [];

  final List<int> scores;
  final List<List<SunkCard>> bags;
  final List<int> air;
  final List<SunkState> state;

  int round = 1;
  int starter;
  int turn;

  /// Waiting on [turn]: a target for Hook or Cut Line, or take / pass for a
  /// Map (the peeked card is the sea's top).
  SunkKind? pending;

  bool isOver = false;
  final List<SunkEvent> events = [];

  bool diving(int p) => state[p] == SunkState.diving;
  Iterable<int> get divers sync* {
    for (var p = 0; p < players; p++) {
      if (diving(p)) yield p;
    }
  }

  int bagValue(int p) => bags[p].fold(0, (a, c) => a + c.value);
  bool holds(int p, int v) => bags[p].any((c) => c.value == v);
  bool hasRun(int p) {
    final vs = {for (final c in bags[p]) c.value};
    return vs.any((v) => vs.contains(v + 1) && vs.contains(v + 2));
  }

  /// What surfacing now would bank.
  int worth(int p) => bagValue(p) + (hasRun(p) ? sunkRunBonus : 0);

  /// Who the current special can be aimed at.
  List<int> get targets {
    final k = pending;
    if (k != SunkKind.hook && k != SunkKind.cut) return const [];
    return [
      for (var q = 0; q < players; q++)
        if (q != turn && diving(q) && _best(q, forHook: k == SunkKind.hook) != null) q,
    ];
  }

  /// Another's best treasure to take: for Hook, one [turn] doesn't hold.
  SunkCard? _best(int q, {required bool forHook}) {
    final cards = [
      for (final c in bags[q])
        if (!forHook || !holds(turn, c.value)) c,
    ]..sort((a, b) => b.value.compareTo(a.value));
    return cards.firstOrNull;
  }

  SunkCard? get peeked {
    if (pending != SunkKind.map) return null;
    final at = peekAt;
    if (at != null) return at();
    _refill();
    return sea.isNotEmpty ? sea.last : null;
  }

  /// The card on top (refilling the sea if needed); null if there's none.
  SunkCard? _take() {
    final src = source;
    if (src != null) {
      final c = src();
      taken.add(c);
      return c;
    }
    _refill();
    final c = sea.isEmpty ? null : sea.removeLast();
    taken.add(c);
    return c;
  }

  void _refill() {
    if (sea.isEmpty && discard.isNotEmpty) {
      final back = [...discard];
      discard.clear();
      reshuffle?.call(back);
      sea.addAll(back);
    }
  }

  void _need(bool ok, String why) {
    if (!ok) throw StateError(why);
  }

  // --- Moves ----------------------------------------------------------------------

  void draw(int p) {
    _need(!isOver && p == turn && diving(p) && pending == null, 'Not your draw');
    final c = _take();
    if (c == null) {
      // Nothing left anywhere: up you come.
      surface(p);
      return;
    }
    _resolve(p, c);
    if (pending == null) _next();
  }

  void surface(int p) {
    _need(!isOver && p == turn && diving(p) && pending == null, 'Not your turn');
    _bank(p);
    _next();
  }

  /// Aims the Hook or Cut Line at [q].
  void aim(int p, int q) {
    _need(p == turn && (pending == SunkKind.hook || pending == SunkKind.cut), 'Nothing to aim');
    _need(targets.contains(q), 'Not a target');
    final hook = pending == SunkKind.hook;
    final card = _best(q, forHook: hook)!;
    bags[q].remove(card);
    if (hook) {
      events.add(SunkHooked(p, q, card));
      pending = null;
      bags[p].add(card);
      _checkHaul(p);
    } else {
      events.add(SunkCut(p, q, card));
      pending = null;
      // It sinks: to the bottom of the sea.
      sea.insert(0, card);
    }
    _next();
  }

  /// After a Map: take the top card, or pass (it stays on top).
  void chart(int p, {required bool take}) {
    _need(p == turn && pending == SunkKind.map, 'No map out');
    pending = null;
    events.add(SunkPeeked(p, took: take));
    if (take) {
      final c = _take();
      if (c != null) _resolve(p, c);
      if (pending != null) return;
    }
    _next();
  }

  void _resolve(int p, SunkCard c, {bool forced = false}) {
    events.add(SunkDrew(p, c, forced: forced));
    switch (c.kind) {
      case SunkKind.treasure:
        if (holds(p, c.value)) {
          if (air[p] > 0) {
            air[p]--;
            discard.add(c);
            events.add(SunkSaved(p, c));
          } else {
            final lost = bagValue(p);
            discard
              ..addAll(bags[p])
              ..add(c);
            bags[p].clear();
            state[p] = SunkState.busted;
            events.add(SunkBusted(p, c, lost));
          }
        } else {
          bags[p].add(c);
          _checkHaul(p);
        }
      case SunkKind.air:
        air[p]++;
        discard.add(c);
      case SunkKind.boo:
        discard.add(c);
        if (forced) return;
        final victims = [
          for (var i = 1; i < players; i++)
            if (diving((p + i) % players)) (p + i) % players,
        ];
        events.add(SunkBoo(p, victims));
        for (final q in victims) {
          if (!diving(q)) continue;
          final d = _take();
          if (d == null) break;
          // Specials drawn in a fright just float away (Spare Air's kept).
          if (d.isTreasure || d.kind == SunkKind.air) {
            _resolve(q, d, forced: true);
          } else {
            events.add(SunkDrew(q, d, forced: true));
            discard.add(d);
          }
        }
      case SunkKind.hook:
      case SunkKind.cut:
        discard.add(c);
        if (forced) return;
        pending = c.kind;
        if (targets.isEmpty) pending = null;
      case SunkKind.map:
        discard.add(c);
        if (forced) return;
        pending = SunkKind.map;
    }
  }

  void _checkHaul(int p) {
    if (diving(p) && {for (final c in bags[p]) c.value}.length >= sunkHaulSize) {
      _bank(p, haul: true);
    }
  }

  void _bank(int p, {bool haul = false}) {
    final run = hasRun(p);
    final pts = bagValue(p) + (run ? sunkRunBonus : 0) + (haul ? sunkHaulBonus : 0);
    scores[p] += pts;
    discard.addAll(bags[p]);
    bags[p].clear();
    state[p] = SunkState.surfaced;
    events.add(SunkSurfaced(p, pts, run: run, haul: haul));
  }

  void _next() {
    if (divers.isEmpty) return _endRound();
    for (var i = 1; i <= players; i++) {
      final q = (turn + i) % players;
      if (diving(q)) {
        turn = q;
        return;
      }
    }
  }

  void _endRound() {
    events.add(SunkRoundOver(turn, round));
    if (scores.any((s) => s >= target)) {
      isOver = true;
      return;
    }
    round++;
    starter = (starter + 1) % players;
    turn = starter;
    for (var p = 0; p < players; p++) {
      state[p] = SunkState.diving;
    }
  }

  List<int> get winners {
    final top = scores.reduce(max);
    return [
      for (var p = 0; p < players; p++)
        if (scores[p] == top) p,
    ];
  }

  // --- Reading the sea -----------------------------------------------------------

  /// What's left to come, as far as anyone can tell: the whole deck less
  /// what's in bags and the discard (and not counting the order).
  Map<String, int> unseen() {
    final left = <String, int>{};
    for (final c in sunkDeck()) {
      left[c.id] = (left[c.id] ?? 0) + 1;
    }
    for (final c in [...discard, for (final b in bags) ...b]) {
      left[c.id] = (left[c.id] ?? 1) - 1;
    }
    return left;
  }

  /// The chance [p]'s next draw busts them (Spare Air counts as safe).
  double bustChance(int p) {
    if (air[p] > 0) return 0;
    final left = unseen();
    final total = left.values.fold(0, (a, b) => a + max(0, b));
    if (total == 0) return 0;
    var bad = 0;
    for (final c in bags[p]) {
      bad += max(0, left['t${c.value}'] ?? 0);
    }
    return bad / total;
  }
}
