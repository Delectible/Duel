/// Version and revision history (shown in About).
class AppInfo {
  const AppInfo._();

  static const name = 'Duel';
  static const version = '0.8.7';

  /// What changed in this build, in plain words: Google Play's "What's new"
  /// (tool/play/whats_new.py). Replace it every build.
  static const latest =
      "Online Hold'em bots now play like the offline ones: they read the table, bluff, trap, tilt and take "
      'their time, so their timing can give them away. Each has a hidden style, revealed at the end. Also '
      'fixes a rare online game that could stall when a short stack went all in on the blinds.';

  /// About: the main ideas of each version, a few words each.
  static const revisions = <(String, List<String>)>[
    (
      '0.8',
      [
        'Blitz: a house game vs bots, with wars',
        "Hold'em: table talk, all-in odds, big-win splashes",
        'Chips with depth; cards dealt from the dealer',
        'New game pictures',
        'Leave and rejoin: the host brings in a bot or ends it',
        "Hold'em: bots that read you; 9 hidden personalities",
        'Read cards, hand history, pot odds, game summary',
        'New faces: 7 parts, 100+ options, Surprise me',
        "Online Hold'em bots read you and give tells too",
      ],
    ),
    ('0.7', ["Hold'em online, with bots in the party"]),
    (
      '0.6',
      [
        'Play with a friend: party by code, host picks',
        'Four in a Row online',
        'Face builder: one part at a time',
      ],
    ),
    ('0.5', ['Spades vs bots: two-handed or teams of four', 'Bids, Nil, bags; play to 150, 250 or 500']),
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
        'Play at home: real-deck guides for every game',
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
