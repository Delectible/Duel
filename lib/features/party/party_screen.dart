import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/session/play_setup.dart';
import '../../core/theme/toon.dart';
import '../../games/catalog.dart';
import '../../core/account/account.dart';
import '../../core/avatars/faces.dart';
import 'coin_toss.dart';
import 'vote.dart';

/// Who's in your party and how it picks games. Online play isn't built
/// yet: for now it's just you.
class PartyScreen extends StatelessWidget {
  const PartyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final setup = PlaySetupScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
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
                Text('Your party', style: Toon.text(26, weight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            ToonBox(
              child: Row(
                children: [
                  Face(AccountScope.of(context).persona, size: 48),
                  const SizedBox(width: 12),
                  Expanded(child: Text('You', style: Toon.text(18))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: Toon.box(Toon.yellow, radius: 8, shadow: 2),
                    child: Text('Host', style: Toon.text(13, color: Toon.inkLight)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ToonButton(
              color: Toon.purple,
              padding: const EdgeInsets.all(14),
              onPressed: () => ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Inviting friends is coming soon.'))),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Icon(Icons.person_add_rounded), SizedBox(width: 8), Text('Invite a friend')],
              ),
            ),
            const SizedBox(height: 24),
            Text('Who picks the game', style: Toon.text(18)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final rule in PickRule.values) ...[
                  if (rule != PickRule.values.first) const SizedBox(width: 6),
                  Expanded(
                    child: ToonButton(
                      color: setup.pickRule == rule ? Toon.yellow : Toon.card,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      onPressed: () => setup.pickRule = rule,
                      child: FittedBox(child: Text(rule.label, style: Toon.text(15))),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(switch (setup.pickRule) {
              PickRule.host => 'The host chooses; everyone else follows along.',
              PickRule.vote => 'Everyone votes; the game with the most votes starts.',
              PickRule.firstCome => 'Whoever taps a game first starts it.',
            }, style: Toon.text(15, weight: FontWeight.w500, color: Toon.muted)),
            if (setup.pickRule == PickRule.vote) ...[
              const SizedBox(height: 4),
              Text(
                'A tie is settled by a coin toss.',
                style: Toon.text(15, weight: FontWeight.w500, color: Toon.muted),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: ToonButton(
                  key: const Key('try coin'),
                  color: Toon.yellow,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  onPressed: () {
                    // A pretend 1-1 vote between the first two games.
                    final tied = [games[0], games[1]];
                    showCoinToss(
                      context,
                      heads: tied[0],
                      tails: tied[1],
                      winner: tossCoin([for (final g in tied) g.id], Random()),
                    );
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.monetization_on_rounded),
                      SizedBox(width: 6),
                      Text('Try the coin toss'),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ToonBox(
              color: Toon.paper,
              shadow: 0,
              child: Text(
                'Online play is on the way: invite a friend once, then hop from '
                'game to game together without reconnecting.',
                style: Toon.text(15, weight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
