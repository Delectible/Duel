import 'dart:math';

import 'package:duel_server/duel_server.dart';
import 'package:test/test.dart';

void main() {
  const luca = Player(uid: 'luca', name: 'Luca'), sam = Player(uid: 'sam', name: 'Sam');
  late MemoryStore store;
  late Referee ref;
  var now = DateTime.utc(2026, 11, 22, 12);

  setUp(() async {
    store = MemoryStore();
    now = DateTime.utc(2026, 11, 22, 12);
    ref = Referee(store, rng: Random(3), clock: () => now);
    await ref.wallet(luca, carry: 5000);
    await ref.wallet(sam, carry: 5000);
  });

  Future<int> balance(String uid) async => (await store.get('wallets/$uid'))!['balance']! as int;
  List<Map<Object?, Object?>?> seats(Map<String, Object?> t) => [
    for (final s in t['seats']! as List) s as Map?,
  ];
  int? seatOf(Map<String, Object?> t, String uid) {
    final i = seats(t).indexWhere((s) => s?['id'] == uid);
    return i < 0 ? null : i;
  }

  /// Plays [rounds] rounds for the people: bet 50, take insurance every
  /// other time, hit under 12, else stand. Returns each person's summed
  /// payouts.
  Future<Map<String, int>> play(String table, List<Player> people, int rounds) async {
    final paid = {for (final p in people) p.uid: 0};
    var t = (await store.get('bj/$table'))!;
    final counted = <int>{};
    for (var i = 0; i < 3000; i++) {
      final no = t['no'] as int? ?? 0;
      if (t['phase'] == 'done' && !counted.contains(no)) {
        counted.add(no);
        final payouts = (t['payouts'] as Map?) ?? const {};
        for (final p in people) {
          final s = seatOf(t, p.uid);
          if (s != null && payouts['$s'] != null) paid[p.uid] = paid[p.uid]! + (payouts['$s']! as int);
        }
        if (counted.length >= rounds) break;
      }
      switch (t['phase']) {
        case 'betting':
          final wants = (t['wants'] as Map?) ?? const {};
          final p = people.firstWhere(
            (p) => !wants.containsKey('${seatOf(t, p.uid)}'),
            orElse: () => people.first,
          );
          if (wants.containsKey('${seatOf(t, p.uid)}')) {
            now = now.add(const Duration(seconds: 20));
            t = await ref.bjTick(luca, table);
          } else {
            t = await ref.bjBet(p, table, 50);
          }
        case 'insurance':
          final answers = (t['answers'] as Map?) ?? const {};
          final bets = t['bets']! as List;
          final p = people.where((p) {
            final s = seatOf(t, p.uid)!;
            return bets[s] != null && !answers.containsKey('$s');
          }).firstOrNull;
          if (p == null) {
            now = now.add(const Duration(seconds: 20));
            t = await ref.bjTick(luca, table);
          } else {
            t = await ref.bjInsure(p, table, no.isEven);
          }
        case 'playing':
          final turn = t['turn']! as int;
          final uid = seats(t)[turn]!['id'];
          final p = people.firstWhere((p) => p.uid == uid);
          final cards = (t['cards']! as List).whereType<String>().length;
          t = await ref.bjMove(p, table, t['version']! as int, cards.isOdd ? 'hit' : 'stand');
        default:
          now = now.add(const Duration(seconds: 5));
          t = await ref.bjTick(luca, table);
      }
    }
    expect(counted.length, rounds);
    return paid;
  }

  test('the lobby: four tables with bots, each with its own rules', () async {
    final lobby = await ref.bjLobby(luca);
    final tables = lobby['tables']! as List;
    expect(tables, hasLength(4));
    for (final t in tables.cast<Map<Object?, Object?>>()) {
      expect((t['seats']! as List).whereType<Map<Object?, Object?>>(), isNotEmpty);
      expect(t['rules'], isA<Map<Object?, Object?>>());
    }
    expect(lobby['mine'], isNull);
  });

  test('two people play rounds with the bots; wallets move by exactly the payouts', () async {
    await ref.bjLobby(luca);
    await ref.bjSit(luca, 'main', seat: 0);
    await ref.bjSit(sam, 'main');
    final paid = await play('main', [luca, sam], 25);
    expect(await balance('luca'), 5000 + paid['luca']!);
    expect(await balance('sam'), 5000 + paid['sam']!);
    final lobby = await ref.bjLobby(luca);
    expect(lobby['mine'], 'main');
  });

  test('the hole card stays hidden until the dealer turns it', () async {
    await ref.bjSit(luca, 'corner');
    var t = await ref.bjBet(luca, 'corner', 10);
    for (var i = 0; i < 200 && t['phase'] != 'playing'; i++) {
      if (t['phase'] == 'insurance') t = await ref.bjInsure(luca, 'corner', false);
      if (t['phase'] == 'done') {
        now = now.add(const Duration(seconds: 5));
        t = await ref.bjTick(luca, 'corner');
        if (t['phase'] == 'betting') t = await ref.bjBet(luca, 'corner', 10);
      }
    }
    expect(t['phase'], 'playing');
    final hole = t['hole']! as int;
    expect((t['cards']! as List)[hole], isNull);
    t = await ref.bjMove(luca, 'corner', t['version']! as int, 'stand');
    // Standing ends it (only bots after): the hole card shows.
    for (var i = 0; i < 50 && t['phase'] == 'playing'; i++) {
      now = now.add(const Duration(seconds: 30));
      t = await ref.bjTick(luca, 'corner');
    }
    expect((t['cards']! as List)[hole], isNotNull);
  });

  test(
    'a turn that runs out is stood for you; twice and you are stood up; walking away empties the seat',
    () async {
      await ref.bjSit(luca, 'main');
      var t = await ref.bjBet(luca, 'main', 50);
      for (var i = 0; i < 400 && seatOf(t, 'luca') != null; i++) {
        now = now.add(const Duration(seconds: 30));
        t = await ref.bjTick(luca, 'main');
        if (t['phase'] == 'betting' && seatOf(t, 'luca') != null) t = await ref.bjBet(luca, 'main', 50);
      }
      expect(seatOf(t, 'luca'), isNull);
    },
  );

  test('bets out of range, or more than you have, are turned down', () async {
    await ref.bjSit(luca, 'main');
    expect(() => ref.bjBet(luca, 'main', 20), throwsA(isA<RefereeError>()));
    expect(() => ref.bjBet(luca, 'main', 9000), throwsA(isA<RefereeError>()));
    expect(() => ref.bjSit(luca, 'vault'), throwsA(isA<RefereeError>()));
  });

  test(
    'leaving mid-round frees the seat at once: you can sit elsewhere, and the round still pays you',
    () async {
      await ref.bjSit(luca, 'main');
      var t = await ref.bjBet(luca, 'main', 50);
      for (var i = 0; i < 50 && t['phase'] == 'insurance'; i++) {
        t = await ref.bjInsure(luca, 'main', false);
      }
      // Wait for a round you're in that isn't over yet.
      for (var i = 0; i < 200 && !(t['phase'] == 'playing' && t['turn'] == seatOf(t, 'luca')); i++) {
        now = now.add(const Duration(seconds: 5));
        t = await ref.bjTick(luca, 'main');
        if (seatOf(t, 'luca') == null) break;
        if (t['phase'] == 'betting') t = await ref.bjBet(luca, 'main', 50);
        if (t['phase'] == 'insurance') t = await ref.bjInsure(luca, 'main', false);
      }
      expect(t['phase'], 'playing');
      final before = await balance('luca');
      final seat = seatOf(t, 'luca')!;
      t = await ref.bjLeave(luca, 'main');
      expect(seatOf(t, 'luca'), isNull, reason: 'the seat is free straight away');
      // The dealer stood for them; with no one left, the round settled.
      expect(t['phase'], 'done');
      final net = (t['payouts']! as Map)['$seat']! as int;
      expect(await balance('luca'), before + 50 + net, reason: 'paid on the way out');
      final lobby = await ref.bjLobby(luca);
      expect(lobby['mine'], isNull);
      final corner = await ref.bjSit(luca, 'corner');
      expect(seatOf(corner, 'luca'), isNotNull, reason: 'free to sit at another table');
    },
  );

  test(
    'a seat left behind (the app closed hours ago) is cleared from the lobby; sitting elsewhere gets you up',
    () async {
      await ref.bjSit(luca, 'main');
      await ref.bjBet(luca, 'main', 50);
      // Hours later, nobody's moved the table on.
      now = now.add(const Duration(hours: 3));
      final lobby = await ref.bjLobby(luca);
      expect(lobby['mine'], isNull, reason: 'stood up: nothing happened for hours');
      final main = (lobby['tables']! as List).cast<Map<String, Object?>>().firstWhere(
        (t) => t['table'] == 'main',
      );
      expect(seatOf(main, 'luca'), isNull);
      // Sitting at a new table while still at another: you get up from it.
      await ref.bjSit(luca, 'main');
      final corner = await ref.bjSit(luca, 'corner');
      expect(seatOf(corner, 'luca'), isNotNull);
      expect(seatOf((await store.get('bj/main'))!, 'luca'), isNull);
    },
  );
}
