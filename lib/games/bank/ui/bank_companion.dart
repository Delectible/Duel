import 'dart:async';
import 'dart:math';

import 'package:duel_engine/bank/bank.dart';
import 'package:flutter/material.dart';

import '../../../core/account/account.dart';
import '../../../core/sound/sound.dart';
import '../../../core/table/table_bits.dart';
import '../../../core/theme/toon.dart';
import 'bank_bits.dart';

/// Playing Bank! in person: the phone in the middle of the table keeps the
/// bank and the scores. With [dice] it rolls them too (big, for everyone to
/// see); without, you roll real dice and tap in what came up.
class BankCompanionSetup extends StatefulWidget {
  const BankCompanionSetup({super.key});

  @override
  State<BankCompanionSetup> createState() => _BankCompanionSetupState();
}

class _BankCompanionSetupState extends State<BankCompanionSetup> {
  var _dice = true;
  var _rounds = 15;
  late final List<TextEditingController> _names = [
    TextEditingController(text: AccountScope.maybeRead(context)?.name ?? 'Player 1'),
    TextEditingController(text: 'Player 2'),
  ];

  @override
  void dispose() {
    for (final n in _names) {
      n.dispose();
    }
    super.dispose();
  }

  List<String> get _players => [
    for (final (i, n) in _names.indexed) n.text.trim().isEmpty ? 'Player ${i + 1}' : n.text.trim(),
  ];

