import 'dart:math';

import '../cards.dart';

/// Casino blackjack, the house rules:
/// - a 6-deck shoe, reshuffled when the cut card (about 3/4 in) comes out;
/// - the dealer stands on all 17s (soft too) and peeks for blackjack under
///   an Ace or a 10;
/// - blackjack pays 3 to 2; no insurance, no surrender;
/// - double on any first two cards, after a split too;
/// - split pairs (any two 10-value cards count) up to four hands; split
///   Aces get one card each and can't be split again; 21 on a split hand is
///   not a blackjack.
const shoeDecks = 6;
const maxHands = 4;

/// A card's worth: 2-10 their number, Jack / Queen / King 10, Ace 11 (or 1).
int bjValue(PlayingCard c) => c.rank == 14 ? 11 : min(c.rank, 10);

/// Best total of [cards] (Aces 11 while that stays 21 or under) and whether
/// an Ace is still counting 11 (soft).
({int total, bool soft}) bjTotal(List<PlayingCard> cards) {
  var total = 0, aces = 0;
  for (final c in cards) {
    total += bjValue(c);
    if (c.rank == 14) aces++;
  }
  while (total > 21 && aces > 0) {
    total -= 10;
    aces--;
  }
  return (total: total, soft: aces > 0);
}

/// The shoe: [shoeDecks] decks shuffled together, dealt from the top.
class Shoe {
  Shoe(this._rng, {List<PlayingCard>? stacked}) {
    _fill();
    if (stacked != null) _cards.insertAll(0, stacked);
  }

  final Random _rng;
  final List<PlayingCard> _cards = [];
  int _dealt = 0;
  int _cut = 0;

  /// Cards dealt since the shuffle, for the hard bots' count.
  int runningCount = 0;

  void _fill() {
    _cards
      ..clear()
      ..addAll([for (var d = 0; d < shoeDecks; d++) ...PlayingCard.fullDeck])
      ..shuffle(_rng);
    _dealt = 0;
    runningCount = 0;
    _cut = (_cards.length * (0.7 + _rng.nextDouble() * 0.1)).round();
  }

  /// Past the cut card: shuffle before the next round.
  bool get due => _dealt >= _cut;

  /// Shuffles a fresh shoe.
  void shuffle() => _fill();

  int get left => _cards.length - _dealt;

  double get decksLeft => max(0.5, left / 52);

  /// Running count over decks left (Hi-Lo).
  double get trueCount => runningCount / decksLeft;

  PlayingCard draw() {
    if (_dealt >= _cards.length) _fill();
    final c = _cards[_dealt++];
    final v = bjValue(c);
    if (v <= 6) {
      runningCount++;
    } else if (v >= 10) {
      runningCount--;
    }
    return c;
  }
}

enum BjResult { blackjack, win, push, lose, bust }

/// One hand at the table (a split makes more).
class BjHand {
  BjHand(this.bet, {this.fromSplit = false, this.splitAces = false});

  final List<PlayingCard> cards = [];
  int bet;
  final bool fromSplit;
  final bool splitAces;
  bool doubled = false;
  bool stood = false;
  BjResult? result;

  int get total => bjTotal(cards).total;
  bool get soft => bjTotal(cards).soft;
  bool get bust => total > 21;
  bool get blackjack => cards.length == 2 && total == 21 && !fromSplit;
  bool get done => stood || bust || doubled || total == 21 || (splitAces && cards.length >= 2);

  /// Paid back on top of the bet (or lost): +1.5x, +1x, 0, -1x.
  int get net => switch (result) {
    BjResult.blackjack => bet * 3 ~/ 2,
    BjResult.win => bet,
    BjResult.push || null => 0,
    BjResult.lose || BjResult.bust => -bet,
  };
}

/// Moves on your turn.
enum BjMove { hit, stand, double, split }

/// Something that happened, for the table's animations and talk.
sealed class BjEvent {
  const BjEvent();
}

class BjDealt extends BjEvent {
  const BjDealt(this.seat, this.hand, this.card, {this.faceDown = false});

  /// -1 = the dealer.
  final int seat;
  final int hand;
  final PlayingCard card;
  final bool faceDown;
}

class BjMoved extends BjEvent {
  const BjMoved(this.seat, this.hand, this.move);
  final int seat;
  final int hand;
  final BjMove move;
}

class BjBusted extends BjEvent {
  const BjBusted(this.seat, this.hand);
  final int seat;
  final int hand;
}

class BjBlackjack extends BjEvent {
  const BjBlackjack(this.seat);

  /// -1 = the dealer (peeked).
  final int seat;
}

class BjHoleShown extends BjEvent {
  const BjHoleShown(this.card);
  final PlayingCard card;
}

class BjSettled extends BjEvent {
  const BjSettled();
}

/// One round: bets in, cards out, everyone plays, the dealer plays, paid.
/// Seats with a null bet sit this one out.
class BjRound {
  BjRound({required this.shoe, required List<int?> bets})
    : seats = bets.length,
      hands = [
        for (final b in bets) b == null || b <= 0 ? <BjHand>[] : [BjHand(b)],
      ] {
    _deal();
  }

  final Shoe shoe;
  final int seats;
  final List<List<BjHand>> hands;
  final List<PlayingCard> dealer = [];
  final List<BjEvent> events = [];

  /// Whose turn: (seat, hand), or null when it's the dealer's (or over).
  (int, int)? turn;

