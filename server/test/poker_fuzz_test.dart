import 'dart:math';

import 'package:duel_server/duel_server.dart';
import 'package:test/test.dart';

/// Two friends and two bots playing every kind of move, many deals: the
/// referee never falls over (any error but a RefereeError is a 500).
void main() {
  const luca = Player(uid: 'luca', name: 'Luca'), sam = Player(uid: 'sam', name: 'Sam');
  final bots = [
    {'name': 'Pip', 'look': 'cap', 'difficulty': 'easy'},
    {'name': 'Finn', 'look': 'fin', 'difficulty': 'hard'},
  ];

  for (var seed = 0; seed < 40; seed++) {
    test('random play, seed $seed', () async {
      final store = MemoryStore();
      var now = DateTime.utc(2026, 10, 18);
      final ref = Referee(store, rng: Random(seed), clock: () => now);
      final rng = Random(seed * 7 + 1);
      final party = await ref.createParty(luca);
      for (final p in [luca, sam]) {
        await ref.wallet(p, carry: 10000);
      }
      await ref.joinParty(sam, party['code']! as String);
      await ref.setBots(luca, party['id']! as String, bots);
      var m = await ref.startMatch(luca, party['id']! as String, 'holdem', stake: 10);
      final id = m['id']! as String;
      for (var i = 0; i < 3000 && m['status'] == 'live'; i++) {
        final seat = (m['seats']! as List)[m['turn']! as int];
        final p = seat == 'luca' ? luca : sam;
        final roll = rng.nextInt(10);
        if (roll == 0) {
          // Someone's slow: the clock runs out and the other claims it.
          now = now.add(const Duration(minutes: 2));
          m = await ref.claimTimeout(p == luca ? sam : luca, id);
          continue;
        }
        final move = switch (roll) {
          1 => {'kind': 'fold'},
          2 || 3 || 4 => {'kind': 'check'},
          5 || 6 || 7 => {'kind': 'call'},
          _ => {'kind': 'raise', 'amount': rng.nextInt(400) + 1},
        };
        try {
          m = await ref.move(p, id, m['version']! as int, move);
        } on RefereeError {
          // Not legal now: the plain answer instead.
          m = await ref
              .move(p, id, m['version']! as int, {'kind': 'check'})
              .catchError((Object _) => ref.move(p, id, m['version']! as int, {'kind': 'call'}));
        }
        now = now.add(const Duration(seconds: 3));
      }
      expect(m['status'], 'over');
    });
  }
}
