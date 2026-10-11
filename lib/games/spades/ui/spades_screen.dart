import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/account/account.dart';
import '../../../core/account/stake.dart';
import '../../../core/cards/card_view.dart';
import '../../../core/help/game_guide.dart';
import '../../../core/session/difficulty.dart';
import '../../../core/table/table_bits.dart';
import '../engine/spades.dart';

/// How to play Spades, by stage (the ? button).
const spadesGuide = [
  GuideStage(
    'deal',
    'The deal',
    'Everyone gets 13 cards. With four players you sit opposite your partner and play as a team.',
    icon: Icons.style_rounded,
  ),
  GuideStage(
    'bid',
    'Bidding',
    'Look at your hand and bid how many tricks you think you can win. Your team adds its bids together.',
    icon: Icons.record_voice_over_rounded,
  ),
  GuideStage(
    'play',
    'Playing tricks',
    'Follow the suit that was led if you can. If you can\'t, play anything, including a spade. Spades always '
        'win: the highest spade takes the trick, otherwise the highest card of the suit led. You can\'t lead '
        'spades until one has been played.',
    icon: Icons.touch_app_rounded,
  ),
  GuideStage(
    'score',
    'Scoring',
    'Make your bid: 10 points per trick bid, plus 1 for each extra trick (a "bag"). Ten bags cost 100 '
        'points. Miss your bid and lose 10 per trick bid. First team to 500 wins.',
    icon: Icons.emoji_events_rounded,
  ),
];

/// Spades against bots: a blank template. It deals and shows your hand
/// on the table layout every game uses; bidding, play and bots are to come.
/// Not on the picker yet (its catalog entry has no `open`).
class SpadesScreen extends StatefulWidget {
  const SpadesScreen({super.key, required this.bots, required this.difficulty, this.seed, this.stake})
    : assert(bots == 1 || bots == 3);

  final int bots;
  final Difficulty difficulty;
  final int? seed;
  final StakeTicket? stake;

  @override
  State<SpadesScreen> createState() => _SpadesScreenState();
}

class _SpadesScreenState extends State<SpadesScreen> {
  late final Account _account = AccountScope.maybeRead(context) ?? Account();
  late final StakeTicket _ticket =
      widget.stake ??
      StakeTicket(
        account: _account,
        gameId: 'spades',
        stake: 0,
        opponents: widget.bots,
        difficulty: widget.difficulty,
      );
  late final Spades _game = Spades(
    players: widget.bots + 1,
    rng: widget.seed == null ? null : Random(widget.seed),
  );

  Future<void> _leave() async {
    if (await confirmLeave(context, _ticket)) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hand = [..._game.hands[0]]
      ..sort((a, b) => a.suit != b.suit ? a.suit.index.compareTo(b.suit.index) : a.rank.compareTo(b.rank));
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: SafeArea(
          child: GameLayout(
            top: GameTopBar(
              title: 'Spades',
              subtitle:
                  'You + ${widget.bots} ${widget.bots == 1 ? 'bot' : 'bots'} · ${widget.difficulty.label}',
              onLeave: _leave,
              ticket: _ticket,
              guide: spadesGuide,
              stage: () => 'deal',
            ),
            commentary: const CommentaryStrip(
              text: 'Spades is coming soon: this is your first hand.',
              yourMove: false,
            ),
            table: Stack(
              children: [
                const Positioned.fill(child: FeltPanel()),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final w = min(56.0, box.maxWidth / 9);
                      final step = min(w * 0.7, (box.maxWidth - 48 - w) / (hand.length - 1));
                      return SizedBox(
                        height: w * 1.4,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            for (final (i, c) in hand.indexed)
                              Transform.translate(
                                offset: Offset((i - (hand.length - 1) / 2) * step, 0),
                                child: CardView(card: c, width: w),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            controls: const SizedBox(height: 12),
          ),
        ),
      ),
    );
  }
}
