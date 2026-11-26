import 'dart:math';

/// A player (or team) on a scoreboard.
class ScorePlayer {
  ScorePlayer({required this.id, required this.name, required this.color, this.uid});

  final String id;
  String name;

  /// An index into the app's palette.
  int color;

  /// Who added themselves (a party member), or null (added by the host or
  /// on this phone).
  final String? uid;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'color': color, 'uid': ?uid};
  static ScorePlayer fromJson(Map<Object?, Object?> j) => ScorePlayer(
    id: j['id']! as String,
    name: j['name'] as String? ?? 'Player',
    color: j['color'] as int? ?? 0,
    uid: j['uid'] as String?,
  );
}

/// One change to someone's score.
class ScoreEntry {
  const ScoreEntry({
    required this.player,
    required this.delta,
    required this.round,
    required this.at,
    this.note,
    this.by,
  });

  final String player;
  final int delta;
  final int round;

  /// When (ms since epoch).
  final int at;

  /// What it was for ("Shot the moon", "Bid 4, took 5").
  final String? note;

  /// Who entered it (a party member), or null.
  final String? by;

  Map<String, Object?> toJson() => {
    'player': player,
    'delta': delta,
    'round': round,
    'at': at,
    'note': ?note,
    'by': ?by,
  };
  static ScoreEntry fromJson(Map<Object?, Object?> j) => ScoreEntry(
    player: j['player']! as String,
    delta: j['delta']! as int,
    round: j['round'] as int? ?? 1,
    at: j['at'] as int? ?? 0,
    note: j['note'] as String?,
    by: j['by'] as String?,
  );
}

/// Counting up by taps, or entering a whole round at once.
enum ScoreMode { counter, rounds }

/// Refused: not allowed, or makes no sense.
class ScoreError implements Exception {
  const ScoreError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A scoreboard for any game played at a table: players (or teams), every
/// score change in order (so anything can be undone and the history shows
/// how it went), and the game's settings: the starting score, a target,
/// whether the lowest score wins, the quick steps, counter or rounds, and
/// (shared with a party) who may change whose score.
///
/// Shared, the referee applies every change through [apply], checking
/// rights: everyone may add themselves once and change their own score
/// (anyone's when the host turns on [anyoneScores]); the host may add any
/// number of players and change anything.
class ScoreBoard {
  ScoreBoard({
    this.name = 'Scoreboard',
    this.preset = 'free',
    this.start = 0,
    this.target,
    this.lowWins = false,
    List<int>? steps,
    this.mode = ScoreMode.counter,
    this.rounds,
    this.anyoneScores = false,
    List<ScorePlayer>? players,
    List<ScoreEntry>? log,
    this.round = 1,
    this.nextId = 1,
  }) : steps = steps ?? [1, 5, 10],
       players = players ?? [],
       log = log ?? [];

  String name;

  /// Which preset it was set up from (the app's tools for it).
  String preset;
  int start;

  /// The score that ends it (reached, or for low-wins games, passed by
  /// someone), or null for none.
  int? target;
  bool lowWins;
  List<int> steps;
  ScoreMode mode;

  /// How many rounds it lasts, or null.
  int? rounds;

  /// Shared: anyone may change anyone's score (else just their own).
  bool anyoneScores;

  final List<ScorePlayer> players;
  final List<ScoreEntry> log;

  /// The round being played.
  int round;
  int nextId;

  int score(String id) => start + log.where((e) => e.player == id).fold(0, (a, e) => a + e.delta);

  /// [id]'s total for round [r].
  int? roundScore(String id, int r) {
    final es = log.where((e) => e.player == id && e.round == r);
    return es.isEmpty ? null : es.fold<int>(0, (a, e) => a + e.delta);
  }

  /// The highest round with any score in it (or the current one).
  int get lastRound => log.fold(round, (a, e) => max(a, e.round));

