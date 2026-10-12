import 'dart:math';

import '../../../core/cards/cards.dart';

/// What happened, in order: the commentary and animations read these.
sealed class SpadesEvent {
  const SpadesEvent();
}

/// Two-handed draw: [player] kept the card they saw, or passed on it and
/// took the next one.
class Drew extends SpadesEvent {
  const Drew(this.player, {required this.kept});
  final int player;
  final bool kept;
}

/// [bid] tricks; 0 = Nil.
class BidMade extends SpadesEvent {
  const BidMade(this.player, this.bid);
  final int player;
  final int bid;
}

class Played extends SpadesEvent {
  const Played(this.player, this.card);
  final int player;
  final PlayingCard card;
}

/// The first spade of the hand was played.
class SpadesBroken extends SpadesEvent {
  const SpadesBroken(this.player);
  final int player;
}

class TrickWon extends SpadesEvent {
  const TrickWon(this.player, this.cards, this.number);
  final int player;

  /// (player, card) in the order played.
  final List<(int, PlayingCard)> cards;

  /// 1 to 13.
  final int number;
}

class HandScored extends SpadesEvent {
  const HandScored(this.results);
  final List<TeamResult> results;
}

class GameWon extends SpadesEvent {
  const GameWon(this.team);
  final int team;
}

/// How one team (or player, two-handed) did in a hand.
class TeamResult {
  const TeamResult({
    required this.team,
    required this.bid,
    required this.tricks,
    required this.nils,
    required this.contractPoints,
    required this.bags,
    required this.bagPenalty,
    required this.total,
    required this.score,
  });

  final int team;

  /// The non-Nil bids added up.
  final int bid;

  /// Tricks taken by the team's non-Nil players.
  final int tricks;

  /// Each Nil bidder: (player, made it?).
  final List<(int, bool)> nils;

  /// +10 per trick bid if made (plus bags), -10 per trick bid if not.
  final int contractPoints;

  /// Overtricks this hand (each +1, and counted towards the bag penalty).
  final int bags;

  /// -100 if the bags piled up to 10 this hand.
  final int bagPenalty;

  /// This hand's change in score.
  final int total;

  /// Score after the hand.
  final int score;

  bool get made => bid == 0 || tricks >= bid;
}

enum SpadesPhase { draw, bid, play, handOver, gameOver }

/// Spades: 4 players in two partnerships (seats 0 & 2 against 1 & 3), or
/// two-handed (each player for themselves, cards drawn instead of dealt).
/// Pure Dart, no Flutter.
///
/// - Two-handed draw: in turn, look at the top card of the stock and keep
///   it (the next card is thrown away unseen by the other player) or throw
///   it away and take the next. Until both have 13.
/// - Bidding: each player bids the tricks they expect to win, or Nil (0):
///   win no tricks at all for +100 (-100 if you take one).
/// - Play: follow suit if you can; spades are trumps. Spades can't be led
///   until one has been played on another suit (unless that's all you have).
/// - Scoring: make your bid: +10 per trick bid, +1 per extra trick (a bag);
///   every 10 bags costs 100. Miss it: -10 per trick bid. A Nil bidder's
///   tricks don't count towards the partner's bid; they count as bags.
/// - First to [target] wins (higher if both pass it); at -200 you lose.
class Spades {
  Spades({required this.players, this.target = 250, Random? rng, this.dealer = 0})
    : assert(players == 2 || players == 4),
      rng = rng ?? Random() {
    scores = List.filled(teams, 0);
    bagCount = List.filled(teams, 0);
    _startHand();
  }

  final int players;
  final int target;
  final Random rng;

  /// Lose at this score or below.
  static const mercy = -200;

  int dealer;

  int get teams => 2;

  /// Team of [player]: 0 is you (and your partner).
  int team(int player) => players == 4 ? player % 2 : player;

  int? partner(int player) => players == 4 ? (player + 2) % 4 : null;

  late List<List<PlayingCard>> hands;
  late List<int?> bids;
  late List<int> tricksWon;
  late List<int> scores;
  late List<int> bagCount;

  /// Two-handed: the face-down stock still to draw from.
  List<PlayingCard> stock = [];

  /// The trick being played: (player, card) in order.
  List<(int, PlayingCard)> trick = [];

  /// Every card played this hand (card memory for bots).
  final Set<PlayingCard> seen = {};

  var spadesBroken = false;
  var tricksPlayed = 0;
  var phase = SpadesPhase.bid;
  late int turn;
  late int leader;

  /// Hands played so far (1 while playing the first).
  var handNumber = 0;

  int? winner;

  final List<SpadesEvent> events = [];

  /// Where this hand's events start in [events].
  var handStart = 0;

  Iterable<SpadesEvent> get handEvents => events.skip(handStart);

  bool get isOver => phase == SpadesPhase.gameOver;

  void _startHand() {
    handNumber++;
    handStart = events.length;
    hands = [for (var p = 0; p < players; p++) <PlayingCard>[]];
    bids = List.filled(players, null);
    tricksWon = List.filled(players, 0);
    trick = [];
    seen.clear();
    spadesBroken = false;
    tricksPlayed = 0;
    final deck = [...PlayingCard.fullDeck]..shuffle(rng);
    turn = (dealer + 1) % players;
    if (players == 4) {
      for (var i = 0; i < 52; i++) {
        hands[(dealer + 1 + i) % 4].add(deck[i]);
      }
      phase = SpadesPhase.bid;
    } else {
      stock = deck;
      phase = SpadesPhase.draw;
    }
  }

  /// Two-handed: the card [turn] is looking at.
  PlayingCard? get offered => phase == SpadesPhase.draw && stock.isNotEmpty ? stock.first : null;

