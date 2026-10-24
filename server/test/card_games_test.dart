import 'dart:math';

import 'package:duel_server/duel_server.dart';
import 'package:test/test.dart';

/// Crazy Eights, Go Fish and Spades online: random play to the end, and
/// Spades' partner picking; plus the party's ways of picking a game.
void main() {
  const luca = Player(uid: 'luca', name: 'Luca'), sam = Player(uid: 'sam', name: 'Sam');

  Future<(Referee, String)> party({String mode = 'host', List<Map<String, Object?>> bots = const []}) async {
    final ref = Referee(MemoryStore(), rng: Random(3));
    final p = await ref.createParty(luca, mode: mode);
    await ref.joinParty(sam, p['code']! as String);
    if (bots.isNotEmpty) await ref.setBots(luca, p['id']! as String, bots);
    return (ref, p['id']! as String);
  }

  const bot = {'name': 'Pip', 'look': 'cap', 'difficulty': 'easy'};
  const bot2 = {'name': 'Finn', 'look': 'fin', 'difficulty': 'hard'};

  /// Plays every person's turn with what an Easy bot would do.
  Future<Map<String, Object?>> playOut(Referee ref, Map<String, Object?> m) async {
    final id = m['id']! as String;
    final rng = Random(5);
    for (var i = 0; i < 3000 && m['status'] == 'live'; i++) {
      final seat = m['turn']! as int;
      final who = (m['seats']! as List)[seat] == 'luca' ? luca : sam;
      final secret = (await ref.store.get('secrets/$id'))!['state']! as Map<String, Object?>;
      final game = onlineGames[m['game']]!;
      m = await ref.move(who, id, m['version']! as int, game.autoMove(secret, seat, rng));
    }
    return m;
  }

  for (final (game, bots) in [
    ('crazy8', [bot]),
    ('gofish', [bot, bot2]),
    ('spades', [bot, bot2]),
    ('spades', <Map<String, Object?>>[]),
    ('blitz', [bot]),
    ('blitz', [bot, bot2]),
  ]) {
    test('$game with ${bots.length} bots plays to the end', () async {
      final (ref, id) = await party(bots: bots);
      var m = await ref.startMatch(luca, id, game, options: const {'target': 150, 'wars': true});
      expect(m['status'], 'live');
      m = await playOut(ref, m);
      expect(m['status'], 'over');
    });
  }

  test('spades partners: two who want each other sit together', () {
    // 0 and 3 want each other; 1 wants 0 (can't have both).
    final (order, tossed) = SpadesGame.pairUp({0: 3, 3: 0, 1: 0}, Random(1));
    final teamOf = {for (final (pos, seat) in order.indexed) seat: pos % 2};
    expect(teamOf[0], teamOf[3]);
    expect(tossed, isFalse);
    // Nobody agrees: a coin toss.
    final (_, toss) = SpadesGame.pairUp({0: 1, 1: 2, 2: 3, 3: 0}, Random(1));
    expect(toss, isTrue);
  });

  test('spades: three players is refused', () async {
    final (ref, id) = await party(bots: [bot]);
    await expectLater(ref.startMatch(luca, id, 'spades'), throwsA(isA<RefereeError>()));
  });

  test('vote: the game everyone picks starts; first come: anyone can start', () async {
    final (ref, id) = await party(mode: 'vote');
    await expectLater(ref.startMatch(luca, id, 'crazy8'), throwsA(isA<RefereeError>()));
    final after = await ref.vote(luca, id, 'crazy8', stake: 10);
    expect(after['matchId'], isNull, reason: 'waiting for Sam');
    final done = await ref.vote(sam, id, 'gofish', stake: 5);
    expect(done['match'], isNotNull);
    expect(((done['lastVote']! as Map)['tossed']), isTrue, reason: 'one vote each');
    final (ref2, id2) = await party(mode: 'first');
    final m = await ref2.startMatch(sam, id2, 'crazy8');
    expect(m['status'], 'live');
  });
}
