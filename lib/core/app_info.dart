/// Version and revision history (shown in About).
class AppInfo {
  const AppInfo._();

  static const name = 'Duel';
  static const version = '1.3.0';

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
      'Tabletop tools: who goes first (fingers on the screen), a team picker, a dice tray, a coin flip and a spinner, '
      'a card dealer (with your party, each phone holds its own hand), and a chip bank that works out who owes whom. '
      'Plus: your pips at Blackjack and cash tables, + and − bets, and Skip moved out of the way.';

  /// About: the main ideas of each version, a few words each.
  static const revisions = <(String, List<String>)>[
    ('1.1', ['Goofspiel and Bank! online']),
    (
      '1.0',
      [
        'Store: faces, card backs, felts, sets',
        'Daily challenges',
        'Blackjack floor and house rules',
        '3D dice: swipe up to roll',
        'A new intro: the ghost takes the deck',
        'Blackjack online; Online / Local switch',
        'Gentler win and loss sounds',
      ],
    ),
    (
      '0.11',
      [
        'Cash games: shared tables online',
        'Pick your seat at a cash table',
        'Tournaments: 18 players, three tables',
        'Boss Tables: a ladder of five bosses',
        'Rivals and bosses remember how you play',
        'Trophy shelf and new achievements',
        'New app icon: the Duel ghost',
        'Show cards: throw them on the table',
        'Four new bot styles; fairer read cards',
        'Cash tables: sit out, pre-moves, table chat',
        'New games: Goofspiel, Blackjack, Bank!',
        'Table colours by stake; gold cards up top',
        'Bank! at home: dice and scorekeeper',
      ],
    ),
    (
      '0.10',
      [
        'Blitz online',
        'Pips kept online: winner takes the pot',
        'Spades: suits alternate colour',
        "Hold'em: rivals, bounties, achievements",
        'Game story and hand of the game',
      ],
    ),
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