  /// Two-handed draw: keep the top card (and throw the next away), or throw
  /// it away and take the next. Returns the card that went into the hand.
  PlayingCard draw(int player, {required bool keep}) {
    if (phase != SpadesPhase.draw || player != turn) throw StateError('Not your draw');
    final first = stock.removeAt(0);
    final second = stock.removeAt(0);
    final taken = keep ? first : second;
    hands[player].add(taken);
    events.add(Drew(player, kept: keep));
    turn = 1 - turn;
    if (stock.isEmpty) {
      phase = SpadesPhase.bid;
      turn = (dealer + 1) % players;
    }
    return taken;
  }

  /// Bid [tricks] (0 = Nil).
  void bid(int player, int tricks) {
    if (phase != SpadesPhase.bid || player != turn) throw StateError('Not your bid');
    if (tricks < 0 || tricks > 13) throw ArgumentError('Bid 0 to 13');
    bids[player] = tricks;
    events.add(BidMade(player, tricks));
    turn = (turn + 1) % players;
    if (bids.every((b) => b != null)) {
      phase = SpadesPhase.play;
      leader = (dealer + 1) % players;
      turn = leader;
    }
  }

  Suit? get ledSuit => trick.isEmpty ? null : trick.first.$2.suit;

  /// The cards [player] may play now.
  List<PlayingCard> legal(int player) {
    if (phase != SpadesPhase.play || player != turn) return const [];
    final hand = hands[player];
    final led = ledSuit;
    if (led == null) {
      if (spadesBroken) return hand;
      final other = hand.where((c) => c.suit != Suit.spades).toList();
      return other.isEmpty ? hand : other;
    }
    final follow = hand.where((c) => c.suit == led).toList();
    return follow.isEmpty ? hand : follow;
  }

  /// Does [a] beat [b] with [led] the suit led?
  static bool beats(PlayingCard a, PlayingCard b, Suit led) {
    if (a.suit == b.suit) return a.rank > b.rank;
    if (a.suit == Suit.spades) return true;
    if (b.suit == Suit.spades) return false;
    return a.suit == led;
  }

  /// Who's winning the trick so far: (player, card).
  (int, PlayingCard)? get winning {
    if (trick.isEmpty) return null;
    var best = trick.first;
    for (final t in trick.skip(1)) {
      if (beats(t.$2, best.$2, trick.first.$2.suit)) best = t;
    }
    return best;
  }

  void play(int player, PlayingCard card) {
    if (!legal(player).contains(card)) throw StateError('Can not play $card now');
    hands[player].remove(card);
    trick.add((player, card));
    seen.add(card);
    events.add(Played(player, card));
    if (card.suit == Suit.spades && !spadesBroken) {
      spadesBroken = true;
      events.add(SpadesBroken(player));
    }
    if (trick.length < players) {
      turn = (turn + 1) % players;
      return;
    }
    final (w, _) = winning!;
    tricksWon[w]++;
    tricksPlayed++;
    events.add(TrickWon(w, trick, tricksPlayed));
    trick = [];
    leader = w;
    turn = w;
    if (tricksPlayed == 13) scoreHand();
  }

  /// The team's contract: the non-Nil bids added up.
  int teamBid(int t) => [
    for (var p = 0; p < players; p++)
      if (team(p) == t && (bids[p] ?? 0) > 0) bids[p]!,
  ].fold(0, (a, b) => a + b);

  /// Tricks towards the team's contract (Nil bidders' don't count).
  int teamTricks(int t) => [
    for (var p = 0; p < players; p++)
      if (team(p) == t && bids[p] != 0) tricksWon[p],
  ].fold(0, (a, b) => a + b);

  /// Scores the hand (called after the 13th trick; tests call it directly).
  void scoreHand() {
    final results = <TeamResult>[];
    for (var t = 0; t < teams; t++) {
      final bid = teamBid(t);
      final tricks = teamTricks(t);
      var contract = 0;
      var bags = 0;
      if (bid > 0) {
        if (tricks >= bid) {
          contract = 10 * bid;
          bags = tricks - bid;
        } else {
          contract = -10 * bid;
        }
      } else {
        bags = tricks; // nobody bid tricks: any taken are bags
      }
      final nils = <(int, bool)>[];
      var nilPoints = 0;
      for (var p = 0; p < players; p++) {
        if (team(p) == t && bids[p] == 0) {
          final made = tricksWon[p] == 0;
          nils.add((p, made));
          nilPoints += made ? 100 : -100;
          bags += tricksWon[p];
        }
      }
      bagCount[t] += bags;
      var penalty = 0;
      while (bagCount[t] >= 10) {
        bagCount[t] -= 10;
        penalty -= 100;
      }
      final total = contract + bags + nilPoints + penalty;
      scores[t] += total;
      results.add(
        TeamResult(
          team: t,
          bid: bid,
          tricks: tricks,
          nils: nils,
          contractPoints: contract,
          bags: bags,
          bagPenalty: penalty,
          total: total,
          score: scores[t],
        ),
      );
    }
    events.add(HandScored(results));
    final w = _gameWinner();
    if (w != null) {
      winner = w;
      phase = SpadesPhase.gameOver;
      events.add(GameWon(w));
    } else {
      phase = SpadesPhase.handOver;
    }
  }

  int? _gameWinner() {
    final (a, b) = (scores[0], scores[1]);
    if (a <= mercy && b > mercy) return 1;
    if (b <= mercy && a > mercy) return 0;
    if (a >= target || b >= target) {
      if (a != b) return a > b ? 0 : 1;
    }
    return null;
  }

  /// Deal the next hand (the deal moves one seat left).
  void nextHand() {
    if (phase != SpadesPhase.handOver) throw StateError('Hand not over');
    dealer = (dealer + 1) % players;
    _startHand();
  }
}
