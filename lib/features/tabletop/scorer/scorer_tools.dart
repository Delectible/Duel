import 'dart:async';
import 'dart:math';

import 'package:duel_engine/scoreboard/scoreboard.dart';
import 'package:flutter/material.dart';

import '../../../core/sound/sound.dart';
import '../../../core/theme/toon.dart';
import '../../../games/bank/dice.dart';
import 'presets.dart';
import 'scorer_controller.dart';

/// A sheet in the toon style: a title, then [child].
Future<T?> showToonSheet<T>(BuildContext context, {required String title, required Widget child}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Toon.paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Toon.muted, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(title, style: Toon.text(20, weight: FontWeight.w700)),
                const SizedBox(height: 6),
                child,
              ],
            ),
          ),
        ),
      ),
    );

// --- A number pad -------------------------------------------------------------

/// Type an amount; add it or take it away. Returns the signed amount.
Future<int?> showKeypad(BuildContext context, {required String title, Color? color, bool signed = true}) =>
    showToonSheet<int>(
      context,
      title: title,
      child: _Keypad(color: color ?? Toon.yellow, signed: signed),
    );

class _Keypad extends StatefulWidget {
  const _Keypad({required this.color, required this.signed});

  final Color color;
  final bool signed;

  @override
  State<_Keypad> createState() => _KeypadState();
}

class _KeypadState extends State<_Keypad> {
  var _text = '';

  int get _value => int.tryParse(_text) ?? 0;

