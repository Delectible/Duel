import 'dart:math';

import 'package:duel_engine/bank/bank.dart';
import 'package:duel_engine/bank/bank_bot.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/goofspiel/goofspiel.dart';
import 'package:duel_engine/goofspiel/gops_bot.dart';
import 'package:duel_engine/liars/liars.dart';
import 'package:duel_engine/liars/liars_bot.dart';
import 'package:duel_engine/sunk/sunk.dart';
import 'package:duel_engine/sunk/sunk_bot.dart';

import 'games.dart';
import 'store.dart';

Difficulty _level(Object? name) => Difficulty.values.asNameMap()[name] ?? Difficulty.normal;

Result _top(List<int> winners, int players) {
  if (winners.length == players) return const Result(draw: true);
  return Result(winner: winners.first, winners: winners.length > 1 ? winners : null);
}

/// Goofspiel: everyone bids at once, face down. The state is the seed (the
/// prizes' order, secret) and every bid in the order made; seats are the
/// engine's players. Bids are in by any seat at any time; the round's are
/// hidden until the last is in. Bots bid first ([turn] picks them), then
/// the clock runs on the first person still to bid.
class GopsGame extends OnlineGame {
  const GopsGame();

  @override
  String get id => 'gops';
  @override
  int get minPlayers => 2;
  @override
  int get maxPlayers => 3;

  static List<int> prizeOrder(int seed) => [for (var v = 1; v <= 13; v++) v]..shuffle(Random(seed));

  static List<List<int>> _bids(Doc state) => [
    for (final b in (state['bids']! as List)) (b as List).cast<int>(),
  ];

  static Goofspiel replay(Doc state) {
    final g = Goofspiel(players: state['n']! as int, prizeOrder: prizeOrder(state['seed']! as int));
    for (final [p, v] in _bids(state)) {
      g.bid(p, v);
    }
    return g;
  }

  @override
  Doc start(
    int players,
    Random rng, {
    required int first,
    required Set<int> humans,
    Doc options = const {},
  }) => {
    'seed': rng.nextInt(1 << 31),
    'n': players,
    'humans': (humans.toList()..sort()),
    'bids': <List<int>>[],
  };

  @override
  int? turn(Doc state) {
    final g = replay(state);
    if (g.isOver) return null;
    final humans = (state['humans']! as List).cast<int>();
    final waiting = [
      for (var p = 0; p < g.players; p++)
        if (!g.hasBid(p)) p,
    ];
    return waiting.where((p) => !humans.contains(p)).firstOrNull ?? waiting.first;
  }

  @override
  bool unversioned(Doc move) => true;

  @override
  bool aside(Doc move) => true;

  @override
  Doc play(Doc state, int seat, Doc move) {
    final g = replay(state);
    if (g.isOver) throw const MoveError('The game is over');
    if (g.hasBid(seat)) throw const MoveError('You have bid already');
    final v = move['bid'];
    if (v is! int || !g.hands[seat].contains(v)) throw const MoveError("That card isn't in your hand");
    return {
      ...state,
      'bids': [
        ..._bids(state),
        [seat, v],
      ],
    };
  }

  @override
  Result? result(Doc state) {
    final g = replay(state);
    return g.isOver ? _top(g.winners, g.players) : null;
  }

  @override
  Doc botMove(Doc state, int seat, Doc bot, Random rng) => {
    'bid': GopsBot(me: seat, difficulty: _level(bot['difficulty']), rng: rng).decide(replay(state)),
  };

  @override
  Doc autoMove(Doc state, int seat, Random rng) => botMove(state, seat, const {'difficulty': 'easy'}, rng);

  @override
  Doc? leave(Doc state, int seat) => state;