  /// Players, best first.
  List<ScorePlayer> get ranked {
    final list = [...players];
    list.sort((a, b) => lowWins ? score(a.id).compareTo(score(b.id)) : score(b.id).compareTo(score(a.id)));
    return list;
  }

  /// Leaders (ties share), when there's anyone.
  List<ScorePlayer> get leaders {
    if (players.isEmpty) return const [];
    final best = score(ranked.first.id);
    return [
      for (final p in players)
        if (score(p.id) == best) p,
    ];
  }

  /// Over: someone reached the target (low wins: someone passed it, and the
  /// lowest wins), or the rounds are done.
  bool get isOver {
    if (players.isEmpty) return false;
    final t = target;
    if (t != null) {
      final hit = players.any((p) => lowWins ? score(p.id) >= t : score(p.id) >= t);
      if (hit) return true;
    }
    final r = rounds;
    return r != null && mode == ScoreMode.rounds && round > r;
  }

  ScorePlayer? player(String id) => players.where((p) => p.id == id).firstOrNull;

  // --- Changes ----------------------------------------------------------------

  /// Applies [op] for [by] (a uid; null = this phone, allowed everything).
  /// [host] says whether [by] is the party's host. [now] stamps entries.
  ///
  /// Ops: `{op: add, name, color, self}` · `{op: remove, id}` ·
  /// `{op: edit, id, name, color}` · `{op: score, id, delta, note}` ·
  /// `{op: round, scores: {id: delta}, note}` (a whole round, then on to the
  /// next) · `{op: undo}` · `{op: next}` (next round) ·
  /// `{op: settings, ...}` · `{op: reset}` (scores to the start) ·
  /// `{op: new, ...settings, players: [...]}` (a fresh board).
  void apply(Map<Object?, Object?> op, {String? by, bool host = true, required int now}) {
    final local = by == null;
    final boss = local || host;
    final kind = op['op'];
    bool mine(ScorePlayer p) => p.uid != null && p.uid == by;
    void need(bool ok, String why) {
      if (!ok) throw ScoreError(why);
    }

    switch (kind) {
      case 'add':
        final self = op['self'] == true && !local;
        need(boss || self, 'Only the host can add other players');
        if (self) need(!players.any(mine), 'You\'re already on the board');
        need(players.length < 16, 'That\'s the most players a board takes');
        final name = '${op['name'] ?? 'Player'}'.trim();
        players.add(
          ScorePlayer(
            id: 'p${nextId++}',
            name: name.isEmpty ? 'Player ${players.length + 1}' : name.substring(0, min(24, name.length)),
            color: op['color'] as int? ?? players.length,
            uid: self ? by : null,
          ),
        );
      case 'remove':
        final p = player('${op['id']}');
        need(p != null, 'No such player');
        need(boss || mine(p!), 'Only the host can remove other players');
        players.remove(p);
        log.removeWhere((e) => e.player == p!.id);
      case 'edit':
        final p = player('${op['id']}');
        need(p != null, 'No such player');
        need(boss || mine(p!), 'Only the host can change other players');
        final name = op['name'];
        if (name is String && name.trim().isNotEmpty) {
          p!.name = name.trim().substring(0, min(24, name.trim().length));
        }
        if (op['color'] is int) p!.color = op['color']! as int;
      case 'score':
        final p = player('${op['id']}');
        need(p != null, 'No such player');
        need(boss || anyoneScores || mine(p!), 'You can only change your own score');
        final delta = op['delta'];
        need(delta is int && delta.abs() <= 1000000, 'Not a number');
        log.add(
          ScoreEntry(player: p!.id, delta: delta! as int, round: round, at: now, note: _note(op), by: by),
        );
      case 'round':
        final scores = (op['scores'] as Map?) ?? const {};
        need(scores.isNotEmpty, 'No scores');
        for (final MapEntry(:key, :value) in scores.entries) {
          final p = player('$key');
          need(p != null, 'No such player');
          need(boss || anyoneScores || mine(p!), 'You can only enter your own score');
          need(value is int && value.abs() <= 1000000, 'Not a number');
        }
        for (final MapEntry(:key, :value) in scores.entries) {
          log.add(
            ScoreEntry(player: '$key', delta: value as int, round: round, at: now, note: _note(op), by: by),
          );
        }
        round++;
      case 'undo':
        // The host (or this phone) takes back the last change; a member,
        // their own last one.
        final i = log.lastIndexWhere((e) => boss || e.by == by);
        need(i >= 0, 'Nothing to undo');
        log.removeAt(i);
      case 'next':
        need(boss || anyoneScores, 'Only the host moves the round on');
        round++;
      case 'settings':
        need(boss, 'Only the host can change the settings');
        _settings(op);
      case 'reset':
        need(boss, 'Only the host can reset the scores');
        log.clear();
        round = 1;
      case 'new':
        need(boss, 'Only the host can start a new board');
        log.clear();
        round = 1;
        _settings(op);
        if (op['players'] is List) {
          players.clear();
          for (final p in op['players']! as List) {
            final m = p as Map;
            players.add(
              ScorePlayer(
                id: 'p${nextId++}',
                name: '${m['name'] ?? 'Player'}',
                color: m['color'] as int? ?? players.length,
                uid: m['uid'] as String?,
              ),
            );
          }
        }
      default:
        throw const ScoreError('Unknown change');
    }
  }

