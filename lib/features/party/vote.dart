import 'dart:math';

/// How a party vote came out: one game with the most votes, or a tie
/// between [leaders] for a coin toss to settle.
class VoteResult {
  const VoteResult(this.leaders);

  /// The games with the most votes (one unless tied), in first-voted order.
  final List<String> leaders;

  bool get isTie => leaders.length > 1;

  String? get winner => isTie ? null : leaders.single;
}

/// Counts [votes] (player -> game id). Empty votes is a tie between
/// nothing: callers only tally once everyone has voted.
VoteResult tallyVotes(Map<String, String> votes) {
  final counts = <String, int>{};
  for (final game in votes.values) {
    counts[game] = (counts[game] ?? 0) + 1;
  }
  if (counts.isEmpty) return const VoteResult([]);
  final top = counts.values.reduce(max);
  return VoteResult([
    for (final e in counts.entries)
      if (e.value == top) e.key,
  ]);
}

/// The coin toss for a tie: which of [tied] wins (its index). Online, the
/// server tosses and every phone plays the same animation to this result.
int tossCoin(List<String> tied, Random rng) => rng.nextInt(tied.length);
