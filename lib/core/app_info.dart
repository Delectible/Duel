/// Version and revision history (shown in About).
class AppInfo {
  const AppInfo._();

  static const name = 'Duel';
  static const version = '0.4.1';

  /// What changed in this build, in plain words: Google Play's "What's new"
  /// (tool/play/whats_new.py). Replace it every build.
  static const latest =
      'Fixed: holding the stake minus button down to Free no longer leaves it stuck. '
      'The stake row is now labelled "Your stake", shows what you have, and its (i) explains how staking works. '
      'Dark mode: black suits off the cards get a light outline so they stand out. '
      'Spades is on the way: see its rules on the Soon tile.';

  /// About: the main ideas of each version, a few words each.
  static const revisions = <(String, List<String>)>[
    (
      '0.4',
      [
        'Go Fish vs bots',
        'Four in a Row vs a bot',
        'Pips: stake on a game, win more; debt if you run out',
        'Profile: your name and a face you build',
        'Settings: dark mode, currency',
        'Landscape: every screen works on its side',
        'Stake row labelled, with (i) for the rules',
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
