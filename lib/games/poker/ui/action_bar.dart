import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/table/table_bits.dart';
import '../../../core/theme/toon.dart';
import 'package:duel_engine/poker/poker_hand.dart';
import '../../../core/account/account.dart';
import 'poker_controller.dart';
import 'table_stats.dart';

/// Fold / Check or Call / Raise, with a raise panel: − and + in big-blind
/// steps (hold to repeat), and Min, ½ Pot, Pot, All-in.
class ActionBar extends StatefulWidget {
  const ActionBar({super.key, required this.c});

  final PokerController c;

  @override
  State<ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends State<ActionBar> {
  var _raising = false;
  var _amount = 0;
  var _turnSeen = false;

  PokerController get c => widget.c;

  @override
  void initState() {
    super.initState();
    _syncTurn();
  }

  @override
  void didUpdateWidget(ActionBar old) {
    super.didUpdateWidget(old);
    _syncTurn();
  }

  /// A fresh turn starts with the raise panel shut at the minimum.
  void _syncTurn() {
    if (c.yourTurn && !_turnSeen) {
      _turnSeen = true;
      _raising = false;
      _amount = c.hand!.legalMoves().minRaiseTo;
      HapticFeedback.mediumImpact();
    } else if (!c.yourTurn) {
      _turnSeen = false;
    }
  }

  void _act(Move m) {
    setState(() => _raising = false);
    c.act(m);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: c.waitingForYou
            ? _nextHandButton()
            : c.phase == TablePhase.shuffle
            ? _dealButton()
            : (c.yourTurn ? (_raising ? _raisePanel() : _buttons()) : _status()),
      ),
    );
  }

  /// After a showdown: the table waits for this (online: counts down).
  Widget _nextHandButton() {
    final left = c.secondsLeft;
    // You're out, or someone has every chip: the results come next.
    final me = c.handPlayer(0);
    final last = (me != null && me.stack == 0) || c.hand!.players.where((p) => p.stack > 0).length <= 1;
    return SizedBox(
      height: 60,
      child: ToonButton(
        key: const Key('next hand'),
        color: Toon.green,
        onPressed: c.nextHand,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(last ? 'Continue' : 'Next hand', style: Toon.text(18, weight: FontWeight.w700)),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_rounded),
            if (left != null) ...[
              const SizedBox(width: 10),
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: Toon.box(Toon.card, radius: 15, shadow: 0),
                child: Text('$left', style: Toon.text(15, weight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Your deal: Deal lights up once you've shuffled.
  Widget _dealButton() => SizedBox(
    height: 60,
    child: ToonButton(
      key: const Key('deal'),
      color: Toon.green,
      onPressed: c.shuffles > 0 ? c.deal : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.style_rounded),
          const SizedBox(width: 8),
          Text(c.shuffles > 0 ? 'Deal' : 'Shuffle first', style: Toon.text(18, weight: FontWeight.w700)),
        ],
      ),
    ),
  );

  Widget _status() {
    String text;
    final seat = c.actingSeat;
    if (c.phase == TablePhase.finished) {
      text = '';
    } else if (seat != null) {
      final left = c.turnSecondsLeft;
      text = c.hurrying
          ? 'Hurrying the bots along…'
          : '${c.personas[seat].name} is thinking…${left == null ? '' : ' ${left}s'}';
    } else if (c.handPlayer(0)?.folded ?? false) {
      text = 'You folded. Next hand soon…';
    } else {
      text = '';
    }
    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: Toon.text(17, color: Toon.muted),
            ),
          ),
          // Bots take their time; this hurries them along.
          if (c.canHurry) ...[
            const SizedBox(width: 10),
            ToonButton(
              key: const Key('hurry'),
              color: Toon.yellow,
              radius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              tooltip: 'Hurry the bots up',
              onPressed: c.hurry,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.fast_forward_rounded, size: 20),
                  const SizedBox(width: 4),
                  Text('Skip', style: Toon.text(15, weight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buttons() {
    final h = c.hand!;
    final legal = h.legalMoves();
    final me = c.handPlayer(0)!;
    final callAll = !legal.canCheck && legal.callAmount >= me.stack;
    final onlyAllIn = legal.canRaise && legal.minRaiseTo >= legal.maxRaiseTo;
    final raiseWord = legal.isBet ? 'Bet' : 'Raise';
    // In the landscape side panel the three stack, under your thumb.
    final stacked = SidePanel.of(context);
    Widget slot(Widget b) => stacked ? b : Expanded(child: b);
    final gap = stacked ? const SizedBox(height: 8) : const SizedBox(width: 8);
    final buttons = [
      slot(
        ToonButton(
          key: const Key('fold'),
          color: Toon.red,
          onPressed: () => _act(const Move.fold()),
          child: const Text('Fold'),
        ),
      ),
      gap,
      slot(
        ToonButton(
          key: const Key('call'),
          color: legal.canCheck ? Toon.blue : Toon.green,
          onPressed: () => _act(legal.canCheck ? const Move.check() : const Move.call()),
          child: Text(
            legal.canCheck
                ? 'Check'
                : (callAll ? 'All-in ${chips(legal.callAmount)}' : 'Call ${chips(legal.callAmount)}'),
            maxLines: 1,
          ),
        ),
      ),
      gap,
      slot(
        ToonButton(
          key: const Key('raise'),
          color: Toon.orange,
          onPressed: !legal.canRaise
              ? null
              : onlyAllIn
              ? () => _act(Move.raiseTo(legal.maxRaiseTo))
              : () => setState(() {
                  _raising = true;
                  _amount = _amount.clamp(legal.minRaiseTo, legal.maxRaiseTo);
                }),
          child: Text(onlyAllIn ? 'All-in' : '$raiseWord…', maxLines: 1),
        ),
      ),
    ];
    final row = stacked
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: buttons.reversed.toList())
        : Row(children: buttons);
    final odds = (AccountScope.maybeRead(context)?.pokerOdds ?? true) ? oddsLine(c) : null;
    if (odds == null) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            odds,
            key: const Key('odds'),
            textAlign: TextAlign.center,
            style: Toon.text(13, weight: FontWeight.w600, color: Toon.muted),
          ),
        ),
        row,
      ],
    );
  }

  Widget _raisePanel() {
    final h = c.hand!;
    final legal = h.legalMoves();
    final bb = h.bigBlind;
    int clampTo(num v) => v.round().clamp(legal.minRaiseTo, legal.maxRaiseTo);
    // Pot-sized raise: call, then raise by the pot after the call.
    int potFraction(double f) {
      final to = h.currentBet + f * (h.pot + legal.callAmount);
      return clampTo((to / h.smallBlind).round() * h.smallBlind);
    }

    void set(int v) => setState(() => _amount = clampTo(v));
    final allIn = _amount >= legal.maxRaiseTo;
    final word = legal.isBet ? 'Bet' : 'Raise to';

    Widget quick(String label, int value) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: ToonButton(
          key: Key('quick $label'),
          color: _amount == value ? Toon.yellow : Toon.card,
          padding: const EdgeInsets.symmetric(vertical: 8),
          onPressed: () => set(value),
          child: Text(label, style: Toon.text(14), maxLines: 1),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            ToonButton(
              repeat: true,
              color: Toon.card,
              onPressed: _amount > legal.minRaiseTo ? () => set(_amount - bb) : null,
              child: const Icon(Icons.remove_rounded, size: 26),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(allIn ? 'All-in' : word, style: Toon.text(14, color: Toon.muted)),
                  Text(chips(_amount), style: Toon.text(30, weight: FontWeight.w700)),
                ],
              ),
            ),
            ToonButton(
              repeat: true,
              color: Toon.card,
              onPressed: _amount < legal.maxRaiseTo ? () => set(_amount + bb) : null,
              child: const Icon(Icons.add_rounded, size: 26),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            quick('Min', legal.minRaiseTo),
            quick('½ Pot', potFraction(0.5)),
            quick('Pot', potFraction(1)),
            quick('All-in', legal.maxRaiseTo),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            ToonButton(
              color: Toon.card,
              onPressed: () => setState(() => _raising = false),
              child: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ToonButton(
                key: const Key('confirm raise'),
                color: allIn ? Toon.red : Toon.orange,
                onPressed: () => _act(Move.raiseTo(_amount)),
                child: Text(allIn ? 'All-in ${chips(_amount)}' : '$word ${chips(_amount)}'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
