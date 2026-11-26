import 'dart:async';
import 'dart:math';

import 'package:duel_engine/scoreboard/scoreboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/account/account.dart';
import '../../../core/session/play_setup.dart';
import '../../../core/sound/sound.dart';
import '../../../core/theme/toon.dart';
import 'presets.dart';
import 'scorer_controller.dart';
import 'scorer_tools.dart';

/// The Score counter's front page: the party's board (when you're in one),
/// a new board, and the boards kept on this phone.
class ScorerHome extends StatelessWidget {
  const ScorerHome({super.key});

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    final party = context.dependOnInheritedWidgetOfExactType<PlaySetupScope>()?.notifier?.party;
    final inParty = party != null && party.party != null;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const _Header(title: 'Score counter', subtitle: 'Keep score for any game at the table'),
            const SizedBox(height: 14),
            if (inParty)
              _BigCard(
                key: const Key('party board'),
                color: Toon.blue,
                icon: Icons.groups_rounded,
                title: 'Party scoreboard',
                body: party.isHost
                    ? 'One board for everyone in your party. You can add anyone and change anything.'
                    : 'One board for everyone in your party. Add yourself and keep your own score.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ScorerScreen(
                      controller: ScorerController.shared(account: account, party: party),
                    ),
                  ),
                ),
              ),
            _BigCard(
              key: const Key('new board'),
              color: Toon.yellow,
              icon: Icons.add_rounded,
              title: 'New scoreboard',
              body: 'Pick a game (or just a counter), add the players.',
              onTap: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ScorerSetup())),
            ),
            if (account.scoreBoards.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('On this phone', style: Toon.text(18, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              for (final saved in account.scoreBoards)
                Builder(
                  builder: (context) {
                    final b = ScoreBoard.fromJson(saved);
                    final id = saved['id']! as String;
                    final preset = ScorePreset.byId(b.preset);
                    final lead = b.leaders.map((p) => p.name).join(' & ');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Dismissible(
                        key: ValueKey(id),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => account.saveScoreBoard(id, null),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: Toon.box(Toon.red, radius: 16, shadow: 0),
                          child: const Icon(Icons.delete_rounded, color: Colors.white),
                        ),
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ScorerScreen(
                                controller: ScorerController.local(account: account, board: b, id: id),
                              ),
                            ),
                          ),
                          child: ToonBox(
                            color: Toon.card,
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(preset.icon, size: 26),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(b.name, style: Toon.text(16, weight: FontWeight.w700)),
                                      Text(
                                        '${b.players.length} players${lead.isEmpty || b.log.isEmpty ? '' : ' · $lead ahead'}',
                                        style: Toon.text(13, color: Toon.muted),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle, this.actions = const []});

  final String title, subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      ToonButton(
        color: Toon.card,
        padding: const EdgeInsets.all(8),
        tooltip: 'Back',
        onPressed: () => Navigator.of(context).pop(),
        child: const Icon(Icons.arrow_back_rounded),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Toon.text(22, weight: FontWeight.w700),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Toon.text(13, weight: FontWeight.w500, color: Toon.muted),
            ),
          ],
        ),
      ),
      ...actions,
    ],
  );
}

