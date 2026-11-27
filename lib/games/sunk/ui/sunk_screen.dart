import 'dart:math';

import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/sunk/sunk.dart';
import 'package:flutter/material.dart';

import '../../../core/account/account.dart';
import '../../../core/account/stake.dart';
import '../../../core/help/game_guide.dart';
import '../../../core/online/online_link.dart';
import '../../../core/table/table_bits.dart';
import '../../../core/theme/toon.dart';
import 'sunk_art.dart';
import 'sunk_controller.dart';

const sunkGuide = [
  GuideStage(
    'dive',
    'Diving',
    'On your turn, dive (draw a card from the sea) or surface. Treasures go in your bag: coins 1–3, pearls 4–5, '
        'gems 6–7, the golden idol 8.',
    icon: Icons.scuba_diving_rounded,
  ),
  GuideStage(
    'sunk',
    'Sunk!',
    'Draw a treasure you already hold (a second 5, say) and you sink: your bag is lost for the round. A Spare Air '
        'tank saves you once. The more you hold, the likelier it gets: your air bar shows the chance.',
    icon: Icons.warning_rounded,
  ),
  GuideStage(
    'surface',
    'Surfacing',
    'Surface to bank your bag. A run of three in a row (4, 5, 6) adds 10. Six different treasures and you come up '
        'by yourself with 20 more: a full haul.',
    icon: Icons.arrow_upward_rounded,
  ),
  GuideStage(
    'specials',
    'Specials',
    'Boo! Captain Boo makes everyone else still diving draw a card at once. Hook: steal another diver\'s best '
        'treasure you haven\'t got. Cut Line: another diver\'s best treasure sinks back into the sea. Map: peek at '
        'the next card, then take it or pass (it stays on top for the next diver).',
    icon: Icons.auto_awesome_rounded,
  ),
  GuideStage(
    'end',
    'Winning',
    'A round ends when everyone\'s up (or sunk). Once someone has reached the target at the end of a round, the '
        'most treasure wins. The sea isn\'t reshuffled until it runs out, so remember what\'s gone.',
    icon: Icons.emoji_events_rounded,
  ),
];

/// Sunk against bots, or with your party.
class SunkScreen extends StatefulWidget {
  const SunkScreen({
    super.key,
    this.bots = 2,
    this.difficulty = Difficulty.normal,
    this.target = 120,
    this.pace = 1,
    this.seed,
    this.stake,
  }) : link = null;

  SunkScreen.online({super.key, required OnlineLink this.link, required StakeTicket this.stake})
    : bots = link.n - 1,
      difficulty = Difficulty.normal,
      target = link.state['target'] as int? ?? 120,
      pace = 1,
      seed = null;

  final OnlineLink? link;
  final int bots;
  final Difficulty difficulty;
  final int target;
  final double pace;
  final int? seed;
  final StakeTicket? stake;

  @override
  State<SunkScreen> createState() => _SunkScreenState();
}

class _SunkScreenState extends State<SunkScreen> with SingleTickerProviderStateMixin {
  late final Account _account = AccountScope.maybeRead(context) ?? Account();
  late StakeTicket _ticket =
      widget.stake ??
      StakeTicket(
        account: _account,
        gameId: 'sunk',
        stake: 0,
        opponents: widget.bots,
        difficulty: widget.difficulty,
      );
  late final SunkController _c = SunkController(
    bots: widget.bots,
    difficulty: widget.difficulty,
    target: widget.target,
    pace: widget.pace,
    rng: widget.seed == null ? null : Random(widget.seed),
    you: _account.persona,
    link: widget.link,
  )..addListener(_settle);

  /// The sea's slow loop (rays, weed, bubbles, the ghost's bob).
  late final AnimationController _sea = AnimationController(vsync: this, duration: const Duration(seconds: 7))
    ..repeat();

  void _settle() {
    if (_c.game.isOver && !_ticket.settled) {
      final w = _c.game.winners;
      _ticket.settle(!w.contains(0) ? Outcome.loss : (w.length == 1 ? Outcome.win : Outcome.tie));
    }
  }