  bool holeShown = false;
  bool settled = false;

  int get dealerTotal => bjTotal(dealer).total;
  PlayingCard get upCard => dealer.first;
  bool get dealerBlackjack => dealer.length == 2 && dealerTotal == 21;

  /// What the players can see of the dealer: the up card until the hole
  /// card turns.
  int get dealerShowing => holeShown ? dealerTotal : bjValue(upCard);

  bool get playing => turn != null;

  /// Seats in this round.
  Iterable<int> get inPlay sync* {
    for (var s = 0; s < seats; s++) {
      if (hands[s].isNotEmpty) yield s;
    }
  }

  void _deal() {
    for (var pass = 0; pass < 2; pass++) {
      for (final s in inPlay) {
        final c = shoe.draw();
        hands[s].first.cards.add(c);
        events.add(BjDealt(s, 0, c));
      }
      final c = shoe.draw();
      dealer.add(c);
      events.add(BjDealt(-1, 0, c, faceDown: pass == 1));
    }
    for (final s in inPlay) {
      if (hands[s].first.blackjack) events.add(BjBlackjack(s));
    }
    // The dealer peeks under an Ace or a 10: a blackjack ends it at once.
    if (bjValue(upCard) >= 10 && dealerBlackjack) {
      events.add(const BjBlackjack(-1));
      _dealerPlays();
      return;
    }
    _advance(0, 0);
  }

  /// Moves to the next hand still to play, from (seat, hand).
  void _advance(int seat, int hand) {
    for (var s = seat; s < seats; s++) {
      for (var h = s == seat ? hand : 0; h < hands[s].length; h++) {
        final x = hands[s][h];
        if (x.cards.length == 1) {
          // A split hand gets its second card when its turn comes.
          final c = shoe.draw();
          x.cards.add(c);
          events.add(BjDealt(s, h, c));
        }
        if (!x.done) {
          turn = (s, h);
          return;
        }
      }
    }
    turn = null;
    _dealerPlays();
  }

  BjHand get current => hands[turn!.$1][turn!.$2];

  /// The moves open to the hand whose turn it is, given [balance] left to
  /// cover a double or a split (null = no limit).
  List<BjMove> moves({int? balance}) {
    if (turn == null) return const [];
    final h = current;
    final first = h.cards.length == 2;
    final afford = balance == null || balance >= h.bet;
    return [
      BjMove.hit,
      BjMove.stand,
      if (first && afford) BjMove.double,
      if (first &&
          afford &&
          bjValue(h.cards[0]) == bjValue(h.cards[1]) &&
          hands[turn!.$1].length < maxHands &&
          !h.splitAces)
        BjMove.split,
    ];
  }

  void act(BjMove move) {
    final (s, i) = turn!;
    final h = current;
    if (!moves().contains(move)) throw StateError('Can\'t $move now');
    events.add(BjMoved(s, i, move));
    switch (move) {
      case BjMove.hit:
        _hit(s, i);
      case BjMove.stand:
        h.stood = true;
      case BjMove.double:
        h.bet *= 2;
        _hit(s, i);
        h.doubled = true;
      case BjMove.split:
        final aces = h.cards.first.rank == 14;
        final second = BjHand(h.bet, fromSplit: true, splitAces: aces)..cards.add(h.cards.removeLast());
        final first = BjHand(h.bet, fromSplit: true, splitAces: aces)..cards.addAll(h.cards);
        hands[s]
          ..removeAt(i)
          ..insertAll(i, [first, second]);
        // The first gets its second card now.
        final c = shoe.draw();
        first.cards.add(c);
        events.add(BjDealt(s, i, c));
    }
    final now = hands[s][i];
    if (now.done) {
      _advance(s, i + 1);
    }
  }

  void _hit(int s, int i) {
    final c = shoe.draw();
    hands[s][i].cards.add(c);
    events.add(BjDealt(s, i, c));
    if (hands[s][i].bust) events.add(BjBusted(s, i));
  }

  /// Whether the dealer has to draw out (someone still standing who isn't
  /// bust or paid already by a blackjack).
  bool get _dealerNeeded => [for (final s in inPlay) ...hands[s]].any((h) => !h.bust && !h.blackjack);

  void _dealerPlays() {
    holeShown = true;
    events.add(BjHoleShown(dealer[1]));
    if (!dealerBlackjack && _dealerNeeded) {
      while (dealerTotal < 17) {
        final c = shoe.draw();
        dealer.add(c);
        events.add(BjDealt(-1, 0, c));
      }
      if (dealerTotal > 21) events.add(const BjBusted(-1, 0));
    }
    _settle();
  }

  void _settle() {
    final d = dealerTotal, dBust = d > 21;
    for (final s in inPlay) {
      for (final h in hands[s]) {
        h.result = h.bust
            ? BjResult.bust
            : dealerBlackjack
            ? (h.blackjack ? BjResult.push : BjResult.lose)
            : h.blackjack
            ? BjResult.blackjack
            : dBust || h.total > d
            ? BjResult.win
            : h.total == d
            ? BjResult.push
            : BjResult.lose;
      }
    }
    settled = true;
    events.add(const BjSettled());
  }

  /// A seat's change in chips this round (all its hands).
  int net(int seat) => hands[seat].fold(0, (a, h) => a + h.net);

  /// What a seat has on the table now (bets incl. doubles and splits).
  int staked(int seat) => hands[seat].fold(0, (a, h) => a + h.bet);
}
