import 'dart:math';

import 'package:duel_engine/difficulty.dart';

/// What a daily challenge counts.
enum ChallengeKind {
  /// Finish [Challenge.goal] games of [Challenge.game].
  play,

  /// Win [Challenge.goal] games of [Challenge.game].
  win,

  /// Finish [Challenge.goal] games of anything.
  playAny,

  /// Win [Challenge.goal] games of anything.
  winAny,

  /// Win a game with pips on it.
  winStaked,

  /// Beat Hard bots.
  winHard,

  /// Play [Challenge.goal] different games.
  variety,
}

/// One of the day's three small goals. No streaks and no timers: whatever
/// you don't finish just goes away at midnight.
class Challenge {
  const Challenge(this.kind, this.goal, this.reward, {this.game, this.gameName});

  final ChallengeKind kind;
  final int goal;
  final int reward;
  final String? game;
  final String? gameName;

  /// "Win 2 games of Go Fish".
  String get title {
    final n = goal == 1 ? 'a game' : '$goal games';
    return switch (kind) {
      ChallengeKind.play when game == 'blackjack' => 'Play $goal hands of Blackjack',
      ChallengeKind.win when game == 'blackjack' => 'Win $goal hands of Blackjack',
      ChallengeKind.play => 'Play $n of $gameName',
      ChallengeKind.win => 'Win $n of $gameName',
      ChallengeKind.playAny => 'Finish $goal games of anything',
      ChallengeKind.winAny => 'Win $goal games of anything',
      ChallengeKind.winStaked => 'Win a game with a stake on it',
      ChallengeKind.winHard => 'Beat Hard bots',
      ChallengeKind.variety => 'Play $goal different games',
    };
  }

  /// How much a finished game moves it on.
  int progress({required String gameId, required bool won, required int stake, Difficulty? difficulty}) =>
      switch (kind) {
        ChallengeKind.play => gameId == game ? 1 : 0,
        ChallengeKind.win => gameId == game && won ? 1 : 0,
        ChallengeKind.playAny => gameId == 'blackjack' ? 0 : 1,
        ChallengeKind.winAny => won && gameId != 'blackjack' ? 1 : 0,
        ChallengeKind.winStaked => won && stake > 0 && gameId != 'blackjack' ? 1 : 0,
        ChallengeKind.winHard => won && difficulty == Difficulty.hard ? 1 : 0,
        ChallengeKind.variety => 0, // counted from the games played today
      };

  /// The three for [day] ("2026-11-22"): the same all day, a new mix
  /// tomorrow. [games] are (id, name) of games you can play with bots.
  static List<Challenge> forDay(String day, [List<(String, String)> games = dailyGames]) {
    var h = 0x811c9dc5;
    for (final u in day.codeUnits) {
      h = ((h ^ u) * 0x01000193) & 0xffffffff;
    }
    final rng = Random(h);
    final picks = [...games]..shuffle(rng);
    final (id, name) = picks.first;
    final (id2, name2) = picks.length > 1 ? picks[1] : picks.first;
    Challenge game(String id, String name, bool win) => id == 'blackjack'
        ? Challenge(win ? ChallengeKind.win : ChallengeKind.play, win ? 3 : 6, win ? 60 : 40, game: id)
        : Challenge(
            win ? ChallengeKind.win : ChallengeKind.play,
            win ? 1 : 2,
            win ? 60 : 40,
            game: id,
            gameName: name,
          );
    final hard = [
      const Challenge(ChallengeKind.winStaked, 1, 75),
      const Challenge(ChallengeKind.winHard, 1, 100),
      const Challenge(ChallengeKind.variety, 3, 75),
      const Challenge(ChallengeKind.winAny, 3, 90),
    ]..shuffle(rng);
    return [
      game(id, name, false),
      rng.nextBool() ? game(id2, name2, true) : const Challenge(ChallengeKind.playAny, 4, 50),
      hard.first,
    ];
  }
}

/// Games a daily challenge can name (ones you can play with bots).
const dailyGames = [
  ('crazy8', 'Crazy Eights'),
  ('gofish', 'Go Fish'),
  ('spades', 'Spades'),
  ('connect4', 'Four in a Row'),
  ('blitz', 'Blitz'),
  ('gops', 'Goofspiel'),
  ('bank', 'Bank!'),
  ('blackjack', 'Blackjack'),
];
