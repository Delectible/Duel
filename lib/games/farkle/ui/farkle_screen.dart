import 'dart:math';

import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/farkle/farkle.dart';
import 'package:flutter/material.dart';

import '../../../core/account/account.dart';
import '../../../core/account/stake.dart';
import '../../../core/help/game_guide.dart';
import '../../../core/table/table_bits.dart';
import '../../../core/theme/toon.dart';
import '../../bank/dice.dart';
import '../../bank/thrown_dice.dart';
import '../../bank/ui/bank_bits.dart';
import 'farkle_controller.dart';

const farkleGuide = [
  GuideStage(
    'roll',
    'Rolling',
    'On your turn, swipe up on the tray (or tap it) to roll six dice.',
    icon: Icons.casino_rounded,
  ),
  GuideStage(
    'keep',
    'Keeping',
    'After every roll you must keep at least one scoring die: 1 = 100, 5 = 50, three of a kind = the face × 100 '
        '(three 1s = 1000), four of a kind 1000, five 2000, six 3000, a straight 1–6 or three pairs 1500, two '
        'triples 2500. Every die you keep has to score.',
    icon: Icons.back_hand_rounded,
  ),
  GuideStage(
    'push',
    'Roll on, or bank',
    'Then roll the dice you didn\'t keep to add more, or bank the turn\'s points. Keep all six and you have hot '
        'dice: roll all six again.',
    icon: Icons.savings_rounded,
  ),
  GuideStage(
    'farkle',
    'Farkle!',
    'A roll with nothing to keep is a Farkle: you lose everything from this turn. The fewer dice you roll, the '
        'likelier it gets (one die: 2 in 3).',
    icon: Icons.warning_rounded,
  ),
  GuideStage(
    'end',
    'Winning',
    'The first to 10,000 sets the score to beat; everyone else gets one last turn. The highest score wins.',
    icon: Icons.emoji_events_rounded,
  ),
];

/// Farkle's own look: a dice tray of deep green felt in a wooden frame.
abstract final class Tray {
  static const felt = Color(0xFF1E5E4E);
  static const feltDark = Color(0xFF123E33);
  static const wood = Color(0xFF8A5A2E);
  static const woodDark = Color(0xFF5E3A1C);
  static const gold = Color(0xFFF2C14E);
}

/// Farkle against bots.
class FarkleScreen extends StatefulWidget {
  const FarkleScreen({
    super.key,
    required this.bots,
    required this.difficulty,
    this.target = 10000,
    this.pace = 1,
    this.seed,
    this.stake,
  });

  final int bots;
  final Difficulty difficulty;
  final int target;
  final double pace;
  final int? seed;
  final StakeTicket? stake;

  @override
  State<FarkleScreen> createState() => _FarkleScreenState();
}

class _FarkleScreenState extends State<FarkleScreen> {
  late final Account _account = AccountScope.maybeRead(context) ?? Account();
  late StakeTicket _ticket =
      widget.stake ??
      StakeTicket(
        account: _account,
        gameId: 'farkle',
        stake: 0,
        opponents: widget.bots,
        difficulty: widget.difficulty,
      );
  late final FarkleController _c = FarkleController(
    bots: widget.bots,
    difficulty: widget.difficulty,
    target: widget.target,
    pace: widget.pace,
    rng: widget.seed == null ? null : Random(widget.seed),
    you: _account.persona,
  )..addListener(_settle);

  void _settle() {
    if (_c.phase == FarklePhase.over && !_ticket.settled) {
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

  Future<void> _leave() async {
    if (_c.phase == FarklePhase.over || await confirmLeave(context, _ticket)) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  String? _stage() => switch (_c.phase) {
    FarklePhase.over => 'end',
    FarklePhase.farkle => 'farkle',
    FarklePhase.choosing => 'keep',
    _ => _c.game.turnPoints > 0 ? 'push' : 'roll',
  };

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
                  title: 'Farkle',
                  subtitle:
                      'To ${chips(widget.target)} · ${widget.bots} ${widget.bots == 1 ? 'bot' : 'bots'} · ${widget.difficulty.label}',
                  onLeave: _leave,
                  ticket: _ticket,
                  guide: farkleGuide,
                  stage: _stage,
                ),
                commentary: CommentaryStrip(
                  text: _c.commentary(),
                  yourMove: _c.canRoll || _c.canPick,
                  leading: _Score(points: _c.game.scores[0]),
                ),
                table: _Table(c: _c),
                controls: _Controls(c: _c),
              ),
              if (_c.phase == FarklePhase.over) Positioned.fill(child: _over(context)),
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
    return GameOverCard(
      face: _c.personas[w.contains(0) ? 0 : w.first],
      title: tie
          ? (w.contains(0) ? "It's a tie!" : 'A tie')
          : (won ? 'You won!' : '${_c.personas[w.first].name} won'),
      subtitle: won
          ? 'You finished on ${chips(g.scores[0])}.'
          : '${chips(g.scores[w.first])} to your ${chips(g.scores[0])}.',
      ticket: _ticket,
      won: won,
      onAgain: () {
        setState(() => _ticket = _ticket.again());
        _c.playAgain();
      },
      leaveLabel: 'Back',
      onLeave: () => Navigator.of(context).pop(),
    );
  }
}

