import 'dart:async';

import 'package:duel_engine/scoreboard/scoreboard.dart';
import 'package:flutter/foundation.dart';

import '../../../core/account/account.dart';
import '../../../core/online/party.dart';

/// A scoreboard in use: on this phone (saved in the account), or the
/// party's (on the referee, the same for everyone; changes go there and
/// come back live). Rights follow [ScoreBoard.apply]: here you can do
/// anything; shared, you add yourself once and change your own score
/// (anyone's when the host allows it), and the host can do anything.
class ScorerController extends ChangeNotifier {
  /// A board on this phone ([id] in the account's saved boards).
  ScorerController.local({required this.account, required ScoreBoard board, required this.id})
    : party = null,
      _board = board; // ignore: prefer_initializing_formals

  /// The party's board.
  ScorerController.shared({required this.account, required PartyService this.party})
    : id = 'party',
      _board = ScoreBoard() {
    final pid = party!.party?['id'] as String?;
    if (pid != null) {
      _sub = party!.backend.watch('boards/$pid').listen(_heard);
      // Make sure it exists (and pick up the members).
      unawaited(_send(const {}));
    }
    party!.addListener(_notify);
  }

  final Account account;
  final PartyService? party;
  final String id;

  ScoreBoard _board;
  ScoreBoard get board => _board;

  StreamSubscription<Doc?>? _sub;
  var _disposed = false;

  /// The last refusal or connection problem, shown for a moment.
  String? error;

  /// Last change per player (the "+3" bubble), with when.
  final Map<String, (int, DateTime)> recent = {};

  bool get shared => party != null;
  bool get loaded => !shared || _loaded;
  bool _loaded = false;

  String? get uid => party?.uid;
  bool get host => !shared || (party?.isHost ?? false);

  ScorePlayer? get me => shared ? _board.players.where((p) => p.uid == uid).firstOrNull : null;

  bool canScore(ScorePlayer p) => host || _board.anyoneScores || (p.uid != null && p.uid == uid);
  bool canEdit(ScorePlayer p) => host || (p.uid != null && p.uid == uid);
  bool get canAddSelf => shared && me == null;
  bool get canAddAny => host;
  bool get canSettings => host;
  bool get canNextRound => host || _board.anyoneScores;

  void _heard(Doc? d) {
    if (_disposed || d == null) return;
    final b = d['board'];
    if (b is Map) {
      _board = ScoreBoard.fromJson(b);
      _loaded = true;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Applies a change: at once here (and saved), or optimistically for a
  /// shared board while the referee checks it (put back if refused).
  Future<bool> apply(Map<String, Object?> op) async {
    error = null;
    final before = _board.copy();
    try {
      _board.apply(op, by: uid, host: host, now: DateTime.now().millisecondsSinceEpoch);
    } on ScoreError catch (e) {
      error = e.message;
      _notify();
      return false;
    }
    if (op['op'] == 'score') {
      final pid = op['id']! as String;
      final prev = recent[pid];
      final fresh = prev != null && DateTime.now().difference(prev.$2).inMilliseconds < 1600;
      recent[pid] = ((fresh ? prev.$1 : 0) + (op['delta']! as int), DateTime.now());
    }
    _notify();
    if (!shared) {
      account.saveScoreBoard(id, _board.toJson());
      return true;
    }
    final ok = await _send(op);
    if (!ok && !_disposed) {
      _board = before;
      _notify();
    }
    return ok;
  }

  Future<bool> _send(Map<String, Object?> op) async {
    final pid = party?.party?['id'] as String?;
    if (pid == null) return false;
    try {
      await party!.signedIn();
      final d = await party!.backend.call('/v1/boards/$pid', op);
      _heard(d);
      return true;
    } on OnlineError catch (e) {
      error = e.message;
      _notify();
      return false;
    } on Object {
      error = 'Lost the connection: try again';
      _notify();
      return false;
    }
  }

  // --- Shortcuts ---------------------------------------------------------------

  Future<bool> score(ScorePlayer p, int delta, {String? note}) =>
      apply({'op': 'score', 'id': p.id, 'delta': delta, 'note': ?note});

  /// A special score: [self] to [p], [others] to everyone else.
  Future<void> quick(ScorePlayer p, int self, int others, String note) async {
    if (self != 0) await score(p, self, note: note);
    if (others != 0) {
      for (final q in [..._board.players]) {
        if (q.id != p.id) await score(q, others, note: '$note (${p.name})');
      }
    }
  }

  Future<bool> addPlayer(String name, int color, {bool self = false}) =>
      apply({'op': 'add', 'name': name, 'color': color, 'self': self});

  Future<bool> undo() => apply({'op': 'undo'});

  /// Team / player bags so far in Spades: the last digit of the score.
  int bags(ScorePlayer p) => (_board.score(p.id) % 10 + 10) % 10;

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    party?.removeListener(_notify);
    super.dispose();
  }
}
