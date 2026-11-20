import 'dart:math';

import 'package:duel_engine/bank/bank.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:flutter/material.dart';

import '../../../core/account/account.dart';
import '../../../core/account/stake.dart';
import '../../../core/help/game_guide.dart';
import '../../../core/table/table_bits.dart';
import '../../../core/theme/toon.dart';
import 'bank_bits.dart';
import 'bank_controller.dart';

const bankGuide = [
  GuideStage(
    'roll',
    'Rolling',
    'Players take turns rolling two dice, and every roll goes into the bank, which everyone shares. Bots roll by '
        'themselves; tap Roll when it\'s yours.',
    icon: Icons.casino_rounded,
  ),
  GuideStage(
    'safe',
    'The safe rolls',
    'The first three rolls of a round are safe: a 7 adds 70, doubles add their total like any roll.',
    icon: Icons.shield_rounded,
  ),
  GuideStage(
    'danger',
    'The danger zone',
    'From the fourth roll on, doubles double the whole bank, but a 7 ends the round and anyone still in gets '
        'nothing. One roll in six is a 7.',
    icon: Icons.warning_rounded,
  ),
  GuideStage(
    'bank',
    'BANK!',
    'Tap BANK! any time you\'re in, even on someone else\'s roll, to add the bank to your score and sit the rest of '
        'the round out. The round ends with a 7 or when everyone has banked.',
    icon: Icons.savings_rounded,
  ),
  GuideStage(
    'end',
    'Winning',
    'Highest score after the last round wins. A tie for the top is a tie: stakes go back.',
    icon: Icons.emoji_events_rounded,
  ),
];

/// Bank! against bots.
class BankScreen extends StatefulWidget {
  const BankScreen({
    super.key,
    required this.bots,
    required this.difficulty,
    this.rounds = 15,
    this.pace = 1,
    this.seed,
    this.stake,
  });

  final int bots;
  final Difficulty difficulty;
  final int rounds;
  final double pace;
  final int? seed;
  final StakeTicket? stake;

  @override
  State<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends State<BankScreen> {
  late final Account _account = AccountScope.maybeRead(context) ?? Account();
  late StakeTicket _ticket =
      widget.stake ??
      StakeTicket(
        account: _account,
        gameId: 'bank',
        stake: 0,
        opponents: widget.bots,
        difficulty: widget.difficulty,
      );
  late final BankController _c = BankController(
    bots: widget.bots,
    difficulty: widget.difficulty,
    rounds: widget.rounds,
    pace: widget.pace,
    rng: widget.seed == null ? null : Random(widget.seed),
    you: _account.persona,
  )..addListener(_settle);

  void _settle() {
    if (_c.phase == BankPhase.over && !_ticket.settled) {
      final w = _c.game.winners;
      _ticket.settle(
        !w.contains(0)
            ? Outcome.loss
            : w.length == 1
            ? Outcome.win
            : Outcome.tie,
      );
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String? _stage() {
    final g = _c.game;
    if (_c.phase == BankPhase.over) return 'end';
    if (_c.canBank && !_c.yourRoll) return 'bank';
    return g.safe ? (g.rolls == 0 ? 'roll' : 'safe') : 'danger';
  }

  Future<void> _leave() async {
    if (_c.phase == BankPhase.over || await confirmLeave(context, _ticket)) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
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
              GameLayout(
                top: GameTopBar(
                  title: 'Bank!',
                  subtitle:
                      'Round ${_c.game.round} of ${_c.game.rounds} · ${widget.bots} ${widget.bots == 1 ? 'bot' : 'bots'} · ${widget.difficulty.label}',
                  onLeave: _leave,
                  ticket: _ticket,
                  guide: bankGuide,
                  stage: _stage,
                ),
                commentary: CommentaryStrip(
                  text: _c.commentary(),
                  yourMove: _c.yourRoll || _c.canBank,
                  leading: _Score(points: _c.game.scores[0]),
                ),
                table: _Table(c: _c),
                controls: _Controls(c: _c),
              ),
              if (_c.phase == BankPhase.over) Positioned.fill(child: _over(context)),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _over(BuildContext context) {
    final g = _c.game;
    final w = g.winners;
    final tie = w.length > 1;
    final won = w.contains(0) && !tie;
    final mine = g.scores[0], top = g.scores[w.first];
    return GameOverCard(
      face: _c.personas[w.contains(0) ? 0 : w.first],
      title: tie
          ? (w.contains(0) ? "It's a tie!" : 'A tie')
          : (won ? 'You won!' : '${_c.personas[w.first].name} won'),
      subtitle: won
          ? 'You banked $mine over ${g.rounds} rounds.'
          : tie
          ? '$top each${w.contains(0) ? ': your stake comes back.' : '. You banked $mine.'}'
          : '$top to your $mine.',
      ticket: _ticket,
      won: won,
      onAgain: () {
        setState(() => _ticket = _ticket.again());
        _c.playAgain();
      },
      onLeave: () => Navigator.of(context).pop(),
    );
  }
}

class _Score extends StatelessWidget {
  const _Score({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 50),
    padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
    decoration: Toon.box(Toon.cardFace, radius: 10, shadow: 0),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$points',
          style: Toon.text(18, weight: FontWeight.w700, color: Toon.inkLight),
        ),
        Text('score', style: Toon.text(10, color: Toon.inkLight)),
      ],
    ),
  );
}

/// The purple dice table: players along the top, the dice and the bank in
/// the middle.
class _Table extends StatelessWidget {
  const _Table({required this.c});