  @override
  void dispose() {
    _sea.dispose();
    _c.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    final link = widget.link;
    if (link != null) return link.leave(context, _ticket, over: _c.game.isOver);
    if (_c.game.isOver || await confirmLeave(context, _ticket)) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  String? _stage() {
    final s = _c.showing;
    if (_c.game.isOver) return 'end';
    return switch (s) {
      SunkBusted() || SunkSaved() => 'sunk',
      SunkSurfaced() => 'surface',
      SunkBoo() || SunkHooked() || SunkCut() => 'specials',
      _ => _c.aiming || _c.charting ? 'specials' : 'dive',
    };
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
                  title: 'Sunk',
                  subtitle: widget.link != null
                      ? 'To ${_c.game.target} · round ${_c.game.round} · with your party${_c.yourTurn ? ' · ${widget.link!.secondsLeft}s' : ''}'
                      : 'To ${_c.game.target} · round ${_c.game.round} · ${widget.difficulty.label}',
                  onLeave: _leave,
                  ticket: _ticket,
                  guide: sunkGuide,
                  stage: _stage,
                ),
                commentary: CommentaryStrip(
                  text: _c.commentary(),
                  yourMove: _c.yourTurn,
                  leading: _Score(points: _c.game.scores[0]),
                ),
                table: _Table(c: _c, sea: _sea),
                controls: _Controls(c: _c),
              ),
              if (_c.game.isOver) Positioned.fill(child: _over(context)),
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
          : (won ? 'Treasure hunter!' : '${_c.personas[w.first].name} won'),
      subtitle: won
          ? 'You brought up ${g.scores[0]} in ${g.round} rounds.'
          : '${g.scores[w.first]} to your ${g.scores[0]}.',
      ticket: _ticket,
      won: won,
      onAgain: widget.link == null
          ? () {
              setState(() => _ticket = _ticket.again());
              _c.playAgain();
            }
          : widget.link!.rematch,
      againLabel: widget.link?.rematchLabel ?? 'Play again',
      leaveLabel: widget.link == null ? 'Back' : 'Back to party',
      onLeave: widget.link == null ? () => Navigator.of(context).pop() : _leave,
    );
  }
}

class _Score extends StatelessWidget {
  const _Score({required this.points});
  final int points;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 50),
    padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 5),
    decoration: Toon.box(Toon.cardFace, radius: 10, shadow: 0),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$points',
          style: Toon.text(20, weight: FontWeight.w700, color: Toon.inkLight),
        ),
        Text('score', style: Toon.text(10, color: Toon.inkLight)),
      ],
    ),
  );
}

class _Table extends StatelessWidget {
  const _Table({required this.c, required this.sea});