  Widget _option(String label, bool on, VoidCallback tap, {Key? key}) => Expanded(
    child: ToonButton(
      key: key,
      color: on ? Toon.yellow : Toon.card,
      padding: const EdgeInsets.symmetric(vertical: 10),
      onPressed: tap,
      child: FittedBox(child: Text(label, maxLines: 1)),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
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
                child: Text('Bank! at the table', style: Toon.text(24, weight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Put the phone in the middle. It keeps the bank and everyone\'s score; anyone can tap a name to bank.',
            style: Toon.text(15, weight: FontWeight.w500, color: Toon.muted),
          ),
          const SizedBox(height: 16),
          Text('Dice', style: Toon.text(18, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(
            children: [
              _option(
                'Roll on the phone',
                _dice,
                () => setState(() => _dice = true),
                key: const Key('mode dice'),
              ),
              const SizedBox(width: 8),
              _option(
                'Our own dice',
                !_dice,
                () => setState(() => _dice = false),
                key: const Key('mode scores'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _dice
                ? 'Big dice on screen, rolled with a tap, with all the drama.'
                : 'Scoring only: roll your own dice and tap in the total (and whether it was doubles).',
            style: Toon.text(13, color: Toon.muted),
          ),
          const SizedBox(height: 16),
          Text('Rounds', style: Toon.text(18, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final (i, r) in [10, 15, 20].indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                _option('$r', _rounds == r, () => setState(() => _rounds = r), key: Key('rounds $r')),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text('Players', style: Toon.text(18, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final (i, n) in _names.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: Key('name $i'),
                      controller: n,
                      textCapitalization: TextCapitalization.words,
                      style: Toon.text(16),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: Toon.card,
                        hintText: 'Player ${i + 1}',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if (_names.length > 2)
                    IconButton(
                      tooltip: 'Remove',
                      onPressed: () => setState(() => _names.removeAt(i).dispose()),
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
            ),
          if (_names.length < 12)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('add player'),
                onPressed: () => setState(() => _names.add(TextEditingController())),
                icon: const Icon(Icons.person_add_rounded),
                label: Text('Add a player', style: Toon.text(15)),
              ),
            ),
          const SizedBox(height: 16),
          ToonButton(
            key: const Key('start companion'),
            color: Toon.green,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BankCompanion(names: _players, rounds: _rounds, dice: _dice),
              ),
            ),
            child: Text('Start', style: Toon.text(20, weight: FontWeight.w700)),
          ),
        ],
      ),
    ),
  );
}

/// One thing that happened, so it can be undone (the game is rebuilt from
/// the list).
sealed class _Step {}

class _Roll extends _Step {
  _Roll(this.a, this.b);
  final int a, b;
}

class _Banked extends _Step {
  _Banked(this.p);
  final int p;
}

class _NextRound extends _Step {}

class _Adjust extends _Step {
  _Adjust(this.p, this.score);
  final int p, score;
}

class BankCompanion extends StatefulWidget {
  const BankCompanion({super.key, required this.names, required this.rounds, required this.dice, this.seed});

  final List<String> names;
  final int rounds;
  final bool dice;
  final int? seed;

  @override
  State<BankCompanion> createState() => _BankCompanionState();
}

class _BankCompanionState extends State<BankCompanion> {
  late final Random _rng = Random(widget.seed);
  final List<_Step> _steps = [];
  late BankGame _g = _rebuild();
  var _rollId = 0;

  /// The dice are in the air (the bank waits for them).
  var _rolling = false;
  Timer? _land;

  @override
  void dispose() {
    _land?.cancel();
    super.dispose();
  }

  BankGame _rebuild() {
    final g = BankGame(players: widget.names.length, rounds: widget.rounds);
    for (final s in _steps) {
      switch (s) {
        case _Roll(:final a, :final b):
          g.roll(a, b);
        case _Banked(:final p):
          g.bankFor(p);
        case _NextRound():
          g.nextRound();
        case _Adjust(:final p, :final score):
          g.scores[p] = score;
      }
    }
    return g;
  }

  void _do(_Step s) {
    setState(() {
      _steps.add(s);
      _g = _rebuild();
    });
  }

  void _undo() {
    if (_steps.isEmpty) return;
    setState(() {
      _steps.removeLast();
      _g = _rebuild();
      _rollId++;
    });
  }

  void _roll([int? a, int? b]) {
    if (_g.roundOver) return;
    a ??= 1 + _rng.nextInt(6);
    b ??= 1 + _rng.nextInt(6);
    _rollId++;
    Sound.play(Sfx.shuffle);
    if (widget.dice) {
      _rolling = true;
      _land?.cancel();
      _land = Timer(const Duration(milliseconds: diceRollMs), () {
        if (mounted) setState(() => _rolling = false);
      });
    }
    _do(_Roll(a, b));
    final r = _g.last!;
    Sound.later(switch (r.kind) {
      BankRollKind.bust => r.before >= 300 ? Sfx.loseBig : Sfx.clash,
      BankRollKind.doubled => r.after >= 400 ? Sfx.winMedium : Sfx.collect,
      BankRollKind.safeSeven => Sfx.chips,
      BankRollKind.add => Sfx.place,
    }, widget.dice ? diceRollMs : 0);
  }

  /// Tap a number in scoring-only mode (any two dice making it).
  void _entered(int sum) {
    final a = max(1, sum - 6);
    // In the safe rolls 2 and 12 come up (as doubles, which add like any
    // roll there); afterwards they're doubles and go through that button.
    _roll(a, sum - a == a && !_g.safe ? a + 1 : sum - a);
  }

  /// Doubles after the safe rolls: the bank doubles, whatever the faces.
  void _enteredDoubles() => _roll(2, 2);

  void _bank(int p) {
    if (!_g.canBank(p)) return;
    Sound.play(Sfx.pot);
    _do(_Banked(p));
  }

  Future<void> _edit(int p) async {
    final ctl = TextEditingController(text: '${_g.scores[p]}');
    final v = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${widget.names[p]}\'s score'),
        content: TextField(
          key: const Key('edit score'),
          controller: ctl,
          autofocus: true,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            key: const Key('save score'),
            onPressed: () => Navigator.pop(context, int.tryParse(ctl.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (v != null) _do(_Adjust(p, v));
  }

  Future<void> _leave() async {
    final ok =
        _steps.isEmpty ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('End this game?'),
                content: const Text('The scores won\'t be kept.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep playing'),
                  ),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('End')),
                ],
              ),
            ) ==
            true;
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final g = _g;
    final r = g.last;
    final reaction = r == null ? null : rollReaction(r);
    final hot = g.bank >= 300 && !g.safe && !g.roundOver;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: hot ? Color.lerp(Toon.purple, Toon.red, 0.3) : Toon.purple,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth > box.maxHeight;
              final center = _center(context, box, wide);
              final players = _players(wide);
              return Stack(
                children: [
                  Column(
                    children: [
                      _topBar(),
                      Expanded(
                        child: wide
                            ? Row(
                                children: [
                                  Expanded(flex: 3, child: center),
                                  SizedBox(width: min(320, box.maxWidth * 0.4), child: players),
                                ],
                              )
                            : Column(
                                children: [
                                  Expanded(child: center),
                                  players,
                                ],
                              ),
                      ),
                    ],
                  ),
                  if (reaction != null && r!.kind == BankRollKind.bust && reaction.$3)
                    Positioned.fill(
                      child: Flash(key: ValueKey('flash$_rollId'), color: Toon.red),
                    ),
                  if (reaction != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: _Delayed(
                          key: ValueKey('pop$_rollId'),
                          ms: widget.dice ? diceRollMs : 0,
                          child: RollPop(
                            text: reaction.$1,
                            color: reaction.$2,
                            big: reaction.$3,
                            shake: r!.kind == BankRollKind.bust,
                          ),
                        ),
                      ),
                    ),
                  if (g.roundOver && !_rolling) Positioned.fill(child: _roundOver()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: Row(
      children: [
        ToonButton(
          color: Toon.card,
          padding: const EdgeInsets.all(8),
          tooltip: 'End game',
          onPressed: _leave,
          child: const Icon(Icons.close_rounded),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Round ${_g.round} of ${_g.rounds}',
            style: Toon.text(20, weight: FontWeight.w700, color: Colors.white),
          ),
        ),
        ToonButton(
          key: const Key('undo'),
          color: Toon.card,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          onPressed: _steps.isEmpty ? null : _undo,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(Icons.undo_rounded, size: 20), SizedBox(width: 4), Text('Undo')],
          ),
        ),
      ],
    ),
  );

