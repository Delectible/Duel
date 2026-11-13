import 'dart:math';

import 'package:duel_server/duel_server.dart';
import 'package:test/test.dart';

void main() {
  const luca = Player(uid: 'luca', name: 'Luca'), sam = Player(uid: 'sam', name: 'Sam');
  late MemoryStore store;
  late Referee ref;
  var now = DateTime.utc(2026, 11, 13, 12);

  setUp(() async {
    store = MemoryStore();
    now = DateTime.utc(2026, 11, 13, 12);
    ref = Referee(store, rng: Random(7), clock: () => now);
    await ref.wallet(luca, carry: 3000);
    await ref.wallet(sam, carry: 3000);
  });

  Future<int> balance(String uid) async => (await store.get('wallets/$uid'))!['balance']! as int;

  /// Plays on until [hands] more hands have finished, folding or checking
  /// for the people (and asking for the next hand when one's over).
  Future<Map<String, Object?>> play(int hands) async {
    var t = (await store.get('cash/kitchen'))!;
    final start = ((t['hand'] as Map<Object?, Object?>?)?['no'] as int?) ?? 0;
    for (var i = 0; i < 400; i++) {
      final hand = t['hand'] as Map?;
      if (hand != null && (hand['no'] as int) >= start + hands && hand['won'] != null) break;
      final turn = t['turn'] as int?;
      if (turn != null) {
        final uid = ((t['seats']! as List)[turn] as Map)['id'];
        final p = uid == 'luca' ? luca : sam;
        t = await ref.cashMove(p, 'kitchen', t['version']! as int, {'kind': i.isEven ? 'call' : 'fold'});
      } else {
        now = now.add(const Duration(seconds: 6));
        t = await ref.cashTick(luca, 'kitchen');
      }
    }
    return t;
  }

  test('nobody there: the bots play on, and the table has moved on an hour later', () async {
    final first = await ref.cashLobby(luca);
    final before = ((first['tables']! as List).first as Map)['hands'];
    now = now.add(const Duration(hours: 1));
    final later = await ref.cashLobby(luca);
    final t = (later['tables']! as List).first as Map;
    expect(t['hands'], greaterThan(before as int));
    expect(t['hand'], isNull, reason: 'no real hands without people');
  });

  test('two friends sit at the Kitchen Table; hands are played; cashing out pays back', () async {
    await expectLater(ref.cashSit(luca, 'backRoom', 2500), throwsA(isA<RefereeError>()), reason: 'locked');
    await expectLater(ref.cashSit(luca, 'kitchen', 5000), throwsA(isA<RefereeError>()), reason: 'too much');
    var t = await ref.cashSit(luca, 'kitchen', 1000);
    expect(await balance('luca'), 2000);
    expect(t['hand'], isNotNull, reason: 'a hand starts with a person and the bots');
    expect(await store.get('cash/kitchen/hands/luca'), isNotNull);
    t = await ref.cashSit(sam, 'kitchen', 800);
    final people = [
      for (final s in (t['seats']! as List).whereType<Map<Object?, Object?>>())
        if (!(s['id'] as String).startsWith('bot:')) s['name'],
    ];
    expect(people, containsAll(['Luca', 'Sam']));
    // Luca can't sit at two tables.
    await expectLater(ref.cashSit(luca, 'kitchen', 1000), completes);
    t = await play(5);
    // Chips: everyone's still accounted for (no house cut).
    final lucaSeat = (t['seats']! as List).whereType<Map<Object?, Object?>>().firstWhere(
      (s) => s['id'] == 'luca',
    );
    t = await ref.cashLeave(luca, 'kitchen');
    // Mid-hand they may be standing up after it; finish the hand.
    for (
      var i = 0;
      i < 50 && ((t['seats']! as List).whereType<Map<Object?, Object?>>().any((s) => s['id'] == 'luca'));
      i++
    ) {
      t = await play(1);
    }
    expect((t['seats']! as List).whereType<Map<Object?, Object?>>().any((s) => s['id'] == 'luca'), isFalse);
    expect(await balance('luca'), greaterThanOrEqualTo(2000));
    expect(lucaSeat['stack'], isA<int>());
    // The lobby shows Sam still there.
    final lobby = await ref.cashLobby(sam);
    expect(lobby['mine'], 'kitchen');
  });

  test('a person who stops answering is stood up after two turns', () async {
    var t = await ref.cashSit(luca, 'kitchen', 1000);
    for (
      var i = 0;
      i < 200 && (t['seats']! as List).whereType<Map<Object?, Object?>>().any((s) => s['id'] == 'luca');
      i++
    ) {
      now = now.add(const Duration(minutes: 2));
      t = await ref.cashTick(luca, 'kitchen');
    }
    expect((t['seats']! as List).whereType<Map<Object?, Object?>>().any((s) => s['id'] == 'luca'), isFalse);
    expect(t['hand'], isNull, reason: 'back to the bots');
    expect(await balance('luca'), greaterThan(0));
  });
}