  final BankController c;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final g = c.game;
      final r = g.last;
      final wide = GameLayout.wide(context);
      final dice = min(box.maxWidth * 0.2, box.maxHeight * (wide ? 0.22 : 0.13)).clamp(48.0, 96.0);
      final reaction = !c.tumbling && r != null ? rollReaction(r) : null;
      final hot = g.bank >= 300 && !g.safe;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              decoration: BoxDecoration(
                color: hot ? Color.lerp(Toon.purple, Toon.red, 0.25) : Toon.purple,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Toon.ink, width: Toon.outline),
              ),
            ),
          ),
          Positioned(
            left: 6,
            right: 6,
            top: 10,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var p = 0; p < g.players; p++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _Player(c: c, p: p),
                    ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            top: wide ? 110 : 130,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    safetyChip(g),
                    SizedBox(height: dice * 0.45),
                    RollingDice(a: r?.a ?? 6, b: r?.b ?? 6, roll: c.rollId, size: dice),
                    const SizedBox(height: 12),
                    Text(
                      'BANK',
                      style: Toon.text(15, weight: FontWeight.w700, color: Colors.white70),
                    ),
                    // The bank moves once the dice are down.
                    BankTotal(value: c.tumbling ? (r?.before ?? 0) : g.bank, size: wide ? 46 : 58),
                    Text(
                      g.rolls == 0 ? 'First roll coming' : 'Roll ${g.rolls}',
                      style: Toon.text(13, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (reaction != null && r!.kind == BankRollKind.bust && reaction.$3)
            Positioned.fill(
              child: Flash(key: ValueKey('flash${c.rollId}'), color: Toon.red),
            ),
          if (reaction != null)
            Positioned.fill(
              top: 100,
              child: IgnorePointer(
                child: RollPop(
                  key: ValueKey('pop${c.rollId}'),
                  text: reaction.$1,
                  color: reaction.$2,
                  big: reaction.$3,
                  shake: r!.kind == BankRollKind.bust,
                ),
              ),
            ),
          if (c.phase == BankPhase.roundOver)
            Positioned.fill(
              child: IgnorePointer(
                child: Align(
                  alignment: const Alignment(0, 0.85),
                  child: Pop(
                    child: ToonBox(
                      color: Toon.card,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Text(
                        'Round ${g.round} done · next up: ${g.round + 1}',
                        style: Toon.text(16, weight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _Player extends StatelessWidget {
  const _Player({required this.c, required this.p});

  final BankController c;
  final int p;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    final banked = g.banked[p];
    final rolling = g.roller == p && !g.roundOver && c.phase == BankPhase.rolling;
    final said = c.speech[p];
    return SizedBox(
      width: 74,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: banked ? 0.75 : 1,
                child: FaceRing(
                  c.personas[p],
                  size: 34,
                  color: rolling ? Toon.yellow : (banked ? Toon.green : null),
                ),
              ),
              if (rolling)
                const Positioned(
                  right: -6,
                  bottom: -4,
                  child: Icon(Icons.casino_rounded, size: 18, color: Colors.white),
                ),
            ],
          ),
          const SizedBox(height: 4),
          NamePlate(
            p == 0 ? 'You' : c.personas[p].name,
            line: banked ? '+${g.bankedAt[p]}' : '${g.scores[p]}',
            color: banked ? Toon.green : null,
          ),
          if (banked) Text('total ${g.scores[p]}', style: Toon.text(10, color: Colors.white70)),
          if (said != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: SpeechBubble(said, key: ValueKey('say$p-${c.speechId}')),
            ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.c});

  final BankController c;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: ToonButton(
              key: const Key('roll'),
              color: Toon.green,
              onPressed: c.yourRoll ? c.roll : null,
              child: FittedBox(child: Text(c.yourRoll ? 'Roll!' : '${_roller(c)} rolls', maxLines: 1)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ToonButton(
              key: const Key('bank'),
              color: Toon.yellow,
              onPressed: c.canBank ? c.bank : null,
              child: FittedBox(
                child: Text(
                  g.banked[0] ? 'Banked ${g.bankedAt[0]}' : (g.bank > 0 ? 'BANK! ${g.bank}' : 'BANK!'),
                  maxLines: 1,
                  style: Toon.text(18, weight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _roller(BankController c) => c.game.roller == 0 ? 'You' : c.personas[c.game.roller].name;
}