class _Score extends StatelessWidget {
  const _Score({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 54),
    padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 5),
    decoration: Toon.box(Toon.cardFace, radius: 10, shadow: 0),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          child: Text(
            chips(points),
            style: Toon.text(18, weight: FontWeight.w700, color: Toon.inkLight),
          ),
        ),
        Text('score', style: Toon.text(10, color: Toon.inkLight)),
      ],
    ),
  );
}

class _Table extends StatelessWidget {
  const _Table({required this.c});

  final FarkleController c;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final g = c.game;
      final wide = GameLayout.wide(context);
      final boardH = wide ? 88.0 : 92.0;
      final shelfH = wide ? 40.0 : 48.0;
      final trayH = box.maxHeight - boardH - shelfH - 18;
      final die = min(box.maxWidth / 5.2, trayH / 3.4).clamp(34.0, 78.0);
      return Column(
        children: [
          SizedBox(
            height: boardH,
            child: _Board(c: c),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: shelfH,
            child: _Shelf(c: c),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Tray.wood,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Toon.ink, width: Toon.outline),
              ),
              padding: const EdgeInsets.all(9),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const RadialGradient(colors: [Tray.felt, Tray.feltDark], radius: 0.9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Tray.woodDark, width: 3),
                ),
                child: LayoutBuilder(
                  builder: (context, inner) {
                    final area = Size(inner.maxWidth, inner.maxHeight);
                    final landed = c.phase == FarklePhase.choosing || c.phase == FarklePhase.farkle;
                    final showing = g.rolled.isNotEmpty;
                    return SwipeToRoll(
                      key: const Key('roll'),
                      enabled: c.canRoll,
                      onRoll: c.roll,
                      hint: g.turnPoints == 0 ? 'Swipe up to roll' : 'Swipe up to roll ${g.diceLeft}',
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          SizedBox.fromSize(size: area),
                          if (showing)
                            ThrownDice(
                              values: g.rolled,
                              roll: c.rollId,
                              size: die,
                              area: area,
                              picked: c.picked,
                              faded: landed && c.yours
                                  ? {for (var i = 0; i < g.rolled.length; i++) i}.difference(c.scoring)
                                  : const {},
                              onTap: c.canPick ? c.tapDie : null,
                            ),
                          if (!showing && c.phase == FarklePhase.ready)
                            Center(
                              child: Text(
                                g.hotDice ? 'HOT DICE!' : '${g.diceLeft} dice',
                                style: Toon.text(
                                  g.hotDice ? 34 : 22,
                                  weight: FontWeight.w700,
                                  color: g.hotDice ? Tray.gold : Colors.white38,
                                ),
                              ),
                            ),
                          if (c.phase == FarklePhase.farkle)
                            const Positioned.fill(child: Center(child: _Stamp())),
                          if (c.phase == FarklePhase.farkle)
                            Positioned.fill(
                              child: Flash(key: ValueKey('fl${c.rollId}'), color: Toon.red),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// FARKLE! stamped across the tray.
class _Stamp extends StatelessWidget {
  const _Stamp();

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 2.2, end: 1),
    duration: const Duration(milliseconds: 380),
    curve: Curves.easeOutBack,
    builder: (context, s, child) => Transform.scale(scale: s, child: child),
    child: Transform.rotate(
      angle: -0.18,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Toon.red, width: 5),
          borderRadius: BorderRadius.circular(12),
          color: Colors.black.withValues(alpha: 0.25),
        ),
        child: Text(
          'FARKLE!',
          style: Toon.text(44, weight: FontWeight.w700, color: Toon.red),
        ),
      ),
    ),
  );
}

/// Everyone's score racing to the target, whose turn it is, the turn so far.
class _Board extends StatelessWidget {
  const _Board({required this.c});

