import 'dart:math';

import '../../../core/cards/cards.dart';

/// Something that happened, for the commentary and animations.
sealed class FishEvent {
  const FishEvent(this.player);

  final int player;
}

/// [player] asked [target] for [rank]; [given] cards came back (0 = go
/// fish).
class Asked extends FishEvent {
  const Asked(super.player, this.target, this.rank, this.cards);

  final int target;
  final int rank;

  /// The cards handed over (they're shown to the table).
  final List<PlayingCard> cards;

  int get given => cards.length;
}

/// [player] drew from the pond. [lucky]: it was the rank they asked for,
/// so they go again.
class Fished extends FishEvent {
  const Fished(super.player, this.card, {required this.lucky});

  final PlayingCard card;
  final bool lucky;
}

/// [player] put down all four [rank]s.
class Booked extends FishEvent {
  const Booked(super.player, this.rank);

  final int rank;
}

/// [player] had no cards and the pond was empty: they're done.
class SatOut extends FishEvent {
  const SatOut(super.player);
}

class GameEnded extends FishEvent {
  const GameEnded(this.winners) : super(-1);

  final List<int> winners;
}

/// Go Fish. Ask a player for a rank you hold; if they have any they hand
/// them all over and you go again. If not, "Go fish!": draw from the pond;
/// if it's the rank you asked for, go again, else the turn passes. Four of
/// a rank is a book, put down at once. A player with no cards draws one on
/// their turn (none left: they sit out). All 13 books made: most wins.
class GoFish {
  GoFish({required this.players, required this.rng, int? dealer}) {
    assert(players >= 2 && players <= 6);
    final deck = [...PlayingCard.fullDeck]..shuffle(rng);
    final perHand = players <= 3 ? 7 : 5;
    hands = [for (var p = 0; p < players; p++) <PlayingCard>[]];
    books = [for (var p = 0; p < players; p++) <int>[]];
    final d = dealer ?? rng.nextInt(players);
    for (var k = 0; k < perHand; k++) {
      for (var p = 1; p <= players; p++) {
        hands[(d + p) % players].add(deck.removeLast());
      }
    }
    pond.addAll(deck);
    // Books dealt straight into a hand go down at once.
    for (var p = 0; p < players; p++) {
      _checkBooks(p);
    }
    turn = (d + 1) % players;
    _startTurn();
  }

  final int players;
  final Random rng;
  late final List<List<PlayingCard>> hands;
  late final List<List<int>> books;
  final List<PlayingCard> pond = [];
  late int turn;

  /// After a miss: the asker must draw from the pond ([fish]).
  bool mustFish = false;

  /// The rank asked for, so a lucky draw is known.
  int? _asked;

  List<int>? winners;
  final List<FishEvent> events = [];

  bool get isOver => winners != null;

  int get booksMade => books.fold(0, (s, b) => s + b.length);

  /// Ranks [player] can ask for (ranks they hold).
  Set<int> askable(int player) => {for (final c in hands[player]) c.rank};

  /// Players [player] can ask (others still holding cards).
  List<int> targets(int player) => [
    for (var p = 0; p < players; p++)
      if (p != player && hands[p].isNotEmpty) p,
  ];

  int count(int player, int rank) => hands[player].where((c) => c.rank == rank).length;

  /// Asks [target] for [rank]. Returns how many came back.
  int ask(int player, int target, int rank) {
    if (isOver || player != turn || mustFish) throw StateError('Not your turn to ask');
    if (!askable(player).contains(rank)) throw ArgumentError('You must hold the rank you ask for');
    if (!targets(player).contains(target)) throw ArgumentError('Ask someone holding cards');
    final got = hands[target].where((c) => c.rank == rank).toList();
    hands[target].removeWhere((c) => c.rank == rank);
    hands[player].addAll(got);
    events.add(Asked(player, target, rank, got));
    if (got.isNotEmpty) {
      _checkBooks(player);
      _afterGoAgain();
    } else {
      _asked = rank;
      if (pond.isEmpty) {
        // Nothing to fish: the turn just passes.
        _next();
      } else {
        mustFish = true;
      }
    }
    return got.length;
  }

  /// Draws after a miss.
  PlayingCard fish(int player) {
    if (isOver || player != turn || !mustFish) throw StateError('Not fishing');
    final card = pond.removeLast();
    hands[player].add(card);
    final lucky = card.rank == _asked;
    events.add(Fished(player, card, lucky: lucky));
    mustFish = false;
    _asked = null;
    _checkBooks(player);
    if (lucky) {
      _afterGoAgain();
    } else {
      _next();
    }
    return card;
  }

  void _checkBooks(int p) {
    for (final rank in askable(p).toList()) {
      if (count(p, rank) == 4) {
        hands[p].removeWhere((c) => c.rank == rank);
        books[p].add(rank);
        events.add(Booked(p, rank));
      }
    }
    if (booksMade == 13) _end();
  }

  void _afterGoAgain() {
    if (isOver) return;
    _startTurn();
  }

  void _next() {
    if (isOver) return;
    turn = (turn + 1) % players;
    _startTurn();
  }

  /// A player out of cards draws one; with none to draw they sit out.
  void _startTurn() {
    for (var guard = 0; guard < players * 2 && !isOver; guard++) {
      if (hands[turn].isNotEmpty && targets(turn).isNotEmpty) return;
      if (hands[turn].isEmpty && pond.isNotEmpty) {
        final card = pond.removeLast();
        hands[turn].add(card);
        events.add(Fished(turn, card, lucky: false));
        if (targets(turn).isNotEmpty) return;
      }
      events.add(SatOut(turn));
      turn = (turn + 1) % players;
    }
    // Nobody can ask anyone: count the books.
    if (!isOver) _end();
  }

  void _end() {
    if (winners != null) return;
    final best = books.map((b) => b.length).reduce(max);
    winners = [
      for (var p = 0; p < players; p++)
        if (books[p].length == best) p,
    ];
    events.add(GameEnded(winners!));
  }
}
