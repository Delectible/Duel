import 'package:flutter/material.dart';

import '../../core/account/account.dart';
import '../../core/account/stake.dart';
import '../../core/help/home_guide.dart';
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

  /// The game's preview choice (Spades: points to play to).
  late int? _choice = game.choice == null ? null : game.choice!.values[game.choice!.initial];

  @override
  Widget build(BuildContext context) {
    final setup = PlaySetupScope.of(context);
    final account = AccountScope.of(context);
    _stake = _stake.clamp(0, account.maxStake);
    final blocked = game.blocked(setup);
    // Time for this table if it fits, else for the nearest that does.
    var players = setup.players.clamp(game.minPlayers, game.maxPlayers);
    final counts = game.playerCounts;
    if (counts != null && !counts.contains(players)) {
      players = counts.reduce((a, b) => (a - players).abs() <= (b - players).abs() ? a : b);
    }
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
          child: Text(game.name, style: Toon.text(28, weight: FontWeight.w700)),
        ),
      ],
    );
    final chips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Chip(icon: Icons.groups_rounded, text: game.playersLabel),
        _Chip(
          icon: Icons.timer_outlined,
          text: 'About ${game.minutesFor(players, _choice)} min · $players players',
        ),
        // Follow along with your own cards.
        ToonButton(
          key: const Key('play at home'),
          color: Toon.yellow,
          radius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => HomeGuideScreen(name: game.name, color: game.color, guide: game.atHome),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.home_rounded, size: 18),
              const SizedBox(width: 6),
              Text('Play at home', style: Toon.text(14, color: Toon.inkLight)),
            ],
          ),
        ),
      ],
    );
    // Upright the board is 210 high; on its side it scales into the room.
    Widget board(double? height) => ToonBox(
      color: game.color,
      padding: const EdgeInsets.all(10),
      child: height != null
          ? SizedBox(height: height, child: game.board(context))
          : FittedBox(child: SizedBox(width: 360, height: 210, child: game.board(context))),
    );
    final rules = <Widget>[
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
    ];
    final bar = Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Toon.paper,
        border: Border(top: BorderSide(color: Toon.ink.withValues(alpha: 0.15), width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (game.choice != null) ...[
            _ChoicePicker(
              choice: game.choice!,
              value: _choice!,
              onChanged: (v) => setState(() => _choice = v),
            ),
            const SizedBox(height: 8),
          ],
          if (blocked == null) ...[
            _StakePicker(
              stake: _stake,
              account: account,
              opponents: game.opponents(setup.players),
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
                            opponents: game.opponents(setup.players),
                            difficulty: setup.difficulty,
                          );
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute<void>(builder: (_) => game.open!(setup, ticket, _choice)),
                          );
                        },
                  child: Text('Play!', style: Toon.text(20, weight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            // On its side: the name and sample board on the left, the rules
            // and Play! on the right.
            if (box.maxWidth > box.maxHeight * 1.15 && box.maxWidth >= 600) {
              return Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          header,
                          const SizedBox(height: 10),
                          chips,
                          const SizedBox(height: 12),
                          Expanded(child: board(null)),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView(padding: const EdgeInsets.fromLTRB(8, 12, 16, 12), children: rules),
                        ),
                        bar,
                      ],
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: [
                      header,
                      const SizedBox(height: 12),
                      chips,
                      const SizedBox(height: 14),
                      board(210),
                      const SizedBox(height: 14),
                      ...rules,
                    ],
                  ),
                ),
                bar,
              ],
            );
          },
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
/// "Play to: Quick 150 / Normal 250 / Long 500".
class _ChoicePicker extends StatelessWidget {
  const _ChoicePicker({required this.choice, required this.value, required this.onChanged});

  final GameChoice choice;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(Icons.flag_rounded, size: 20, color: Toon.fg),
      const SizedBox(width: 6),
      Text(choice.label, style: Toon.text(16, weight: FontWeight.w700)),
      const SizedBox(width: 10),
      for (final (i, v) in choice.values.indexed) ...[
        if (i > 0) const SizedBox(width: 6),
        Expanded(
          child: ToonButton(
            key: Key('choice $v'),
            color: v == value ? Toon.yellow : Toon.card,
            radius: 10,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            onPressed: () => onChanged(v),
            child: FittedBox(
              child: Text(
                '${choice.names[i]} $v',
                maxLines: 1,
                style: Toon.text(14, color: Toon.on(v == value ? Toon.yellow : Toon.card)),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

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
        // What this row is: your stake, what you have, and the rules.
        Row(
          children: [
            Icon(Icons.toll_rounded, size: 20, color: Toon.fg),
            const SizedBox(width: 6),
            Text('Your stake', style: Toon.text(16, weight: FontWeight.w700)),
            const SizedBox(width: 2),
            IconButton(
              key: const Key('stake info'),
              tooltip: 'How staking works',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () => showStakeRules(context),
              icon: Icon(Icons.info_outline_rounded, size: 20, color: Toon.muted),
            ),
            const Spacer(),
            Text(
              account.inDebt
                  ? 'Debt ${account.money(-account.balance)}'
                  : 'You have ${account.money(account.balance)}',
              style: Toon.text(13, weight: FontWeight.w600, color: account.inDebt ? Toon.red : Toon.muted),
            ),
          ],
        ),
        const SizedBox(height: 4),
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