  final SunkController c;
  final Animation<double> sea;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final size = Size(box.maxWidth, box.maxHeight);
      final wide = GameLayout.wide(context);
      final others = [for (var p = 1; p < c.players; p++) p];
      final booSize = min(size.width * 0.26, size.height * 0.24).clamp(60.0, 130.0);
      final cardW = min(size.width * 0.24, size.height * 0.22).clamp(56.0, 100.0);
      // Captain Boo looks at whoever's turn it is.
      final turn = c.game.turn;
      final lookX = turn == 0 ? 0.0 : (others.indexOf(turn) / max(1, others.length - 1)) * 2 - 1;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: sea,
                builder: (context, _) =>
                    CustomPaint(painter: SeaPainter(sea.value), foregroundPainter: BubblesPainter(sea.value)),
              ),
            ),
          ),
          // The divers.
          Positioned(
            left: 8,
            right: 8,
            top: 8,
            child: Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: 6,
              runSpacing: 4,
              children: [for (final p in others) _Diver(c: c, p: p, compact: others.length > 3 || wide)],
            ),
          ),
          // Captain Boo, over the wreck.
          Positioned(
            right: size.width * 0.08,
            bottom: size.height * 0.2 + (wide ? 0 : 20),
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: sea,
                builder: (context, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 34,
                      child: c.ghostSays == null
                          ? null
                          : Pop(key: ValueKey('boo says ${c.ghostSaid}'), child: SpeechBubble(c.ghostSays!)),
                    ),
                    CaptainBoo(size: booSize, t: sea.value, mood: c.mood, lookX: lookX),
                  ],
                ),
              ),
            ),
          ),
          // The card rising from the wreck.
          if (c.reveal != null)
            Positioned(
              left: size.width * 0.12,
              top: size.height * (wide ? 0.32 : 0.36),
              child: TweenAnimationBuilder<double>(
                key: ValueKey('reveal ${c.reveals}'),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutBack,
                builder: (context, t, child) => Transform.translate(
                  offset: Offset(0, (1 - t) * size.height * 0.35),
                  child: Transform.rotate(
                    angle: (1 - t) * 0.5,
                    child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SunkCardView(
                      card: c.reveal,
                      width: cardW * (c.revealForced ? 0.8 : 1),
                      glow: c.reveal!.isTreasure && c.reveal!.value >= 7,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        c.revealFor == 0 ? 'Yours' : c.personas[c.revealFor!].name,
                        style: Toon.text(13, weight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // What just happened, big.
          if (c.showing != null)
            Positioned(
              left: 0,
              right: 0,
              top: size.height * 0.42,
              child: Center(child: _Banner(c: c)),
            ),
          // Your bag.
          Positioned(left: 8, right: 8, bottom: 8, child: _YourBag(c: c)),
        ],
      );
    },
  );
}

/// Someone else: their face in a diving helmet, what they've banked, what's
/// in their bag; up on the surface, sunk, or bubbling away below.
class _Diver extends StatelessWidget {
  const _Diver({required this.c, required this.p, required this.compact});

  final SunkController c;
  final int p;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    final st = g.state[p];
    final turn = g.turn == p && !g.isOver;
    final target = c.aiming && g.targets.contains(p);
    final said = c.speech[p];
    final ring = target ? Toon.red : (turn ? Deep.gold : null);
    final face = AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: st == SunkState.busted ? 0.45 : 1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          FaceRing(c.personas[p], size: compact ? 30 : 38, color: ring),
          // The helmet's glass.
          IgnorePointer(
            child: Container(
              width: compact ? 40 : 50,
              height: compact ? 40 : 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Deep.goldDark, width: 3),
                gradient: LinearGradient(
                  colors: [Colors.white.withValues(alpha: 0.28), Colors.transparent],
                  begin: Alignment.topLeft,
                  end: Alignment.center,
                ),
              ),
            ),
          ),
          if (c.thinking == p)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
    return GestureDetector(
      key: Key('diver $p'),
      onTap: target ? () => c.aim(p) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: target ? 0.35 : 0.22),
          borderRadius: BorderRadius.circular(14),
          border: target ? Border.all(color: Toon.red, width: 2.5) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                face,
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 70),
                      child: Text(
                        c.personas[p].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Toon.text(12, weight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                    Text(
                      '${g.scores[p]}',
                      style: Toon.text(15, weight: FontWeight.w700, color: Deep.gold),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 18,
              child: switch (st) {
                SunkState.surfaced => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_upward_rounded, size: 14, color: Deep.foam),
                    Text(
                      'up',
                      style: Toon.text(12, weight: FontWeight.w700, color: Deep.foam),
                    ),
                  ],
                ),
                SunkState.busted => Text(
                  'sunk',
                  style: Toon.text(12, weight: FontWeight.w700, color: const Color(0xFFFF9C9C)),
                ),
                SunkState.diving => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final card in g.bags[p])
                      Padding(
                        padding: const EdgeInsets.only(right: 1),
                        child: TreasureToken(card.value, size: 16),
                      ),
                    for (var i = 0; i < g.air[p]; i++)
                      const Icon(Icons.air_rounded, size: 15, color: Colors.white),
                    if (g.bags[p].isEmpty && g.air[p] == 0)
                      Text('diving', style: Toon.text(11, color: Colors.white60)),
                  ],
                ),
              },
            ),
            if (said != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SpeechBubble(said, key: ValueKey('say $p ${c.speechId}')),
              ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.c});
  final SunkController c;

  @override
  Widget build(BuildContext context) {
    final s = c.showing!;
    final (text, color) = switch (s) {
      SunkBusted(:final player) => (
        '${player == 0 ? 'YOU SANK' : '${c.personas[player].name.toUpperCase()} SANK'}!',
        Toon.red,
      ),
      SunkSaved() => ('SAVED BY AIR!', const Color(0xFFF5A524)),
      SunkSurfaced(:final points, :final haul) => (haul ? 'FULL HAUL! +$points' : '+$points', Toon.green),
      SunkBoo() => ('BOO!', Colors.white),
      SunkHooked() => ('HOOKED!', Toon.blue),
      SunkCut() => ('LINE CUT!', Toon.purple),
      SunkRoundOver() => ('ROUND ${c.game.round}', Deep.mid),
      _ => ('', Colors.transparent),
    };
    if (text.isEmpty) return const SizedBox.shrink();
    return Pop(
      key: ValueKey('banner ${c.shows}'),
      child: Transform.rotate(
        angle: -0.05,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: Toon.box(color, radius: 14, shadow: 3),
          child: Text(
            text,
            style: Toon.text(26, weight: FontWeight.w700, color: Toon.on(color)),
          ),
        ),
      ),
    );
  }
}

