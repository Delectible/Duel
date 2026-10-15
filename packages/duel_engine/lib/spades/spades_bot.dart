import 'dart:math';

import '../cards.dart';
import '../difficulty.dart';
import 'spades.dart';

/// A Spades bot.
/// - Easy: rough bids, never Nil, often plays any legal card.
/// - Normal: counts its sure tricks, bids Nil on a weak hand, plays
///   sensibly (wins cheaply, lets a winning partner have the trick).
/// - Hard: also remembers every card played (knows which cards are now
///   the highest left), covers a partner's Nil, and ducks once the bid is
///   made so it doesn't collect bags.
class SpadesBot {
  SpadesBot({required this.difficulty, required this.rng});

  final Difficulty difficulty;
  final Random rng;

  bool get _easy => difficulty == Difficulty.easy;
  bool get _hard => difficulty == Difficulty.hard;

  // --- Two-handed draw -----------------------------------------------------

  /// Keep the card on top of the stock, or take the next one instead?
  bool keep(Spades g, int me, PlayingCard card) {
    bool keepIt;
    if (_easy) {
      keepIt = card.rank >= 10 || rng.nextBool();
    } else if (card.suit == Suit.spades) {
      keepIt = card.rank >= (_hard ? 6 : 8);
    } else {
      keepIt = card.rank >= 12;
    }
    // Hard remembers what it threw away: those cards are out of play.
    if (_hard && !keepIt) _remember(g).add(card);
    return keepIt;
  }

  /// Cards this bot knows are out of play this hand (two-handed discards).
  final Set<PlayingCard> _dead = {};
  int _deadHand = -1;

  Set<PlayingCard> _remember(Spades g) {
    if (_deadHand != g.handNumber) {
      _dead.clear();
      _deadHand = g.handNumber;
    }
    return _dead;
  }

  // --- Bidding ---------------------------------------------------------------

  /// How many tricks this hand should win, roughly.
  static double estimate(List<PlayingCard> hand) {
    final bySuit = {
      for (final s in Suit.values) s: hand.where((c) => c.suit == s).map((c) => c.rank).toList(),
    };
    final spades = bySuit[Suit.spades]!;
    var tricks = 0.0;
    // Top spades, then long spades win tricks.
    if (spades.contains(14)) tricks += 1;
    if (spades.contains(13)) tricks += spades.length >= 2 ? 0.9 : 0.4;
    if (spades.contains(12)) tricks += spades.length >= 3 ? 0.7 : 0.2;
    tricks += max(0, spades.length - 3) * 0.85;
    // Side-suit Aces and Kings; short suits let the spades trump.
    var spareSpades = max(0, spades.length - 2);
    for (final s in [Suit.clubs, Suit.diamonds, Suit.hearts]) {
      final r = bySuit[s]!;
      if (r.contains(14)) tricks += r.length <= 5 ? 0.95 : 0.7;
      if (r.contains(13)) tricks += r.length >= 2 ? 0.65 : 0.2;
      if (r.contains(12) && r.length >= 3) tricks += 0.25;
      if (spareSpades > 0 && r.length <= 1) {
        tricks += r.isEmpty ? 0.8 : 0.5;
        spareSpades--;
      }
    }
    return tricks;
  }

  /// A Nil-worthy hand: almost no tricks, nothing high in spades.
  static bool nilHand(List<PlayingCard> hand) {
    final spades = hand.where((c) => c.suit == Suit.spades).toList();
    final highSpade = spades.isEmpty ? 0 : spades.map((c) => c.rank).reduce(max);
    final aces = hand.where((c) => c.rank == 14).length;
    return estimate(hand) < 1.3 && spades.length <= 3 && highSpade <= 10 && aces == 0;
  }

  /// A fair bid for [hand]: the estimate, corrected by bot-only games
  /// (four players win ~0.65 more than it says; two-handed hands are
  /// picked, not dealt, and win ~1.5 more).
  static int suggest(List<PlayingCard> hand, int players) =>
      (estimate(hand) + (players == 4 ? 0.5 : 1.3)).round().clamp(1, 13);

