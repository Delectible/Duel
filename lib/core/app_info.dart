/// Version and revision history (shown in About).
class AppInfo {
  const AppInfo._();

  static const name = 'Duel';
  static const version = '0.3.0';

  /// What changed in this build, in plain words: Google Play's "What's new"
  /// (tool/play/whats_new.py). Replace it every build.
  static const latest =
      'Tap your hand under your cards for a poker hands cheat sheet that shows where you stand. '
      "When the deal comes round to you, shuffle the deck and deal. Fixed: the Blinds up! notice now shows.";

  /// About: the main ideas of each version, a few words each.
  static const revisions = <(String, List<String>)>[
    ('0.3', ['Poker hands cheat sheet: see where your hand ranks', 'Shuffle and deal on your deal']),
    (
      '0.2',
      [
        "Texas Hold'em vs bots, 2 to 6 players",
        'Bots or Friend bar: difficulty and bot count',
        'Party screen: who picks the game',
        'Cartoon look',
      ],
    ),
    ('0.1', ['First build: home screen and release pipeline']),
  ];
}
