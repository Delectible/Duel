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
  const Player({required this.uid, required this.name, this.avatar = const {}, this.version = ''});
  final String uid;
  final String name;
  final Doc avatar;

  /// The app's version ("0.9.3"; empty from apps older than this): kept
  /// per member so an older app can tell its player to update.
  final String version;
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
///   rematch votes and the next match's id. People who leave mid-game are
///   in `left`; a bot playing a left seat is in `standIns` (by seat); while
///   the host decides what happens to a seat, `paused` is {seats, decider,
///   at, until} and nobody moves.
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
  /// How a party picks its games: the host picks, everyone votes, or
  /// whoever goes first.
  static const modes = {'host', 'vote', 'first'};

  Future<Doc> createParty(Player host, {String mode = 'host'}) => store.transaction((tx) async {
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
      'versions': {if (host.version.isNotEmpty) host.uid: host.version},
      'bots': <Doc>[],
      'mode': modes.contains(mode) ? mode : 'host',
      'votes': <String, Object?>{},
      'matchId': null,
      'createdAt': _now,
    };
    _put(tx, 'parties/$id', party);
    _put(tx, 'codes/$code', {'party': id});
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
    if (p.version.isNotEmpty) {
      party['versions'] = {...((party['versions'] as Map?) ?? const {}), p.uid: p.version};
    }
    party['members'] = members;
    _put(tx, 'parties/$id', party);
    return party;
  });

  /// Leaves a party; the last one out closes it. A new host is picked if
  /// the host leaves.
  Future<void> leaveParty(Player p, String id) => store.transaction((tx) async {
    final party = await tx.get('parties/$id');
    if (party == null) return;
    // In the party's game: leaving the party leaves the game too.
    final matchId = party['matchId'] as String?;
    final match = matchId == null ? null : await tx.get('matches/$matchId');
    if (match != null && match['status'] == 'live') {
      final seat = (match['seats']! as List).indexOf(p.uid);
      if (seat >= 0 && !_left(match).contains(seat)) {
        final game = onlineGames[match['game']]!;
        await _leave(
          tx,
          match,
          game,
          await _state(tx, matchId!),
          seat,
          reason: 'forfeit',
          party: party,
          leaving: p.uid,
        );
      }
    }
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
    _put(tx, 'parties/$id', party);
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
    _put(tx, 'parties/$partyId', party);
    return party;
  });

  // --- Matches -------------------------------------------------------------

  /// Biggest stake the host can set.
  static const maxStake = 1000;

  /// Starts [gameId] for everyone in the party and its bots (host only).
  /// [stake] is what every player puts in (from their wallet; see [_save]).
  Future<Doc> startMatch(Player p, String partyId, String gameId, {int stake = 0, Doc options = const {}}) =>
      store.transaction((tx) async {
        final party = await tx.get('parties/$partyId');
        if (party == null) throw const RefereeError(404, 'No such party');
        switch (party['mode'] ?? 'host') {
          case 'vote':
            throw const RefereeError(409, 'This party votes: vote for a game instead');
          case 'first':
            if (!(party['members']! as List).contains(p.uid)) {
              throw const RefereeError(403, "You're not in this party");
            }
          default:
            if (party['host'] != p.uid) throw const RefereeError(403, 'Only the host can start a game');
        }
        return _start(tx, party, gameId, stake: stake, options: options);
      });

  /// Votes for [gameId] (a party that votes). Once everyone has, the game
  /// with the most votes starts (a coin toss between a tie), at the
  /// smallest stake anyone voted for it with. Voting again changes your
  /// vote.
  Future<Doc> vote(Player p, String partyId, String gameId, {int stake = 0, Doc options = const {}}) =>
      store.transaction((tx) async {
        final party = await tx.get('parties/$partyId');
        if (party == null) throw const RefereeError(404, 'No such party');
        final members = (party['members']! as List).cast<String>();
        if (!members.contains(p.uid)) throw const RefereeError(403, "You're not in this party");
        if (!onlineGames.containsKey(gameId)) throw RefereeError(400, "$gameId can't be played online yet");
        final votes = {...((party['votes'] as Map?) ?? const {}).cast<String, Object?>()};
        votes[p.uid] = {'game': gameId, 'stake': stake.clamp(0, maxStake), 'options': options, 'at': _now};
        party['votes'] = votes;
        if (!members.every(votes.containsKey)) {
          _put(tx, 'parties/$partyId', party);
          return party;
        }
        final tally = <String, int>{};
        for (final v in votes.values) {
          tally.update((v! as Map)['game']! as String, (n) => n + 1, ifAbsent: () => 1);
        }
        final most = tally.values.reduce(max);
        final top = (tally.keys.where((g) => tally[g] == most).toList()..sort());
        final pick = top[_rng.nextInt(top.length)];
        final forIt = [
          for (final v in votes.values)
            if ((v! as Map)['game'] == pick) v,
        ]..sort((a, b) => ((a as Map)['at'] as int).compareTo((b as Map)['at'] as int));
        party['votes'] = <String, Object?>{};
        party['lastVote'] = {'game': pick, 'tally': tally, 'tossed': top.length > 1};
        final match = await _start(
          tx,
          party,
          pick,
          stake: forIt.map((v) => (v as Map)['stake'] as int).reduce(min),
          options: ((forIt.first as Map)['options'] as Map?)?.cast<String, Object?>() ?? const {},
        );
        return {...party, 'match': match};
      });

  Future<Doc> _start(Tx tx, Doc party, String gameId, {int stake = 0, Doc options = const {}}) async {
    final partyId = party['id']! as String;
    // One game at a time: a live one has to finish or be ended first
    // (one nobody has touched for a long while is ended here).
    final currentId = party['matchId'] as String?;
    final current = currentId == null ? null : await tx.get('matches/$currentId');
    if (current != null && current['status'] == 'live') {
      if (!_abandoned(current)) {
        throw const RefereeError(409, 'A game is still going. Finish it, or end it from the party screen.');
      }
      _end(current);
      await _save(tx, current);
    }
    final game = onlineGames[gameId];
    if (game == null) throw RefereeError(400, "$gameId can't be played online yet");
    final members = (party['members']! as List).cast<String>();
    final bots = ((party['bots'] as List?) ?? const []).cast<Map<Object?, Object?>>();
    final count = members.length + bots.length;
    if (count < game.minPlayers || count > game.maxPlayers) {
      throw RefereeError(409, '${game.id} is for ${game.minPlayers}–${game.maxPlayers} players');
    }
    if (game.counts case final ok? when !ok.contains(count)) {
      throw RefereeError(409, '${game.id} is for ${(ok.toList()..sort()).join(' or ')} players');
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
      options: options,
    );
    party['matchId'] = match['id'];
    _put(tx, 'parties/$partyId', party);
    return match;
  }

  Future<Doc> _newMatch(
    Tx tx,
    OnlineGame game,
    String partyId,
    List<String> seats,
    Map<Object?, Object?> names,
    List<Doc?> bots, {
    required int first,
    int stake = 0,
    Doc options = const {},
  }) async {
    final humans = {
      for (final (i, b) in bots.indexed)
        if (b == null) i,
    };
    // Everyone puts the stake in now (bots' come from the bank).
    if (stake > 0) {
      for (final i in humans) {
        final w = await tx.get('wallets/${seats[i]}');
        final name = names[seats[i]] ?? 'Player';
        if (w == null) throw RefereeError(409, '$name needs the latest Duel to play for pips');
        final balance = w['balance']! as int;
        if (balance < stake) {
          throw RefereeError(409, "$name has ${max(balance, 0)} pips: that's not enough for this stake");
        }
        _setWallet(tx, seats[i], {...w, 'balance': balance - stake});
      }
    }
    final state = game.start(seats.length, _rng, first: first, humans: humans, options: options);
    final match = <String, Object?>{
      'id': _id(),
      'game': game.id,
      'party': partyId,
      'seats': seats,
      'names': [for (final s in seats) names[s] ?? 'Player'],
      'bots': bots,
      'gone': <int>[],
      'left': <int>[],
      'standIns': <String, Object?>{},
      'paused': null,
      'first': first,
      'status': 'live',
      'stake': stake,
      'options': options,
      'version': 0,
      'turn': null,
      'state': null,
      'deadline': null,
      'turnAt': null,
      'timeouts': List.filled(seats.length, 0),
      'result': null,
      'paid': stake <= 0,
      'rematch': <String>[],
      'next': null,
      'createdAt': _now,
    };
    await _commit(tx, match, game, state, state);
    return match;
  }

  /// Plays [move] in match [id]. [version] must be the version the player
  /// saw, so a stale tap (or a double tap) can't land twice.
  Future<Doc> move(Player p, String id, int version, Doc move) => store.transaction((tx) async {
    final match = await _match(tx, id);
    if (match['status'] != 'live') throw const RefereeError(409, 'The game is over');
    if (match['paused'] != null) throw const RefereeError(409, 'Paused: waiting for the host');
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
    if (!game.aside(move)) (match['timeouts']! as List)[seat] = 0;
    await _commit(tx, match, game, before, state, keepClock: game.aside(move));
    return match;
  });

  /// Anyone in the match can claim it once the player to move has run out
  /// of time: a legal move is made for them; after [maxTimeouts] in a row
  /// they're out (two players: the other wins).
  Future<Doc> claimTimeout(Player p, String id) => store.transaction((tx) async {
    final match = await _match(tx, id);
    _seat(match, p);
    if (match['status'] != 'live') throw const RefereeError(409, 'The game is over');
    final deadline = match['deadline'] as int?;
    if (match['paused'] != null || deadline == null) {
      throw const RefereeError(409, 'Paused: waiting for the host');
    }
    if (_now < deadline) throw const RefereeError(409, 'There is still time');
    final game = onlineGames[match['game']]!;
    final seat = match['turn']! as int;
    final before = await _state(tx, id);
    final timeouts = (match['timeouts']! as List).cast<int>();
    timeouts[seat]++;
    match['timeouts'] = timeouts;
    if (timeouts[seat] >= maxTimeouts) {
      final party = await tx.get('parties/${match['party']}');
      await _leave(tx, match, game, before, seat, reason: 'timeout', party: party);
    } else {
      await _commit(tx, match, game, before, game.play(before, seat, game.autoMove(before, seat, _rng)));
    }
    return match;
  });

  /// Leaves mid-game (on purpose). See [_leave] for what happens next.
  Future<Doc> forfeit(Player p, String id) => store.transaction((tx) async {
    final match = await _match(tx, id);
    final seat = _seat(match, p);
    if (match['status'] != 'live' || _left(match).contains(seat)) return match;
    final game = onlineGames[match['game']]!;
    final party = await tx.get('parties/${match['party']}');
    await _leave(tx, match, game, await _state(tx, id), seat, reason: 'forfeit', party: party);
    return match;
  });

  /// How long the host has to choose (bot or end) before a bot sits in.
  static const decideTime = Duration(seconds: 30);

  /// [seat] has left (or timed out for good):
  /// - a one-on-one with no bots: the other person wins;
  /// - one person (or nobody) left among bots: the game ends, and the
  ///   people still in get their stakes back ([_end]);
  /// - two or more people still in: the game pauses for the host to bring
  ///   in a bot for them or end the game ([decide]); the leaver can come
  ///   back ([rejoin]) until then, or later in place of the bot.
  Future<void> _leave(
    Tx tx,
    Doc match,
    OnlineGame game,
    Doc before,
    int seat, {
    required String reason,
    Doc? party,
    String? leaving,
  }) async {
    final left = ({..._left(match), seat}.toList()..sort());
    match['left'] = left;
    final seats = (match['seats']! as List).cast<String>();
    final bots = match['bots']! as List;
    final people = [
      for (var i = 0; i < seats.length; i++)
        if (bots[i] == null && !left.contains(i)) i,
    ];
    final anyBots = bots.any((b) => b != null) || _standIns(match).isNotEmpty;
    final after = game.leave(before, seat);
    if (people.length == 1 && !anyBots && seats.length == 2) {
      _finish(match, Result(winner: people.single), reason: reason);
      await _save(tx, match);
      return;
    }
    if (people.length <= 1 || after == null) {
      _end(match);
      await _save(tx, match);
      return;
    }
    // Pause for the host. If the host is the one who left, the next person
    // still playing takes over as host.
    final paused = (match['paused'] as Map?)?.cast<String, Object?>();
    final waiting = {...((paused?['seats'] as List?) ?? const []).cast<int>(), seat}.toList()..sort();
    final playing = {for (final i in people) seats[i]};
    var decider = party?['host'] as String?;
    if (decider == null || !playing.contains(decider)) {
      final members = ((party?['members'] as List?) ?? const []).cast<String>().where((m) => m != leaving);
      decider = members.where(playing.contains).firstOrNull ?? seats[people.first];
      if (party != null && party['host'] != decider && (party['members']! as List).contains(decider)) {
        party['host'] = decider;
        _put(tx, 'parties/${party['id']}', party);
      }
    }
    match['paused'] = {
      'seats': waiting,
      'decider': decider,
      'at': _now,
      'until': _now + decideTime.inMilliseconds,
    };
    match['turn'] = null;
    match['deadline'] = null;
    match['state'] = game.public(after);
    match['version'] = (match['version']! as int) + 1;
    _put(tx, 'secrets/${match['id']}', {'state': after});
    await _save(tx, match);
  }

  /// The host's call on the seats waiting in [Doc] `paused`: `bot` (a bot
  /// plays them from where they are) or `end` (the game stops; stakes back
  /// for the people still in). Once the time is up anyone may ask for the
  /// bot, so a game never waits on a phone in a pocket.
  Future<Doc> decide(Player p, String id, String choice) => store.transaction((tx) async {
    final match = await _match(tx, id);
    _seat(match, p);
    final paused = (match['paused'] as Map?)?.cast<String, Object?>();
    if (match['status'] != 'live' || paused == null) return match; // already decided
    final isDecider = paused['decider'] == p.uid;
    if (choice == 'end') {
      if (!isDecider) throw const RefereeError(403, 'The host decides');
      _end(match);
      await _save(tx, match);
      return match;
    }
    if (choice != 'bot') throw const RefereeError(400, 'Choose bot or end');
    if (!isDecider && _now < (paused['until']! as int)) throw const RefereeError(409, 'Waiting for the host');
    final names = match['names']! as List;
    final standIns = _standIns(match);
    for (final seat in (paused['seats']! as List).cast<int>()) {
      standIns['$seat'] = {
        'name': names[seat],
        'look': const ['cap', 'shades', 'fin', 'spiky'][_rng.nextInt(4)],
        'difficulty': 'normal',
      };
    }
    match['standIns'] = standIns;
    match['paused'] = null;
    final game = onlineGames[match['game']]!;
    final state = await _state(tx, id);
    await _commit(tx, match, game, state, state);
    return match;
  });

  /// Back in after leaving: your seat as it stands (taken back from the
  /// bot, or straight back while the host is still deciding).
  Future<Doc> rejoin(Player p, String id) => store.transaction((tx) async {
    final match = await _match(tx, id);
    final seat = _seat(match, p);
    if (match['status'] != 'live') throw const RefereeError(409, 'That game is over');
    final left = _left(match);
    if (!left.contains(seat)) return match; // still in
    match['left'] = left..remove(seat);
    match['standIns'] = _standIns(match)..remove('$seat');
    (match['timeouts']! as List)[seat] = 0;
    final game = onlineGames[match['game']]!;
    final state = game.rejoin(await _state(tx, id), seat);
    final paused = (match['paused'] as Map?)?.cast<String, Object?>();
    if (paused != null) {
      final waiting = (paused['seats']! as List).cast<int>()..remove(seat);
      if (waiting.isNotEmpty) {
        // Others still to decide on: stay paused.
        match['paused'] = {...paused, 'seats': waiting};
        match['state'] = game.public(state);
        match['version'] = (match['version']! as int) + 1;
        _put(tx, 'secrets/$id', {'state': state});
        await _save(tx, match);
        return match;
      }
      match['paused'] = null;
    }
    await _commit(tx, match, game, state, state);
    return match;
  });

  /// Host: ends the party's live game for everyone (stakes back for those
  /// still in). For a game that's stuck, or that the party wants to stop.
  Future<Doc> endMatch(Player p, String id) => store.transaction((tx) async {
    final match = await _match(tx, id);
    final party = await tx.get('parties/${match['party']}');
    if (party?['host'] != p.uid) throw const RefereeError(403, 'Only the host can end the game');
    if (match['status'] != 'live') return match;
    _end(match);
    await _save(tx, match);
    return match;
  });

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
    // Whoever left isn't in the rematch (nor the bots that sat in for them).
    final left = _left(match);
    final allSeats = (match['seats']! as List).cast<String>();
    final allBots = (match['bots'] as List? ?? List.filled(allSeats.length, null))
        .cast<Map<Object?, Object?>?>();
    final keep = [
      for (var i = 0; i < allSeats.length; i++)
        if (!left.contains(i)) i,
    ];
    final seats = [for (final i in keep) allSeats[i]];
    final bots = [for (final i in keep) allBots[i]];
    final people = [
      for (final (i, s) in seats.indexed)
        if (bots[i] == null) s,
    ];
    if (!people.contains(p.uid)) throw const RefereeError(409, 'You left that game');
    final game = onlineGames[match['game']]!;
    if (seats.length < game.minPlayers) throw RefereeError(409, 'Not enough players left for a rematch');
    if (people.every(votes.contains)) {
      final first = ((match['first'] as int? ?? 0) + 1) % seats.length;
      final names = {for (final i in keep) allSeats[i]: (match['names']! as List)[i]};
      final next = await _newMatch(
        tx,
        game,
        match['party']! as String,
        seats,
        names,
        [for (final b in bots) b?.cast<String, Object?>()],
        first: first,
        stake: match['stake'] as int? ?? 0,
        options: (match['options'] as Map?)?.cast<String, Object?>() ?? const {},
      );
      match['next'] = next['id'];
      final party = await tx.get('parties/${match['party']}');
      if (party != null) {
        party['matchId'] = next['id'];
        _put(tx, 'parties/${match['party']}', party);
      }
    }
    match['version'] = (match['version']! as int) + 1;
    await _save(tx, match);
    return match;
  });

  // --- Wallets -------------------------------------------------------------

  /// Most a phone can bring over (or report from bot games in one go): a
  /// sanity limit, not a rule anyone meets playing.
  static const maxCarry = 10000000;

  /// Your pips, kept here (`wallets/{uid}`: balance, the last report ids
  /// applied). The first call makes it with the phone's own balance
  /// ([carry], debt and all); later ones add what bot games won or lost
  /// since ([delta], once per [id], so a resend can't count twice).
  Future<Doc> wallet(Player p, {int? carry, String? id, int delta = 0}) => store.transaction((tx) async {
    final w = await tx.get('wallets/${p.uid}');
    final Doc next;
    if (w == null) {
      next = {
        'balance': (carry ?? startingBalance).clamp(-maxCarry, maxCarry),
        'applied': [?id],
        'createdAt': _now,
      };
    } else {
      final applied = ((w['applied'] as List?) ?? const []).cast<String>();
      if (id == null || applied.contains(id)) return w;
      next = {
        ...w,
        'balance': (w['balance']! as int) + delta.clamp(-maxCarry, maxCarry),
        'applied': [...applied.skip(max(0, applied.length - 19)), id],
      };
    }
    _setWallet(tx, p.uid, next);
    return next;
  });

  /// What a phone starts with (as the app does).
  static const startingBalance = 100;

  void _setWallet(Tx tx, String uid, Doc w) => tx.set('wallets/$uid', {...w, 'updatedAt': _now});

  /// Writes the match; once it's over, pays out its pot (once):
  /// - won: the pot (everyone's stake, bots' too) goes to the winner,
  ///   split between partners; a bot's (or a leaver's) share stays with
  ///   the bank;
  /// - a draw, or ended early: the people still in get their stake back;
  ///   whoever left lost theirs.
  /// The payouts go in the result (`payouts`: seat -> pips).
  Future<void> _save(Tx tx, Doc match) async {
    final stake = match['stake'] as int? ?? 0;
    final result = (match['result'] as Map?)?.cast<String, Object?>();
    if (match['status'] == 'over' && match['paid'] == false && stake > 0 && result != null) {
      final seats = (match['seats']! as List).cast<String>();
      final bots = match['bots']! as List;
      final left = _left(match);
      bool person(int i) => bots[i] == null && !left.contains(i);
      final payouts = <String, int>{};
      final reason = result['reason'];
      if (reason == 'draw' || reason == 'ended') {
        for (var i = 0; i < seats.length; i++) {
          if (person(i)) payouts['$i'] = stake;
        }
      } else {
        final winners = ((result['winners'] as List?) ?? [?result['winner']]).cast<int>();
        final share = stake * seats.length ~/ max(1, winners.length);
        for (final i in winners) {
          if (person(i)) payouts['$i'] = share;
        }
      }
      for (final e in payouts.entries) {
        final uid = seats[int.parse(e.key)];
        final w = await tx.get('wallets/$uid');
        if (w != null) _setWallet(tx, uid, {...w, 'balance': (w['balance']! as int) + e.value});
      }
      match['result'] = {...result, 'payouts': payouts};
      match['paid'] = true;
    }
    _put(tx, 'matches/${match['id']}', match);
  }

  // --- Helpers -------------------------------------------------------------

  /// How long things last after their last change before Firestore deletes
  /// them (its TTL policy on `expireAt`; see online.yml). Finished games
  /// are only needed for the game-over screen, a rematch or coming back.
  static const gameLife = Duration(days: 1);
  static const partyLife = Duration(days: 30);

  /// Writes [doc] with its expiry: games (with their secret state and
  /// hands) a day after the last move, parties (and their codes) 30 days
  /// after the last change.
  void _put(Tx tx, String path, Doc doc) {
    final party = path.startsWith('parties/') || path.startsWith('codes/');
    final expireAt = _clock().toUtc().add(party ? partyLife : gameLife);
    tx.set(path, {...doc, 'expireAt': expireAt});
    // Keep the code alive as long as its party.
    if (path.startsWith('parties/') && doc['code'] != null) {
      tx.set('codes/${doc['code']}', {'party': doc['id'], 'expireAt': expireAt});
    }
  }

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

  static List<int> _left(Doc match) => [...((match['left'] as List?) ?? const []).cast<int>()];

  static Map<String, Object?> _standIns(Doc match) => {
    ...((match['standIns'] as Map?) ?? const {}).cast<String, Object?>(),
  };

  /// Live, but nobody has touched it for a long while (everyone closed the
  /// app): a new game may replace it.
  bool _abandoned(Doc match) {
    final paused = match['paused'] as Map?;
    final last = paused != null ? paused['until'] as int? : match['deadline'] as int?;
    return last != null && _now > last + const Duration(minutes: 10).inMilliseconds;
  }

  /// Ends a game nobody won: people left or the host stopped it. The
  /// people still in get their stakes back; whoever left lost theirs.
  void _end(Doc match) {
    match['paused'] = null;
    _finish(match, const Result(), reason: 'ended');
    (match['result']! as Map)['left'] = _left(match);
  }

  /// Plays bots (and players who left) until a person is to move, then
  /// writes it all: the secret state, the public match, each person's own
  /// cards. [before] is the state the players last saw.
  Future<void> _commit(
    Tx tx,
    Doc match,
    OnlineGame game,
    Doc before,
    Doc state, {
    bool keepClock = false,
  }) async {
    final bots = match['bots']! as List;
    final gone = (match['gone']! as List).cast<int>();
    final standIns = _standIns(match);
    for (var guard = 0; guard < 5000 && game.result(state) == null; guard++) {
      final turn = game.turn(state);
      if (turn == null) break;
      final bot = bots[turn] ?? standIns['$turn'];
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
    } else if (!keepClock || match['turn'] != game.turn(state)) {
      match['turn'] = game.turn(state);
      match['deadline'] = _now + (turnTime + game.show(before, state)).inMilliseconds;
      match['turnAt'] = _now;
    }
    _put(tx, 'secrets/$id', {'state': state});
    final seats = (match['seats']! as List).cast<String>();
    for (final (i, uid) in seats.indexed) {
      if (bots[i] != null) continue;
      final mine = game.private(state, i);
      if (mine != null) _put(tx, 'matches/$id/hands/$uid', mine);
    }
    await _save(tx, match);
  }

  void _finish(Doc match, Result result, {required String reason}) {
    match['status'] = 'over';
    match['turn'] = null;
    match['deadline'] = null;
    match['result'] = {...result.toJson(), 'reason': reason};
    match['version'] = (match['version']! as int) + 1;
  }
}