  static String? _note(Map<Object?, Object?> op) {
    final n = op['note'];
    return n is String && n.isNotEmpty ? n.substring(0, min(60, n.length)) : null;
  }

  void _settings(Map<Object?, Object?> op) {
    final n = op['name'];
    if (n is String && n.trim().isNotEmpty) name = n.trim();
    if (op['preset'] is String) preset = op['preset']! as String;
    if (op['start'] is int) start = op['start']! as int;
    if (op.containsKey('target')) target = op['target'] as int?;
    if (op['lowWins'] is bool) lowWins = op['lowWins']! as bool;
    if (op['steps'] is List) {
      final s = [
        for (final v in op['steps']! as List)
          if (v is int && v > 0) v,
      ];
      if (s.isNotEmpty) steps = s.take(6).toList();
    }
    if (op['mode'] is String) mode = ScoreMode.values.asNameMap()[op['mode']] ?? mode;
    if (op.containsKey('rounds')) rounds = op['rounds'] as int?;
    if (op['anyoneScores'] is bool) anyoneScores = op['anyoneScores']! as bool;
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'preset': preset,
    'start': start,
    'target': target,
    'lowWins': lowWins,
    'steps': steps,
    'mode': mode.name,
    'rounds': rounds,
    'anyoneScores': anyoneScores,
    'players': [for (final p in players) p.toJson()],
    'log': [for (final e in log) e.toJson()],
    'round': round,
    'nextId': nextId,
  };

  static ScoreBoard fromJson(Map<Object?, Object?> j) => ScoreBoard(
    name: j['name'] as String? ?? 'Scoreboard',
    preset: j['preset'] as String? ?? 'free',
    start: j['start'] as int? ?? 0,
    target: j['target'] as int?,
    lowWins: j['lowWins'] as bool? ?? false,
    steps: [
      for (final s in (j['steps'] as List?) ?? const [1, 5, 10]) s as int,
    ],
    mode: ScoreMode.values.asNameMap()[j['mode']] ?? ScoreMode.counter,
    rounds: j['rounds'] as int?,
    anyoneScores: j['anyoneScores'] as bool? ?? false,
    players: [for (final p in (j['players'] as List?) ?? const []) ScorePlayer.fromJson(p as Map)],
    log: [for (final e in (j['log'] as List?) ?? const []) ScoreEntry.fromJson(e as Map)],
    round: j['round'] as int? ?? 1,
    nextId: j['nextId'] as int? ?? 1,
  );

  ScoreBoard copy() => fromJson(toJson());
}
