part of 'referee.dart';

/// A party's shared scoreboard (Tabletop's Score counter): one per party,
/// `boards/{partyId}` (the [ScoreBoard] JSON in `board`, the party's
/// `members` and `host` for reading rights, a `version`). Every change goes
/// through [ScoreBoard.apply], which checks who may do what: everyone adds
/// themselves once and changes their own score (anyone's when the host
/// allows it); the host does anything.
extension Boards on Referee {
  Future<Doc> board(Player p, String partyId, Doc op) => store.transaction((tx) async {
    final party = await tx.get('parties/$partyId');
    if (party == null) throw const RefereeError(404, 'No such party');
    final members = (party['members']! as List).cast<String>();
    if (!members.contains(p.uid)) throw const RefereeError(403, "You're not in this party");
    final doc = await tx.get('boards/$partyId');
    final board = doc?['board'] is Map ? ScoreBoard.fromJson(doc!['board']! as Map) : ScoreBoard();
    if (op['op'] != null) {
      try {
        board.apply(op, by: p.uid, host: party['host'] == p.uid, now: _now);
      } on ScoreError catch (e) {
        throw RefereeError(403, e.message);
      }
    }
    final out = <String, Object?>{
      'party': partyId,
      'board': board.toJson(),
      'members': members,
      'host': party['host'],
      'version': ((doc?['version'] as int?) ?? 0) + (op['op'] != null || doc == null ? 1 : 0),
    };
    if (op['op'] != null ||
        doc == null ||
        doc['host'] != party['host'] ||
        '${doc['members']}' != '$members') {
      _put(tx, 'boards/$partyId', out);
    }
    return out;
  });
}
