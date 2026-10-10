/// Version and revision history (shown in About).
class AppInfo {
  const AppInfo._();

  static const name = 'Duel';
  static const version = '0.4.0';

  /// What changed in this build, in plain words: Google Play's "What's new"
  /// (tool/play/whats_new.py). Replace it every build.
  static const latest =
      'Two new games against bots: Go Fish (2 to 6 players) and Four in a Row. '
      'Pips, your wallet: stake some on a game to win more (harder bots pay more), or play free. '
      'Run out and you can still stake 1 on credit, paid back from winnings. '
      'New profile (name and face) and settings: dark mode and how money is shown.';

  /// About: the main ideas of each version, a few words each.
  static const revisions = <(String, List<String>)>[
    (
      '0.4',
      [
        'Go Fish vs bots',
        'Four in a Row vs a bot',
        'Pips: stake on a game, win more; debt if you run out',
        'Profile: your name and face',
        'Settings: dark mode, currency',
      ],
    ),
    (
      '0.3',
      [
        'Crazy Eights vs bots',
        'How to play guide in every game (?)',
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
