import 'dart:math';

import 'package:duel_server/duel_server.dart';
import 'package:test/test.dart';

/// Goofspiel and Bank! online: bids in any order, hidden until all are in;
/// banking between rolls, bots' rolls waited out, late banks refused.
void main() {
  const luca = Player(uid: 'luca', name: 'Luca'), sam = Player(uid: 'sam', name: 'Sam');
  const bot = {'name': 'Pip', 'look': 'cap', 'difficulty': 'hard'};

  var now = DateTime(2026);
  Future<(Referee, String)> party({List<Map<String, Object?>> bots = const []}) async {
    now = DateTime(2026);
    final ref = Referee(MemoryStore(), rng: Random(3), clock: () => now);
    final p = await ref.createParty(luca);
    for (final p in [luca, sam]) {
      await ref.wallet(p, carry: 10000);
    }
    await ref.joinParty(sam, p['code']! as String);
    if (bots.isNotEmpty) await ref.setBots(luca, p['id']! as String, bots);
    return (ref, p['id']! as String);
  }

  Player who(Map<String, Object?> m, int seat) => (m['seats']! as List)[seat] == 'luca' ? luca : sam;

  test('goofspiel: bids hidden until all are in, any order, a stale version is fine', () async {
    final (ref, id) = await party(bots: [bot]);
    var m = await ref.startMatch(luca, id, 'gops');
    final mid = m['id']! as String;
    final seats = (m['seats']! as List).cast<String>();
    final lucaSeat = seats.indexOf('luca'), samSeat = seats.indexOf('sam');
    // The bot has bid already; nobody can see what.
    var state = m['state']! as Map;
    expect((state['ready']! as List).length, 1);
    expect(state['bids'], isEmpty);
    expect(state.containsKey('seed'), isFalse);
    final v = m['version']! as int;
    // Sam bids out of turn on an old version; then Luca on the same one.
    final hand = (await ref.store.get('matches/$mid/hands/sam'));
    expect(hand?['bid'], isNull);
    m = await ref.move(sam, mid, v, {'bid': 13});
    expect((await ref.store.get('matches/$mid/hands/sam'))!['bid'], 13);
    await expectLater(ref.move(sam, mid, v, {'bid': 12}), throwsA(isA<RefereeError>()));
    m = await ref.move(luca, mid, v, {'bid': 1});
    state = m['state']! as Map;
    expect((state['bids']! as List).length, 3);
    expect((state['prizes']! as List).length, 2);
    // Played out.
    final rng = Random(4);
    for (var i = 0; i < 100 && m['status'] == 'live'; i++) {
      final secret = (await ref.store.get('secrets/$mid'))!['state']! as Map<String, Object?>;
      for (final s in [lucaSeat, samSeat]) {
        if (m['status'] != 'live') break;
        final ready = ((m['state']! as Map)['ready']! as List);
        if (ready.contains(s)) continue;
        m = await ref.move(who(m, s), mid, 0, onlineGames['gops']!.autoMove(secret, s, rng));
      }
    }
    expect(m['status'], 'over');
  });

  test('bank: people bank between rolls; bots roll once their wait is up', () async {
    final (ref, id) = await party(bots: [bot]);
    var m = await ref.startMatch(luca, id, 'bank', options: const {'rounds': 3});
    final mid = m['id']! as String;
    expect((m['state']! as Map).containsKey('seed'), isFalse);
    var banks = 0, late = 0;
    final tried = <int>{};
    for (var i = 0; i < 2000 && m['status'] == 'live'; i++) {
      final turn = m['turn']! as int;
      final state = m['state']! as Map;
      final moves = state['moves']! as List;
      if ((m['bots']! as List)[turn] != null) {
        // Not yet: the others have their moment.
        await expectLater(ref.claimTimeout(luca, mid), throwsA(isA<RefereeError>()));
        now = DateTime.fromMillisecondsSinceEpoch(m['deadline']! as int).add(const Duration(milliseconds: 1));
        m = await ref.claimTimeout(luca, mid);
        continue;
      }
      // Someone not rolling banks now and then (on an old version: fine).
      final people = [
        for (final (s, b) in (m['bots']! as List).indexed)
          if (b == null && s != turn) s,
      ];
      final other = people.first;
      final rolls = moves.where((x) => (x as Map)['k'] == 'roll').length;
      if (rolls % 4 == 3 && tried.add(rolls)) {
        try {
          final g = BankOnline.replay(
            (await ref.store.get('secrets/$mid'))!['state']! as Map<String, Object?>,
          );
          m = await ref.move(who(m, other), mid, 0, {'k': 'bank', 'at': g.rolls, 'round': g.round});
          banks++;
        } on RefereeError {
          late++;
        }
        continue;
      }
      m = await ref.move(who(m, turn), mid, m['version']! as int, {'k': 'roll'});
    }
    expect(m['status'], 'over');
    expect(banks, greaterThan(0));
    expect(late + banks, greaterThan(0));
  });

  test('bank: a bank made on an earlier roll is refused', () async {
    final (ref, id) = await party();
    var m = await ref.startMatch(luca, id, 'bank', options: const {'rounds': 1});
    final mid = m['id']! as String;
    final turn = m['turn']! as int;
    m = await ref.move(who(m, turn), mid, m['version']! as int, {'k': 'roll'});
    await expectLater(
      () => ref.move(who(m, 1 - turn), mid, 0, {'k': 'bank', 'at': 0, 'round': 1}),
      throwsA(isA<RefereeError>()),
    );
    m = await ref.move(who(m, 1 - turn), mid, 0, {'k': 'bank', 'at': 1, 'round': 1});
    expect(((m['state']! as Map)['moves']! as List).last, {'p': 1 - turn, 'k': 'bank'});
  });

  test('liars: cups stay hidden until called; plays to the end with bots', () async {
    final (ref, id) = await party(bots: [bot]);
    var m = await ref.startMatch(luca, id, 'liars', options: const {'dice': 3});
    final mid = m['id']! as String;
    var state = m['state']! as Map;
    expect(state.containsKey('seed'), isFalse);
    expect(state['cups'], isEmpty);
    final mine = await ref.store.get('matches/$mid/hands/luca');
    expect((mine!['dice']! as List).length, 3);
    final rng = Random(2);
    for (var i = 0; i < 500 && m['status'] == 'live'; i++) {
      final turn = m['turn']! as int;
      final secret = (await ref.store.get('secrets/$mid'))!['state']! as Map<String, Object?>;
      m = await ref.move(
        who(m, turn),
        mid,
        m['version']! as int,
        onlineGames['liars']!.autoMove(secret, turn, rng),
      );
    }
    expect(m['status'], 'over');
    state = m['state']! as Map;
    expect((state['cups']! as List), isNotEmpty);
  });
}
