/// Version and revision history (shown in About).
class AppInfo {
  const AppInfo._();

  static const name = 'Duel';
  static const version = '0.2.0';

  /// What changed in this build, in plain words: Google Play's "What's new"
  /// (tool/play/whats_new.py). Replace it every build.
  static const latest =
      "Texas Hold'em against bots: a Sit & Go for 2 to 6 players with rising blinds, "
      'bots in four personalities at three difficulties, and a new cartoon look.';

  /// About: the main ideas of each version, a few words each.
  static const revisions = <(String, List<String>)>[
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
