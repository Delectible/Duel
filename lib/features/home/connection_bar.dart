import 'package:flutter/material.dart';

import 'package:duel_engine/difficulty.dart';
import '../../core/session/play_setup.dart';
import '../../core/theme/toon.dart';
import '../party/party_screen.dart';

/// Always at the top: who you're playing with. Bots (with their difficulty
/// and how many), or a friend (with your party).
class ConnectionBar extends StatelessWidget {
  const ConnectionBar({super.key});

  @override
  Widget build(BuildContext context) {
    final setup = PlaySetupScope.of(context);
    final bots = setup.mode == PlayMode.bots;
    return ToonBox(
      color: Toon.card,
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          _ModeSwitch(setup: setup),
          const SizedBox(width: 6),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: bots
                  ? Row(
                      key: const ValueKey('bots'),
                      children: [
                        Expanded(child: _DifficultyButton(setup: setup)),
                        const SizedBox(width: 6),
                        _BotCount(setup: setup),
                      ],
                    )
                  : ToonButton(
                      key: const ValueKey('party'),
                      color: Toon.purple,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      onPressed: () => Navigator.of(
                        context,
                      ).push(MaterialPageRoute<void>(builder: (_) => const PartyScreen())),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.groups_rounded, size: 22),
                          const SizedBox(width: 6),
                          Text('Party · ${setup.partySize}', style: Toon.text(16)),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bots | Friend.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.setup});

  final PlaySetup setup;

  @override
  Widget build(BuildContext context) {
    Widget option(PlayMode mode, IconData icon, String label) {
      final on = setup.mode == mode;
      return Semantics(
        selected: on,
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setup.mode = mode,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            decoration: BoxDecoration(
              color: on ? (mode == PlayMode.bots ? Toon.teal : Toon.purple) : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              border: on ? Border.all(color: Toon.ink, width: 2) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: on ? Toon.ink : Toon.muted),
                const SizedBox(width: 4),
                Text(label, style: Toon.text(15, color: on ? Toon.ink : Toon.muted)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Toon.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Toon.ink, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          option(PlayMode.bots, Icons.smart_toy_rounded, 'Bots'),
          option(PlayMode.friends, Icons.person_rounded, 'Friend'),
        ],
      ),
    );
  }
}

class _DifficultyButton extends StatelessWidget {
  const _DifficultyButton({required this.setup});

  final PlaySetup setup;

  static const _colors = {
    Difficulty.easy: Toon.green,
    Difficulty.normal: Toon.yellow,
    Difficulty.hard: Toon.red,
  };

  @override
  Widget build(BuildContext context) => ToonButton(
    color: _colors[setup.difficulty]!,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    tooltip: 'Bot difficulty',
    onPressed: () =>
        setup.difficulty = Difficulty.values[(setup.difficulty.index + 1) % Difficulty.values.length],
    child: FittedBox(child: Text(setup.difficulty.label, style: Toon.text(16))),
  );
}

/// − 3 bots +
class _BotCount extends StatelessWidget {
  const _BotCount({required this.setup});

  final PlaySetup setup;

  @override
  Widget build(BuildContext context) {
    final n = setup.botCount;
    Widget step(IconData icon, int to, String tip) => ToonButton(
      color: Toon.card,
      padding: const EdgeInsets.all(6),
      radius: 10,
      tooltip: tip,
      onPressed: to >= 1 && to <= PlaySetup.maxBots ? () => setup.botCount = to : null,
      child: Icon(icon, size: 18),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        step(Icons.remove_rounded, n - 1, 'Fewer bots'),
        SizedBox(
          width: 42,
          child: Column(
            children: [
              Text('$n', style: Toon.text(18, weight: FontWeight.w700)),
              Text(n == 1 ? 'bot' : 'bots', style: Toon.text(11, color: Toon.muted)),
            ],
          ),
        ),
        step(Icons.add_rounded, n + 1, 'More bots'),
      ],
    );
  }
}