  /// The prizes turned up so far, the finished rounds' bids, and who has
  /// bid this one (not what).
  @override
  Doc public(Doc state) {
    final n = state['n']! as int;
    final bids = _bids(state);
    final done = bids.length ~/ n;
    return {
      'n': n,
      'order': [for (var i = 0; i < n; i++) i],
      'humans': state['humans'],
      'prizes': prizeOrder(state['seed']! as int).take(min(13, done + 1)).toList(),
      'bids': bids.take(done * n).toList(),
      'ready': [for (final [p, _] in bids.skip(done * n)) p],
    };
  }

  /// Your bid this round, so a phone that reloads still shows it.
  @override
  Doc? private(Doc state, int seat) {
    final n = state['n']! as int;
    final bids = _bids(state);
    final mine = bids.skip(bids.length ~/ n * n).where((b) => b[0] == seat).firstOrNull;
    return {'bid': mine?[1]};
  }

  @override
  Duration show(Doc before, Doc after) {
    final n = after['n']! as int;
    final rounds = _bids(after).length ~/ n - _bids(before).length ~/ n;
    return Duration(milliseconds: rounds * 2600);
  }
}

/// Bank!: the roller rolls (dice from the server), anyone still in banks
/// at any time. The state is the seed (secret: the dice), each seat's bot
/// level (null for people) and the log: `{p, k: roll, a, b}` and
/// `{p, k: bank}`. Bots bank right after a roll; a bot's roll waits
/// [botWait] so people can bank between rolls. A bank names the roll it
/// was made on (`at`): one that crosses with the next roll is refused.
class BankOnline extends OnlineGame {
  const BankOnline();

  @override
  String get id => 'bank';
  @override
  int get minPlayers => 2;
  @override
  int get maxPlayers => 6;

  @override
  Duration? get botWait => const Duration(milliseconds: 1200);

  static List<Map<Object?, Object?>> _moves(Doc state) =>
      (state['moves']! as List).cast<Map<Object?, Object?>>();

  /// The game after the log; [settle]: on to the next round if this one's
  /// done (as the server sees it; phones pause there first).
  static BankGame replay(Doc state, {bool settle = true}) {
    final g = BankGame(
      players: state['n']! as int,
      rounds: state['rounds']! as int,
      firstRoller: state['first']! as int,
    );
    for (final m in _moves(state)) {
      if (g.roundOver && !g.isOver) g.nextRound();
      if (m['k'] == 'roll') {
        g.roll(m['a']! as int, m['b']! as int);
      } else {
        g.bankFor(m['p']! as int);
      }
    }
    if (settle && g.roundOver && !g.isOver) g.nextRound();
    return g;
  }

  @override
  Doc start(
    int players,
    Random rng, {
    required int first,
    required Set<int> humans,
    Doc options = const {},
  }) => {
    'seed': rng.nextInt(1 << 31),
    'n': players,
    'rounds': ((options['rounds'] as int?) ?? 10).clamp(1, 30),
    'first': first,
    'order': [for (var i = 0; i < players; i++) i],
    'levels': List<String?>.filled(players, null),
    'moves': <Doc>[],
  };

  @override
  Doc withBots(Doc state, List<Object?> bots) => {
    ...state,
    'levels': [for (final b in bots) b is Map ? (b['difficulty'] as String? ?? 'normal') : null],
  };

  @override
  int? turn(Doc state) {
    final g = replay(state);
    return g.isOver ? null : g.roller;
  }

  @override
  bool unversioned(Doc move) => move['k'] == 'bank';

  @override
  bool aside(Doc move) => move['k'] == 'bank';