  int bid(Spades g, int me) {
    final hand = g.hands[me];
    // Easy guesses from the raw count, give or take one.
    if (_easy) return (estimate(hand) + rng.nextDouble() * 2 - 1).round().clamp(1, 13);
    final partner = g.partner(me);
    final partnerNil = partner != null && g.bids[partner] == 0;
    // Nil only with a partner to cover it.
    if (g.players == 4 && !partnerNil && nilHand(hand)) return 0;
    var b = suggest(hand, g.players);
    // Hard, near the bag limit, bids a trick fuller.
    if (_hard && g.bagCount[g.team(me)] >= 7) b = (b + 1).clamp(1, 13);
    return b;
  }

  // --- Play --------------------------------------------------------------------

  PlayingCard play(Spades g, int me) {
    final legal = g.legal(me);
    if (legal.length == 1) return legal.single;
    if (_easy && rng.nextDouble() < 0.35) return legal[rng.nextInt(legal.length)];
    final amNil = g.bids[me] == 0;
    final partner = g.partner(me);
    final partnerNil = partner != null && g.bids[partner] == 0;
    final t = g.team(me);
    final need = g.teamBid(t) - g.teamTricks(t);
    // Can we still stop the other side making their bid?
    final left = 13 - g.tricksPlayed;
    final theirNeed = g.teamBid(1 - t) - g.teamTricks(1 - t);
    final canSet = theirNeed > 0 && theirNeed > left - 2;
    // Normal and Easy always want tricks; Hard stops once the bid is made
    // (extra tricks are bags), unless it can set the other side or they're
    // close to winning.
    final wantTricks = !amNil && (need > 0 || !_hard || canSet || g.scores[1 - t] >= g.target - 60);

    if (g.trick.isEmpty) return _lead(g, me, legal, amNil: amNil, wantTricks: wantTricks);

    final led = g.ledSuit!;
    final (curPlayer, curCard) = g.winning!;
    final last = g.trick.length == g.players - 1;
    final winners = legal.where((c) => Spades.beats(c, curCard, led)).toList();
    final losers = legal.where((c) => !Spades.beats(c, curCard, led)).toList();

    if (amNil) {
      // Stay under the winner with the highest card that does; forced to
      // win, win with the highest (get rid of danger).
      if (losers.isNotEmpty) return _highest(losers);
      return _highest(legal);
    }
    final partnerWinning = partner != null && curPlayer == partner;
    // Hard: an opponent bid Nil and hasn't taken a trick: make them.
    final nilTarget = _hard ? _bustableNil(g, me) : null;
    if (nilTarget != null) {
      final theyPlayed = g.trick.any((x) => x.$1 == nilTarget);
      if (theyPlayed && curPlayer == nilTarget && losers.isNotEmpty) {
        return _highest(losers); // leave it with them
      }
      if (!theyPlayed && losers.isNotEmpty) return _lowest(legal); // play under, so they might be forced over
    }
    // Cover a partner's Nil: if they're winning, take it off them.
    if (partnerNil && partnerWinning && _hard && winners.isNotEmpty) return _lowest(winners);
    if (partnerNil && _hard && !g.trick.any((x) => x.$1 == partner) && winners.isNotEmpty) {
      // Partner still to play: win high so they can duck.
      return _highest(winners);
    }
    if (partnerWinning && (last || _boss(g, me, curCard) || curCard.rank >= 13)) {
      return _lowest(legal);
    }
    if (wantTricks && winners.isNotEmpty) {
      if (last) return _lowest(winners);
      // Not last: win with a card that's likely to hold.
      final sameSuit = winners.where((c) => c.suit == led).toList();
      if (sameSuit.isNotEmpty) {
        // Hard: an opponent still to play who's out of this suit will trump
        // it; don't waste a high card into that.
        if (_hard && _trumpComing(g, me, led) && losers.isNotEmpty) return _lowest(losers);
        final boss = sameSuit.where((c) => _boss(g, me, c)).toList();
        return boss.isNotEmpty ? _lowest(boss) : _highest(sameSuit);
      }
      return _lowest(winners); // trump as cheaply as possible
    }
    if (!wantTricks && losers.isNotEmpty) return _highest(losers); // duck, shedding high cards
    return _lowest(legal);
  }

