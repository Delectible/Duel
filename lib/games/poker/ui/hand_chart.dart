import 'package:flutter/material.dart';

import '../../../core/cards/card_view.dart';
import '../../../core/cards/cards.dart';
import '../../../core/theme/toon.dart';
import '../engine/hand_eval.dart';

/// One row of the cheat sheet.
class HandRankInfo {
  const HandRankInfo(this.name, this.how, this.example, this.category, {this.royal = false});

  final String name;
  final String how;
  final String example;
  final HandCategory category;
  final bool royal;
}

/// Best first.
const handRanks = [
  HandRankInfo(
    'Royal flush',
    'A K Q J 10, all one suit',
    'As Ks Qs Js Ts',
    HandCategory.straightFlush,
    royal: true,
  ),
  HandRankInfo('Straight flush', 'Five in a row, all one suit', '9h 8h 7h 6h 5h', HandCategory.straightFlush),
  HandRankInfo('Four of a kind', 'Four cards of one rank', 'Qc Qd Qh Qs 7d', HandCategory.quads),
  HandRankInfo('Full house', 'Three of a kind plus a pair', 'Ks Kh Kd 4c 4s', HandCategory.fullHouse),
  HandRankInfo('Flush', 'Any five of one suit', 'Ad Jd 8d 5d 2d', HandCategory.flush),
  HandRankInfo('Straight', 'Five in a row, any suits', 'Tc 9d 8s 7h 6c', HandCategory.straight),
  HandRankInfo('Three of a kind', 'Three cards of one rank', '7s 7h 7d Kc 2s', HandCategory.trips),
  HandRankInfo('Two pair', 'Two different pairs', 'Jh Jc 4d 4s Ah', HandCategory.twoPair),
  HandRankInfo('Pair', 'Two cards of one rank', 'Ts Th Kd 6c 3h', HandCategory.pair),
  HandRankInfo('High card', 'None of the above: highest card plays', 'Ac Jd 8h 5s 2c', HandCategory.highCard),
];

/// The cheat sheet of poker hands, best to worst. With [category], that row
/// is outlined ("You") and scrolled into view, and [cards] (your best five,
/// or your two cards before the flop) are shown on top with [name].
Future<void> showHandChart(
  BuildContext context, {
  HandCategory? category,
  bool royal = false,
  List<PlayingCard> cards = const [],
  String? name,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Toon.paper,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, scroll) =>
          HandChart(scroll: scroll, category: category, royal: royal, cards: cards, name: name),
    ),
  );
}

class HandChart extends StatefulWidget {
  const HandChart({
    super.key,
    this.scroll,
    this.category,
    this.royal = false,
    this.cards = const [],
    this.name,
  });

  final ScrollController? scroll;
  final HandCategory? category;
  final bool royal;
  final List<PlayingCard> cards;
  final String? name;

  @override
  State<HandChart> createState() => _HandChartState();
}

class _HandChartState extends State<HandChart> {
  final _yours = GlobalKey();

  int? get _yourRow {
    final c = widget.category;
    if (c == null) return null;
    return handRanks.indexWhere((r) => r.category == c && r.royal == widget.royal);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _yours.currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(ctx, alignment: 0.4, duration: const Duration(milliseconds: 300));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final yours = _yourRow;
    final preflop = widget.cards.length == 2;
    // Title and your hand stay put; the list of hands scrolls to yours.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Poker hands', style: Toon.text(26, weight: FontWeight.w700)),
              Text(
                'Best at the top. Your best five cards count.',
                style: Toon.text(15, weight: FontWeight.w500, color: Toon.muted),
              ),
              if (widget.name != null && widget.cards.isNotEmpty) ...[
                const SizedBox(height: 10),
                ToonBox(
                  color: Toon.yellow,
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('You have', style: Toon.text(13, color: Toon.ink.withValues(alpha: 0.7))),
                            Text(widget.name!, style: Toon.text(18, weight: FontWeight.w700)),
                            if (preflop)
                              Text(
                                'Just your two cards so far: the flop adds three more.',
                                style: Toon.text(12, weight: FontWeight.w500),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _CardRow(widget.cards, width: preflop ? 36 : 28),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.scroll,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              for (final (i, r) in handRanks.indexed)
                Padding(
                  key: i == yours ? _yours : null,
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RankRow(rank: i + 1, info: r, yours: i == yours),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.info, required this.yours});

  final int rank;
  final HandRankInfo info;
  final bool yours;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: yours ? Toon.card : Toon.card.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: yours ? Toon.yellow : Toon.ink.withValues(alpha: 0.25),
          width: yours ? 4 : 1.5,
        ),
        boxShadow: [if (yours) BoxShadow(color: Toon.ink, spreadRadius: 1.5, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text('$rank', style: Toon.text(16, color: Toon.muted)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.name, style: Toon.text(16, weight: FontWeight.w700)),
                Text(
                  info.how,
                  style: Toon.text(12, weight: FontWeight.w500, color: Toon.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _CardRow(PlayingCard.parseAll(info.example), width: 25),
        ],
      ),
    );
    if (!yours) return row;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        row,
        Positioned(
          right: 8,
          top: -10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: Toon.box(Toon.yellow, radius: 8, shadow: 2),
            child: Text(
              'You',
              style: Toon.text(13, weight: FontWeight.w700, color: Toon.inkLight),
            ),
          ),
        ),
      ],
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow(this.cards, {required this.width});

  final List<PlayingCard> cards;
  final double width;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (i, c) in cards.indexed)
        Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : width * 0.12),
          child: CardView(card: c, width: width),
        ),
    ],
  );
}
