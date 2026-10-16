import 'dart:async';

import 'package:flutter/widgets.dart';

import '../account/account.dart';
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

  /// A game screen is showing [match] (so a new one isn't pushed on top).
  bool onScreen = false;

  StreamSubscription<Doc?>? _partySub;
  StreamSubscription<Doc?>? _matchSub;
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

  int get size => members.length;

  String get hostName => members.where((m) => m.host).map((m) => m.persona.name).firstOrNull ?? 'The host';

  /// The game the party is on, while it's being played.
  bool get playing => match != null && match!['status'] == 'live';

  Doc get _me => {'name': account.name == 'You' ? 'Player' : account.name, 'avatar': account.avatar.toJson()};

  // --- Party -----------------------------------------------------------------

  /// Makes a party with you as host. Returns an error to show, or null.
  Future<String?> create() => _run(() async {
    await _signIn();
    _follow(await backend.call('/v1/parties', _me));
  });

  Future<String?> join(String code) => _run(() async {
    final c = code.trim().toUpperCase();
    if (c.length != 6) throw const OnlineError('Codes are 6 letters and numbers.');
    await _signIn();
    _follow(await backend.call('/v1/parties/join', {..._me, 'code': c}));
  });

  /// Leaves the party (a live game you're in is given up first).
  Future<String?> leave() => _run(() async {
    final id = partyId;
    if (id == null) return;
    if (playing && _seat(match!) >= 0) await backend.call('/v1/matches/${match!['id']}/forfeit');
    await backend.call('/v1/parties/$id/leave');
    _clear();
  });

  /// Host: starts [gameId] for everyone, with each player putting in [stake].
  Future<String?> start(String gameId, {int stake = 0}) => _run(() async {
    final id = partyId;
    if (id == null) throw const OnlineError('Make or join a party first.');
    _take(await backend.call('/v1/parties/$id/start', {'game': gameId, 'stake': stake}), adopt: true);
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
    _partySub = _matchSub = null;
    party = match = null;
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
  Future<String?> forfeit() => _matchCall('forfeit');
  Future<String?> rematch() => _matchCall('rematch');

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
