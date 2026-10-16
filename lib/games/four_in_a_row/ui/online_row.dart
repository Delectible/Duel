import 'dart:async';

import 'package:duel_engine/four_in_a_row/four_in_a_row.dart';
import 'package:flutter/foundation.dart';

import '../../../core/avatars/faces.dart';
import '../../../core/online/party.dart';
import 'row_controller.dart';

/// Four in a Row with a friend: the referee's game, seen from your seat.
/// Whoever you are on the server, here you're red (player 0). Your drop
/// shows at once and is confirmed (or undone) by the referee.
class OnlineRowController extends ChangeNotifier implements RowTable {
  OnlineRowController(this.party, {required this.you, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    party.addListener(_changed);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _second());
    _changed();
  }

  final PartyService party;
  final DateTime Function() _clock;

  @override
  final Persona you;

  @override
  FourInARow game = FourInARow();

  /// The match being shown, and your seat in it.
  Doc? _m;
  int _seat = 0;

  /// Your drop on its way to the referee.
  int? _pending;

  /// Last time-out claim (per version), so it's sent once.
  int? _claimed;

  /// When this phone heard of the current turn (its own clock).
  DateTime _heard = DateTime.now();

  /// Something the referee turned down, to show once.
  String? error;

  late final Timer _tick;
  var _disposed = false;

  String? get matchId => _m?['id'] as String?;
  int get stake => _m?['stake'] as int? ?? 0;
  bool get live => _m?['status'] == 'live';
  Doc get _result => (_m?['result'] as Map?)?.cast<String, Object?>() ?? const {};

  /// Why it ended: won, draw, timeout or forfeit.
  String? get reason => _result['reason'] as String?;

  String get _otherUid => ((_m?['seats'] as List?) ?? const ['', ''])[1 - _seat] as String;

  @override
  Persona get bot {
    final names = (_m?['names'] as List?) ?? const [];
    final member = party.members.where((m) => m.uid == _otherUid).firstOrNull;
    return Persona(
      name: names.length > 1 ? '${names[1 - _seat]}' : 'Friend',
      look: Look.headband,
      avatar: member?.persona.avatar ?? const Avatar(color: AvatarColor.lilac),
    );
  }

  /// Your friend is still in the party (else there's no rematch).
  bool get friendHere => party.members.any((m) => m.uid == _otherUid);

  bool get _myTurn => live && _m!['turn'] == _seat;

  @override
  bool get thinking => live && !_myTurn;
  @override
  bool get yourTurn => _myTurn && _pending == null;

  @override
  List<int> get yourWins => over || game.isOver ? const [] : game.winningMoves(0);
  @override
  List<int> get threats => over || game.isOver ? const [] : game.winningMoves(1);

  @override
  bool get over => _m != null && !live;
  @override
  bool get draw => _result['draw'] == true;
  @override
  bool get youWon => _result['winner'] == _seat;

  /// Milliseconds left on the turn (below 0: over time). Counted from when
  /// this phone heard of the turn, so a phone's clock being off doesn't
  /// matter.
  int get _msLeft {
    final d = _m?['deadline'] as int?;
    if (d == null || !live) return 0;
    final at = _m?['turnAt'] as int?;
    if (at == null) return d - _clock().millisecondsSinceEpoch;
    return (d - at) - _clock().difference(_heard).inMilliseconds;
  }

  /// Seconds left for the player to move (0 when it's up).
  int get secondsLeft => (_msLeft / 1000).ceil().clamp(0, 999);

  /// You asked for a rematch (waiting for your friend).
  bool get askedRematch => ((_m?['rematch'] as List?) ?? const []).contains(party.uid);

  void _changed() {
    final m = party.match;
    if (m == null || _disposed) return;
    final newer =
        _m == null || m['id'] != _m!['id'] || (m['version'] as int? ?? 0) != (_m!['version'] as int? ?? 0);
    if (!newer && _m != null) {
      _notify();
      return;
    }
    if (m['turnAt'] != _m?['turnAt'] || m['id'] != _m?['id']) _heard = _clock();
    _m = m;
    _seat = party.seat < 0 ? 0 : party.seat;
    _pending = null;
    _rebuild();
    _notify();
  }

  void _rebuild() {
    final state = (_m?['state'] as Map?) ?? const {};
    // Seat 0 on the server is player 0 there; here you are always 0.
    final first = (state['first'] as int? ?? 0) ^ _seat;
    final g = FourInARow(first: first);
    for (final col in ((state['moves'] as List?) ?? const []).cast<int>()) {
      g.drop(col);
    }
    final p = _pending;
    if (p != null && !g.isOver && g.canDrop(p)) g.drop(p);
    game = g;
  }

  @override
  void drop(int col) {
    if (!yourTurn || !game.canDrop(col)) return;
    _pending = col;
    _rebuild();
    _notify();
    unawaited(
      party.move({'column': col}).then((e) {
        if (e == null || _disposed) return;
        // Turned down (the game moved on, or a lost connection): undo.
        _pending = null;
        error = e;
        _rebuild();
        _notify();
      }),
    );
  }

  /// Everyone may claim a turn that ran out; the referee moves for them.
  void _second() {
    if (_disposed || !live) return;
    _notify();
    final v = _m!['version'] as int?;
    if (_m!['deadline'] != null && _msLeft < -1500 && _claimed != v) {
      _claimed = v;
      unawaited(party.claimTimeout());
    }
  }

  Future<String?> rematch() => party.rematch();

  /// Gives the game up (leaving early).
  Future<String?> forfeit() => party.forfeit();

  @override
  String commentary() {
    final name = bot.name;
    final g = game;
    if (_m == null) return 'Getting the board ready…';
    if (over) {
      return switch (reason) {
        'draw' => 'The board is full and nobody made four: a draw.',
        'timeout' =>
          youWon ? '$name ran out of time twice. You win.' : 'You ran out of time twice, so $name wins.',
        'forfeit' => youWon ? '$name gave up. You win.' : 'You gave up, so $name wins.',
        _ => youWon ? 'Four in a row! You win.' : '$name made four in a row.',
      };
    }
    if (thinking) {
      final last = g.moves.isEmpty ? null : 'You dropped in column ${g.moves.last + 1}';
      return last == null ? '$name goes first…' : '$last  ·  $name’s turn…';
    }
    if (_pending != null) return 'Sending your move…';
    final wins = yourWins, danger = threats;
    if (wins.isNotEmpty) return 'You can win right now: column ${wins.first + 1}!';
    if (danger.isNotEmpty) {
      return danger.length > 1
          ? 'Watch out: $name can win in two places (${danger.map((c) => c + 1).join(' and ')}). Block one!'
          : 'Watch out: $name can win in column ${danger.first + 1}. Block it!';
    }
    final theirs = g.moves.isEmpty ? null : g.moves.last;
    final start = theirs == null ? '' : '$name dropped in column ${theirs + 1}. ';
    return '${start}Your turn: tap a column to drop a red disc.';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _tick.cancel();
    party.removeListener(_changed);
    super.dispose();
  }
}
