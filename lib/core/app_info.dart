/// Version and revision history (shown in About).
class AppInfo {
  const AppInfo._();

  static const name = 'Duel';
  static const version = '0.3.0';

  /// What changed in this build, in plain words: Google Play's "What's new"
  /// (tool/play/whats_new.py). Replace it every build.
  static const latest =
      'Tap any game for a preview: the rules, how long it takes, a sample board, then Play! '
      'In poker, tap your hand for a cheat sheet, shuffle and deal on your deal, and showdowns wait '
      "for Next hand so there's time to read who won. Fixed: the Blinds up! notice now shows.";

  /// About: the main ideas of each version, a few words each.
  static const revisions = <(String, List<String>)>[
    (
      '0.3',
      [
        'Poker hands cheat sheet: see where your hand ranks',
        'Shuffle and deal on your deal',
        'Showdowns wait for Next hand',
        'Party votes: a coin toss settles ties',
        'Game previews: rules, time, sample board',
      ],
    ),
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
