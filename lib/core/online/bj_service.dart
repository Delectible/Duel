import 'dart:async';

import 'party.dart';

/// The shared blackjack tables, through the referee: the lobby (every
/// table), sitting down, bets, insurance, moves and standing up. The table
/// you're at is followed live ([watch]); every card is in it but the
/// dealer's hole card (until it turns).
class BjService {
  BjService(this.party);

  final PartyService party;

  OnlineBackend get backend => party.backend;
  String? get uid => party.uid;

  /// Every table and the one you're at; throws (offline, server down) or
  /// times out after [limit].
  Future<({List<Doc> tables, String? mine})> lobby({Duration limit = const Duration(seconds: 5)}) async {
    await party.signedIn().timeout(limit);
    final r = await backend.call('/v1/bj').timeout(limit);
    return (
      tables: [for (final t in (r['tables'] as List?) ?? const []) (t as Map).cast<String, Object?>()],
      mine: r['mine'] as String?,
    );
  }

  Future<Doc> sit(String table, {int? seat}) => backend.call('/v1/bj/$table/sit', {
    'seat': ?seat,
    'name': party.account.name == 'You' ? 'Player' : party.account.name,
    'avatar': party.account.avatar.toJson(),
  });

  /// Your bet for the coming round (0 = sit this one out).
  Future<Doc> bet(String table, int amount) => backend.call('/v1/bj/$table/bet', {'amount': amount});

  Future<Doc> insure(String table, bool yes) => backend.call('/v1/bj/$table/insure', {'yes': yes});

  Future<Doc> move(String table, int version, String move) =>
      backend.call('/v1/bj/$table/move', {'version': version, 'move': move});

  Future<Doc> tick(String table) => backend.call('/v1/bj/$table/tick');

  Future<Doc> leave(String table) => backend.call('/v1/bj/$table/leave');

  Stream<Doc?> watch(String table) => backend.watch('bj/$table');
}
