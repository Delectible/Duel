import 'dart:math';

import '../../../core/cards/cards.dart';

/// Spades: a blank template. Pure Dart, no Flutter (like the other
/// engines). So far it only deals; bidding, trick play and scoring are
/// still to come.
///
/// Rules to build towards: four players in two partnerships (two-handed
/// variant for 1 v 1), 13 cards each. Everyone bids how many tricks they'll
/// take; spades are always trump and can't lead until "broken". Make your
/// bid: 10 points per trick bid, +1 per overtrick (a "bag"); 10 bags cost
/// 100. Miss it: lose 10 per trick bid. First team to 500 wins.
class Spades {
  Spades({required this.players, Random? rng, this.dealer = 0})
    : assert(players == 2 || players == 4),
      _rng = rng ?? Random() {
    _deal();
  }

  /// 2 (two-handed) or 4 (partners: seats 0 & 2 v 1 & 3).
  final int players;
  final int dealer;
  final Random _rng;

  late final List<List<PlayingCard>> hands;

  /// Each seat's bid, null until they've bid.
  late final List<int?> bids = List.filled(players, null);

  /// Tricks won this hand, per seat.
  late final List<int> tricks = List.filled(players, 0);

  /// Whose turn it is (bidding starts left of the dealer).
  late int turn = (dealer + 1) % players;

  /// 13 cards each. (Two-handed spades really draws its 13 one at a time,
  /// keeping or discarding; that comes with the rules.)
  void _deal() {
    final deck = Deck.shuffled(_rng);
    hands = [
      for (var p = 0; p < players; p++) [for (var i = 0; i < 13; i++) deck.draw()],
    ];
  }
}