  final FarkleController c;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    return Row(
      children: [
        for (var p = 0; p < g.players; p++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _Player(c: c, p: p),
            ),
          ),
      ],
    );
  }
}

class _Player extends StatelessWidget {
  const _Player({required this.c, required this.p});

  final FarkleController c;
  final int p;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    final turn = g.turn == p && c.phase != FarklePhase.over;
    final said = c.speech[p];
    final last = c.lastTurn;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 5),
          decoration: Toon.box(turn ? Tray.gold : Toon.card, radius: 12, shadow: turn ? 3 : 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaceRing(c.personas[p], size: GameLayout.wide(context) ? 22 : 26),
              const SizedBox(height: 2),
              FittedBox(
                child: Text(
                  p == 0 ? 'You' : c.personas[p].name,
                  maxLines: 1,
                  style: Toon.text(11, weight: FontWeight.w600, color: turn ? Toon.inkLight : null),
                ),
              ),
              FittedBox(
                child: Text(
                  chips(g.scores[p]) + (turn && g.turnPoints > 0 ? ' +${g.turnPoints}' : ''),
                  maxLines: 1,
                  style: Toon.text(13, weight: FontWeight.w700, color: turn ? Toon.inkLight : null),
                ),
              ),
              const SizedBox(height: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (g.scores[p] / g.target).clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: Colors.black12,
                  valueColor: AlwaysStoppedAnimation(g.closer == p ? Toon.red : Toon.green),
                ),
              ),
            ],
          ),
        ),
        if (last != null && last.player == p && last.end == FarkleEnd.banked)
          Positioned(
            top: -8,
            child: Pop(key: ValueKey('pop${g.history.length}'), child: _tag('+${last.points}', Toon.green)),
          ),
        if (said != null)
          Positioned(top: 64, child: SpeechBubble(said, key: ValueKey('say$p-${c.speechId}'))),
      ],
    );
  }

  Widget _tag(String s, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: Toon.box(color, radius: 8, shadow: 0),
    child: Text(
      s,
      style: Toon.text(11, weight: FontWeight.w700, color: Colors.white),
    ),
  );
}

/// The dice kept this turn, set aside on a shelf above the tray.
class _Shelf extends StatelessWidget {
  const _Shelf({required this.c});

  final FarkleController c;

  @override
  Widget build(BuildContext context) {
    if (c.shelf.isEmpty) {
      return Center(
        child: Text(
          'Kept dice go here',
          style: Toon.text(13, weight: FontWeight.w500, color: Toon.muted),
        ),
      );
    }
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, group) in c.shelf.indexed)
              Pop(
                key: ValueKey('shelf$i-${c.rollId}'),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  decoration: Toon.box(Toon.card, radius: 10, shadow: 1),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final d in group) Die(d, size: 24),
                      const SizedBox(width: 3),
                      Text('+${farkleScore(group)}', style: Toon.text(12, weight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.c});

  final FarkleController c;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    if (c.canPick) {
      final s = c.pickedScore;
      return Row(
        children: [
          ToonButton(
            key: const Key('best'),
            color: Toon.card,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            tooltip: 'Pick every scoring die',
            onPressed: c.pickBest,
            child: const Icon(Icons.auto_awesome_rounded, size: 20),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ToonButton(
              key: const Key('keep roll'),
              color: Toon.green,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              onPressed: c.canKeepAndRoll ? c.keepAndRoll : null,
              child: FittedBox(
                child: Text(s == null ? 'Keep & roll' : '+$s · roll ${c.afterKeep}', maxLines: 1),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ToonButton(
              key: const Key('keep bank'),
              color: Tray.gold,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              onPressed: c.canKeepAndBank ? c.keepAndBank : null,
              child: FittedBox(
                child: Text(s == null ? 'Keep & bank' : 'Bank ${g.turnPoints + s}', maxLines: 1),
              ),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: Center(
              child: Text(
                c.canRoll
                    ? 'Your roll'
                    : (c.phase == FarklePhase.over ? '' : '${c.personas[g.turn].name}\'s turn'),
                style: Toon.text(16, weight: FontWeight.w700, color: Toon.muted),
              ),
            ),
          ),
        ),
        if (c.canBankNow)
          ToonButton(
            key: const Key('bank'),
            color: Tray.gold,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
            onPressed: c.bankNow,
            child: Text('Bank ${g.turnPoints}'),
          ),
      ],
    );
  }
}
