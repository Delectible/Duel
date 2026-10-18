import 'dart:math';

import '../cards.dart';

/// A card in a castle (home row): face down until revealed.
class CastleCard {
  CastleCard(this.card, {this.faceUp = false});

  final PlayingCard card;
  bool faceUp;

  @override
  String toString() => faceUp ? '$card' : '[$card]';
}

// --- Moves -------------------------------------------------------------------

/// Something a player does on their turn.
sealed class BlitzMove {
  const BlitzMove();
}

/// Match a hand card with an opponent's castle card: both are discarded.
/// Face up: same value, or the hand card is an Ace. Face down: Aces only.
class Strike extends BlitzMove {
  const Strike(this.card, this.target, this.index);
  final PlayingCard card;
  final int target;
  final int index;

  @override
  bool operator ==(Object o) => o is Strike && o.card == card && o.target == target && o.index == index;
  @override
  int get hashCode => Object.hash('strike', card, target, index);
  @override
  String toString() => 'Strike($card -> $target:$index)';
}

/// Discard a hand card and turn an opponent's face-down card face up.
class Scout extends BlitzMove {
  const Scout(this.card, this.target, this.index);
  final PlayingCard card;
  final int target;
  final int index;

  @override
  bool operator ==(Object o) => o is Scout && o.card == card && o.target == target && o.index == index;
  @override
  int get hashCode => Object.hash('scout', card, target, index);
  @override
  String toString() => 'Scout($card -> $target:$index)';
}

/// Match a hand card with one of your own face-up castle cards: both go,
/// and two new cards join your castle (one face down, one face up).
class Fortify extends BlitzMove {
  const Fortify(this.card, this.index);
  final PlayingCard card;
  final int index;

  @override
  bool operator ==(Object o) => o is Fortify && o.card == card && o.index == index;
  @override
  int get hashCode => Object.hash('fortify', card, index);
  @override
  String toString() => 'Fortify($card -> $index)';
}

/// Discard a pair from your hand, draw two, then do something else (once a
/// turn).
class Pair extends BlitzMove {
  const Pair(this.rank);
  final int rank;

  @override
  bool operator ==(Object o) => o is Pair && o.rank == rank;
  @override
  int get hashCode => Object.hash('pair', rank);
  @override
  String toString() => 'Pair($rank)';
}

/// Five cards of one colour: discard them, knock out every face-up card of
/// [target]'s castle, draw five and go again.
class BlitzAttack extends BlitzMove {
  const BlitzAttack({required this.red, required this.target});
  final bool red;
  final int target;

  @override
  bool operator ==(Object o) => o is BlitzAttack && o.red == red && o.target == target;
  @override
  int get hashCode => Object.hash('blitz', red, target);
  @override
  String toString() => 'Blitz(${red ? 'red' : 'black'} -> $target)';
}

/// Nothing at all can be done.
class PassTurn extends BlitzMove {
  const PassTurn();

  @override
  bool operator ==(Object o) => o is PassTurn;
  @override
  int get hashCode => 0;
}

// --- Events ------------------------------------------------------------------

/// Something that happened, for the commentary line and animations.
sealed class BlitzEvent {
  const BlitzEvent(this.player);

  final int player;
}

class TurnStarted extends BlitzEvent {
  const TurnStarted(super.player, {required this.extra});

  /// After a Blitz: a whole extra turn (no draw).
  final bool extra;
}

class Drew extends BlitzEvent {
  const Drew(super.player, this.count);
  final int count;
}

class Struck extends BlitzEvent {
  const Struck(super.player, this.card, this.target, this.hit, {required this.blind});
  final PlayingCard card;
  final int target;

  /// The castle card knocked out.
  final PlayingCard hit;

  /// It was face down (an Ace's blind hit).
  final bool blind;
}

class Scouted extends BlitzEvent {
  const Scouted(super.player, this.card, this.target, this.revealed);
  final PlayingCard card;
  final int target;
  final PlayingCard revealed;
}

class Fortified extends BlitzEvent {
  const Fortified(super.player, this.card, this.matched, this.added);
  final PlayingCard card;
  final PlayingCard matched;

  /// Cards added to the castle (normally 2).
  final int added;
}

class Paired extends BlitzEvent {
  const Paired(super.player, this.rank);
  final int rank;
}