class _BigCard extends StatelessWidget {
  const _BigCard({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String title, body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: GestureDetector(
      onTap: onTap,
      child: ToonBox(
        color: color,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, size: 34, color: Toon.on(color)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Toon.text(18, weight: FontWeight.w700, color: Toon.on(color)),
                  ),
                  Text(body, style: Toon.text(14, color: Toon.on(color))),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// --- Setting up -------------------------------------------------------------------

/// A new board: the game (a preset), the players, the rules for winning.
/// With [controller], it sets up the party's board instead (the host).
class ScorerSetup extends StatefulWidget {
  const ScorerSetup({super.key, this.controller});

  final ScorerController? controller;

  @override
  State<ScorerSetup> createState() => _ScorerSetupState();
}

class _ScorerSetupState extends State<ScorerSetup> {
  var _preset = scorePresets.first;
  final List<(String, int)> _players = [];
  late int? _target = _preset.target;
  late bool _lowWins = _preset.lowWins;
  late int _start = _preset.start;
  late ScoreMode _mode = _preset.mode;

  @override
  void initState() {
    super.initState();
    _pick(scorePresets.first);
  }

  void _pick(ScorePreset p) {
    setState(() {
      final names = _players.map((x) => x.$1).toList();
      _preset = p;
      _target = p.target;
      _lowWins = p.lowWins;
      _start = p.start;
      _mode = p.mode;
      final teams = p.teams;
      if (teams != null) {
        _players
          ..clear()
          ..addAll([for (final (i, t) in teams.indexed) (t, i)]);
      } else if (_players.isEmpty || names.every((n) => n == 'Us' || n == 'Them')) {
        final me = AccountScope.maybeRead(context)?.name;
        _players
          ..clear()
          ..addAll([(me == null || me == 'You' ? 'Player 1' : me, 0), ('Player 2', 1)]);
      }
    });
  }

  Future<void> _addPlayer() async {
    final name = await _askName(context, 'Player ${_players.length + 1}');
    if (name != null) setState(() => _players.add((name, _players.length)));
  }

  void _go() {
    final settings = {
      ..._preset.settings(),
      'target': _target,
      'lowWins': _lowWins,
      'start': _start,
      'mode': _mode.name,
    };
    final players = [
      for (final (n, c) in _players) {'name': n, 'color': c},
    ];
    final shared = widget.controller;
    if (shared != null) {
      shared.apply({'op': 'new', ...settings, 'players': players});
      Navigator.of(context).pop();
      return;
    }
    final account = AccountScope.read(context);
    final board = ScoreBoard()..apply({'op': 'new', ...settings, 'players': players}, now: 0);
    final id = 'b${DateTime.now().millisecondsSinceEpoch}';
    account.saveScoreBoard(id, board.toJson());
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ScorerScreen(
          controller: ScorerController.local(account: account, board: board, id: id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _Header(
              title: widget.controller != null ? 'Party scoreboard' : 'New scoreboard',
              subtitle: 'Pick the game, then the players',
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Text('Game', style: Toon.text(17, weight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in scorePresets)
                      GestureDetector(
                        key: Key('preset ${p.id}'),
                        onTap: () => _pick(p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 104,
                          padding: const EdgeInsets.all(8),
                          decoration: Toon.box(
                            p == _preset ? Toon.yellow : Toon.card,
                            radius: 14,
                            shadow: p == _preset ? 3 : 1,
                          ),
                          child: Column(
                            children: [
                              Icon(p.icon, size: 26, color: p == _preset ? Toon.inkLight : null),
                              const SizedBox(height: 2),
                              Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Toon.text(
                                  13,
                                  weight: FontWeight.w700,
                                  color: p == _preset ? Toon.inkLight : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(_preset.tip ?? _preset.blurb, style: Toon.text(13, color: Toon.muted)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      _preset.teams != null ? 'Teams' : 'Players',
                      style: Toon.text(17, weight: FontWeight.w700),
                    ),
                    const Spacer(),
                    ToonButton(
                      key: const Key('add player'),
                      color: Toon.green,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      onPressed: _players.length < 16 ? _addPlayer : null,
                      child: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (final (i, (name, color)) in _players.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _players[i] = (name, (color + 1) % scoreColors.length)),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: Toon.box(scoreColor(color), radius: 15, shadow: 0),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final n = await _askName(context, name);
                              if (n != null) setState(() => _players[i] = (n, color));
                            },
                            child: Text(name, style: Toon.text(16, weight: FontWeight.w600)),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _players.removeAt(i)),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                if (widget.controller != null)
                  Text(
                    'Everyone in the party can add themselves too.',
                    style: Toon.text(13, color: Toon.muted),
                  ),
                const SizedBox(height: 10),
                Text('Rules', style: Toon.text(17, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                _Setting(
                  label: 'Ends at',
                  value: _target == null ? 'No limit' : '$_target',
                  onTap: () async {
                    final v = await showKeypad(context, title: 'Ends at (0 = no limit)', signed: false);
                    if (v != null) setState(() => _target = v == 0 ? null : v);
                  },
                ),
                _Setting(
                  label: 'Starting score',
                  value: '$_start',
                  onTap: () async {
                    final v = await showKeypad(context, title: 'Starting score', signed: false);
                    if (v != null) setState(() => _start = v);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Lowest score wins', style: Toon.text(15, weight: FontWeight.w600)),
                  value: _lowWins,
                  onChanged: (v) => setState(() => _lowWins = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Score round by round', style: Toon.text(15, weight: FontWeight.w600)),
                  subtitle: Text(
                    'A table of rounds instead of counters',
                    style: Toon.text(12, color: Toon.muted),
                  ),
                  value: _mode == ScoreMode.rounds,
                  onChanged: (v) => setState(() => _mode = v ? ScoreMode.rounds : ScoreMode.counter),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: ToonButton(
                key: const Key('start board'),
                color: Toon.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
                onPressed: _players.isEmpty && widget.controller == null ? null : _go,
                child: const Text('Start'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Setting extends StatelessWidget {
  const _Setting({required this.label, required this.value, required this.onTap});

  final String label, value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Toon.text(15, weight: FontWeight.w600)),
          ),
          Text(value, style: Toon.text(15, weight: FontWeight.w700)),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    ),
  );
}

Future<String?> _askName(BuildContext context, String initial) async {
  final text = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Toon.paper,
      title: Text('Name', style: Toon.text(20, weight: FontWeight.w700)),
      content: TextField(
        key: const Key('name field'),
        controller: text..selection = TextSelection(baseOffset: 0, extentOffset: initial.length),
        autofocus: true,
        maxLength: 24,
        textCapitalization: TextCapitalization.words,
        onSubmitted: (v) => Navigator.of(context).pop(v.trim().isEmpty ? null : v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          key: const Key('name ok'),
          onPressed: () => Navigator.of(context).pop(text.text.trim().isEmpty ? null : text.text.trim()),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

// --- The board ----------------------------------------------------------------------

/// A scoreboard in play: a tile per player (tap the top half to add, the
/// bottom half to take away, hold for any amount) or, round by round, a
/// table; the step, the game's special scores, undo, history, dice, a
/// timer and the settings.
class ScorerScreen extends StatefulWidget {
  const ScorerScreen({super.key, required this.controller});

  final ScorerController controller;

  @override
  State<ScorerScreen> createState() => _ScorerScreenState();
}

class _ScorerScreenState extends State<ScorerScreen> {
  ScorerController get c => widget.controller;
  var _step = 0;
  var _sorted = false;

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  int get step => c.board.steps[_step.clamp(0, c.board.steps.length - 1)];

  void _changed() {
    final e = c.error;
    if (e != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e), duration: const Duration(seconds: 2)));
      c.error = null;
    }
  }

  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
  }

  Future<void> _tap(ScorePlayer p, int sign) async {
    if (!c.canScore(p)) {
      c.error = 'You can only change your own score';
      _changed();
      return;
    }
    unawaited(HapticFeedback.selectionClick());
    Sound.play(Sfx.tap, gain: 0.4);
    await c.score(p, sign * step);
  }

  Future<void> _hold(ScorePlayer p) async {
    if (!c.canScore(p)) return;
    final v = await showKeypad(context, title: p.name, color: scoreColor(p.color));
    if (v != null) await c.score(p, v);
  }

  Future<void> _round() async {
    final r = await showRoundEntry(context, c);
    if (r == null) return;
    await c.apply({'op': 'round', 'scores': r.$1, 'note': ?r.$2});
  }

  Future<void> _playerMenu(ScorePlayer p) async {
    if (!c.canEdit(p)) return;
    final preset = ScorePreset.byId(c.board.preset);
    await showToonSheet<void>(
      context,
      title: p.name,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (c.canScore(p))
            for (final q in preset.quick)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ToonButton(
                  color: Toon.yellow,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  onPressed: () {
                    Navigator.of(context).pop();
                    c.quick(p, q.self, q.others, q.label);
                  },
                  child: Text(
                    '${q.label}: ${q.self != 0 ? '${q.self > 0 ? '+' : ''}${q.self}' : ''}${q.others != 0 ? '${q.others > 0 ? '+' : ''}${q.others} to everyone else' : ''}',
                  ),
                ),
              ),
          ToonButton(
            color: Toon.card,
            padding: const EdgeInsets.symmetric(vertical: 12),
            onPressed: () async {
              Navigator.of(context).pop();
              final n = await _askName(context, p.name);
              if (n != null) await c.apply({'op': 'edit', 'id': p.id, 'name': n});
            },
            child: const Text('Rename'),
          ),
          const SizedBox(height: 6),
          ToonButton(
            color: Toon.card,
            padding: const EdgeInsets.symmetric(vertical: 12),
            onPressed: () {
              Navigator.of(context).pop();
              c.apply({'op': 'edit', 'id': p.id, 'color': (p.color + 1) % scoreColors.length});
            },
            child: const Text('Next colour'),
          ),
          const SizedBox(height: 6),
          ToonButton(
            color: Toon.red,
            padding: const EdgeInsets.symmetric(vertical: 12),
            onPressed: () {
              Navigator.of(context).pop();
              c.apply({'op': 'remove', 'id': p.id});
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _settings() async {
    await showToonSheet<void>(
      context,
      title: 'Settings',
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final b = c.board;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Setting(
                label: 'Ends at',
                value: b.target == null ? 'No limit' : '${b.target}',
                onTap: () async {
                  final v = await showKeypad(context, title: 'Ends at (0 = no limit)', signed: false);
                  if (v != null) await c.apply({'op': 'settings', 'target': v == 0 ? null : v});
                },
              ),
              _Setting(
                label: 'Starting score',
                value: '${b.start}',
                onTap: () async {
                  final v = await showKeypad(context, title: 'Starting score', signed: false);
                  if (v != null) await c.apply({'op': 'settings', 'start': v});
                },
              ),
              _Setting(
                label: 'Steps',
                value: b.steps.join(' · '),
                onTap: () async {
                  final v = await showKeypad(context, title: 'Add a step', signed: false);
                  if (v != null && v > 0) {
                    final steps = {...b.steps, v}.toList()..sort();
                    await c.apply({
                      'op': 'settings',
                      'steps': steps.length > 6 ? steps.sublist(steps.length - 6) : steps,
                    });
                  }
                },
              ),
              if (b.steps.length > 1)
                Wrap(
                  spacing: 6,
                  children: [
                    for (final s in b.steps)
                      InputChip(
                        label: Text('$s'),
                        onDeleted: () => c.apply({
                          'op': 'settings',
                          'steps': [...b.steps]..remove(s),
                        }),
                      ),
                  ],
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Lowest score wins', style: Toon.text(15, weight: FontWeight.w600)),
                value: b.lowWins,
                onChanged: (v) => c.apply({'op': 'settings', 'lowWins': v}),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Score round by round', style: Toon.text(15, weight: FontWeight.w600)),
                value: b.mode == ScoreMode.rounds,
                onChanged: (v) => c.apply({'op': 'settings', 'mode': v ? 'rounds' : 'counter'}),
              ),
              if (c.shared)
                SwitchListTile(
                  key: const Key('anyone scores'),
                  contentPadding: EdgeInsets.zero,
                  title: Text('Anyone can change any score', style: Toon.text(15, weight: FontWeight.w600)),
                  subtitle: Text(
                    b.anyoneScores
                        ? 'Everyone in the party can score for anyone.'
                        : 'Each person changes only their own; you change anyone.',
                    style: Toon.text(12, color: Toon.muted),
                  ),
                  value: b.anyoneScores,
                  onChanged: (v) => c.apply({'op': 'settings', 'anyoneScores': v}),
                ),
              const SizedBox(height: 8),
              ToonButton(
                key: const Key('reset scores'),
                color: Toon.red,
                padding: const EdgeInsets.symmetric(vertical: 12),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Toon.paper,
                      title: const Text('Reset every score?'),
                      content: const Text('The players stay; the scores and history start again.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) await c.apply({'op': 'reset'});
                },
                child: const Text('Reset scores'),
              ),
              if (c.shared) ...[
                const SizedBox(height: 6),
                ToonButton(
                  color: Toon.card,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(
                      this.context,
                    ).push(MaterialPageRoute<void>(builder: (_) => ScorerSetup(controller: c)));
                  },
                  child: const Text('New game for the party'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _addPlayer({bool self = false}) async {
    final account = AccountScope.read(context);
    final name = self
        ? (account.name == 'You' ? 'Me' : account.name)
        : await _askName(context, 'Player ${c.board.players.length + 1}');
    if (name == null) return;
    final used = {for (final p in c.board.players) p.color};
    final color = List.generate(
      scoreColors.length,
      (i) => i,
    ).firstWhere((i) => !used.contains(i), orElse: () => 0);
    await c.addPlayer(name, color, self: self);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final b = c.board;
          final preset = ScorePreset.byId(b.preset);
          final wide = MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
          final players = _sorted ? b.ranked : b.players;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: _Header(
                  title: b.name,
                  subtitle: [
                    if (c.shared) 'Party board',
                    if (b.mode == ScoreMode.rounds)
                      'Round ${b.round}${b.rounds == null ? '' : ' of ${b.rounds}'}',
                    if (b.target != null) '${b.lowWins ? 'Out at' : 'To'} ${b.target}',
                    if (b.lowWins) 'lowest wins',
                  ].join(' · '),
                  actions: [
                    IconButton(
                      key: const Key('undo'),
                      tooltip: 'Undo',
                      onPressed: b.log.isEmpty ? null : c.undo,
                      icon: const Icon(Icons.undo_rounded),
                    ),
                    PopupMenuButton<String>(
                      key: const Key('board menu'),
                      icon: const Icon(Icons.more_vert_rounded),
                      color: Toon.paper,
                      onSelected: (v) => switch (v) {
                        'dice' => showDiceRoller(context),
                        'timer' => showTurnTimer(context),
                        'history' => showHistory(context, c),
                        'sort' => setState(() => _sorted = !_sorted),
                        'settings' => _settings(),
                        'add' => _addPlayer(),
                        _ => null,
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'dice', child: Text('Dice')),
                        const PopupMenuItem(value: 'timer', child: Text('Timer')),
                        const PopupMenuItem(value: 'history', child: Text('History')),
                        PopupMenuItem(
                          value: 'sort',
                          child: Text(_sorted ? 'Seating order' : 'Sort by score'),
                        ),
                        if (c.canAddAny) const PopupMenuItem(value: 'add', child: Text('Add a player')),
                        if (c.canSettings) const PopupMenuItem(value: 'settings', child: Text('Settings')),
                      ],
                    ),
                  ],
                ),
              ),
              if (b.isOver) _Winner(board: b),
              Expanded(
                child: !c.loaded
                    ? const Center(child: CircularProgressIndicator())
                    : b.players.isEmpty
                    ? _Empty(
                        c: c,
                        onAdd: () => _addPlayer(self: c.canAddSelf),
                        onSetup: c.shared && c.host
                            ? () => Navigator.of(
                                context,
                              ).push(MaterialPageRoute<void>(builder: (_) => ScorerSetup(controller: c)))
                            : null,
                      )
                    : b.mode == ScoreMode.rounds
                    ? _RoundsTable(c: c, players: players, onTapPlayer: _playerMenu)
                    : _Tiles(
                        c: c,
                        players: players,
                        wide: wide,
                        step: step,
                        onTap: _tap,
                        onHold: _hold,
                        onMenu: _playerMenu,
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: Row(
                  children: [
                    if (c.canAddSelf)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ToonButton(
                          key: const Key('add me'),
                          color: Toon.green,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          onPressed: () => _addPlayer(self: true),
                          child: const Text('Add me'),
                        ),
                      ),
                    if (b.mode == ScoreMode.counter) ...[
                      Text(
                        'Step',
                        style: Toon.text(14, weight: FontWeight.w600, color: Toon.muted),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final (i, s) in b.steps.indexed)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: GestureDetector(
                                    key: Key('step $s'),
                                    onTap: () => setState(() => _step = i),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                      decoration: Toon.box(
                                        i == _step ? Toon.yellow : Toon.card,
                                        radius: 12,
                                        shadow: i == _step ? 2 : 0,
                                      ),
                                      child: Text(
                                        '$s',
                                        style: Toon.text(
                                          16,
                                          weight: FontWeight.w700,
                                          color: i == _step ? Toon.inkLight : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: ToonButton(
                          key: const Key('add round'),
                          color: Toon.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          onPressed: b.players.isEmpty ? null : _round,
                          child: Text(
                            preset.calculator == 'spades' ? 'Score the hand' : 'Add round ${b.round}',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _Winner extends StatelessWidget {
  const _Winner({required this.board});
  final ScoreBoard board;

  @override
  Widget build(BuildContext context) {
    final w = board.leaders;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: Toon.box(Toon.yellow, radius: 14, shadow: 2),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: Toon.inkLight),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              w.length > 1 ? 'A tie: ${w.map((p) => p.name).join(' & ')}' : '${w.first.name} wins!',
              style: Toon.text(17, weight: FontWeight.w700, color: Toon.inkLight),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.c, required this.onAdd, this.onSetup});

  final ScorerController c;
  final VoidCallback onAdd;
  final VoidCallback? onSetup;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.scoreboard_rounded, size: 56),
          const SizedBox(height: 8),
          Text(
            c.shared ? 'Nobody on the board yet' : 'No players yet',
            style: Toon.text(20, weight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            c.shared
                ? (c.host
                      ? 'Set up the game, or let everyone add themselves.'
                      : 'Add yourself to keep score.')
                : 'Add the players from the menu.',
            textAlign: TextAlign.center,
            style: Toon.text(14, color: Toon.muted),
          ),
          if (onSetup != null) ...[
            const SizedBox(height: 12),
            ToonButton(
              key: const Key('set up party board'),
              color: Toon.yellow,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              onPressed: onSetup,
              child: const Text('Pick the game'),
            ),
          ],
        ],
      ),
    ),
  );
}

/// A coloured tile per player: tap the top half to add the step, the
/// bottom half to take it away; hold for any amount; the dots for more.
class _Tiles extends StatelessWidget {
  const _Tiles({
    required this.c,
    required this.players,
    required this.wide,
    required this.step,
    required this.onTap,
    required this.onHold,
    required this.onMenu,
  });

  final ScorerController c;
  final List<ScorePlayer> players;
  final bool wide;
  final int step;
  final void Function(ScorePlayer, int) onTap;
  final void Function(ScorePlayer) onHold;
  final void Function(ScorePlayer) onMenu;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final n = players.length;
      final cols = wide ? min(n, n <= 4 ? n : (n / 2).ceil()) : (n <= 3 ? 1 : (n <= 8 ? 2 : 3));
      final rows = (n / cols).ceil();
      final gap = 8.0;
      final w = (box.maxWidth - 24 - gap * (cols - 1)) / cols;
      final h = max(84.0, (box.maxHeight - gap * (rows - 1) - 4) / rows);
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final p in players)
              SizedBox(
                width: w,
                height: h,
                child: _Tile(c: c, p: p, step: step, onTap: onTap, onHold: onHold, onMenu: onMenu),
              ),
          ],
        ),
      );
    },
  );
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.c,
    required this.p,
    required this.step,
    required this.onTap,
    required this.onHold,
    required this.onMenu,
  });

  final ScorerController c;
  final ScorePlayer p;
  final int step;
  final void Function(ScorePlayer, int) onTap;
  final void Function(ScorePlayer) onHold;
  final void Function(ScorePlayer) onMenu;

  @override
  Widget build(BuildContext context) {
    final b = c.board;
    final color = scoreColor(p.color);
    final ink = Toon.on(color);
    final score = b.score(p.id);
    final leading = b.log.isNotEmpty && b.leaders.contains(p);
    final recent = c.recent[p.id];
    final fresh = recent != null && DateTime.now().difference(recent.$2).inMilliseconds < 1600;
    final mine = c.shared && p.uid == c.uid;
    final allowed = c.canScore(p);
    final t = b.target;
    return Container(
      key: Key('tile ${p.name}'),
      decoration: Toon.box(color, radius: 20, shadow: 3),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // The two halves.
            Column(
              children: [
                Expanded(
                  child: InkWell(
                    key: Key('plus ${p.name}'),
                    onTap: () => onTap(p, 1),
                    onLongPress: () => onHold(p),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          '+$step',
                          style: Toon.text(
                            15,
                            weight: FontWeight.w700,
                            color: ink.withValues(alpha: allowed ? 0.7 : 0.25),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    key: Key('minus ${p.name}'),
                    onTap: () => onTap(p, -1),
                    onLongPress: () => onHold(p),
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          '−$step',
                          style: Toon.text(
                            15,
                            weight: FontWeight.w700,
                            color: ink.withValues(alpha: allowed ? 0.7 : 0.25),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Name, score, progress.
            IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 44, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        if (leading) Icon(Icons.emoji_events_rounded, size: 18, color: ink),
                        if (leading) const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${p.name}${mine ? ' (you)' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Toon.text(17, weight: FontWeight.w700, color: ink),
                          ),
                        ),
                      ],
                    ),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '$score',
                          style: Toon.text(54, weight: FontWeight.w700, color: ink),
                        ),
                      ),
                    ),
                    if (t != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: (score / t).clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: ink.withValues(alpha: 0.18),
                          valueColor: AlwaysStoppedAnimation(ink.withValues(alpha: 0.7)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (fresh)
              Positioned(
                right: 44,
                top: 8,
                child: IgnorePointer(
                  child: Container(
                    key: ValueKey('recent ${p.id} ${recent.$1}'),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${recent.$1 >= 0 ? '+' : ''}${recent.$1}',
                      style: Toon.text(16, weight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
              ),
            if (c.canEdit(p))
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    key: Key('menu ${p.name}'),
                    onPressed: () => onMenu(p),
                    icon: Icon(Icons.more_vert_rounded, color: ink),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Round by round: a column per player, a row per round, totals on top.
class _RoundsTable extends StatelessWidget {
  const _RoundsTable({required this.c, required this.players, required this.onTapPlayer});

  final ScorerController c;
  final List<ScorePlayer> players;
  final void Function(ScorePlayer) onTapPlayer;

  @override
  Widget build(BuildContext context) {
    final b = c.board;
    final rounds = [
      for (var r = b.lastRound; r >= 1; r--)
        if (players.any((p) => b.roundScore(p.id, r) != null)) r,
    ];
    final leaders = b.log.isEmpty ? const <ScorePlayer>[] : b.leaders;
    return LayoutBuilder(
      builder: (context, box) {
        final colW = max(84.0, (box.maxWidth - 24 - 40) / max(1, players.length));
        Widget cell(Widget child, {double? width, Color? color}) => Container(
          width: width ?? colW,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 6),
          color: color,
          child: child,
        );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            width: max(box.maxWidth - 24, 40 + colW * players.length),
            child: Column(
              children: [
                Row(
                  children: [
                    cell(const SizedBox(), width: 40),
                    for (final p in players)
                      GestureDetector(
                        onTap: () => onTapPlayer(p),
                        child: Container(
                          width: colW - 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          decoration: Toon.box(scoreColor(p.color), radius: 14, shadow: 2),
                          child: Column(
                            children: [
                              Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Toon.text(
                                  14,
                                  weight: FontWeight.w700,
                                  color: Toon.on(scoreColor(p.color)),
                                ),
                              ),
                              FittedBox(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (leaders.contains(p))
                                      Icon(
                                        Icons.emoji_events_rounded,
                                        size: 18,
                                        color: Toon.on(scoreColor(p.color)),
                                      ),
                                    Text(
                                      '${b.score(p.id)}',
                                      style: Toon.text(
                                        28,
                                        weight: FontWeight.w700,
                                        color: Toon.on(scoreColor(p.color)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: rounds.isEmpty
                      ? Center(
                          child: Text('No rounds yet', style: Toon.text(15, color: Toon.muted)),
                        )
                      : ListView(
                          children: [
                            for (final r in rounds)
                              Row(
                                children: [
                                  cell(
                                    Text(
                                      'R$r',
                                      style: Toon.text(13, weight: FontWeight.w700, color: Toon.muted),
                                    ),
                                    width: 40,
                                  ),
                                  for (final p in players)
                                    cell(
                                      Text(
                                        b.roundScore(p.id, r) == null ? '–' : '${b.roundScore(p.id, r)}',
                                        style: Toon.text(17, weight: FontWeight.w600),
                                      ),
                                      color: r.isEven ? Toon.card.withValues(alpha: 0.5) : null,
                                    ),
                                ],
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
