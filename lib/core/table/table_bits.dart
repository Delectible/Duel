import 'dart:math';

import 'package:flutter/material.dart';

import '../account/stake.dart';
import '../avatars/faces.dart';
import '../cards/card_view.dart';
import 'package:duel_engine/cards.dart';
import '../help/game_guide.dart';
import '../theme/toon.dart';

/// Pieces every game table uses: the top bar, the commentary strip, the
/// game-over card and a few animations.

/// Centres [child] on [at] inside a Stack.
class At extends StatelessWidget {
  const At(this.at, {super.key, required this.child});

  final Offset at;
  final Widget child;

  @override
  Widget build(BuildContext context) => Positioned(
    left: at.dx,
    top: at.dy,
    child: FractionalTranslation(translation: const Offset(-0.5, -0.5), child: child),
  );
}

/// Slides in from [from] (offset) and fades up, after [delay] ms.
class DealIn extends StatelessWidget {
  const DealIn({super.key, required this.child, this.delay = 0, this.from = const Offset(0, 120)});

  final Widget child;
  final int delay;
  final Offset from;

  @override
  Widget build(BuildContext context) {
    final total = 350 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Transform.translate(
        offset: from * (1 - t),
        child: Opacity(opacity: t, child: child),
      ),
      child: child,
    );
  }
}

/// Pops in with a bounce.
class Pop extends StatelessWidget {
  const Pop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 420),
    curve: Curves.elasticOut,
    builder: (context, t, child) => Transform.scale(scale: t, child: child),
    child: child,
  );
}

/// Cards flying from [from] to [to] (fanned a little), fading as they land.
class FlyingCards extends StatelessWidget {
  const FlyingCards({
    super.key,
    required this.from,
    required this.to,
    required this.cards,
    required this.width,
    this.faceUp = false,
  });

  final Offset from;
  final Offset to;
  final List<PlayingCard> cards;
  final double width;
  final bool faceUp;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 650),
    curve: Curves.easeInOutCubic,
    builder: (context, t, child) {
      final lift = sin(t * pi) * 40;
      return At(
        Offset.lerp(from, to, t)! - Offset(0, lift),
        child: Opacity(opacity: t < 0.85 ? 1 : (1 - t) / 0.15, child: child),
      );
    },
    child: IgnorePointer(
      child: SizedBox(
        width: width * (1 + 0.35 * (cards.length - 1)),
        height: width * 1.4,
        child: Stack(
          children: [
            for (final (i, c) in cards.indexed)
              Positioned(
                left: i * width * 0.35,
                child: Transform.rotate(
                  angle: (i - (cards.length - 1) / 2) * 0.12,
                  child: CardView(card: c, width: width, faceUp: faceUp),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// The felt every card table sits on.
class FeltPanel extends StatelessWidget {
  const FeltPanel({super.key});

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      decoration: BoxDecoration(
        color: Toon.felt,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Toon.wood, width: 10),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Toon.ink, width: 2.5),
      ),
    ),
  );
}

/// How a game screen sits: upright, the top bar, commentary, table and
/// controls stack top to bottom; on its side (landscape) the table fills
/// the left and the rest stacks in a panel on the right.
class GameLayout extends StatelessWidget {
  const GameLayout({
    super.key,
    required this.top,
    required this.commentary,
    required this.table,
    required this.controls,
    this.panelExtra,
  });

  final Widget top;
  final Widget commentary;
  final Widget table;
  final Widget controls;

  /// Landscape only: shown in the side panel between commentary and
  /// controls (e.g. who's playing).
  final Widget? panelExtra;

  /// Wide enough for the side panel?
  static bool isWide(Size size) => size.width > size.height * 1.15;

  /// Whether the game around [context] is laid out on its side.
  static bool wide(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Landscape>()?.wide ?? false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => _Landscape(wide: isWide(box.biggest), child: _layout(box)),
  );

  Widget _layout(BoxConstraints box) {
    {
      // Each part paints on its own layer: a ticking clock in the
      // controls or a line of commentary doesn't redraw the whole table.
      final table = RepaintBoundary(child: this.table);
      final top = RepaintBoundary(child: this.top);
      final commentary = RepaintBoundary(child: this.commentary);
      final controls = RepaintBoundary(child: this.controls);
      if (!isWide(box.biggest)) {
        return Column(
          children: [
            top,
            commentary,
            Expanded(child: table),
            controls,
          ],
        );
      }
      final panel = (box.maxWidth * 0.36).clamp(250.0, 340.0);
      return Row(
        children: [
          Expanded(
            child: Padding(padding: const EdgeInsets.only(bottom: 6), child: table),
          ),
          SizedBox(
            width: panel,
            child: SidePanel(
              child: Column(
                children: [
                  top,
                  commentary,
                  Expanded(
                    child: Align(alignment: Alignment.center, child: panelExtra ?? const SizedBox.shrink()),
                  ),
                  controls,
                ],
              ),
            ),
          ),
        ],
      );
    }
  }
}

class _Landscape extends InheritedWidget {
  const _Landscape({required this.wide, required super.child});

  final bool wide;

  @override
  bool updateShouldNotify(_Landscape old) => old.wide != wide;
}

/// Marks the landscape side panel, where the commentary gets an extra line.
class SidePanel extends InheritedWidget {
  const SidePanel({super.key, required super.child});

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SidePanel>() != null;

  @override
  bool updateShouldNotify(SidePanel old) => false;
}

/// Back, title + subtitle, stake, and the ? guide.
class GameTopBar extends StatelessWidget {
  const GameTopBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onLeave,
    required this.ticket,
    required this.guide,
    required this.stage,
  });

  final String title;
  final String subtitle;
  final VoidCallback onLeave;
  final StakeTicket ticket;
  final List<GuideStage> guide;
  final String? Function() stage;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: Row(
      children: [
        ToonButton(
          color: Toon.card,
          padding: const EdgeInsets.all(8),
          tooltip: 'Leave game',
          onPressed: onLeave,
          child: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Toon.text(18, weight: FontWeight.w700)),
              Text(
                subtitle,
                style: Toon.text(14, weight: FontWeight.w500, color: Toon.muted),
              ),
            ],
          ),
        ),
        StakeBadge(ticket),
        const SizedBox(width: 8),
        GuideButton(title: title, stages: guide, current: stage),
      ],
    ),
  );
}

