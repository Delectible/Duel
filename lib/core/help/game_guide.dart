import 'package:flutter/material.dart';

import '../theme/toon.dart';

/// One stage of a game, for the mid-game "How to play" sheet.
class GuideStage {
  const GuideStage(this.id, this.title, this.body, {this.icon = Icons.lightbulb_outline_rounded});

  final String id;
  final String title;
  final String body;
  final IconData icon;
}

/// The ? button every game has in its top bar.
class GuideButton extends StatelessWidget {
  const GuideButton({super.key, required this.title, required this.stages, required this.current});

  final String title;
  final List<GuideStage> stages;

  /// Id of the stage the player is in now (marked "You are here").
  final String? Function() current;

  @override
  Widget build(BuildContext context) => ToonButton(
    key: const Key('guide'),
    color: Toon.card,
    padding: const EdgeInsets.all(8),
    tooltip: 'How to play',
    onPressed: () => showGameGuide(context, title: title, stages: stages, current: current()),
    child: const Icon(Icons.help_outline_rounded),
  );
}

/// "How to play" by stage, with the stage you're in outlined and scrolled
/// to. The game keeps going underneath (bots don't wait), except where it
/// is waiting for you anyway.
Future<void> showGameGuide(
  BuildContext context, {
  required String title,
  required List<GuideStage> stages,
  String? current,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Toon.paper,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, scroll) => GameGuide(title: title, stages: stages, current: current, scroll: scroll),
    ),
  );
}

class GameGuide extends StatefulWidget {
  const GameGuide({super.key, required this.title, required this.stages, this.current, this.scroll});

  final String title;
  final List<GuideStage> stages;
  final String? current;
  final ScrollController? scroll;

  @override
  State<GameGuide> createState() => _GameGuideState();
}

class _GameGuideState extends State<GameGuide> {
  final _here = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _here.currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(ctx, alignment: 0.3, duration: const Duration(milliseconds: 300));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // The title stays put; the stages scroll to where you are.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How to play', style: Toon.text(26, weight: FontWeight.w700)),
              Text(
                widget.title,
                style: Toon.text(16, weight: FontWeight.w500, color: Toon.muted),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.scroll,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              for (final (i, s) in widget.stages.indexed)
                Padding(
                  key: s.id == widget.current ? _here : null,
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _Stage(number: i + 1, stage: s, here: s.id == widget.current),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({required this.number, required this.stage, required this.here});

  final int number;
  final GuideStage stage;
  final bool here;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Toon.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: here ? Toon.yellow : Toon.ink.withValues(alpha: 0.25),
          width: here ? 4 : 1.5,
        ),
        boxShadow: [if (here) BoxShadow(color: Toon.ink, spreadRadius: 1.5, offset: const Offset(0, 3))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: Toon.box(here ? Toon.yellow : Toon.paper, radius: 17, shadow: 0),
            child: Icon(stage.icon, size: 19, color: Toon.ink),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$number. ${stage.title}', style: Toon.text(17, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(stage.body, style: Toon.text(15, weight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
    if (!here) return box;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        box,
        Positioned(
          right: 10,
          top: -11,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: Toon.box(Toon.yellow, radius: 8, shadow: 2),
            child: Text(
              'You are here',
              style: Toon.text(13, weight: FontWeight.w700, color: Toon.inkLight),
            ),
          ),
        ),
      ],
    );
  }
}