  @override
  Doc play(Doc state, int seat, Doc move) {
    final g = replay(state);
    if (g.isOver) throw const MoveError('The game is over');
    final moves = [..._moves(state)];
    final seed = state['seed']! as int;
    if (move['k'] == 'bank') {
      if (!g.canBank(seat)) throw const MoveError("You can't bank now");
      if (move['at'] != g.rolls || move['round'] != g.round) {
        throw const MoveError('Too late: the dice rolled on');
      }
      moves.add({'p': seat, 'k': 'bank'});
      return {...state, 'moves': moves};
    }
    if (move['k'] != 'roll') throw const MoveError('Roll or bank');
    if (g.roller != seat) throw const MoveError('Not your roll');
    final dice = Random(seed ^ (moves.length * 7919 + 1));
    final a = 1 + dice.nextInt(6), b = 1 + dice.nextInt(6);
    g.roll(a, b);
    moves.add({'p': seat, 'k': 'roll', 'a': a, 'b': b});
    // The bots have their say.
    final levels = (state['levels']! as List).cast<String?>();
    for (var p = 0; p < g.players && !g.roundOver; p++) {
      final level = levels[p];
      if (level == null || !g.canBank(p)) continue;
      final bot = BankBot(
        me: p,
        style: BankStyle.values[(seed + p) % 3],
        difficulty: _level(level),
        rng: Random(seed ^ (g.round * 977 + p * 31)),
      );
      if (bot.wantsToBank(g)) {
        g.bankFor(p);
        moves.add({'p': p, 'k': 'bank'});
      }
    }
    return {...state, 'moves': moves};
  }

  @override
  Result? result(Doc state) {
    final g = replay(state);
    return g.isOver ? _top(g.winners, g.players) : null;
  }

  @override
  Doc autoMove(Doc state, int seat, Random rng) => const {'k': 'roll'};

  @override
  Doc? leave(Doc state, int seat) => state;

  @override
  Doc public(Doc state) => {...state}..remove('seed');

  @override
  Duration show(Doc before, Doc after) {
    final a = _moves(before), b = _moves(after);
    final rolls = b.skip(a.length).where((m) => m['k'] == 'roll').length;
    final rounds = replay(after, settle: false).round - replay(before, settle: false).round;
    return Duration(milliseconds: rolls * 1500 + rounds * 2600);
  }
}

/// Liar's Dice: every cup is rolled by the referee (seed secret); each
/// player sees only their own (`hands`), and the cups come up in public
/// (`cups`, per finished round) once someone calls. The log is
/// `{p, kind: bid, count, face, tempo}` and `{p, kind: liar | spotOn}`.
class LiarsOnline extends OnlineGame {
  const LiarsOnline();

  @override
  String get id => 'liars';
  @override
  int get minPlayers => 2;
  @override
  int get maxPlayers => 6;

  static List<Map<Object?, Object?>> _moves(Doc state) =>
      (state['moves']! as List).cast<Map<Object?, Object?>>();

  static List<List<int>> _cups(LiarsGame g, int seed) => g.rollFor(Random(seed ^ ((g.round + 1) * 7919)));

  /// The game after the log, the next round rolled if one's due. [reads]
  /// collects how each player's bids held up when called.
  static LiarsGame replay(Doc state, {LiarsReads? reads}) {
    final seed = state['seed']! as int;
    final g = LiarsGame(
      players: state['n']! as int,
      rules: LiarsRules.fromJson(state['rules'] as Map?),
      first: state['first']! as int,
    );
    for (final m in _moves(state)) {
      if (g.needsRoll) g.roll(_cups(g, seed));
      final p = m['p']! as int;
      if (m['kind'] == 'bid') {
        g.raise(p, LiarsBid(m['count']! as int, m['face']! as int));
      } else {
        final r = g.challenge(p, LiarsCall.values.byName(m['kind']! as String));
        reads?.saw(r);
      }
    }
    if (g.needsRoll) g.roll(_cups(g, seed));
    return g;
  }

  @override
  Doc start(
    int players,
    Random rng, {
    required int first,
    required Set<int> humans,
    Doc options = const {},
  }) => {
    'seed': rng.nextInt(1 << 31),
    'n': players,
    'first': first,
    'order': [for (var i = 0; i < players; i++) i],
    'rules': LiarsRules.fromJson((options['rules'] as Map?) ?? options).toJson(),
    'moves': <Doc>[],
  };

  @override
  int? turn(Doc state) {
    final g = replay(state);
    return g.isOver ? null : g.turn;
  }