/// What just happened and what you can do, in up to two lines. Yellow when
/// it's your move.
class CommentaryStrip extends StatelessWidget {
  const CommentaryStrip({super.key, required this.text, required this.yourMove, this.leading});

  final String text;
  final bool yourMove;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final bg = yourMove ? Toon.yellow : Toon.card;
    final lines = SidePanel.of(context) ? 3 : 2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: ToonBox(
        color: bg,
        shadow: 3,
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 8)],
            Expanded(
              child: SizedBox(
                height: lines * 17.0 + 6,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  layoutBuilder: (current, previous) {
                    // A line that comes back while an old copy still fades
                    // out would clash: show each line once.
                    final seen = <Key?>{current?.key};
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        for (final w in previous)
                          if (seen.add(w.key)) w,
                        ?current,
                      ],
                    );
                  },
                  child: Text(
                    text,
                    key: ValueKey(text),
                    maxLines: lines,
                    overflow: TextOverflow.ellipsis,
                    style: Toon.text(14, color: Toon.on(bg)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A speech bubble with a little tail, popping in.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Toon.cardFace;
    return Pop(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 170),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: Toon.box(bg, radius: 12, shadow: 2),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Toon.text(13, color: Toon.on(bg)),
          ),
        ),
      ),
    );
  }
}

/// Win / lose card over the table: the winner's face, the money, and Play
/// again / Games. Suits burst out when you win.
class GameOverCard extends StatelessWidget {
  const GameOverCard({
    super.key,
    required this.face,
    required this.title,
    required this.subtitle,
    required this.ticket,
    required this.won,
    required this.onAgain,
    required this.onLeave,
    this.againLabel = 'Play again',
    this.leaveLabel = 'Games',
  });

  final Persona face;
  final String title;
  final String subtitle;
  final StakeTicket ticket;
  final bool won;

  /// Null greys the button out (online: waiting for the others).
  final VoidCallback? onAgain;
  final VoidCallback onLeave;
  final String againLabel;
  final String leaveLabel;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Toon.ink.withValues(alpha: 0.55),
    child: Stack(
      children: [
        if (won) const Positioned.fill(child: IgnorePointer(child: SuitConfetti())),
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.7, end: 1),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            builder: (context, s, child) => Transform.scale(scale: s, child: child),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: ToonBox(
                  color: Toon.paper,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Face(face, size: 72),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Toon.text(28, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: Toon.text(16, weight: FontWeight.w500),
                      ),
                      const SizedBox(height: 10),
                      StakeResult(ticket),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ToonButton(
                              color: Toon.card,
                              key: const Key('over leave'),
                              onPressed: onLeave,
                              child: FittedBox(child: Text(leaveLabel, maxLines: 1)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ToonButton(
                              key: const Key('again'),
                              color: Toon.green,
                              onPressed: onAgain,
                              child: FittedBox(child: Text(againLabel, maxLines: 1)),
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

/// Suits bursting out from the middle.
class SuitConfetti extends StatelessWidget {
  const SuitConfetti({super.key});

  @override
  Widget build(BuildContext context) {
    final rng = Random(8);
    final bits = [
      for (var i = 0; i < 24; i++)
        (angle: rng.nextDouble() * 2 * pi, dist: 140 + rng.nextDouble() * 220, suit: Suit.values[i % 4]),
    ];
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1600),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => Stack(
        alignment: Alignment.center,
        children: [
          for (final b in bits)
            Transform.translate(
              offset: Offset(cos(b.angle), sin(b.angle)) * b.dist * t + Offset(0, 120 * t * t),
              child: Opacity(
                opacity: (1 - t).clamp(0, 1),
                child: Transform.rotate(angle: t * 4, child: SuitIcon(b.suit, size: 26)),
              ),
            ),
        ],
      ),
    );
  }
}