  /// The dice (or the number pad), the bank, whose roll it is.
  Widget _center(BuildContext context, BoxConstraints box, bool wide) {
    final g = _g;
    final r = g.last;
    final dice = min(box.maxWidth * (wide ? 0.16 : 0.3), box.maxHeight * 0.18).clamp(60.0, 150.0);
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              safetyChip(g),
              SizedBox(height: widget.dice ? dice * 0.4 : 10),
              if (widget.dice)
                GestureDetector(
                  key: const Key('tap dice'),
                  onTap: g.roundOver || _rolling ? null : _roll,
                  child: RollingDice(a: r?.a ?? 6, b: r?.b ?? 6, roll: _rollId, size: dice),
                )
              else
                _pad(),
              const SizedBox(height: 14),
              Text(
                'BANK',
                style: Toon.text(18, weight: FontWeight.w700, color: Colors.white70),
              ),
              BankTotal(value: _rolling ? (r?.before ?? 0) : g.bank, size: wide ? 64 : 84),
              Text(
                g.roundOver ? '' : '${widget.names[g.roller]}\'s roll · roll ${g.rolls + 1}',
                style: Toon.text(16, weight: FontWeight.w600, color: Colors.white),
              ),
              if (widget.dice) ...[
                const SizedBox(height: 10),
                ToonButton(
                  key: const Key('roll'),
                  color: Toon.green,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  onPressed: g.roundOver || _rolling ? null : _roll,
                  child: Text('Roll', style: Toon.text(22, weight: FontWeight.w700)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Scoring only: tap the total you rolled (after the safe rolls,
  /// doubles of any kind are one button).
  Widget _pad() {
    final safe = _g.safe;
    final sums = safe ? [for (var i = 2; i <= 12; i++) i] : [3, 4, 5, 6, 7, 8, 9, 10, 11];
    return SizedBox(
      width: 320,
      child: Column(
        children: [
          Text(
            'What did you roll?',
            style: Toon.text(16, weight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in sums)
                SizedBox(
                  width: 62,
                  child: ToonButton(
                    key: Key('sum $s'),
                    color: s == 7 ? Toon.red : Toon.cardFace,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    onPressed: _g.roundOver ? null : () => _entered(s),
                    child: Text(
                      '$s',
                      style: Toon.text(20, weight: FontWeight.w700, color: Toon.inkLight),
                    ),
                  ),
                ),
              if (!safe)
                SizedBox(
                  width: 132,
                  child: ToonButton(
                    key: const Key('doubles'),
                    color: Toon.yellow,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    onPressed: _g.roundOver ? null : _enteredDoubles,
                    child: Text(
                      'Doubles',
                      style: Toon.text(20, weight: FontWeight.w700, color: Toon.inkLight),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Everyone: tap to bank, hold to fix a score.
  Widget _players(bool wide) {
    final g = _g;
    final order = [for (var p = 0; p < g.players; p++) p];
    final tiles = [
      for (final p in order)
        GestureDetector(
          key: Key('player $p'),
          onTap: g.canBank(p) ? () => _bank(p) : null,
          onLongPress: () => _edit(p),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: wide ? double.infinity : 150,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: Toon.box(
              g.banked[p] ? Toon.green : (g.roller == p && !g.roundOver ? Toon.yellow : Toon.cardFace),
              radius: 14,
              shadow: 3,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.names[p],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Toon.text(15, weight: FontWeight.w700, color: Toon.inkLight),
                      ),
                      Text(
                        g.banked[p] ? 'Banked ${g.bankedAt[p]}' : (g.canBank(p) ? 'Tap to BANK' : ' '),
                        style: Toon.text(12, color: Toon.inkLight),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${g.scores[p]}',
                  style: Toon.text(20, weight: FontWeight.w700, color: Toon.inkLight),
                ),
              ],
            ),
          ),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.all(10),
      child: wide
          ? ListView(
              children: [for (final t in tiles) Padding(padding: const EdgeInsets.only(bottom: 8), child: t)],
            )
          : Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: tiles),
    );
  }

  Widget _roundOver() {
    final g = _g;
    final r = g.last;
    final lost = [for (final p in g.stillIn) widget.names[p]];
    final ranked = [for (var p = 0; p < g.players; p++) p]
      ..sort((a, b) => g.scores[b].compareTo(g.scores[a]));
    final done = g.isOver;
    return ColoredBox(
      color: Toon.ink.withValues(alpha: 0.5),
      child: Stack(
        children: [
          if (done) const Positioned.fill(child: IgnorePointer(child: SuitConfetti())),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _Delayed(
                ms: r?.kind == BankRollKind.bust ? 900 : 300,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: ToonBox(
                    color: Toon.paper,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          done ? '${widget.names[ranked.first]} wins!' : 'Round ${g.round} done',
                          textAlign: TextAlign.center,
                          style: Toon.text(26, weight: FontWeight.w700),
                        ),
                        if (!done && r?.kind == BankRollKind.bust && lost.isNotEmpty)
                          Text(
                            'Seven! Nothing for ${lost.join(', ')}.',
                            textAlign: TextAlign.center,
                            style: Toon.text(15, color: Toon.muted),
                          ),
                        const SizedBox(height: 10),
                        for (final (i, p) in ranked.indexed)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Text('${g.placeOf(p) + 1}.', style: Toon.text(16)),
                                ),
                                Expanded(
                                  child: Text(
                                    widget.names[p],
                                    style: Toon.text(16, weight: i == 0 ? FontWeight.w700 : FontWeight.w500),
                                  ),
                                ),
                                Text('${g.scores[p]}', style: Toon.text(16, weight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ToonButton(
                                color: Toon.card,
                                onPressed: _undo,
                                child: const FittedBox(child: Text('Undo', maxLines: 1)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: ToonButton(
                                key: const Key('next round'),
                                color: Toon.green,
                                onPressed: done
                                    ? () => setState(() {
                                        _steps.clear();
                                        _g = _rebuild();
                                        _rollId++;
                                      })
                                    : () => _do(_NextRound()),
                                child: FittedBox(
                                  child: Text(done ? 'Play again' : 'Next round', maxLines: 1),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows [child] after [ms] (once the dice have landed).
class _Delayed extends StatefulWidget {
  const _Delayed({super.key, required this.ms, required this.child});

  final int ms;
  final Widget child;

  @override
  State<_Delayed> createState() => _DelayedState();
}

class _DelayedState extends State<_Delayed> {
  late bool _shown = widget.ms == 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (!_shown) {
      _timer = Timer(Duration(milliseconds: widget.ms), () {
        if (mounted) setState(() => _shown = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _shown ? widget.child : const SizedBox.shrink();
}