  @override
  Doc play(Doc state, int seat, Doc move) {
    final g = replay(state);
    if (g.isOver) throw const MoveError('The game is over');
    if (g.turn != seat) throw const MoveError('Not your turn');
    final kind = move['kind'];
    final Doc clean;
    if (kind == 'bid') {
      final count = move['count'], face = move['face'];
      if (count is! int || face is! int || !g.beats(LiarsBid(count, face))) {
        throw const MoveError("That bid doesn't beat the last one");
      }
      clean = {'p': seat, 'kind': 'bid', 'count': count, 'face': face, 'tempo': ?move['tempo']};
    } else if (kind == 'liar' || (kind == 'spotOn' && g.rules.spotOn)) {
      if (!g.canCall) throw const MoveError('Nothing to call yet');
      clean = {'p': seat, 'kind': kind, 'tempo': ?move['tempo']};
    } else {
      throw const MoveError('Bid, or call');
    }
    return {
      ...state,
      'moves': [..._moves(state), clean],
    };
  }

  @override
  Result? result(Doc state) {
    final g = replay(state);
    return g.isOver ? Result(winner: g.winner) : null;
  }

  @override
  Doc botMove(Doc state, int seat, Doc bot, Random rng) {
    final reads = LiarsReads(state['n']! as int);
    final g = replay(state, reads: reads);
    final seed = state['seed']! as int;
    return LiarsBot(
      me: seat,
      difficulty: _level(bot['difficulty']),
      style: LiarsStyle.values[(seed + seat) % 3],
      rng: rng,
      reads: reads,
    ).decide(g).toJson();
  }

  @override
  Doc autoMove(Doc state, int seat, Random rng) => botMove(state, seat, const {'difficulty': 'easy'}, rng);

  @override
  Doc? leave(Doc state, int seat) => state;

  /// No dice but those already shown: each finished round's cups.
  @override
  Doc public(Doc state) {
    final g = replay(state);
    final cups = <List<List<int>>>[
      for (final e in g.events)
        if (e is LiarsCalled) e.reveal.dice,
    ];
    return {...state, 'cups': cups, 'round': g.round}..remove('seed');
  }

  /// Your cup this round.
  @override
  Doc? private(Doc state, int seat) {
    final g = replay(state);
    return {'round': g.round, 'dice': g.isOver ? <int>[] : g.dice[seat]};
  }

  /// Bots think (their tempo), calls take a while to show.
  @override
  Duration show(Doc before, Doc after) {
    final a = _moves(before), b = _moves(after);
    var ms = 0;
    for (final m in b.skip(a.length)) {
      ms += m['kind'] == 'bid' ? 1500 + (m['tempo'] as int? ?? 50) * 25 : 5000;
    }
    return Duration(milliseconds: min(60000, ms));
  }
}

/// Sunk: the sea is dealt from the secret seed. Phones never see what's
/// still in it, only the cards drawn so far (`taken`, in order, which is
/// all a phone's replay needs) and, for whoever's reading a Map, the card
/// it shows (`hands`). The log is `{p, kind: draw | surface | aim |
/// chart, target, take, tempo}`.
class SunkOnline extends OnlineGame {
  const SunkOnline();

  @override
  String get id => 'sunk';
  @override
  int get minPlayers => 2;
  @override
  int get maxPlayers => 6;

  static List<Map<Object?, Object?>> _moves(Doc state) =>
      (state['moves']! as List).cast<Map<Object?, Object?>>();

  static SunkGame replay(Doc state) {
    final seed = state['seed']! as int;
    var shuffles = 0;
    final g = SunkGame(
      players: state['n']! as int,
      sea: sunkDeck()..shuffle(Random(seed)),
      target: state['target'] as int? ?? 120,
      first: state['first']! as int,
    )..reshuffle = (cards) => cards.shuffle(Random(seed + (++shuffles) * 7919));
    for (final m in _moves(state)) {
      _apply(g, m);
    }
    return g;
  }