class Blitzed extends BlitzEvent {
  const Blitzed(super.player, this.target, {required this.red, required this.knocked});
  final int target;
  final bool red;

  /// Face-up cards knocked out.
  final int knocked;
}

/// A castle's new top card turned face up.
class Flipped extends BlitzEvent {
  const Flipped(super.player, this.card);
  final PlayingCard card;
}

/// Wars: players showing the same value; [losers] each lost theirs.
class War extends BlitzEvent {
  const War(this.rank, this.fighters, this.losers) : super(-1);
  final int rank;
  final List<int> fighters;
  final List<int> losers;
}

class Passed extends BlitzEvent {
  const Passed(super.player);
}

class Reshuffled extends BlitzEvent {
  const Reshuffled() : super(-1);
}

/// [player]'s castle fell: out, finishing in [place].
class Out extends BlitzEvent {
  const Out(super.player, this.place);
  final int place;
}

class Won extends BlitzEvent {
  const Won(super.player, {this.stalled = false});

  /// The game ran far too long: the biggest castle won.
  final bool stalled;
}

/// Blitz, a game invented by a friend of Luca's: knock down every other
/// castle and keep yours.
///
/// Everyone has a castle (a row of cards, face down except the top) and a
/// hand of 4. On your turn draw one, then do one thing: [Strike] an
/// opponent's face-up card with the same value, [Scout] (discard to turn an
/// opponent's face-down card up), [Fortify] (match your own face-up card
/// and grow your castle), [Pair] (discard a pair, draw two, go on), or
/// [BlitzAttack] with five cards of one colour. An Ace from your hand is a
/// wild value: it matches anything and can hit face-down cards. An Ace in a
/// castle is just an Ace: only another Ace matches it.
/// With [wars] on, matching face-up values across castles fight at once:
/// the smallest castle keeps its card. Last castle standing wins.
///
/// Players sit clockwise; 0 is you. 2-4 players share one deck, 5-6 two.
class Blitz {
  Blitz({
    required this.players,
    required this.rng,
    this.wars = false,
    this.castleSize = 7,
    this.handSize = 4,
    int? first,
  }) : assert(players >= 2 && players <= 6) {
    final deck = [for (var d = 0; d < decksFor(players); d++) ...PlayingCard.fullDeck]..shuffle(rng);
    castles = [for (var p = 0; p < players; p++) <CastleCard>[]];
    hands = [for (var p = 0; p < players; p++) <PlayingCard>[]];
    for (var k = 0; k < castleSize; k++) {
      for (var p = 0; p < players; p++) {
        castles[p].add(CastleCard(deck.removeLast()));
      }
    }
    for (final c in castles) {
      c.last.faceUp = true;
    }
    for (var k = 0; k < handSize; k++) {
      for (var p = 0; p < players; p++) {
        hands[p].add(deck.removeLast());
      }
    }
    drawPile.addAll(deck);
    _settle();
    turn = first ?? rng.nextInt(players);
    _beginTurn(draw: true, extra: false);
  }

  /// Decks shuffled together: one for up to 4 players, two for 5-6.
  static int decksFor(int players) => players <= 4 ? 1 : 2;

  /// A safety net: after this many turns the biggest castle wins.
  static const maxTurns = 400;

  final int players;
  final Random rng;
  final bool wars;
  final int castleSize;
  final int handSize;

  /// Each castle in order; the last card is the top.
  late final List<List<CastleCard>> castles;
  late final List<List<PlayingCard>> hands;
  final List<PlayingCard> drawPile = [];
  final List<PlayingCard> discard = [];

  late int turn;

  /// A pair has been played this turn.
  bool pairUsed = false;

  /// Finishing places of players who are out (1 = winner).
  final Map<int, int> places = {};
  int? winner;
  final List<BlitzEvent> events = [];
  int turns = 0;

  bool get isOver => winner != null;
  bool isOut(int p) => places.containsKey(p);
  List<int> get alive => [
    for (var p = 0; p < players; p++)
      if (!isOut(p)) p,
  ];

  /// Can hand card [a] match castle card [b]? Same value, or [a] is an Ace.
  static bool matches(PlayingCard a, PlayingCard b) => a.rank == b.rank || a.rank == 14;

