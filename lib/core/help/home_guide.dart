import 'package:flutter/material.dart';

import '../theme/split_page.dart';
import '../theme/toon.dart';

/// "Play at home": how to play a game with your own cards (or board),
/// written for someone who has never played it, or any card game.
class HomeGuide {
  const HomeGuide({required this.needs, required this.setup, required this.play, required this.win});

  /// What you need: the deck, how many players, anything else.
  final List<(IconData, String)> needs;
  final List<String> setup;
  final List<String> play;
  final List<String> win;

  List<List<String>> get parts => [setup, play, win];

  static const partNames = ['Setup', 'Gameplay', 'Winning'];
}

/// What a standard deck is, for guides that use one.
const standardDeck =
    'A standard deck of 52 playing cards. Take out the jokers. There are four suits (hearts, diamonds, clubs and '
    'spades), each running 2 to 10, then Jack, Queen, King and Ace.';

/// The follow-along screen: what you need, then Setup / Gameplay / Winning
/// step by step.
class HomeGuideScreen extends StatefulWidget {
  const HomeGuideScreen({super.key, required this.name, required this.color, required this.guide});

  final String name;
  final Color color;
  final HomeGuide guide;

  @override
  State<HomeGuideScreen> createState() => _HomeGuideScreenState();
}

class _HomeGuideScreenState extends State<HomeGuideScreen> {
  var _part = 0;

  /// Where the steps start: switching part scrolls back up to it.
  final _top = GlobalKey();

  void _show(int part) {
    setState(() => _part = part);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _top.currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.guide;
    final header = Row(
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
              Text('Play at home', style: Toon.text(24, weight: FontWeight.w700)),
              Text(
                '${widget.name} with your own cards',
                style: Toon.text(14, weight: FontWeight.w500, color: Toon.muted),
              ),
            ],
          ),
        ),
      ],
    );
    final needs = ToonBox(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      shadow: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What you need', style: Toon.text(17, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final (icon, text) in g.needs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: widget.color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(text, style: Toon.text(15, weight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    final tabs = Row(
      children: [
        for (final (i, name) in HomeGuide.partNames.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: ToonButton(
              key: Key('home ${name.toLowerCase()}'),
              color: _part == i ? Toon.yellow : Toon.card,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              onPressed: () => _show(i),
              child: FittedBox(child: Text('${i + 1}. $name', maxLines: 1)),
            ),
          ),
        ],
      ],
    );
    final steps = [
      for (final (i, step) in g.parts[_part].indexed)
        _Step(key: ValueKey('$_part-$i'), number: i + 1, text: step, color: widget.color, delay: i * 50),
      const SizedBox(height: 6),
      ToonButton(
        key: const Key('home next'),
        color: _part < 2 ? Toon.green : Toon.card,
        onPressed: () => _part < 2 ? _show(_part + 1) : Navigator.of(context).pop(),
        child: Text(_part < 2 ? 'Next: ${HomeGuide.partNames[_part + 1]}' : 'Done'),
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            // On its side: what you need and the tabs on the left, the
            // steps on the right.
            if (isLandscape(box.biggest)) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
                      children: [header, const SizedBox(height: 14), tabs, const SizedBox(height: 14), needs],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(8, 12, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(key: _top),
                          ...steps,
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }
            // Upright everything scrolls together; all of it is built so
            // switching part can scroll back up to the tabs.
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  const SizedBox(height: 14),
                  needs,
                  const SizedBox(height: 16),
                  SizedBox(key: _top),
                  tabs,
                  const SizedBox(height: 14),
                  ...steps,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One numbered step, sliding in.
class _Step extends StatelessWidget {
  const _Step({
    super.key,
    required this.number,
    required this.text,
    required this.color,
    required this.delay,
  });

  final int number;
  final String text;
  final Color color;
  final int delay;

  @override
  Widget build(BuildContext context) {
    final total = 260 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: Toon.box(color, radius: 15, shadow: 2),
              child: Text(
                '$number',
                style: Toon.text(15, weight: FontWeight.w700, color: Toon.on(color)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(text, style: Toon.text(16, weight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
