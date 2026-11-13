import 'dart:async';

import 'package:duel_engine/poker/cash.dart';

import 'party.dart';

/// The shared cash tables, through the referee: the lobby (every table,
/// caught up), sitting down, moves, top-ups and standing up. The table
/// you're at is followed live ([watch]); your own cards come privately.
class CashService {
  CashService(this.party);

  final PartyService party;

  OnlineBackend get backend => party.backend;
  String? get uid => party.uid;

  /// Every table and the one you're at; throws (offline, server down) or
  /// times out after [limit], and the lobby falls back to this phone's
  /// tables.
  Future<({List<Doc> tables, String? mine})> lobby({Duration limit = const Duration(seconds: 5)}) async {
    await party.signedIn().timeout(limit);
    final r = await backend.call('/v1/cash').timeout(limit);
    return (
      tables: [for (final t in (r['tables'] as List?) ?? const []) (t as Map).cast<String, Object?>()],
      mine: r['mine'] as String?,
    );
  }

  Future<Doc> sit(CashStake stake, int buyIn) => backend.call('/v1/cash/${stake.name}/sit', {
    'buyIn': buyIn,
    'name': party.account.name == 'You' ? 'Player' : party.account.name,
    'avatar': party.account.avatar.toJson(),
  });

  Future<Doc> move(CashStake stake, int version, Doc move) =>
      backend.call('/v1/cash/${stake.name}/move', {'version': version, 'move': move});

  Future<Doc> tick(CashStake stake) => backend.call('/v1/cash/${stake.name}/tick');

  Future<Doc> leave(CashStake stake) => backend.call('/v1/cash/${stake.name}/leave');

  Future<Doc> topUp(CashStake stake, int pips) =>
      backend.call('/v1/cash/${stake.name}/topup', {'pips': pips});

  Stream<Doc?> watch(CashStake stake) => backend.watch('cash/${stake.name}');

  Stream<Doc?> mine(CashStake stake) => backend.watch('cash/${stake.name}/hands/$uid');
}
