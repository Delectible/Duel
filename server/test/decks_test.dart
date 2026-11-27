import 'dart:math';

import 'package:duel_server/duel_server.dart';
import 'package:test/test.dart';

/// The party's card dealer: the host deals, everyone sees only their own
/// hand, anyone draws and plays; nobody else can deal.
void main() {
  const luca = Player(uid: 'luca', name: 'Luca'), sam = Player(uid: 'sam', name: 'Sam');

  test('deal, hidden hands, draw and play', () async {
    final ref = Referee(MemoryStore(), rng: Random(1));
    final p = await ref.createParty(luca);
    final id = p['id']! as String;
    await ref.joinParty(sam, p['code']! as String);
    await expectLater(ref.deckTable(sam, id, {'op': 'deal', 'n': 5}), throwsA(isA<RefereeError>()));
    var t = await ref.deckTable(luca, id, {'op': 'deal', 'n': 5});
    expect(t['deckLeft'], 42);
    expect(t['counts'], {'luca': 5, 'sam': 5});
    expect(t.containsKey('deck'), isFalse);
    expect(t.containsKey('hands'), isFalse);
    final samHand = (await ref.store.get('deck/$id/hands/sam'))!['cards']! as List;
    expect(samHand, hasLength(5));
    t = await ref.deckTable(sam, id, {'op': 'play', 'card': samHand.first});
    expect(t['pile'], [samHand.first]);
    await expectLater(
      ref.deckTable(luca, id, {'op': 'play', 'card': samHand[1]}),
      throwsA(isA<RefereeError>()),
    );
    t = await ref.deckTable(luca, id, {'op': 'draw'});
    expect(t['counts'], {'luca': 6, 'sam': 4});
    t = await ref.deckTable(luca, id, {'op': 'take'});
    expect((t['mine']! as List), contains(samHand.first));
  });
}
