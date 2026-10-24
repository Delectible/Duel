import 'dart:async';

import 'package:duel_engine/difficulty.dart';
import 'package:flutter/widgets.dart';

import '../account/account.dart';
import '../app_info.dart';
import '../avatars/faces.dart';

typedef Doc = Map<String, Object?>;

/// Something the server (or the network) turned down, in plain words.
class OnlineError implements Exception {
  const OnlineError(this.message);
  final String message;

  @override
  String toString() => message;
}

/// What the app needs from the online side: who you are, live documents,
/// and calls to the referee. [FirebaseBackend] in the app; tests use the
/// real referee in memory.
abstract interface class OnlineBackend {
  /// Signs in (anonymously, first time only) and returns your uid.
  Future<String> signIn();

  /// A document as it changes (null while it doesn't exist or you may not
  /// see it).
  Stream<Doc?> watch(String path);

  /// POSTs [body] to the referee at [path]; throws [OnlineError].
  Future<Doc> call(String path, [Doc body = const {}]);
}

/// Someone in your party.
class PartyMember {
  const PartyMember({required this.uid, required this.persona, required this.host, required this.you});

  final String uid;
  final Persona persona;
  final bool host;
  final bool you;
}

/// A bot sitting in with the party (the host adds them, each with its own
/// difficulty).
class PartyBot {
  const PartyBot({required this.name, required this.look, required this.difficulty});

  final String name;
  final Look look;
  final Difficulty difficulty;

  Persona get persona => Persona.bot(name, look);

  Doc toJson() => {'name': name, 'look': look.name, 'difficulty': difficulty.name};

  static PartyBot fromJson(Map<Object?, Object?> j) => PartyBot(
    name: '${j['name'] ?? 'Bot'}',
    look: Look.values.asNameMap()[j['look']] ?? Look.cap,
    difficulty: Difficulty.values.asNameMap()[j['difficulty']] ?? Difficulty.normal,
  );

  PartyBot copyWith({Difficulty? difficulty}) =>
      PartyBot(name: name, look: look, difficulty: difficulty ?? this.difficulty);
}

/// Your party and the game it's playing: live from the server. Moves and
/// party changes go to the referee; everything shown comes back through
/// the live documents (or the referee's answer, whichever is newer).
class PartyService extends ChangeNotifier {
  PartyService(this.backend, {required this.account}) {
    final saved = account.partyId;
    if (saved != null) unawaited(_resume(saved));
  }

  final OnlineBackend backend;
  final Account account;

  String? uid;
  Doc? party;
  Doc? match;

  /// A call is on its way (buttons wait).
  bool busy = false;

  /// A game screen is showing (or being opened), so a new one isn't pushed
  /// on top. Openers set it; each screen says [showing] / [hidden] itself,
  /// with [screenGame] the game it's for: if the party moves on to another
  /// game, the stale screen is closed and the new one opened.
  bool get onScreen => _opening || _screen != null;
  set onScreen(bool v) => _opening = v;
  var _opening = false;
  Object? _screen;
  String? screenGame;

  void showing(Object screen, String game) {
    _screen = screen;
    screenGame = game;
    _opening = false;
  }

  /// [screen] closed (only counts if it's still the one showing: an old
  /// screen can finish closing after the next has opened).
  void hidden(Object screen) {
    if (!identical(_screen, screen)) return;
    _screen = null;
    screenGame = null;
  }

  StreamSubscription<Doc?>? _partySub;
  StreamSubscription<Doc?>? _matchSub;
  StreamSubscription<Doc?>? _mineSub;
  String? _matchId;
  var _disposed = false;

  bool get inParty => party != null;
  String? get code => party?['code'] as String?;
  String? get partyId => party?['id'] as String?;
  bool get isHost => party != null && party!['host'] == uid;

  /// Everyone in the party, host first.
  List<PartyMember> get members {
    final p = party;
    if (p == null) return const [];
    final names = (p['names'] as Map?) ?? const {};
    final faces = (p['avatars'] as Map?) ?? const {};
    final list = [
      for (final m in (p['members']! as List).cast<String>())
        PartyMember(
          uid: m,
          host: m == p['host'],
          you: m == uid,
          persona: Persona(
            name: m == uid ? 'You' : '${names[m] ?? 'Player'}',
            look: Look.headband,
            avatar: faces[m] is Map
                ? Avatar.fromJson((faces[m] as Map).cast<String, dynamic>())
                : const Avatar(),
          ),
        ),
    ];
    list.sort((a, b) => a.host == b.host ? 0 : (a.host ? -1 : 1));
    return list;
  }

  /// The newest app version in the party when it's a newer x.Y than yours
  /// (playing old against new may go wrong), else null.
  String? get newerVersion {
    String? newest;
    for (final v in ((party?['versions'] as Map?) ?? const {}).values) {
      if (v is String && AppInfo.behind(v) && (newest == null || !_atLeast(newest, v))) newest = v;
    }
    return newest;
  }

