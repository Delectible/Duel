part of 'referee.dart';

/// A party's deck of cards (Tabletop's card dealer): `deck/{party}` is
/// what everyone sees (how many cards each holds, the face-up pile, the
/// log), `deck/{party}/hands/{uid}` each person's own cards, and
/// `deckSecrets/{party}` the whole table. Seats follow the party's
/// members; the host deals and gathers, anyone draws, plays and takes.
extension Decks on Referee {
  Future<Doc> deckTable(Player p, String partyId, Doc op) => store.transaction((tx) async {
    final party = await tx.get('parties/$partyId');
    if (party == null) throw const RefereeError(404, 'No such party');
    final members = (party['members']! as List).cast<String>();
    if (!members.contains(p.uid)) throw const RefereeError(403, "You're not in this party");
    final names = {for (final e in ((party['names'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}'};
    final secret = await tx.get('deckSecrets/$partyId');
    var table = secret?['table'] is Map ? DeckTable.fromJson(secret!['table']! as Map) : null;
    // New members get a seat (an empty hand); leavers' cards go back.
    if (table == null || '${table.players}' != '$members') {
      final old = table;
      table = DeckTable.fresh(members, {for (final m in members) m: names[m] ?? 'Player'}, _rng);
      if (old != null) {
        for (final m in members) {
          table.hands[m] = [...?old.hands[m]];
        }
        table.pile.addAll(old.pile);
        table.pileBy.addAll(old.pileBy);
        table.deck = [
          ...old.deck,
          for (final h in old.hands.entries)
            if (!members.contains(h.key)) ...h.value,
        ];
        table.deals = old.deals;
        table.log.addAll(old.log);
      }
    }
    if (op['op'] != null) {
      try {
        table.apply(op, by: p.uid, host: party['host'] == p.uid);
      } on DeckError catch (e) {
        throw RefereeError(403, e.message);
      }
    }
    final version = ((secret?['version'] as int?) ?? 0) + 1;
    _put(tx, 'deckSecrets/$partyId', {'table': table.toJson(), 'version': version});
    final out = {
      ...table.public(),
      'party': partyId,
      'members': members,
      'host': party['host'],
      'version': version,
    };
    _put(tx, 'deck/$partyId', out);
    for (final m in members) {
      _put(tx, 'deck/$partyId/hands/$m', {
        'cards': [for (final c in table.hands[m] ?? const []) '$c'],
        'version': version,
      });
    }
    return {
      ...out,
      'mine': [for (final c in table.hands[p.uid] ?? const []) '$c'],
    };
  });
}
