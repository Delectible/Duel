import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/session/difficulty.dart';
import '../../../core/theme/toon.dart';
import 'action_bar.dart';
import 'faces.dart';
import 'poker_controller.dart';
import 'table_view.dart';

/// Texas Hold'em Sit & Go against [bots] bots.
class PokerScreen extends StatefulWidget {
  const PokerScreen({super.key, required this.bots, required this.difficulty, this.pace = 1, this.seed});

  final int bots;
  final Difficulty difficulty;

  /// Multiplies every delay (tests).
  final double pace;

  /// Fixed shuffles and bot choices (tests).
  final int? seed;

  @override
  State<PokerScreen> createState() => _PokerScreenState();
}

class _PokerScreenState extends State<PokerScreen> {
  late PokerController _c;

  @override
  void initState() {
    super.initState();
    _c = _newTable();
  }

  PokerController _newTable() => PokerController(
    bots: widget.bots,
    difficulty: widget.difficulty,
    pace: widget.pace,
    rng: widget.seed == null ? null : Random(widget.seed),
  )..start();

  void _playAgain() {
    setState(() {
      _c.dispose();
      _c = _newTable();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_c.phase == TablePhase.finished) {
      Navigator.of(context).pop();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ToonBox(
          color: Toon.paper,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Leave the table?', style: Toon.text(22, weight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                "Your chips stay behind and this game won't count.",
                textAlign: TextAlign.center,
                style: Toon.text(16, weight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ToonButton(
                      color: Toon.card,
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Stay'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ToonButton(
                      color: Toon.red,
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Leave'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _c,
            builder: (context, _) => Stack(
              children: [
                Column(
                  children: [
                    _Hud(c: _c, onLeave: _leave),
                    Expanded(child: TableView(c: _c)),
                    ActionBar(c: _c),
                  ],
                ),
                if (_c.phase == TablePhase.finished)
                  Positioned.fill(
                    child: _GameOver(c: _c, onAgain: _playAgain, onLeave: () => Navigator.of(context).pop()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.c, required this.onLeave});

  final PokerController c;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final (sb, bb) = c.game.blinds;
    final left = c.game.handsToNextLevel;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          ToonButton(
            color: Toon.card,
            padding: const EdgeInsets.all(8),
            tooltip: 'Leave table',
            onPressed: onLeave,
            child: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Texas Hold'em", style: Toon.text(18, weight: FontWeight.w700)),
                Text(
                  'Blinds ${chips(sb)} / ${chips(bb)}'
                  '${left == null ? '' : ' · up in $left hand${left == 1 ? '' : 's'}'}',
                  style: Toon.text(14, weight: FontWeight.w500, color: Toon.muted),
                ),
              ],
            ),
          ),
          ToonBox(
            color: Toon.card,
            shadow: 3,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            // While you shuffle, the coming hand's number.
            child: Text(
              'Hand ${c.handNumber + (c.phase == TablePhase.shuffle ? 1 : 0)}',
              style: Toon.text(14),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameOver extends StatelessWidget {
  const _GameOver({required this.c, required this.onAgain, required this.onLeave});

  final PokerController c;
  final VoidCallback onAgain;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final place = c.yourPlace ?? 1;
    final won = place == 1;
    final players = c.personas.length;
    return ColoredBox(
      color: Toon.ink.withValues(alpha: 0.5),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.7, end: 1),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          builder: (context, s, child) => Transform.scale(scale: s, child: child),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ToonBox(
              color: Toon.paper,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Face(c.personas[0], size: 72),
                  const SizedBox(height: 10),
                  Text(
                    won ? 'You won!' : 'Out in ${_ordinal(place)}',
                    style: Toon.text(30, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    won ? 'You took every chip at a table of $players.' : 'Of $players players.',
                    textAlign: TextAlign.center,
                    style: Toon.text(16, weight: FontWeight.w500),
                  ),
                  Text(
                    '${c.game.handsPlayed} hand${c.game.handsPlayed == 1 ? '' : 's'}',
                    style: Toon.text(14, weight: FontWeight.w500, color: Toon.muted),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ToonButton(color: Toon.card, onPressed: onLeave, child: const Text('Games')),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ToonButton(
                          color: Toon.green,
                          onPressed: onAgain,
                          child: const Text('Play again'),
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
    );
  }
}

String _ordinal(int n) => switch (n) {
  1 => '1st',
  2 => '2nd',
  3 => '3rd',
  _ => '${n}th',
};
