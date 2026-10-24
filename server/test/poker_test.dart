import 'dart:math';

import 'package:duel_engine/poker/bot.dart';
import 'package:duel_server/duel_server.dart';
import 'package:test/test.dart';

/// Texas Hold'em online: two friends and two bots, the referee dealing.
void main() {
  late MemoryStore store;
  late Referee ref;
  late DateTime now;
  const luca = Player(uid: 'luca', name: 'Luca'), sam = Player(uid: 'sam', name: 'Sam');
  final bots = [
    {'name': 'Pip', 'look': 'cap', 'difficulty': 'easy'},
    {'name': 'Finn', 'look': 'fin', 'difficulty': 'hard'},
  ];

  setUp(() {
    store = MemoryStore();
    now = DateTime.utc(2026, 10, 16);
    ref = Referee(store, rng: Random(4), clock: () => now);
  });

  Future<Map<String, Object?>> table() async {
    final party = await ref.createParty(luca);
    for (final p in [luca, sam]) {
      await ref.wallet(p, carry: 10000);
    }
    await ref.joinParty(sam, party['code']! as String);
    await ref.setBots(luca, party['id']! as String, bots);
    return ref.startMatch(luca, party['id']! as String, 'holdem', stake: 10);
  }

  Player who(Map<String, Object?> m) => (m['seats']! as List)[m['turn']! as int] == 'luca' ? luca : sam;

  test('bots: host only, each with a difficulty, the table holds six', () async {
    final party = await ref.createParty(luca);
    for (final p in [luca, sam]) {
      await ref.wallet(p, carry: 10000);
    }
    final id = party['id']! as String;
    await ref.joinParty(sam, party['code']! as String);
    await expectLater(ref.setBots(sam, id, bots), throwsA(isA<RefereeError>()));
    await expectLater(
      ref.setBots(luca, id, List.filled(5, bots.first)),
      throwsA(isA<RefereeError>().having((e) => e.message, 'message', contains('room for 4'))),
    );
    await expectLater(
      ref.setBots(luca, id, [
        {'name': 'X', 'difficulty': 'silly'},
      ]),
      throwsA(isA<RefereeError>()),
    );
    final p = await ref.setBots(luca, id, bots);
    expect((p['bots']! as List).map((b) => (b as Map)['difficulty']), ['easy', 'hard']);
    expect((p['bots']! as List).map((b) => (b as Map)['id']), ['bot:0', 'bot:1']);
    // Four in a Row is for two: with bots in the party it can't start.
    await expectLater(ref.startMatch(luca, id, 'connect4'), throwsA(isA<RefereeError>()));
  });

  test('a deal: bots play themselves, a person is to act, cards stay private', () async {
    final m = await table();
    final id = m['id']! as String;
    expect(m['seats'], hasLength(4));
    expect(m['bots'], hasLength(4));
    expect(['luca', 'sam'], contains((m['seats']! as List)[m['turn']! as int]), reason: 'bots moved already');
    // What everyone sees: moves and the board, never the deck or hands.
    final public = m['state']! as Map;
    expect(public.containsKey('seed'), isFalse);
    expect(((public['hands']! as List).last as Map)['shown'], isEmpty);
    // Each person's own two cards, privately.
    final mine = (await store.get('matches/$id/hands/luca'))!;
    final cards = ((mine['hands']! as Map).values.last as List).cast<String>();
    expect(cards, hasLength(2));
    expect(await store.get('matches/$id/hands/bot:0'), isNull);
    expect((await store.get('secrets/$id'))!['state'], contains('seed'));
    // The clock allows for showing the bots' moves.
    expect((m['deadline']! as int) - (m['turnAt']! as int), greaterThanOrEqualTo(45000));
  });

  test('moves are checked: whose turn, legal amounts', () async {
    final m = await table();
    final id = m['id']! as String;
    final p = who(m), other = p == luca ? sam : luca;
    await expectLater(
      ref.move(other, id, m['version']! as int, {'kind': 'fold'}),
      throwsA(isA<RefereeError>().having((e) => e.status, 'status', 400)),
    );
    await expectLater(
      ref.move(p, id, m['version']! as int, {'kind': 'raise', 'amount': 1}),
      throwsA(isA<RefereeError>().having((e) => e.message, 'message', contains("isn't allowed"))),
    );
    await expectLater(ref.move(p, id, m['version']! as int, {'kind': 'dance'}), throwsA(isA<RefereeError>()));
  });

  test('play it out: shoving every hand ends the tournament with a winner', () async {
    var m = await table();
    final id = m['id']! as String;
    var hands = 0;
    for (var i = 0; i < 400 && m['status'] == 'live'; i++) {
      // Go all in (or call when you can't raise).
      m = await ref
          .move(who(m), id, m['version']! as int, {'kind': 'raise', 'amount': 100000})
          .catchError((Object _) => ref.move(who(m), id, m['version']! as int, {'kind': 'call'}));
      final hs = ((m['state']! as Map)['hands']! as List).cast<Map<Object?, Object?>>();
      hands = hs.length;
      // Finished hands that went to a showdown show the cards turned up.
      for (final h in hs.take(hs.length - 1)) {
        expect((h['board']! as List).length, anyOf(0, 3, 4, 5));
      }
    }
    expect(m['status'], 'over');
    expect(m['result'], containsPair('reason', 'won'));
    expect((m['result']! as Map)['winner'], isA<int>());
    expect(hands, greaterThan(1));
    final shown = ((m['state']! as Map)['hands']! as List).cast<Map<Object?, Object?>>().where(
      (h) => (h['shown']! as Map).isNotEmpty,
    );
    expect(shown, isNotEmpty, reason: 'all-ins get shown down');
  });

  test('bots play hidden styles and take their time; the styles show once it is over', () async {
    var m = await table();
    final id = m['id']! as String;
    final styles = ((await store.get('secrets/$id'))!['state']! as Map)['styles']! as List;
    expect(styles, hasLength(4));
    expect(styles.toSet(), hasLength(4), reason: 'no two alike');
    expect((m['state']! as Map).containsKey('styles'), isFalse, reason: 'hidden while playing');
    final seats = (m['seats']! as List).cast<String>();
    final botSeats = {
      for (final (i, uid) in seats.indexed)
        if (uid.startsWith('bot:')) i,
    };
    for (var i = 0; i < 400 && m['status'] == 'live'; i++) {
      m = await ref
          .move(who(m), id, m['version']! as int, {'kind': 'raise', 'amount': 100000, 'tempo': 99})
          .catchError(
            (Object _) => ref.move(who(m), id, m['version']! as int, {'kind': 'call', 'tempo': 99}),
          );
    }
    expect(m['status'], 'over');
    final state = (await store.get('secrets/$id'))!['state']! as Map;
    // Replay who moved: bots' moves carry their thinking time, people's never.
    final t = PokerGame.replay(state.cast<String, Object?>());
    expect(t.reads.history, isNotEmpty);
    final public = m['state']! as Map;
    var botMoves = 0;
    for (final h in (public['hands']! as List).cast<Map<Object?, Object?>>()) {
      for (final move in (h['moves']! as List).cast<List<Object?>>()) {
        if (move.length > 2) {
          botMoves++;
          expect(move[2], inInclusiveRange(0, 100));
        }
      }
    }
    expect(botMoves, greaterThan(0));
    final shown = (public['styles']! as Map).cast<String, Object?>();
    expect(shown.keys.map(int.parse).toSet(), botSeats, reason: 'only the bots are revealed');
    for (final e in shown.entries) {
      expect(e.value, styles[int.parse(e.key)]);
    }
  });

  test('a person cannot fake a thinking time', () async {
    final m = await table();
    final id = m['id']! as String;
    final after = await ref.move(who(m), id, m['version']! as int, {'kind': 'fold', 'tempo': 50});
    final secret = (await store.get('secrets/$id'))!['state']! as Map;
    final humans = (secret['humans']! as List).cast<int>();
    final seats = (after['seats']! as List).cast<String>();
    expect(humans.map((i) => seats[i]).toSet(), {'luca', 'sam'});
    // Replay the log: every move by a person has just kind and amount.
    final g = PokerGame.replay(secret.cast<String, Object?>());
    expect(g.reads.players.fold(0, (n, r) => n + r.folds), greaterThan(0));
    final logged = ((after['state']! as Map)['hands']! as List).cast<Map<Object?, Object?>>();
    final h0 = (logged.first['moves']! as List).cast<List<Object?>>();
    expect(h0.where((mv) => mv.length > 2 && mv[2] == 50), isEmpty);
  });

  test('older matches (no styles) still play by look', () {
    expect(PokerGame.styleAt({}, 0, {'look': 'shades'}), BotStyle.rock);
    expect(
      PokerGame.styleAt(
        {
          'styles': ['maniac'],
        },
        0,
        {'look': 'shades'},
      ),
      BotStyle.maniac,
    );
  });

  test('a friend leaves: with only one person left among bots, the game ends (stakes back)', () async {
    var m = await table();
    final id = m['id']! as String;
    m = await ref.forfeit(sam, id);
    expect(m['status'], 'over');
    expect(m['result'], containsPair('reason', 'ended'));
    expect((m['result']! as Map)['left'], [(m['seats']! as List).indexOf('sam')]);
    expect((m['result']! as Map)['winner'], isNull);
  });

  test('both people bust: the bots are ranked by their chances, a full lineup', () async {
    ref = Referee(store, rng: Random(4), clock: () => now); // a deal where the people go out first
    var m = await table();
    final id = m['id']! as String;
    final seats = (m['seats']! as List).cast<String>();
    final people = {seats.indexOf('luca'), seats.indexOf('sam')};
    // The people shove every hand; play until neither has chips.
    for (var i = 0; i < 400 && m['status'] == 'live'; i++) {
      Future<Map<String, Object?>> go(String kind) =>
          ref.move(who(m), id, m['version']! as int, {'kind': kind, 'amount': 100000});
      m = await go('raise').catchError((Object _) => go('call')).catchError((Object _) => go('check'));
    }
    expect(m['status'], 'over');
    final state = m['state']! as Map;
    final places = (state['places']! as Map).map((k, v) => MapEntry(int.parse('$k'), v as int));
    expect(places.keys.toSet(), {0, 1, 2, 3}, reason: 'everyone has a place');
    expect(places.values.toSet(), {1, 2, 3, 4});
    expect(places[(m['result']! as Map)['winner']], 1);
    // The people went out first: the bots were ranked, not played out.
    expect(state['simulated'], isTrue);
    expect(people.map((s) => places[s]).every((p) => p! >= 3), isTrue, reason: 'people at the bottom');
  });

  test('the ranking leans on stack size', () {
    final rng = Random(1);
    final firsts = <int, int>{};
    for (var i = 0; i < 3000; i++) {
      final order = PokerTable.rankByChances({0: 3000, 1: 1500, 2: 500}, rng);
      expect(order.toSet(), {0, 1, 2});
      firsts[order.first] = (firsts[order.first] ?? 0) + 1;
    }
    // About 60% / 30% / 10%.
    expect(firsts[0]! / 3000, closeTo(0.6, 0.05));
    expect(firsts[1]! / 3000, closeTo(0.3, 0.05));
    expect(firsts[2]! / 3000, closeTo(0.1, 0.04));
  });

  test('a person who loses a showdown mucks unless they show; a winner everyone folded to may show', () {
    const g = PokerGame();
    var state = g.start(2, Random(1), first: 0, humans: {0, 1});
    Map<String, Object?> hand(int i) =>
        ((g.public(state)['hands']! as List)[i] as Map).cast<String, Object?>();
    // Hand 1: check it down to a showdown.
    while ((state['hands']! as List).length == 1) {
      final seat = g.turn(state)!;
      final t = PokerGame.replay(state);
      state = g.play(state, seat, {'kind': t.hand.legalMoves().canCheck ? 'check' : 'call'});
    }
    final first = PokerGame.replay({
      ...state,
      'hands': [(state['hands']! as List).first],
    });
    final winners = {
      for (final e in first.hand.result!.winnings.entries)
        if (e.value > 0) first.seats[e.key],
    };
    final loser = {0, 1}.difference(winners).single;
    expect(hand(0)['mucked'], [loser]);
    expect(
      (hand(0)['shown']! as Map).keys,
      containsAll(['0', '1']),
      reason: 'the phones need both to settle the pot',
    );
    expect(PokerGame.replay(state).history.first['mucked'], [loser]);
    expect(() => g.play(state, winners.single, {'kind': 'show', 'hand': 0}), throwsA(isA<MoveError>()));
    final turn = g.turn(state);
    state = g.play(state, loser, {'kind': 'show', 'hand': 0});
    expect(hand(0)['mucked'], isNull);
    expect(g.turn(state), turn, reason: 'showing is not a turn');
    expect(g.aside({'kind': 'show'}), isTrue);
    // Hand 2: the first to act raises, the other folds.
    final raiser = g.turn(state)!;
    state = g.play(state, raiser, {'kind': 'raise', 'amount': 200});
    state = g.play(state, g.turn(state)!, {'kind': 'fold'});
    expect(() => g.play(state, 1 - raiser, {'kind': 'show', 'hand': 1}), throwsA(isA<MoveError>()));
    expect(hand(1)['showed'], isNull);
    state = g.play(state, raiser, {'kind': 'show', 'hand': 1});
    expect(hand(1)['showed'], [raiser]);
    expect((hand(1)['shown']! as Map).keys, ['$raiser']);
  });
}