  PlayingCard _lead(
    Spades g,
    int me,
    List<PlayingCard> legal, {
    required bool amNil,
    required bool wantTricks,
  }) {
    if (amNil || !wantTricks) return _lowest(legal);
    // Hard: lead low into an opponent's Nil (in a suit they still have).
    final nilTarget = _hard ? _bustableNil(g, me) : null;
    if (nilTarget != null) {
      final safe = legal.where((c) => !_voids(g).contains((nilTarget, c.suit))).toList();
      if (safe.isNotEmpty) return _lowest(safe);
    }
    // A card nobody can beat in its suit (Hard counts what's gone, and
    // skips suits an opponent can trump).
    final bosses = legal
        .where((c) => c.suit != Suit.spades && _boss(g, me, c) && !(_hard && _opponentVoid(g, me, c.suit)))
        .toList();
    if (bosses.isNotEmpty) return _highest(bosses);
    final aces = legal.where((c) => c.rank == 14).toList();
    if (aces.isNotEmpty) return aces.first;
    // Plenty of trumps: draw out the opponents' spades.
    final spades = legal.where((c) => c.suit == Suit.spades).toList();
    if (spades.length >= 4 && spades.any((c) => _boss(g, me, c))) return _highest(spades);
    // Otherwise lead low from the longest side suit.
    final side = legal.where((c) => c.suit != Suit.spades).toList();
    if (side.isEmpty) return _lowest(legal);
    final counts = <Suit, int>{};
    for (final c in side) {
      counts[c.suit] = (counts[c.suit] ?? 0) + 1;
    }
    final longest = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return _lowest(side.where((c) => c.suit == longest).toList());
  }

  /// Nobody else can beat [c] within its suit: every higher card of the
  /// suit has been played or is in this hand. Normal only trusts Aces
  /// (and Kings after their Ace has gone, which it does notice).
  bool _boss(Spades g, int me, PlayingCard c) {
    if (c.rank == 14) return true;
    if (!_hard) return c.rank == 13 && g.seen.contains(PlayingCard(14, c.suit));
    for (var r = c.rank + 1; r <= 14; r++) {
      final higher = PlayingCard(r, c.suit);
      if (!g.seen.contains(higher) && !g.hands[me].contains(higher) && !_remember(g).contains(higher)) {
        return false;
      }
    }
    return true;
  }

  /// (player, suit) pairs: who has shown they're out of a suit this hand.
  static Set<(int, Suit)> _voids(Spades g) {
    final out = <(int, Suit)>{};
    void scan(List<(int, PlayingCard)> trick) {
      if (trick.isEmpty) return;
      final led = trick.first.$2.suit;
      for (final (p, c) in trick.skip(1)) {
        if (c.suit != led) out.add((p, led));
      }
    }

    for (final e in g.handEvents.whereType<TrickWon>()) {
      scan(e.cards);
    }
    scan(g.trick);
    return out;
  }

  static bool _opponentVoid(Spades g, int me, Suit suit) {
    final voids = _voids(g);
    return [
      for (var p = 0; p < g.players; p++)
        if (g.team(p) != g.team(me)) p,
    ].any((p) => voids.contains((p, suit)));
  }

  /// An opponent still to play this trick is out of [led] (and may trump).
  static bool _trumpComing(Spades g, int me, Suit led) {
    final voids = _voids(g);
    final played = g.trick.map((x) => x.$1).toSet();
    for (var p = 0; p < g.players; p++) {
      if (p == me || played.contains(p) || g.team(p) == g.team(me)) continue;
      if (voids.contains((p, led)) && !voids.contains((p, Suit.spades))) return true;
    }
    return false;
  }

  /// An opponent who bid Nil and hasn't taken a trick yet.
  static int? _bustableNil(Spades g, int me) {
    for (var p = 0; p < g.players; p++) {
      if (g.team(p) != g.team(me) && g.bids[p] == 0 && g.tricksWon[p] == 0) return p;
    }
    return null;
  }

  /// Lowest card, keeping spades (trumps) for later.
  static PlayingCard _lowest(List<PlayingCard> cards) => cards.reduce(
    (a, b) => (a.suit == Suit.spades) != (b.suit == Suit.spades)
        ? (a.suit == Suit.spades ? b : a)
        : (a.rank <= b.rank ? a : b),
  );

  static PlayingCard _highest(List<PlayingCard> cards) => cards.reduce(
    (a, b) => (a.suit == Suit.spades) != (b.suit == Suit.spades)
        ? (a.suit == Suit.spades ? a : b)
        : (a.rank >= b.rank ? a : b),
  );
}