  int faceUpCount(int p) => castles[p].where((c) => c.faceUp).length;

  /// Everything [p] may do now (just [PassTurn] when there's nothing).
  List<BlitzMove> moves(int p) {
    if (isOver || p != turn) return const [];
    final out = <BlitzMove>[];
    final hand = hands[p];
    final cards = {...hand};
    for (final c in cards) {
      for (final q in alive) {
        if (q == p) continue;
        for (final (i, cc) in castles[q].indexed) {
          if (cc.faceUp) {
            if (matches(c, cc.card)) out.add(Strike(c, q, i));
          } else {
            if (c.rank == 14) out.add(Strike(c, q, i));
            out.add(Scout(c, q, i));
          }
        }
      }
      for (final (i, cc) in castles[p].indexed) {
        if (cc.faceUp && matches(c, cc.card)) out.add(Fortify(c, i));
      }
    }
    if (!pairUsed) {
      final counts = <int, int>{};
      for (final c in hand) {
        counts[c.rank] = (counts[c.rank] ?? 0) + 1;
      }
      for (final e in counts.entries) {
        if (e.value >= 2) out.add(Pair(e.key));
      }
    }
    for (final red in [true, false]) {
      if (hand.where((c) => c.suit.isRed == red).length >= 5) {
        for (final q in alive) {
          if (q != p) out.add(BlitzAttack(red: red, target: q));
        }
      }
    }
    return out.isEmpty ? const [PassTurn()] : out;
  }

  /// Plays [move] for the player whose turn it is.
  void apply(BlitzMove move) {
    if (isOver) throw StateError('The game is over');
    final p = turn;
    if (!moves(p).contains(move)) throw ArgumentError('$move is not allowed now');
    switch (move) {
      case Strike(:final card, :final target, :final index):
        hands[p].remove(card);
        final hit = castles[target].removeAt(index);
        discard
          ..add(card)
          ..add(hit.card);
        events.add(Struck(p, card, target, hit.card, blind: !hit.faceUp));
        _endAction(p, endsTurn: true);
      case Scout(:final card, :final target, :final index):
        hands[p].remove(card);
        discard.add(card);
        final cc = castles[target][index]..faceUp = true;
        events.add(Scouted(p, card, target, cc.card));
        _endAction(p, endsTurn: true);
      case Fortify(:final card, :final index):
        hands[p].remove(card);
        final mine = castles[p].removeAt(index);
        discard
          ..add(card)
          ..add(mine.card);
        var added = 0;
        for (final up in [false, true]) {
          final c = _take();
          if (c == null) break;
          castles[p].add(CastleCard(c, faceUp: up));
          added++;
        }
        events.add(Fortified(p, card, mine.card, added));
        _endAction(p, endsTurn: true);
      case Pair(:final rank):
        for (var k = 0; k < 2; k++) {
          final c = hands[p].firstWhere((c) => c.rank == rank);
          hands[p].remove(c);
          discard.add(c);
        }
        pairUsed = true;
        events.add(Paired(p, rank));
        _drawInto(p, 2);
        _endAction(p, endsTurn: false);
      case BlitzAttack(:final red, :final target):
        final spent = _blitzCards(p, red);
        for (final c in spent) {
          hands[p].remove(c);
          discard.add(c);
        }
        final up = castles[target].where((c) => c.faceUp).toList();
        castles[target].removeWhere((c) => c.faceUp);
        discard.addAll([for (final c in up) c.card]);
        events.add(Blitzed(p, target, red: red, knocked: up.length));
        _drawInto(p, 5);
        _endAction(p, endsTurn: false, extraTurn: true);
      case PassTurn():
        events.add(Passed(p));
        _endAction(p, endsTurn: true);
    }
  }

  /// The five cards a Blitz spends: keep Aces and pairs if possible, spend
  /// the lowest first.
  List<PlayingCard> _blitzCards(int p, bool red) {
    final hand = hands[p];
    final counts = <int, int>{};
    for (final c in hand) {
      counts[c.rank] = (counts[c.rank] ?? 0) + 1;
    }
    int cost(PlayingCard c) => (c.rank == 14 ? 100 : 0) + ((counts[c.rank] ?? 0) >= 2 ? 20 : 0) + c.rank;
    final pool = hand.where((c) => c.suit.isRed == red).toList()..sort((a, b) => cost(a).compareTo(cost(b)));
    return pool.take(5).toList();
  }

