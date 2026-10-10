import 'package:flutter/material.dart';

import '../../core/account/account.dart';
import '../../core/account/stake.dart';
import '../../core/session/difficulty.dart';
import '../../core/session/play_setup.dart';
import '../../core/theme/toon.dart';
import '../../games/catalog.dart';

/// What you see when you tap a game: the basics, how long it takes for
/// your table, a sample board, then Play! or Nevermind.
///
/// Only Play! counts. Until then it's a look: in a party it doesn't vote,
/// pick the game or start a coin toss.
class GamePreviewScreen extends StatefulWidget {
  const GamePreviewScreen({super.key, required this.game});

  final GameInfo game;

  @override
  State<GamePreviewScreen> createState() => _GamePreviewScreenState();
}

class _GamePreviewScreenState extends State<GamePreviewScreen> {
  /// 0 = free play.
  var _stake = 0;

  GameInfo get game => widget.game;

  @override
  Widget build(BuildContext context) {
    final setup = PlaySetupScope.of(context);
    final account = AccountScope.of(context);
    _stake = _stake.clamp(0, account.maxStake);
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
                  if (blocked == null) ...[
                    _StakePicker(
                      stake: _stake,
                      account: account,
                      opponents: setup.players - 1,
                      difficulty: setup.difficulty,
                      onChanged: (v) => setState(() => _stake = v),
                    ),
                    const SizedBox(height: 10),
                  ],
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
                              : () {
                                  // The stake is taken now; the game settles it.
                                  final ticket = StakeTicket(
                                    account: account,
                                    gameId: game.id,
                                    stake: account.placeStake(_stake),
                                    opponents: setup.players - 1,
                                    difficulty: setup.difficulty,
                                  );
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute<void>(builder: (_) => game.open!(setup, ticket)),
                                  );
                                },
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

/// Free, or a stake: quick amounts and − / +, with what a win pays.
class _StakePicker extends StatelessWidget {
  const _StakePicker({
    required this.stake,
    required this.account,
    required this.opponents,
    required this.difficulty,
    required this.onChanged,
  });

  final int stake;
  final Account account;
  final int opponents;
  final Difficulty difficulty;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final max = account.maxStake;
    final broke = account.balance <= 0;
    final step = stake < 10 ? 1 : (stake < 50 ? 5 : 10);
    final win = Account.winnings(stake, opponents, difficulty);
    Widget quick(String label, int value, Key key) => Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ToonButton(
        key: key,
        color: stake == value ? Toon.yellow : Toon.card,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        radius: 10,
        onPressed: value <= max ? () => onChanged(value) : null,
        child: Text(label, style: Toon.text(14, color: Toon.on(stake == value ? Toon.yellow : Toon.card))),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            quick('Free', 0, const Key('stake free')),
            if (!broke) ...[
              if (max >= 10) quick('10', 10, const Key('stake 10')),
              quick('Max', max, const Key('stake max')),
            ] else
              quick('1 on credit', 1, const Key('stake 1')),
            const Spacer(),
            if (!broke) ...[
              ToonButton(
                key: const Key('stake minus'),
                color: Toon.card,
                padding: const EdgeInsets.all(6),
                radius: 10,
                repeat: true,
                onPressed: stake > 0 ? () => onChanged((stake - step).clamp(0, max)) : null,
                child: const Icon(Icons.remove_rounded, size: 18),
              ),
              const SizedBox(width: 6),
              ToonButton(
                key: const Key('stake plus'),
                color: Toon.card,
                padding: const EdgeInsets.all(6),
                radius: 10,
                repeat: true,
                onPressed: stake < max ? () => onChanged((stake + step).clamp(0, max)) : null,
                child: const Icon(Icons.add_rounded, size: 18),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          stake == 0
              ? (broke
                    ? "You're out of money: play free, or stake 1 on credit (it adds to your debt)."
                    : 'Free game: nothing to lose, nothing to win.')
              : 'Stake ${account.money(stake)}: win +${account.money(win)}, lose −${account.money(stake)}'
                    '${difficulty == Difficulty.normal ? '' : ' (${difficulty.label} bots pay ${difficulty == Difficulty.easy ? 'half' : '1.5×'})'}',
          key: const Key('stake line'),
          textAlign: TextAlign.center,
          style: Toon.text(14, weight: FontWeight.w600, color: stake == 0 ? Toon.muted : Toon.fg),
        ),
      ],
    );
  }
}