/// Your bag: big tokens (a run glows), your air tanks, how many kinds you
/// have toward a full haul.
class _YourBag extends StatelessWidget {
  const _YourBag({required this.c});
  final SunkController c;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    final bag = [...g.bags[0]]..sort((a, b) => a.value.compareTo(b.value));
    final vs = {for (final x in bag) x.value};
    final inRun = <int>{
      for (final v in vs)
        if ((vs.contains(v + 1) && vs.contains(v + 2)) ||
            (vs.contains(v - 1) && vs.contains(v + 1)) ||
            (vs.contains(v - 1) && vs.contains(v - 2)))
          v,
    };
    final st = g.state[0];
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: st != SunkState.diving
                ? Text(
                    st == SunkState.busted ? 'Sunk this round' : 'Up on the boat',
                    style: Toon.text(15, weight: FontWeight.w700, color: Colors.white70),
                  )
                : bag.isEmpty
                ? Text('Your bag is empty', style: Toon.text(14, color: Colors.white70))
                : Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final x in bag)
                        Pop(
                          key: ValueKey('mine ${x.value}'),
                          child: TreasureToken(x.value, size: 32, lit: inRun.contains(x.value)),
                        ),
                    ],
                  ),
          ),
          if (g.air[0] > 0) ...[
            const Icon(Icons.air_rounded, color: Colors.white),
            Text(
              '×${g.air[0]}',
              style: Toon.text(14, weight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(width: 6),
          ],
          if (st == SunkState.diving && bag.isNotEmpty)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${g.worth(0)}',
                  style: Toon.text(20, weight: FontWeight.w700, color: Deep.gold),
                ),
                Text('${vs.length}/$sunkHaulSize kinds', style: Toon.text(10, color: Colors.white70)),
              ],
            ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.c});
  final SunkController c;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    if (c.aiming) {
      final hook = g.pending == SunkKind.hook;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            hook ? 'Hook: whose treasure do you steal?' : 'Cut Line: whose treasure sinks?',
            style: Toon.text(15, weight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final q in g.targets)
                ToonButton(
                  key: Key('aim $q'),
                  color: hook ? Toon.blue : Toon.purple,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  onPressed: () => c.aim(q),
                  child: Text('${c.personas[q].name} (${g.bags[q].map((x) => x.value).reduce(max)})'),
                ),
            ],
          ),
        ],
      );
    }
    if (c.charting) {
      final peek = g.peeked;
      return Row(
        children: [
          if (peek != null) SunkCardView(card: peek, width: 44),
          const SizedBox(width: 8),
          Expanded(
            child: ToonButton(
              key: const Key('leave it'),
              color: Toon.card,
              padding: const EdgeInsets.symmetric(vertical: 12),
              onPressed: () => c.chart(take: false),
              child: const FittedBox(child: Text('Leave it', maxLines: 1)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ToonButton(
              key: const Key('take it'),
              color: Toon.green,
              padding: const EdgeInsets.symmetric(vertical: 12),
              onPressed: peek == null ? null : () => c.chart(take: true),
              child: const FittedBox(child: Text('Take it', maxLines: 1)),
            ),
          ),
        ],
      );
    }
    final risk = c.risk;
    final worth = g.worth(0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Your air: the chance the next card sinks you, as a tank running low.
        if (g.diving(0))
          Row(
            children: [
              const Icon(Icons.air_rounded, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: 1 - risk),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 10,
                      backgroundColor: Toon.card,
                      valueColor: AlwaysStoppedAnimation(Color.lerp(Toon.red, Toon.green, v)!),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 78,
                child: Text(
                  g.air[0] > 0 ? 'safe (tank)' : '${(risk * 100).round()}% to sink',
                  style: Toon.text(12, weight: FontWeight.w700, color: Toon.muted),
                ),
              ),
            ],
          ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: ToonButton(
                key: const Key('surface'),
                color: Deep.gold,
                padding: const EdgeInsets.symmetric(vertical: 12),
                onPressed: c.canDive && worth > 0 ? c.surface : null,
                child: FittedBox(child: Text(worth > 0 ? 'Surface +$worth' : 'Surface', maxLines: 1)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ToonButton(
                key: const Key('dive'),
                color: Deep.shallow,
                padding: const EdgeInsets.symmetric(vertical: 12),
                onPressed: c.canDive ? c.dive : null,
                child: const FittedBox(child: Text('Dive', maxLines: 1)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
