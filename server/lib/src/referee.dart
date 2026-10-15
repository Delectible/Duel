import 'dart:math';

import 'games.dart';
import 'store.dart';

/// A request the referee turns down: [status] is the HTTP status to send.
class RefereeError implements Exception {
  const RefereeError(this.status, this.message);
  final int status;
  final String message;

  @override
  String toString() => 'RefereeError($status): $message';
}

/// Who's asking: a signed-in player (Firebase uid) with their display name
/// and face (as the app sends them).
class Player {
  const Player({required this.uid, required this.name, this.avatar = const {}});
  final String uid;
  final String name;
  final Doc avatar;
}

/// The online referee: parties (friends connected together) and matches
/// (one game). Only the referee writes these; players read them live and
/// send moves here. Pure logic over a [Store], so it's tested without any
/// servers.
///
/// Documents:
/// - `parties/{id}`: code, host, members (uids), names, avatars, matchId.
/// - `codes/{CODE}`: {party} so a code finds its party.
/// - `matches/{id}`: game, party, seats (uids), names, status (live/over),
///   version (bumps on every change), turn, state, deadline (ms), result,
///   rematch votes and the next match's id.
class Referee {
  Referee(this.store, {Random? rng, DateTime Function()? clock, this.turnTime = const Duration(seconds: 45)})
    : _rng = rng ?? Random.secure(),
      _clock = clock ?? DateTime.now;

  final Store store;
  final Random _rng;
  final DateTime Function() _clock;

  /// How long a player has for a move before anyone can claim the timeout.
  final Duration turnTime;

  /// Two timeouts in a row for the same player and they forfeit.
  static const maxTimeouts = 2;

  static const maxPartySize = 6;
  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O, 1/I

  int get _now => _clock().millisecondsSinceEpoch;

  String _id() => List.generate(20, (_) => _codeChars[_rng.nextInt(_codeChars.length)]).join().toLowerCase();

  static String cleanName(String name) {
    final n = name.trim();
    if (n.isEmpty) return 'Player';
    return n.length > 14 ? n.substring(0, 14) : n;
  }

  // --- Parties -------------------------------------------------------------

  /// Starts a party with [host] in it. Returns the party (with its code).
  Future<Doc> createParty(Player host) => store.transaction((tx) async {
    String code;
    do {
      code = List.generate(6, (_) => _codeChars[_rng.nextInt(_codeChars.length)]).join();
    } while (await tx.get('codes/$code') != null);
    final id = _id();
    final party = <String, Object?>{
      'id': id,
      'code': code,
      'host': host.uid,
      'members': [host.uid],
      'names': {host.uid: cleanName(host.name)},
      'avatars': {host.uid: host.avatar},
      'matchId': null,
      'createdAt': _now,
    };
    tx.set('parties/$id', party);
    tx.set('codes/$code', {'party': id});
    return party;
  });

  /// Joins the party with [code]. Joining twice is fine.
  Future<Doc> joinParty(Player p, String code) => store.transaction((tx) async {
    final c = await tx.get('codes/${code.trim().toUpperCase()}');
    if (c == null) throw const RefereeError(404, 'No party with that code');
    final id = c['party']! as String;
    final party = (await tx.get('parties/$id'))!;
    final members = (party['members']! as List).cast<String>();
    if (!members.contains(p.uid)) {
      if (members.length >= maxPartySize) throw const RefereeError(409, 'That party is full');
      members.add(p.uid);
    }
    (party['names']! as Map)[p.uid] = cleanName(p.name);
    (party['avatars']! as Map)[p.uid] = p.avatar;
    party['members'] = members;
    tx.set('parties/$id', party);
    return party;
  });

  /// Leaves a party; the last one out closes it. A new host is picked if
  /// the host leaves.
  Future<void> leaveParty(Player p, String id) => store.transaction((tx) async {
    final party = await tx.get('parties/$id');
    if (party == null) return;
    final members = (party['members']! as List).cast<String>()..remove(p.uid);
    if (members.isEmpty) {
      tx.delete('parties/$id');
      tx.delete('codes/${party['code']}');
      return;
    }
    (party['names']! as Map).remove(p.uid);
    (party['avatars']! as Map).remove(p.uid);
    party['members'] = members;
    if (party['host'] == p.uid) party['host'] = members.first;
    tx.set('parties/$id', party);
  });

  // --- Matches -------------------------------------------------------------

  /// Starts [gameId] for everyone in the party (host only).
  Future<Doc> startMatch(Player p, String partyId, String gameId) => store.transaction((tx) async {
    final party = await tx.get('parties/$partyId');
    if (party == null) throw const RefereeError(404, 'No such party');
    if (party['host'] != p.uid) throw const RefereeError(403, 'Only the host can start a game');
    final game = onlineGames[gameId];
    if (game == null) throw RefereeError(400, "$gameId can't be played online yet");
    final members = (party['members']! as List).cast<String>();
    if (members.length < game.minPlayers || members.length > game.maxPlayers) {
      throw RefereeError(409, '${game.id} is for ${game.minPlayers}–${game.maxPlayers} players');
    }
    final seats = [...members]..shuffle(_rng);
    final match = _newMatch(game, partyId, seats, party['names']! as Map, first: _rng.nextInt(seats.length));
    tx.set('matches/${match['id']}', match);
    party['matchId'] = match['id'];
    tx.set('parties/$partyId', party);
    return match;
  });

