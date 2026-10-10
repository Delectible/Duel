import 'package:flutter/material.dart';

import '../../core/session/play_setup.dart';
import '../../core/theme/toon.dart';
import '../../games/catalog.dart';

/// What you see when you tap a game: the basics, how long it takes for
/// your table, a sample board, then Play! or Nevermind.
///
/// Only Play! counts. Until then it's a look: in a party it doesn't vote,
/// pick the game or start a coin toss.
class GamePreviewScreen extends StatelessWidget {
  const GamePreviewScreen({super.key, required this.game});

  final GameInfo game;

  @override
  Widget build(BuildContext context) {
    final setup = PlaySetupScope.of(context);
    final blocked = game.blocked(setup);
    // Time for this table if it fits, else for the smallest that does.
    final players = setup.players.clamp(game.minPlayers, game.maxPlayers);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                        child: Text(game.name, style: Toon.text(28, weight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Chip(icon: Icons.groups_rounded, text: game.playersLabel),
                      _Chip(
                        icon: Icons.timer_outlined,
                        text: 'About ${game.minutes(players)} min · $players players',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ToonBox(
                    color: game.color,
                    padding: const EdgeInsets.all(10),
                    child: SizedBox(height: 210, child: game.board(context)),
                  ),
                  const SizedBox(height: 14),
                  Text('How to play', style: Toon.text(20, weight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  for (final rule in game.rules)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(top: 6, right: 10),
                            decoration: BoxDecoration(
                              color: game.color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Toon.ink, width: 2),
                            ),
                          ),
                          Expanded(
                            child: Text(rule, style: Toon.text(16, weight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                color: Toon.paper,
                border: Border(top: BorderSide(color: Toon.ink.withValues(alpha: 0.15), width: 2)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (blocked != null) ...[
                    Text(
                      blocked.$2,
                      textAlign: TextAlign.center,
                      style: Toon.text(15, weight: FontWeight.w500, color: Toon.muted),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: ToonButton(
                          key: const Key('nevermind'),
                          color: Toon.card,
                          onPressed: () => Navigator.of(context).pop(),
                          child: const FittedBox(child: Text('Nevermind', maxLines: 1)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ToonButton(
                          key: const Key('play'),
                          color: Toon.green,
                          // Play! is the only thing that counts: it starts the game
                          // here, and will be your vote / pick in a party.
                          onPressed: blocked != null
                              ? null
                              : () => Navigator.of(
                                  context,
                                ).pushReplacement(MaterialPageRoute<void>(builder: (_) => game.open!(setup))),
                          child: Text('Play!', style: Toon.text(20, weight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: Toon.box(Toon.card, radius: 12, shadow: 2),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Toon.ink),
        const SizedBox(width: 6),
        Text(text, style: Toon.text(14)),
      ],
    ),
  );
}
