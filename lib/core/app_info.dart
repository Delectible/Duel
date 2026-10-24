/// Version and revision history (shown in About).
class AppInfo {
  const AppInfo._();

  static const name = 'Duel';
  static const version = '0.10.0';

  /// Whether [other] (another app's version) is a newer x.Y than ours: the
  /// middle number goes up when old and new apps may not play well together
  /// online (the last one for anything else).
  static bool behind(String other) {
    (int, int)? major(String v) {
      final parts = v.split('.');
      if (parts.length < 2) return null;
      final a = int.tryParse(parts[0]), b = int.tryParse(parts[1]);
      return a == null || b == null ? null : (a, b);
    }

    final mine = major(version)!, theirs = major(other);
    if (theirs == null) return false;
    return theirs.$1 > mine.$1 || (theirs.$1 == mine.$1 && theirs.$2 > mine.$2);
  }

  /// What changed in this build, in plain words: Google Play's "What's new"
  /// (tool/play/whats_new.py). Replace it every build.
  static const latest =
      'Blitz online with your party. Your pips are now kept online: online stakes come out of everyone\'s '
      'pips and the winner takes the pot. Fix: when your party starts a new game, it opens on every phone, '
      'even one still on the last game.';

  /// About: the main ideas of each version, a few words each.
  static const revisions = <(String, List<String>)>[
    ('0.10', ['Blitz online', 'Pips kept online: winner takes the pot']),
    (
      '0.9',
      [
        'Crazy Eights, Go Fish, Spades online',
        'Spades: pick your partner',
        'Parties: host picks, vote or first come',
        'Sound effects (Settings: on / off, volume)',
        'Background music: five to pick from',
        "Hold'em: Improve your game tips",
        "Hold'em: show or muck your cards",
        'Smoother: full refresh rate, less redrawing',
        'Tells you when your party has a newer Duel',
      ],
    ),
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