  /// After a move: tops face up, wars, knock-outs, then whose turn.
  void _endAction(int p, {required bool endsTurn, bool extraTurn = false}) {
    _settle();
    if (isOver) return;
    if (extraTurn) {
      // Blitz: a whole new turn, without a draw (the five drawn make up
      // for the five spent).
      pairUsed = false;
      _beginTurn(draw: false, extra: true);
      return;
    }
    if (!endsTurn) {
      // After a pair: something else this turn (or nothing, if nothing's left).
      if (moves(p).first is PassTurn) {
        events.add(Passed(p));
        _nextTurn();
      }
      return;
    }
    _nextTurn();
  }

  void _nextTurn() {
    var q = turn;
    do {
      q = (q + 1) % players;
    } while (isOut(q));
    turn = q;
    pairUsed = false;
    _beginTurn(draw: true, extra: false);
  }

  void _beginTurn({required bool draw, required bool extra}) {
    turns++;
    if (turns > maxTurns) {
      _stall();
      return;
    }
    events.add(TurnStarted(turn, extra: extra));
    if (draw) _drawInto(turn, 1);
  }

  /// Turns every castle's top face up, fights wars, knocks out empty
  /// castles. Repeats until nothing changes.
  void _settle() {
    for (var changed = true; changed;) {
      changed = false;
      for (final p in alive) {
        final c = castles[p];
        if (c.isNotEmpty && !c.last.faceUp) {
          c.last.faceUp = true;
          events.add(Flipped(p, c.last.card));
          changed = true;
        }
      }
      if (wars && _war()) changed = true;
    }
    for (final p in alive) {
      if (castles[p].isEmpty) _knockOut(p);
    }
    final left = alive;
    if (left.length == 1 && winner == null) {
      winner = left.single;
      places[winner!] = 1;
      events.add(Won(winner!));
    }
  }

  /// One war, if any: players showing the same value (not Aces). The
  /// smallest castle keeps its card, the rest lose theirs; a tie for
  /// smallest and they all lose. A last card is never lost to a war.
  bool _war() {
    for (var rank = 2; rank <= 13; rank++) {
      final fighters = [
        for (final p in alive)
          if (castles[p].any((c) => c.faceUp && c.card.rank == rank)) p,
      ];
      if (fighters.length < 2) continue;
      final smallest = fighters.map((p) => castles[p].length).reduce(min);
      final keepers = fighters.where((p) => castles[p].length == smallest).toList();
      final losers = [
        for (final p in fighters)
          if ((keepers.length > 1 || !keepers.contains(p)) && castles[p].length > 1) p,
      ];
      if (losers.isEmpty) continue;
      for (final p in losers) {
        final c = castles[p];
        // Lose this value's face-up cards, but never the last card.
        for (var i = c.length - 1; i >= 0 && c.length > 1; i--) {
          if (c[i].faceUp && c[i].card.rank == rank) discard.add(c.removeAt(i).card);
        }
      }
      events.add(War(rank, fighters, losers));
      return true;
    }
    return false;
  }

  void _knockOut(int p) {
    final place = alive.length;
    places[p] = place;
    discard.addAll(hands[p]);
    hands[p].clear();
    events.add(Out(p, place));
  }

  /// Ran far too long: the biggest castles finish highest.
  void _stall() {
    final left = alive..sort((a, b) => castles[b].length.compareTo(castles[a].length));
    for (final (i, p) in left.indexed) {
      places[p] = i + 1;
    }
    winner = left.first;
    events.add(Won(winner!, stalled: true));
  }

  PlayingCard? _take() {
    if (drawPile.isEmpty) {
      if (discard.isEmpty) return null;
      drawPile.addAll(discard..shuffle(rng));
      discard.clear();
      events.add(const Reshuffled());
    }
    return drawPile.removeLast();
  }

  void _drawInto(int p, int n) {
    var got = 0;
    for (var k = 0; k < n; k++) {
      final c = _take();
      if (c == null) break;
      hands[p].add(c);
      got++;
    }
    if (got > 0) events.add(Drew(p, got));
  }
}