  Doc _newMatch(
    OnlineGame game,
    String partyId,
    List<String> seats,
    Map<Object?, Object?> names, {
    required int first,
  }) {
    final state = game.start(seats.length, _rng, first: first);
    return {
      'id': _id(),
      'game': game.id,
      'party': partyId,
      'seats': seats,
      'names': [for (final s in seats) names[s] ?? 'Player'],
      'status': 'live',
      'version': 1,
      'turn': game.turn(state),
      'state': game.public(state),
      'deadline': _now + turnTime.inMilliseconds,
      'timeouts': List.filled(seats.length, 0),
      'result': null,
      'rematch': <String>[],
      'next': null,
      'createdAt': _now,
    };
  }

  /// Plays [move] in match [id]. [version] must be the version the player
  /// saw, so a stale tap (or a double tap) can't land twice.
  Future<Doc> move(Player p, String id, int version, Doc move) => store.transaction((tx) async {
    final match = await _match(tx, id);
    if (match['status'] != 'live') throw const RefereeError(409, 'The game is over');
    if (match['version'] != version) throw const RefereeError(409, 'Out of date: the game moved on');
    final seat = _seat(match, p);
    final game = onlineGames[match['game']]!;
    try {
      _apply(match, game, seat, move);
    } on MoveError catch (e) {
      throw RefereeError(400, e.message);
    }
    (match['timeouts']! as List)[seat] = 0;
    tx.set('matches/$id', match);
    return match;
  });

  /// Anyone in the match can claim it once the player to move has run out
  /// of time: a legal move is made for them; after [maxTimeouts] in a row
  /// they forfeit.
  Future<Doc> claimTimeout(Player p, String id) => store.transaction((tx) async {
    final match = await _match(tx, id);
    _seat(match, p);
    if (match['status'] != 'live') throw const RefereeError(409, 'The game is over');
    if (_now < (match['deadline']! as int)) throw const RefereeError(409, 'There is still time');
    final game = onlineGames[match['game']]!;
    final seat = match['turn']! as int;
    final timeouts = (match['timeouts']! as List).cast<int>();
    timeouts[seat]++;
    match['timeouts'] = timeouts;
    if (timeouts[seat] >= maxTimeouts) {
      _finish(match, Result(winner: _nextSeat(match, seat)), reason: 'timeout');
    } else {
      _apply(match, game, seat, game.autoMove(_state(match), seat, _rng));
    }
    tx.set('matches/$id', match);
    return match;
  });

  /// Gives up: the other side wins (two players; with more, the next seat).
  Future<Doc> forfeit(Player p, String id) => store.transaction((tx) async {
    final match = await _match(tx, id);
    final seat = _seat(match, p);
    if (match['status'] != 'live') return match;
    _finish(match, Result(winner: _nextSeat(match, seat)), reason: 'forfeit');
    tx.set('matches/$id', match);
    return match;
  });

  /// Asks for a rematch; when everyone has, a new match starts (the next
  /// seat goes first) and [Doc]'s `next` points at it.
  Future<Doc> rematch(Player p, String id) => store.transaction((tx) async {
    final match = await _match(tx, id);
    _seat(match, p);
    if (match['status'] != 'over') throw const RefereeError(409, 'The game is still on');
    if (match['next'] != null) return match;
    final votes = (match['rematch']! as List).cast<String>();
    if (!votes.contains(p.uid)) votes.add(p.uid);
    match['rematch'] = votes;
    final seats = (match['seats']! as List).cast<String>();
    if (seats.every(votes.contains)) {
      final game = onlineGames[match['game']]!;
      final first = ((_state(match)['first'] as int? ?? 0) + 1) % seats.length;
      final names = {for (final (i, s) in seats.indexed) s: (match['names']! as List)[i]};
      final next = _newMatch(game, match['party']! as String, seats, names, first: first);
      tx.set('matches/${next['id']}', next);
      match['next'] = next['id'];
      final party = await tx.get('parties/${match['party']}');
      if (party != null) {
        party['matchId'] = next['id'];
        tx.set('parties/${match['party']}', party);
      }
    }
    match['version'] = (match['version']! as int) + 1;
    tx.set('matches/$id', match);
    return match;
  });

  // --- Helpers -------------------------------------------------------------

  Future<Doc> _match(Tx tx, String id) async {
    final m = await tx.get('matches/$id');
    if (m == null) throw const RefereeError(404, 'No such game');
    return m;
  }

  int _seat(Doc match, Player p) {
    final seat = (match['seats']! as List).indexOf(p.uid);
    if (seat < 0) throw const RefereeError(403, "You're not in this game");
    return seat;
  }

  static Doc _state(Doc match) => (match['state']! as Map).cast<String, Object?>();

  static int _nextSeat(Doc match, int seat) => (seat + 1) % (match['seats']! as List).length;

  void _apply(Doc match, OnlineGame game, int seat, Doc move) {
    final state = game.play(_state(match), seat, move);
    match['state'] = game.public(state);
    match['version'] = (match['version']! as int) + 1;
    final result = game.result(state);
    if (result != null) {
      _finish(match, result, reason: result.draw ? 'draw' : 'won');
    } else {
      match['turn'] = game.turn(state);
      match['deadline'] = _now + turnTime.inMilliseconds;
    }
  }

  void _finish(Doc match, Result result, {required String reason}) {
    match['status'] = 'over';
    match['turn'] = null;
    match['deadline'] = null;
    match['result'] = {...result.toJson(), 'reason': reason};
    match['version'] = (match['version']! as int) + 1;
  }
}
