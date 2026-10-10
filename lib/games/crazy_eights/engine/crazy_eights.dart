import 'dart:math';

import '../../../core/cards/cards.dart';

/// Something that happened, for the commentary line and animations.
sealed class EightsEvent {
  const EightsEvent(this.player);

  final int player;
}

class Played extends EightsEvent {
  const Played(super.player, this.card, {this.chose});

  final PlayingCard card;

  /// The suit picked after an eight.
  final Suit? chose;
}

class Drew extends EightsEvent {
  const Drew(super.player, this.card, {required this.playable});

  final PlayingCard card;

  /// It fits: the player may play it now.
  final bool playable;
}

/// Turn over without playing (drew a card that didn't fit, or kept it).
class Passed extends EightsEvent {
  const Passed(super.player);
}

/// The draw pile ran out: the discards (all but the top) were shuffled in.
class Reshuffled extends EightsEvent {
  const Reshuffled() : super(-1);
}

class Won extends EightsEvent {
  const Won(super.player, {this.blocked = false});

  /// Nobody could play or draw: fewest cards won.
  final bool blocked;
}

/// Crazy Eights, the classic rules: match the top card by suit or number;
/// eights are wild (play on anything, name the next suit); can't or won't
/// play, draw one and play it if it fits, else your turn ends. First to
/// empty their hand wins. Players sit clockwise; 0 is you.
class CrazyEights {
  CrazyEights({required this.players, required this.rng, int? dealer}) {
    assert(players >= 2 && players <= 4);
    final deck = [...PlayingCard.fullDeck]..shuffle(rng);
    final perHand = players == 2 ? 7 : 5;
    hands = [for (var p = 0; p < players; p++) <PlayingCard>[]];
    final d = dealer ?? rng.nextInt(players);
    for (var k = 0; k < perHand; k++) {
      for (var p = 1; p <= players; p++) {
        hands[(d + p) % players].add(deck.removeLast());
      }
    }
    // The starter can't be an eight: bury it and turn another.
    var start = deck.removeLast();
    while (start.rank == 8) {
      deck.insert(rng.nextInt(deck.length + 1), start);
      start = deck.removeLast();
    }
    discard.add(start);
    drawPile.addAll(deck);
    suit = start.suit;
    turn = (d + 1) % players;
  }

  final int players;
  final Random rng;

  late final List<List<PlayingCard>> hands;
  final List<PlayingCard> drawPile = [];
  final List<PlayingCard> discard = [];

  /// The suit to follow: the top card's, or the one named after an eight.
  late Suit suit;

  /// Whose turn it is.
  late int turn;

  /// The card drawn this turn; only it may be played now.
  PlayingCard? drawn;

  int? winner;
  final List<EightsEvent> events = [];

  /// For bots: suits each player drew on (couldn't follow).
  final Map<int, Set<Suit>> lacking = {};

  var _passesInARow = 0;

  PlayingCard get top => discard.last;

  bool get isOver => winner != null;

  /// [card] can go on the pile now.
  bool fits(PlayingCard card) =>
      card.rank == 8 || card.suit == suit || (card.rank == top.rank && top.rank != 8);

  /// What [player] may play right now.
  List<PlayingCard> playable(int player) {
    if (player != turn || isOver) return const [];
    final d = drawn;
    if (d != null) return fits(d) ? [d] : const [];
    return hands[player].where(fits).toList();
  }

  /// Nothing left to draw and nothing to reshuffle.
  bool get _cannotDraw => drawPile.isEmpty && discard.length <= 1;

  bool get canDraw => !isOver && drawn == null && !_cannotDraw;

  /// May end the turn without playing: after drawing, or when there's
  /// nothing to draw.
  bool get canPass => !isOver && (drawn != null || _cannotDraw);

  void play(int player, PlayingCard card, {Suit? chose}) {
    if (player != turn || isOver) throw StateError('Not your turn');
    if (!playable(player).contains(card)) throw ArgumentError('$card does not fit');
    if (card.rank == 8 && chose == null) throw ArgumentError('An eight needs a suit');
    hands[player].remove(card);
    discard.add(card);
    if (card.rank != 8) lacking[player]?.remove(card.suit);
    suit = card.rank == 8 ? chose! : card.suit;
    drawn = null;
    _passesInARow = 0;
    events.add(Played(player, card, chose: card.rank == 8 ? chose : null));
    if (hands[player].isEmpty) {
      winner = player;
      events.add(Won(player));
      return;
    }
    _next();
  }

  /// Draws one card. If it doesn't fit, the turn passes straight away.
  PlayingCard draw(int player) {
    if (player != turn || isOver) throw StateError('Not your turn');
    if (!canDraw) throw StateError('Cannot draw');
    if (drawPile.isEmpty) {
      final keep = discard.removeLast();
      drawPile.addAll(discard..shuffle(rng));
      discard
        ..clear()
        ..add(keep);
      events.add(const Reshuffled());
    }
    final card = drawPile.removeLast();
    hands[player].add(card);
    final ok = fits(card);
    if (!ok) lacking.putIfAbsent(player, () => {}).add(suit);
    events.add(Drew(player, card, playable: ok));
    _passesInARow = 0;
    if (ok) {
      drawn = card;
    } else {
      events.add(Passed(player));
      _next();
    }
    return card;
  }

  /// Ends the turn without playing (keeps a drawn card).
  void pass(int player) {
    if (player != turn || !canPass) throw StateError('Cannot pass');
    drawn = null;
    events.add(Passed(player));
    _passesInARow++;
    if (_cannotDraw && _passesInARow >= players) {
      // Blocked: nobody can play or draw. Fewest cards wins.
      var best = 0;
      for (var p = 1; p < players; p++) {
        if (hands[p].length < hands[best].length) best = p;
      }
      winner = best;
      events.add(Won(best, blocked: true));
      return;
    }
    _next();
  }

  void _next() {
    drawn = null;
    turn = (turn + 1) % players;
  }
}
