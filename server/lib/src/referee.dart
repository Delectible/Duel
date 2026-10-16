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
///   version (bumps on every change), turn, state, deadline and turnAt
///   (server ms: phones count down deadline - turnAt from when they hear
///   of the turn, so their own clocks don't matter), result,
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
      'bots': <Doc>[],
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

  /// Bot looks the app knows how to draw (each plays its own way).
  static const botLooks = {'cap', 'shades', 'fin', 'spiky'};

  /// Host: the bots that sit in with the party (each with its own name,
  /// look and difficulty). Replaces the list.
  Future<Doc> setBots(Player p, String partyId, List<Object?> bots) => store.transaction((tx) async {
    final party = await tx.get('parties/$partyId');
    if (party == null) throw const RefereeError(404, 'No such party');
    if (party['host'] != p.uid) throw const RefereeError(403, 'Only the host can add bots');
    final members = (party['members']! as List).length;
    if (members + bots.length > maxPartySize) {
      throw RefereeError(409, 'A table holds $maxPartySize: room for ${maxPartySize - members} bots');
    }
    final clean = <Doc>[];
    for (final (i, b) in bots.indexed) {
      if (b is! Map) throw const RefereeError(400, 'Send {name, look, difficulty} for each bot');
      final difficulty = b['difficulty'];
      if (!const {'easy', 'normal', 'hard'}.contains(difficulty)) {
        throw const RefereeError(400, 'Difficulty is easy, normal or hard');
      }
      clean.add({
        'id': 'bot:$i',
        'name': cleanName('${b['name'] ?? 'Bot'}'),
        'look': botLooks.contains(b['look']) ? b['look'] : 'cap',
        'difficulty': difficulty,
      });
    }
    party['bots'] = clean;
    tx.set('parties/$partyId', party);
    return party;
  });

  // --- Matches -------------------------------------------------------------

  /// Biggest stake the host can set (each phone settles its own pips).
  static const maxStake = 1000;

  /// Starts [gameId] for everyone in the party and its bots (host only).
  /// [stake] is what every player puts in; each phone takes and settles it.
  Future<Doc> startMatch(Player p, String partyId, String gameId, {int stake = 0}) =>
      store.transaction((tx) async {
        final party = await tx.get('parties/$partyId');
        if (party == null) throw const RefereeError(404, 'No such party');
        if (party['host'] != p.uid) throw const RefereeError(403, 'Only the host can start a game');
        final game = onlineGames[gameId];
        if (game == null) throw RefereeError(400, "$gameId can't be played online yet");
        final members = (party['members']! as List).cast<String>();
        final bots = ((party['bots'] as List?) ?? const []).cast<Map<Object?, Object?>>();
        final count = members.length + bots.length;
        if (count < game.minPlayers || count > game.maxPlayers) {
          throw RefereeError(409, '${game.id} is for ${game.minPlayers}–${game.maxPlayers} players');
        }
        final names = <Object?, Object?>{...party['names']! as Map, for (final b in bots) b['id']: b['name']};
        final seats = [...members, for (final b in bots) b['id']! as String]..shuffle(_rng);
        final botSeats = {for (final b in bots) b['id']: b.cast<String, Object?>()};
        final match = await _newMatch(
          tx,
          game,
          partyId,
          seats,
          names,
          [for (final s in seats) botSeats[s]],
          first: _rng.nextInt(seats.length),
          stake: stake.clamp(0, maxStake),
        );
        party['matchId'] = match['id'];
        tx.set('parties/$partyId', party);
        return match;
      });

  Future<Doc> _newMatch(
    Tx tx,
    OnlineGame game,
    String partyId,
    List<String> seats,
    Map<Object?, Object?> names,
    List<Doc?> bots, {
    required int first,
    int stake = 0,
  }) async {
    final humans = {
      for (final (i, b) in bots.indexed)
        if (b == null) i,
    };
    final state = game.start(seats.length, _rng, first: first, humans: humans);
    final match = <String, Object?>{
      'id': _id(),
      'game': game.id,
      'party': partyId,
      'seats': seats,
      'names': [for (final s in seats) names[s] ?? 'Player'],
      'bots': bots,
      'gone': <int>[],
      'first': first,
      'status': 'live',
      'stake': stake,
      'version': 0,
      'turn': null,
      'state': null,
      'deadline': null,
      'turnAt': null,
      'timeouts': List.filled(seats.length, 0),
      'result': null,
      'rematch': <String>[],
      'next': null,
      'createdAt': _now,
    };
    _commit(tx, match, game, state, state);
    return match;
  }

  /// Plays [move] in match [id]. [version] must be the version the player
  /// saw, so a stale tap (or a double tap) can't land twice.
  Future<Doc> move(Player p, String id, int version, Doc move) => store.transaction((tx) async {
    final match = await _match(tx, id);
    if (match['status'] != 'live') throw const RefereeError(409, 'The game is over');
    if (match['version'] != version) throw const RefereeError(409, 'Out of date: the game moved on');
    final seat = _seat(match, p);
    final game = onlineGames[match['game']]!;
    final before = await _state(tx, id);
    final Doc state;
    try {
      state = game.play(before, seat, move);
    } on MoveError catch (e) {
      throw RefereeError(400, e.message);
    }
    (match['timeouts']! as List)[seat] = 0;
    _commit(tx, match, game, before, state);
    return match;
  });

  /// Anyone in the match can claim it once the player to move has run out
  /// of time: a legal move is made for them; after [maxTimeouts] in a row
  /// they're out (two players: the other wins).
  Future<Doc> claimTimeout(Player p, String id) => store.transaction((tx) async {
    final match = await _match(tx, id);
    _seat(match, p);
    if (match['status'] != 'live') throw const RefereeError(409, 'The game is over');
    if (_now < (match['deadline']! as int)) throw const RefereeError(409, 'There is still time');
    final game = onlineGames[match['game']]!;
    final seat = match['turn']! as int;
    final before = await _state(tx, id);
    final timeouts = (match['timeouts']! as List).cast<int>();
    timeouts[seat]++;
    match['timeouts'] = timeouts;
    if (timeouts[seat] >= maxTimeouts) {
      _leave(tx, match, game, before, seat, reason: 'timeout');
    } else {
      _commit(tx, match, game, before, game.play(before, seat, game.autoMove(before, seat, _rng)));
    }
    return match;
  });

  /// Gives up / leaves mid-game: with two players the other wins; with more
  /// the game goes on and the server plays (folds) for you.
  Future<Doc> forfeit(Player p, String id) => store.transaction((tx) async {
    final match = await _match(tx, id);
    final seat = _seat(match, p);
    if (match['status'] != 'live') return match;
    final game = onlineGames[match['game']]!;
    _leave(tx, match, game, await _state(tx, id), seat, reason: 'forfeit');
    return match;
  });

  void _leave(Tx tx, Doc match, OnlineGame game, Doc before, int seat, {required String reason}) {
    final gone = {...(match['gone']! as List).cast<int>(), seat}.toList()..sort();
    final bots = match['bots']! as List;
    final people = [
      for (var i = 0; i < bots.length; i++)
        if (bots[i] == null && !gone.contains(i)) i,
    ];
    final after = game.leave(before, seat);
    if (after == null || people.isEmpty) {
      // Nobody left to play with: whoever's next (a person if possible) wins.
      final winner = people.isNotEmpty ? people.first : _nextSeat(match, seat);
      match['gone'] = gone;
      _finish(match, Result(winner: winner), reason: reason);
      tx.set('matches/${match['id']}', match);
      return;
    }
    match['gone'] = gone;
    _commit(tx, match, game, before, after);
  }

  /// Asks for a rematch; when everyone still here has, a new match starts
  /// (the next seat goes first, same bots) and `next` points at it.
  Future<Doc> rematch(Player p, String id) => store.transaction((tx) async {
    final match = await _match(tx, id);
    _seat(match, p);
    if (match['status'] != 'over') throw const RefereeError(409, 'The game is still on');
    if (match['next'] != null) return match;
    final votes = (match['rematch']! as List).cast<String>();
    if (!votes.contains(p.uid)) votes.add(p.uid);
    match['rematch'] = votes;
    final seats = (match['seats']! as List).cast<String>();
    final bots = (match['bots'] as List? ?? List.filled(seats.length, null)).cast<Map<Object?, Object?>?>();
    final people = [
      for (final (i, s) in seats.indexed)
        if (bots[i] == null) s,
    ];
    if (people.every(votes.contains)) {
      final game = onlineGames[match['game']]!;
      final first = ((match['first'] as int? ?? 0) + 1) % seats.length;
      final names = {for (final (i, s) in seats.indexed) s: (match['names']! as List)[i]};
      final next = await _newMatch(
        tx,
        game,
        match['party']! as String,
        seats,
        names,
        [for (final b in bots) b?.cast<String, Object?>()],
        first: first,
        stake: match['stake'] as int? ?? 0,
      );
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

  /// The full state (secret: only the referee reads it).
  static Future<Doc> _state(Tx tx, String id) async {
    final s = await tx.get('secrets/$id');
    if (s == null) throw const RefereeError(404, 'No such game');
    return (s['state']! as Map).cast<String, Object?>();
  }

  static int _nextSeat(Doc match, int seat) => (seat + 1) % (match['seats']! as List).length;

  /// Plays bots (and players who left) until a person is to move, then
  /// writes it all: the secret state, the public match, each person's own
  /// cards. [before] is the state the players last saw.
  void _commit(Tx tx, Doc match, OnlineGame game, Doc before, Doc state) {
    final bots = match['bots']! as List;
    final gone = (match['gone']! as List).cast<int>();
    for (var guard = 0; guard < 5000 && game.result(state) == null; guard++) {
      final turn = game.turn(state);
      if (turn == null) break;
      final bot = bots[turn];
      if (bot != null) {
        state = game.play(state, turn, game.botMove(state, turn, (bot as Map).cast<String, Object?>(), _rng));
      } else if (gone.contains(turn)) {
        state = game.play(state, turn, game.autoMove(state, turn, _rng));
      } else {
        break;
      }
    }
    final id = match['id']! as String;
    match['state'] = game.public(state);
    match['version'] = (match['version']! as int) + 1;
    final result = game.result(state);
    if (result != null) {
      _finish(match, result, reason: result.draw ? 'draw' : 'won');
    } else {
      match['turn'] = game.turn(state);
      match['deadline'] = _now + (turnTime + game.show(before, state)).inMilliseconds;
      match['turnAt'] = _now;
    }
    tx.set('secrets/$id', {'state': state});
    final seats = (match['seats']! as List).cast<String>();
    for (final (i, uid) in seats.indexed) {
      if (bots[i] != null) continue;
      final mine = game.private(state, i);
      if (mine != null) tx.set('matches/$id/hands/$uid', mine);
    }
    tx.set('matches/$id', match);
  }

  void _finish(Doc match, Result result, {required String reason}) {
    match['status'] = 'over';
    match['turn'] = null;
    match['deadline'] = null;
    match['result'] = {...result.toJson(), 'reason': reason};
    match['version'] = (match['version']! as int) + 1;
  }
}