  static bool _atLeast(String a, String b) {
    final x = a.split('.').map(int.tryParse).toList(), y = b.split('.').map(int.tryParse).toList();
    for (var i = 0; i < 3; i++) {
      final p = i < x.length ? x[i] ?? 0 : 0, q = i < y.length ? y[i] ?? 0 : 0;
      if (p != q) return p > q;
    }
    return true;
  }

  /// The newer version you've already been told about (Ignore).
  String? versionNoticeSeen;

  /// Bots sitting in with the party.
  List<PartyBot> get bots => [
    for (final b in ((party?['bots'] as List?) ?? const [])) PartyBot.fromJson(b as Map),
  ];

  /// Everyone at the table: people and bots.
  int get size => members.length + bots.length;

  /// Most people and bots at one table.
  static const maxTable = 6;

  /// How this party picks games: 'host', 'vote' or 'first' (come).
  String get mode => party?['mode'] as String? ?? 'host';

  /// Votes so far (vote mode): uid -> the game they picked.
  Map<String, String> get votes => {
    for (final e in ((party?['votes'] as Map?) ?? const {}).entries)
      '${e.key}': '${(e.value as Map)['game']}',
  };

  /// Your vote, if you've cast one.
  String? get myVote => votes[uid];

  /// The last vote's outcome: {game, tally, tossed}.
  Map<Object?, Object?>? get lastVote => party?['lastVote'] as Map?;

  /// You can start a game yourself (host picks: the host; first come:
  /// anyone; a vote: nobody, you vote).
  bool get canStart => switch (mode) {
    'first' => true,
    'vote' => false,
    _ => isHost,
  };

  String get hostName => members.where((m) => m.host).map((m) => m.persona.name).firstOrNull ?? 'The host';

  /// The game the party is on, while it's being played.
  bool get playing => match != null && match!['status'] == 'live';

  /// Seats whose person left the game (a bot may be sitting in).
  List<int> get leftSeats => [...((match?['left'] as List?) ?? const []).cast<int>()];

  /// You're seated in the live game and playing (not left).
  bool get inGame => playing && seat >= 0 && !leftSeats.contains(seat);

  /// You left the live game: you can come back ([rejoin]).
  bool get leftGame => playing && seat >= 0 && leftSeats.contains(seat);

  /// The game waits while the host decides about someone who left:
  /// {seats, decider (uid), at, until (server ms)}.
  Map<Object?, Object?>? get paused => playing ? match!['paused'] as Map? : null;

  /// It's your call (bot or end) while [paused].
  bool get deciding => paused?['decider'] == uid;

  /// A bot is playing [seat] (server seat) for someone who left.
  bool standIn(int seat) => ((match?['standIns'] as Map?) ?? const {}).containsKey('$seat');

  /// The name at server [seat] of the current match.
  String nameAt(int seat) => '${((match?['names'] as List?) ?? const [])[seat] ?? 'Player'}';

  Doc get _me => {
    'name': account.name == 'You' ? 'Player' : account.name,
    'avatar': account.avatar.toJson(),
    'version': AppInfo.version,
  };

  // --- Party -----------------------------------------------------------------

  /// Makes a party with you as host. Returns an error to show, or null.
  /// [mode]: who picks the games ('host', 'vote' or 'first').
  Future<String?> create({String mode = 'host'}) => _run(() async {
    await _signIn();
    _follow(await backend.call('/v1/parties', {..._me, 'mode': mode}));
  });

  Future<String?> join(String code) => _run(() async {
    final c = code.trim().toUpperCase();
    if (c.length != 6) throw const OnlineError('Codes are 6 letters and numbers.');
    await _signIn();
    _follow(await backend.call('/v1/parties/join', {..._me, 'code': c}));
  });

  /// Leaves the party (and the game, if you're in one: the server sees to
  /// that).
  Future<String?> leave() => _run(() async {
    final id = partyId;
    if (id == null) return;
    await backend.call('/v1/parties/$id/leave');
    _clear();
  });

  /// Host: the bots that sit in (replaces the list).
  Future<String?> setBots(List<PartyBot> bots) => _run(() async {
    final id = partyId;
    if (id == null) return;
    final p = await backend.call('/v1/parties/$id/bots', {
      'bots': [for (final b in bots) b.toJson()],
    });
    if (p['id'] == id) {
      party = p;
      _notify();
    }
  });

  /// Your own cards in the current game (card games), live.
  Doc? mine;

  /// Host: starts [gameId] for everyone, with each player putting in [stake].
  Future<String?> start(String gameId, {int stake = 0, Doc options = const {}}) => _run(() async {
    final id = partyId;
    if (id == null) throw const OnlineError('Make or join a party first.');
    _take(
      await backend.call('/v1/parties/$id/start', {'game': gameId, 'stake': stake, 'options': options}),
      adopt: true,
    );
  });

