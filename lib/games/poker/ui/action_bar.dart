import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/toon.dart';
import '../engine/poker_hand.dart';
import 'poker_controller.dart';

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
        child: c.phase == TablePhase.shuffle
            ? _dealButton()
            : (c.yourTurn ? (_raising ? _raisePanel() : _buttons()) : _status()),
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
      text = '${c.personas[seat].name} is thinking…';
    } else if (c.handPlayer(0)?.folded ?? false) {
      text = 'You folded. Next hand soon…';
    } else {
      text = '';
    }
    return SizedBox(
      height: 60,
      child: Center(
        child: Text(text, style: Toon.text(17, color: Toon.muted)),
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
    return Row(
      children: [
        Expanded(
          child: ToonButton(
            key: const Key('fold'),
            color: Toon.red,
            onPressed: () => _act(const Move.fold()),
            child: const Text('Fold'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ToonButton(
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
        const SizedBox(width: 8),
        Expanded(
          child: ToonButton(
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
