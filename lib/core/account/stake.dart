import 'package:flutter/material.dart';

import '../session/difficulty.dart';
import '../theme/toon.dart';
import 'account.dart';

/// The staking rules, in plain words (the preview's (i) and Settings).
const stakeRules = [
  'Free games cost nothing and win nothing.',
  'Your stake is taken when the game starts.',
  'Win: you get your stake back plus stake × the number of opponents. '
      'Easy bots pay half of that, Hard bots one and a half times.',
  'A tie gives your stake back.',
  'Lose, or leave a game early, and the stake is gone.',
  'Out of money? You can always stake 1 on credit. It goes on your debt, '
      'which your winnings pay off first. No time limit.',
];

/// The rules as a bulleted list.
class StakeRules extends StatelessWidget {
  const StakeRules({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final rule in stakeRules)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 6, right: 10),
                decoration: BoxDecoration(
                  color: Toon.yellow,
                  shape: BoxShape.circle,
                  border: Border.all(color: Toon.ink, width: 2),
                ),
              ),
              Expanded(
                child: Text(rule, style: Toon.text(15, weight: FontWeight.w500)),
              ),
            ],
          ),
        ),
    ],
  );
}

/// "How staking works" as a sheet over the screen.
Future<void> showStakeRules(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  backgroundColor: Toon.paper,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        key: const Key('stake rules'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How staking works', style: Toon.text(24, weight: FontWeight.w700)),
          const SizedBox(height: 12),
          const StakeRules(),
        ],
      ),
    ),
  ),
);

/// One game's stake: taken when the game starts (Play! / Play again),
/// settled once when it ends, or lost if you leave early.
class StakeTicket {
  StakeTicket({
    required this.account,
    required this.gameId,
    required this.stake,
    required this.opponents,
    required this.difficulty,
  });

  final Account account;
  final String gameId;

  /// Already taken from the balance (0 = free play).
  final int stake;
  final int opponents;
  final Difficulty difficulty;

  /// The balance change once settled: +winnings, 0, or -stake.
  int? result;

  bool get settled => result != null;

  /// What a win would pay on top of the stake.
  int get winnings => Account.winnings(stake, opponents, difficulty);

  /// Settles once; later calls do nothing. Free games still count in stats.
  int settle(Outcome outcome) => result ??= account.settle(
    gameId: gameId,
    stake: stake,
    outcome: outcome,
    opponents: opponents,
    difficulty: difficulty,
  );

  /// Leaving before the end counts as a loss.
  void forfeit() {
    if (!settled) settle(Outcome.loss);
  }

  /// Another game at the same stake (capped at what you can stake now).
  StakeTicket again() => StakeTicket(
    account: account,
    gameId: gameId,
    stake: account.placeStake(stake),
    opponents: opponents,
    difficulty: difficulty,
  );
}

/// "Stake 10 pips" for a game's top bar.
class StakeBadge extends StatelessWidget {
  const StakeBadge(this.ticket, {super.key});

  final StakeTicket ticket;

  @override
  Widget build(BuildContext context) => ticket.stake == 0
      ? const SizedBox.shrink()
      : Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: Toon.box(Toon.yellow, radius: 10, shadow: 2),
          child: Text(
            'Stake ${ticket.account.money(ticket.stake)}',
            style: Toon.text(13, weight: FontWeight.w700, color: Toon.inkLight),
          ),
        );
}

/// The money line on a game-over card: "+45 pips", "−10 pips", "Free game".
class StakeResult extends StatelessWidget {
  const StakeResult(this.ticket, {super.key});

  final StakeTicket ticket;

  @override
  Widget build(BuildContext context) {
    final r = ticket.result ?? 0;
    final money = ticket.account.money(r.abs());
    final (text, color) = ticket.stake == 0
        ? ('Free game: no stake, no winnings', Toon.muted)
        : r > 0
        ? ('+$money', Toon.green)
        : r < 0
        ? ('−$money', Toon.red)
        : ('Stake back: ${ticket.account.money(ticket.stake)}', Toon.muted);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, s, child) => Transform.scale(scale: s, child: child),
      child: Text(
        text,
        key: const Key('stake result'),
        textAlign: TextAlign.center,
        style: Toon.text(ticket.stake == 0 ? 14 : 26, weight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// The leave-game question; with a stake it says what leaving costs.
Future<bool> confirmLeave(BuildContext context, StakeTicket ticket) async {
  final cost = ticket.stake > 0 && !ticket.settled
      ? "Leaving now counts as a loss: you'll lose your ${ticket.account.money(ticket.stake)} stake."
      : "This game won't count.";
  final leave = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: ToonBox(
        color: Toon.paper,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Leave the game?', style: Toon.text(22, weight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              cost,
              textAlign: TextAlign.center,
              style: Toon.text(16, weight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ToonButton(
                    key: const Key('stay'),
                    color: Toon.card,
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Stay'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ToonButton(
                    key: const Key('leave'),
                    color: Toon.red,
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Leave'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (leave == true) ticket.forfeit();
  return leave == true;
}