  /// Vote mode: your pick. Once everyone has voted the winner starts.
  Future<String?> vote(String gameId, {int stake = 0, Doc options = const {}}) => _run(() async {
    final id = partyId;
    if (id == null) throw const OnlineError('Make or join a party first.');
    final p = await backend.call('/v1/parties/$id/vote', {
      'game': gameId,
      'stake': stake,
      'options': options,
    });
    final match = p['match'];
    if (match is Map) {
      _take(match.cast<String, Object?>(), adopt: true);
    } else if (p['id'] == id) {
      party = p;
      _notify();
    }
  });

  Future<void> _resume(String id) async {
    try {
      await _signIn();
      _watchParty(id);
    } on Object {
      // Offline at launch: stay out; the party is still there to rejoin.
    }
  }

  Future<void> _signIn() async => uid ??= await backend.signIn();

  void _follow(Doc p) {
    party = p;
    account.partyId = p['id'] as String?;
    _watchParty(p['id']! as String);
    _notify();
  }

  void _watchParty(String id) {
    unawaited(_partySub?.cancel());
    _partySub = backend
        .watch('parties/$id')
        .listen(
          (p) {
            if (p == null || !(p['members'] as List? ?? const []).contains(uid)) {
              // Closed, or you're not in it any more.
              if (party != null) _clear();
              return;
            }
            party = p;
            final m = p['matchId'] as String?;
            if (m != null && m != _matchId) _watchMatch(m);
            _notify();
          },
          onError: (Object _) {
            if (party != null) _clear();
          },
        );
  }

  void _watchMatch(String id) {
    _matchId = id;
    unawaited(_matchSub?.cancel());
    _matchSub = backend.watch('matches/$id').listen((m) {
      if (m != null && m['id'] == _matchId) _take(m);
    }, onError: (Object _) {});
    mine = null;
    unawaited(_mineSub?.cancel());
    _mineSub = backend.watch('matches/$id/hands/$uid').listen((d) {
      if (_matchId != id) return;
      mine = d;
      _notify();
    }, onError: (Object _) {});
  }

  /// Keeps the newest version of the current match ([adopt]: a new one).
  void _take(Doc m, {bool adopt = false}) {
    final id = m['id'] as String?;
    if (id == null) return;
    if (id != _matchId) {
      if (!adopt) return; // an answer about a match we've moved on from
      _watchMatch(id);
    } else if (match != null &&
        match!['id'] == id &&
        (match!['version'] as int? ?? 0) > (m['version'] as int? ?? 0)) {
      return;
    }
    match = m;
    _notify();
  }

  void _clear() {
    unawaited(_partySub?.cancel());
    unawaited(_matchSub?.cancel());
    unawaited(_mineSub?.cancel());
    _partySub = _matchSub = _mineSub = null;
    party = match = mine = null;
    _matchId = null;
    account.partyId = null;
    _notify();
  }

  // --- The game --------------------------------------------------------------

  /// Your seat in [m], or -1.
  int _seat(Doc m) => (m['seats'] as List? ?? const []).indexOf(uid);
  int get seat => match == null ? -1 : _seat(match!);

  Future<String?> move(Doc move) => _matchCall('move', {'version': match?['version'], 'move': move});
  Future<String?> claimTimeout() => _matchCall('timeout');
  Future<String?> rematch() => _matchCall('rematch');

  /// Leaves the game. [stake] went with it (it comes back if you [rejoin]).
  Future<String?> forfeit({int stake = 0}) {
    final m = match;
    if (m != null && stake > 0) account.leftGame(m['id']! as String, '${m['game']}', stake);
    return _matchCall('forfeit');
  }

  /// Back into the game you left: your seat as it stands.
  Future<String?> rejoin() async {
    final id = match?['id'] as String?;
    final error = await _matchCall('rejoin');
    if (error == null && id != null) account.takeBack(id);
    return error;
  }

  /// While [paused] (you're [deciding], or the time is up): `bot` or `end`.
  Future<String?> decide(String choice) => _matchCall('decide', {'choice': choice});

  /// Host: ends the live game for everyone (stakes back for those still in).
  Future<String?> endGame() => _matchCall('end');

  Future<String?> _matchCall(String what, [Doc body = const {}]) => _run(() async {
    final m = match;
    if (m == null) return;
    final r = await backend.call('/v1/matches/${m['id']}/$what', body);
    _take(r);
    // Everyone asked for a rematch: on to the next game.
    final next = r['next'] as String?;
    if (next != null && next != _matchId) _watchMatch(next);
  });

  Future<String?> _run(Future<void> Function() f) async {
    busy = true;
    _notify();
    try {
      await f();
      return null;
    } on OnlineError catch (e) {
      return e.message;
    } on Object {
      return "Couldn't reach the server. Check your connection and try again.";
    } finally {
      busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_partySub?.cancel());
    unawaited(_matchSub?.cancel());
    unawaited(_mineSub?.cancel());
    super.dispose();
  }
}

/// The party, for every screen (null when this build can't go online).
class PartyScope extends InheritedNotifier<PartyService> {
  const PartyScope({super.key, required PartyService? party, required super.child}) : super(notifier: party);

  static PartyService? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PartyScope>()?.notifier;

  static PartyService? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PartyScope>()?.notifier;
}