  static void _apply(SunkGame g, Map<Object?, Object?> m) {
    final p = m['p']! as int;
    switch (m['kind']) {
      case 'draw':
        g.draw(p);
      case 'surface':
        g.surface(p);
      case 'aim':
        g.aim(p, m['target']! as int);
      case 'chart':
        g.chart(p, take: m['take'] == true);
    }
  }

  @override
  Doc start(
    int players,
    Random rng, {
    required int first,
    required Set<int> humans,
    Doc options = const {},
  }) => {
    'seed': rng.nextInt(1 << 31),
    'n': players,
    'first': first,
    'target': ((options['target'] as int?) ?? 120).clamp(40, 400),
    'order': [for (var i = 0; i < players; i++) i],
    'levels': List<String?>.filled(players, null),
    'moves': <Doc>[],
  };

  @override
  Doc withBots(Doc state, List<Object?> bots) => {
    ...state,
    'levels': [for (final b in bots) b is Map ? (b['difficulty'] as String? ?? 'normal') : null],
  };

  @override
  int? turn(Doc state) {
    final g = replay(state);
    return g.isOver ? null : g.turn;
  }

  @override
  Doc play(Doc state, int seat, Doc move) {
    final g = replay(state);
    if (g.isOver) throw const MoveError('The game is over');
    if (g.turn != seat) throw const MoveError('Not your turn');
    final kind = move['kind'];
    final clean = <String, Object?>{'p': seat, 'kind': kind};
    try {
      switch (kind) {
        case 'draw':
        case 'surface':
          break;
        case 'aim':
          clean['target'] = move['target'];
        case 'chart':
          clean['take'] = move['take'] == true;
        default:
          throw const MoveError('Draw, surface, aim or chart');
      }
      if (move['tempo'] is int) clean['tempo'] = move['tempo'];
      _apply(g, clean);
    } on StateError catch (e) {
      throw MoveError(e.message);
    } on TypeError {
      throw const MoveError('Not a move');
    }
    return {
      ...state,
      'moves': [..._moves(state), clean],
    };
  }

  @override
  Result? result(Doc state) {
    final g = replay(state);
    return g.isOver ? _top(g.winners, g.players) : null;
  }

  @override
  Doc botMove(Doc state, int seat, Doc bot, Random rng) {
    final g = replay(state);
    final seed = state['seed']! as int;
    final b = SunkBot(
      me: seat,
      difficulty: _level(bot['difficulty']),
      style: SunkStyle.values[(seed + seat) % 3],
      rng: rng,
    );
    return {...b.decide(g).toJson(), 'tempo': (b.tempo(g) * 100).round()};
  }

  @override
  Doc autoMove(Doc state, int seat, Random rng) {
    // Out of time: surface (or aim at anyone, or pass on the map).
    final g = replay(state);
    return switch (g.pending) {
      SunkKind.hook || SunkKind.cut => {'kind': 'aim', 'target': g.targets.first},
      SunkKind.map => {'kind': 'chart', 'take': false},
      _ => {'kind': g.bags[seat].isEmpty ? 'draw' : 'surface'},
    };
  }

  @override
  Doc? leave(Doc state, int seat) => state;

  /// Everything but the seed: the cards drawn so far, in order.
  @override
  Doc public(Doc state) {
    final g = replay(state);
    return {
      ...state,
      'taken': [for (final c in g.taken) c?.id],
      'round': g.round,
    }..remove('seed');
  }

  /// What your Map shows.
  @override
  Doc? private(Doc state, int seat) {
    final g = replay(state);
    final peek = g.turn == seat ? g.peeked : null;
    return {'peek': peek?.id, 'at': _moves(state).length};
  }

  @override
  Duration show(Doc before, Doc after) {
    final a = _moves(before), b = _moves(after);
    var ms = 0;
    for (final m in b.skip(a.length)) {
      ms += 1100 + (m['tempo'] as int? ?? 0) * 15;
    }
    return Duration(milliseconds: min(60000, ms));
  }
}