  void _tap(String k) {
    setState(() {
      if (k == 'del') {
        if (_text.isNotEmpty) _text = _text.substring(0, _text.length - 1);
      } else if (_text.length < 7) {
        _text = _text == '0' ? k : _text + k;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // On its side the screen is short: smaller keys.
    final compact = MediaQuery.sizeOf(context).height < 560;
    Widget key(String k) => Expanded(
      child: Padding(
        padding: EdgeInsets.all(compact ? 2 : 4),
        child: ToonButton(
          key: Key('key $k'),
          color: Toon.card,
          padding: EdgeInsets.symmetric(vertical: compact ? 5 : 14),
          onPressed: () => _tap(k),
          child: k == 'del'
              ? const Icon(Icons.backspace_outlined)
              : Text(k, style: Toon.text(22, weight: FontWeight.w700)),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.symmetric(vertical: compact ? 2 : 10),
          decoration: Toon.box(widget.color, radius: 14, shadow: 2),
          child: Text(
            _text.isEmpty ? '0' : _text,
            textAlign: TextAlign.center,
            style: Toon.text(compact ? 24 : 36, weight: FontWeight.w700, color: Toon.on(widget.color)),
          ),
        ),
        SizedBox(height: compact ? 2 : 8),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['00', '0', 'del'],
        ])
          Row(children: [for (final k in row) key(k)]),
        const SizedBox(height: 6),
        Row(
          children: [
            if (widget.signed) ...[
              Expanded(
                child: ToonButton(
                  key: const Key('pad minus'),
                  color: Toon.red,
                  padding: EdgeInsets.symmetric(vertical: compact ? 8 : 14),
                  onPressed: _value == 0 ? null : () => Navigator.of(context).pop(-_value),
                  child: Text('− $_value'),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: ToonButton(
                key: const Key('pad plus'),
                color: Toon.green,
                padding: EdgeInsets.symmetric(vertical: compact ? 8 : 14),
                onPressed: _value == 0 && widget.signed ? null : () => Navigator.of(context).pop(_value),
                child: Text(widget.signed ? '+ $_value' : 'OK'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// --- Dice -----------------------------------------------------------------------

/// Roll any dice: how many and how many sides; the total and each die.
Future<void> showDiceRoller(BuildContext context) =>
    showToonSheet<void>(context, title: 'Dice', child: const _DiceRoller());

class _DiceRoller extends StatefulWidget {
  const _DiceRoller();

  @override
  State<_DiceRoller> createState() => _DiceRollerState();
}

class _DiceRollerState extends State<_DiceRoller> {
  final _rng = Random();
  var _count = 2, _sides = 6, _rolls = 0;
  List<int> _values = [];

  void _roll() {
    Sound.play(Sfx.shuffle);
    setState(() {
      _rolls++;
      _values = [for (var i = 0; i < _count; i++) 1 + _rng.nextInt(_sides)];
    });
    Sound.later(Sfx.drop, 500);
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Text('Dice', style: Toon.text(15, weight: FontWeight.w600)),
          const Spacer(),
          for (var n = 1; n <= 6; n++)
            _Pill(label: '$n', on: n == _count, onTap: () => setState(() => _count = n)),
        ],
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.end,
        children: [
          Text('Sides', style: Toon.text(15, weight: FontWeight.w600)),
          for (final s in const [2, 4, 6, 8, 10, 12, 20, 100])
            _Pill(label: s == 2 ? 'coin' : 'd$s', on: s == _sides, onTap: () => setState(() => _sides = s)),
        ],
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 120,
        child: Center(
          child: _values.isEmpty
              ? Text('Tap Roll', style: Toon.text(18, color: Toon.muted))
              : TweenAnimationBuilder<double>(
                  key: ValueKey(_rolls),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 600),
                  builder: (context, t, _) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final (i, v) in _values.indexed)
                        Transform.rotate(
                          angle: (1 - t) * (i.isEven ? 6 : -6),
                          child: Transform.scale(
                            scale: 0.4 + 0.6 * Curves.easeOutBack.transform(t),
                            child: _sides == 6
                                ? Die(t < 0.8 ? 1 + _rng.nextInt(6) : v, size: 48)
                                : _Token(
                                    text: _sides == 2
                                        ? (v == 1 ? 'Heads' : 'Tails')
                                        : '${t < 0.8 ? 1 + _rng.nextInt(_sides) : v}',
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
      if (_values.length > 1 && _sides != 2)
        Text(
          'Total ${_values.fold(0, (a, b) => a + b)}',
          textAlign: TextAlign.center,
          style: Toon.text(18, weight: FontWeight.w700),
        ),
      const SizedBox(height: 10),
      ToonButton(
        key: const Key('roll dice'),
        color: Toon.green,
        padding: const EdgeInsets.symmetric(vertical: 14),
        onPressed: _roll,
        child: Text(_sides == 2 ? 'Flip' : 'Roll'),
      ),
    ],
  );
}

class _Token extends StatelessWidget {
  const _Token({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 52),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: Toon.box(Toon.cardFace, radius: 14, shadow: 2),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: Toon.text(22, weight: FontWeight.w700, color: Toon.inkLight),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: Toon.box(on ? Toon.yellow : Toon.card, radius: 10, shadow: on ? 2 : 0),
        child: Text(
          label,
          style: Toon.text(14, weight: FontWeight.w700, color: on ? Toon.inkLight : null),
        ),
      ),
    ),
  );
}

// --- Timer ----------------------------------------------------------------------

/// A stopwatch, or a countdown for turns (it buzzes at zero).
Future<void> showTurnTimer(BuildContext context) =>
    showToonSheet<void>(context, title: 'Timer', child: const _Timer());

class _Timer extends StatefulWidget {
  const _Timer();

  @override
  State<_Timer> createState() => _TimerState();
}

class _TimerState extends State<_Timer> {
  Timer? _tick;
  final _watch = Stopwatch();

  /// Counting down from this many seconds, or null: a stopwatch.
  int? _from = 60;

  int get _elapsed => _watch.elapsed.inSeconds;
  int get _left => max(0, (_from ?? 0) - _elapsed);
  bool _buzzed = false;

  void _start() {
    _watch.start();
    _tick ??= Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      if (_from != null && _left == 0 && !_buzzed) {
        _buzzed = true;
        _watch.stop();
        Sound.play(Sfx.tension);
        Sound.later(Sfx.yourTurn, 400);
      }
      setState(() {});
    });
    setState(() {});
  }

  void _reset() {
    _watch
      ..stop()
      ..reset();
    _buzzed = false;
    setState(() {});
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final shown = _from == null ? _elapsed : _left;
    final done = _from != null && _left == 0 && _buzzed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (final s in const [30, 60, 120, 300, null])
              _Pill(
                label: s == null ? 'Stopwatch' : _fmt(s),
                on: s == _from,
                onTap: () {
                  _from = s;
                  _reset();
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: Toon.box(done ? Toon.red : Toon.card, radius: 18, shadow: 3),
          child: Text(
            _fmt(shown),
            textAlign: TextAlign.center,
            style: Toon.text(56, weight: FontWeight.w700, color: done ? Colors.white : null),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ToonButton(
                color: Toon.card,
                padding: const EdgeInsets.symmetric(vertical: 14),
                onPressed: _reset,
                child: const Text('Reset'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ToonButton(
                key: const Key('timer go'),
                color: _watch.isRunning ? Toon.yellow : Toon.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
                onPressed: () {
                  if (_watch.isRunning) {
                    _watch.stop();
                    setState(() {});
                  } else {
                    if (done) _reset();
                    _start();
                  }
                },
                child: Text(_watch.isRunning ? 'Pause' : (done ? 'Again' : 'Start')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// --- History --------------------------------------------------------------------

/// Every change, newest first: who, how much, what for, when.
Future<void> showHistory(BuildContext context, ScorerController c) => showToonSheet<void>(
  context,
  title: 'History',
  child: ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final b = c.board;
      if (b.log.isEmpty) return Text('Nothing scored yet.', style: Toon.text(15, color: Toon.muted));
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in b.log.reversed.take(120))
            Builder(
              builder: (context) {
                final p = b.player(e.player);
                final t = DateTime.fromMillisecondsSinceEpoch(e.at);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: scoreColor(p?.color ?? 0), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${p?.name ?? '?'}${e.note == null ? '' : ' · ${e.note}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Toon.text(14, weight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        '${e.delta >= 0 ? '+' : ''}${e.delta}',
                        style: Toon.text(
                          15,
                          weight: FontWeight.w700,
                          color: e.delta >= 0 ? Toon.green : Toon.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'R${e.round} · ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                        style: Toon.text(12, color: Toon.muted),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      );
    },
  ),
);

// --- A whole round ----------------------------------------------------------------

/// Enter everyone's score for a round (or, Spades, each team's bid and
/// tricks); returns {player id: points} and a note.
Future<(Map<String, int>, String?)?> showRoundEntry(BuildContext context, ScorerController c) =>
    showToonSheet<(Map<String, int>, String?)>(
      context,
      title: 'Round ${c.board.round}',
      child: ScorePreset.byId(c.board.preset).calculator == 'spades' ? _SpadesRound(c: c) : _RoundEntry(c: c),
    );

class _RoundEntry extends StatefulWidget {
  const _RoundEntry({required this.c});
  final ScorerController c;

  @override
  State<_RoundEntry> createState() => _RoundEntryState();
}

class _RoundEntryState extends State<_RoundEntry> {
  late final Map<String, int> _scores = {
    for (final p in widget.c.board.players)
      if (widget.c.canScore(p)) p.id: 0,
  };

  @override
  Widget build(BuildContext context) {
    final b = widget.c.board;
    final preset = ScorePreset.byId(b.preset);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (preset.tip != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(preset.tip!, style: Toon.text(13, color: Toon.muted)),
          ),
        for (final p in b.players.where((p) => _scores.containsKey(p.id)))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(color: scoreColor(p.color), shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(p.name, style: Toon.text(16, weight: FontWeight.w600)),
                ),
                ToonButton(
                  color: Toon.card,
                  padding: const EdgeInsets.all(8),
                  onPressed: () => setState(() => _scores[p.id] = _scores[p.id]! - (b.steps.first)),
                  child: const Icon(Icons.remove_rounded, size: 18),
                ),
                GestureDetector(
                  key: Key('round ${p.name}'),
                  onTap: () async {
                    final v = await showKeypad(context, title: p.name, color: scoreColor(p.color));
                    if (v != null) setState(() => _scores[p.id] = v);
                  },
                  child: Container(
                    width: 72,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: Toon.box(Toon.cardFace, radius: 10, shadow: 0),
                    child: Text(
                      '${_scores[p.id]}',
                      textAlign: TextAlign.center,
                      style: Toon.text(18, weight: FontWeight.w700, color: Toon.inkLight),
                    ),
                  ),
                ),
                ToonButton(
                  color: Toon.card,
                  padding: const EdgeInsets.all(8),
                  onPressed: () => setState(() => _scores[p.id] = _scores[p.id]! + (b.steps.first)),
                  child: const Icon(Icons.add_rounded, size: 18),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        ToonButton(
          key: const Key('save round'),
          color: Toon.green,
          padding: const EdgeInsets.symmetric(vertical: 14),
          onPressed: () => Navigator.of(context).pop((_scores, null)),
          child: const Text('Save round'),
        ),
      ],
    );
  }
}

/// Spades: each team's bid, tricks and nil; the points worked out.
class _SpadesRound extends StatefulWidget {
  const _SpadesRound({required this.c});
  final ScorerController c;

  @override
  State<_SpadesRound> createState() => _SpadesRoundState();
}

class _SpadesRoundState extends State<_SpadesRound> {
  late final List<ScorePlayer> _teams = [
    for (final p in widget.c.board.players)
      if (widget.c.canScore(p)) p,
  ];
  late final Map<String, int> _bid = {
    for (final (i, p) in _teams.indexed) p.id: _teams.length == 2 ? (i == 0 ? 6 : 5) : 3,
  };
  late final Map<String, int> _took = {
    for (final (i, p) in _teams.indexed) p.id: _teams.length == 2 ? (i == 0 ? 7 : 6) : 3,
  };
  final Map<String, bool> _nil = {};

  @override
  Widget build(BuildContext context) {
    final results = {
      for (final p in _teams)
        p.id: spadesRound(
          bid: _bid[p.id]!,
          tricks: _took[p.id]!,
          bagsBefore: widget.c.bags(p),
          nil: _nil[p.id] ?? false,
        ),
    };
    final tricks = _took.values.fold(0, (a, b) => a + b);
    Widget stepper(String label, int value, ValueChanged<int> set, {int maxV = 13}) => Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(label, style: Toon.text(14, weight: FontWeight.w600)),
        ),
        ToonButton(
          color: Toon.card,
          padding: const EdgeInsets.all(6),
          onPressed: value > 0 ? () => set(value - 1) : null,
          child: const Icon(Icons.remove_rounded, size: 18),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Toon.text(18, weight: FontWeight.w700),
          ),
        ),
        ToonButton(
          color: Toon.card,
          padding: const EdgeInsets.all(6),
          onPressed: value < maxV ? () => set(value + 1) : null,
          child: const Icon(Icons.add_rounded, size: 18),
        ),
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in _teams)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: Toon.box(Toon.card, radius: 14, shadow: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(color: scoreColor(p.color), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(p.name, style: Toon.text(16, weight: FontWeight.w700)),
                    ),
                    Text('bags ${widget.c.bags(p)}', style: Toon.text(12, color: Toon.muted)),
                  ],
                ),
                const SizedBox(height: 6),
                if (!(_nil[p.id] ?? false))
                  stepper('Bid', _bid[p.id]!, (v) => setState(() => _bid[p.id] = v)),
                const SizedBox(height: 4),
                stepper('Took', _took[p.id]!, (v) => setState(() => _took[p.id] = v)),
                Row(
                  children: [
                    Checkbox(
                      value: _nil[p.id] ?? false,
                      onChanged: (v) => setState(() => _nil[p.id] = v ?? false),
                    ),
                    Text('Nil', style: Toon.text(14)),
                    const Spacer(),
                    Text(
                      '${results[p.id]!.points >= 0 ? '+' : ''}${results[p.id]!.points}',
                      style: Toon.text(
                        20,
                        weight: FontWeight.w700,
                        color: results[p.id]!.points >= 0 ? Toon.green : Toon.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (_teams.length == 2 && tricks != 13)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Tricks add up to $tricks (a full hand is 13).',
              style: Toon.text(13, color: Toon.red),
            ),
          ),
        ToonButton(
          key: const Key('save round'),
          color: Toon.green,
          padding: const EdgeInsets.symmetric(vertical: 14),
          onPressed: () => Navigator.of(context).pop((
            {for (final p in _teams) p.id: results[p.id]!.points},
            [for (final p in _teams) '${p.name}: ${results[p.id]!.note}'].join('; '),
          )),
          child: const Text('Save round'),
        ),
      ],
    );
  }
}
