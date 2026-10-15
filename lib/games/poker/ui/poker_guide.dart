import 'package:flutter/material.dart';

import '../../../core/help/game_guide.dart';
import 'package:duel_engine/poker/poker_hand.dart';
import 'poker_controller.dart';

/// Stages of a Texas Hold'em hand for the "How to play" sheet.
const pokerGuide = [
  GuideStage(
    'deal',
    'The deal and the blinds',
    'The dealer button (D) moves one seat each hand. The two players after it put in the blinds, small '
        'forced bets so there is something to win. When the button reaches you, shuffle and deal.',
    icon: Icons.style_rounded,
  ),
  GuideStage(
    'preflop',
    'Before the flop',
    'You get two cards only you can see. Fold to give up the hand, Call to match the bet, or Raise to bet '
        'more. Good starting cards: pairs, two high cards, cards of the same suit.',
    icon: Icons.front_hand_rounded,
  ),
  GuideStage(
    'board',
    'Flop, turn and river',
    'Shared cards come out in the middle: three (the flop), then one (the turn), then one (the river), with '
        'a betting round after each. Your hand is your best five of the seven; tap its name for the chart. '
        'If nobody has bet you can Check (bet nothing).',
    icon: Icons.view_carousel_rounded,
  ),
  GuideStage(
    'raise',
    'Betting tools',
    'Raise… opens the panel: − and + change it by a big blind (hold to repeat); Min, ½ Pot, Pot and All-in '
        'jump to common sizes. All-in puts every chip in; you can only win as much as you put in from each '
        'player (side pots).',
    icon: Icons.casino_rounded,
  ),
  GuideStage(
    'showdown',
    'Showdown',
    'Hands still in at the end are turned over. The best five-card hand wins the pot; equal hands split it. '
        'If everyone else folds, the last player wins without showing. Tap Next hand when you have read it.',
    icon: Icons.visibility_rounded,
  ),
  GuideStage(
    'end',
    'Winning the Sit & Go',
    'The blinds go up every few hands (the top bar shows when), so stacks keep moving. Lose all your chips '
        "and you're out; the last player with chips wins.",
    icon: Icons.emoji_events_rounded,
  ),
];

/// Which stage the table is in, for "You are here".
String? pokerStage(PokerController c) {
  switch (c.phase) {
    case TablePhase.shuffle:
      return 'deal';
    case TablePhase.finished:
      return 'end';
    case TablePhase.payout:
      return 'showdown';
    case TablePhase.dealing || TablePhase.acting || TablePhase.collecting:
      final h = c.hand;
      if (h == null) return 'deal';
      return h.street == Street.preflop ? 'preflop' : 'board';
  }
}
