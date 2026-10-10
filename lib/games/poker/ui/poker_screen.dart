import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/help/game_guide.dart';
import '../../../core/session/difficulty.dart';
import '../../../core/theme/toon.dart';
import 'action_bar.dart';
import '../../../core/account/account.dart';
import '../../../core/account/stake.dart';
import '../../../core/avatars/faces.dart';
import 'poker_guide.dart';
import 'poker_controller.dart';
import 'table_view.dart';

/// Texas Hold'em Sit & Go against [bots] bots.
class PokerScreen extends StatefulWidget {
  const PokerScreen({
    super.key,
    required this.bots,
    required this.difficulty,
    this.pace = 1,
    this.seed,
    this.resultTimeout,
    this.stake,
  });

  final int bots;
  final Difficulty difficulty;

  /// Multiplies every delay (tests).
  final double pace;

  /// Fixed shuffles and bot choices (tests).
  final int? seed;

  /// Showdown results wait this long for Next hand; null waits for you
  /// (bot games). Online games will pass 10 seconds.
  final Duration? resultTimeout;

  /// The stake taken when you hit Play! (null: a free game).
  final StakeTicket? stake;

  @override
  State<PokerScreen> createState() => _PokerScreenState();
}

class _PokerScreenState extends State<PokerScreen> {
  late PokerController _c;
  late StakeTicket _ticket;
  late Account _account;

  @override
  void initState() {
    super.initState();
    _account = AccountScope.maybeRead(context) ?? Account();
    _ticket =
        widget.stake ??
        StakeTicket(
          account: _account,
          gameId: 'holdem',
          stake: 0,
          opponents: widget.bots,
          difficulty: widget.difficulty,
        );
    _c = _newTable();
  }

  /// A fresh table. Stored in [_c] before it starts: [_settle] reads it.
  PokerController _newTable() {
    final c = _c = PokerController(
      bots: widget.bots,
      difficulty: widget.difficulty,
      pace: widget.pace,
      resultTimeout: widget.resultTimeout,
      rng: widget.seed == null ? null : Random(widget.seed),
      you: _account.persona,
    );
    c
      ..addListener(_settle)
      ..start();
    return c;
  }

  /// Your tournament's over: win only for first place.
  void _settle() {
    if (_c.phase == TablePhase.finished && !_ticket.settled) {
      _ticket.settle(_c.yourPlace == 1 ? Outcome.win : Outcome.loss);
    }
  }

  void _playAgain() {
    setState(() {
      _c.dispose();
      _ticket = _ticket.again();
      _c = _newTable();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_c.phase == TablePhase.finished || await confirmLeave(context, _ticket)) {
      if (mounted) Navigator.of(context).pop();
    }
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
                    _Hud(c: _c, ticket: _ticket, onLeave: _leave),
                    Expanded(child: TableView(c: _c)),
                    ActionBar(c: _c),
                  ],
                ),
                if (_c.phase == TablePhase.finished)
                  Positioned.fill(
                    child: _GameOver(
                      c: _c,
                      ticket: _ticket,
                      onAgain: _playAgain,
                      onLeave: () => Navigator.of(context).pop(),
                    ),
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
  const _Hud({required this.c, required this.ticket, required this.onLeave});

  final PokerController c;
  final StakeTicket ticket;
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
                Row(
                  children: [
                    Text("Texas Hold'em", style: Toon.text(18, weight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    StakeBadge(ticket),
                  ],
                ),
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
          const SizedBox(width: 8),
          GuideButton(title: "Texas Hold'em", stages: pokerGuide, current: () => pokerStage(c)),
        ],
      ),
    );
  }
}

class _GameOver extends StatelessWidget {
  const _GameOver({required this.c, required this.ticket, required this.onAgain, required this.onLeave});

  final PokerController c;
  final StakeTicket ticket;
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
                  const SizedBox(height: 10),
                  StakeResult(ticket),
                  const SizedBox(height: 14),
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
