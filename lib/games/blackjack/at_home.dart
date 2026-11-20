import 'package:flutter/material.dart';

import '../../core/help/home_guide.dart';

/// Blackjack (21) with a real deck.
const blackjackAtHome = HomeGuide(
  needs: [
    (Icons.style_rounded, standardDeck),
    (Icons.groups_rounded, '2 or more players: one is the dealer, everyone else plays against the dealer.'),
    (
      Icons.toll_rounded,
      'Something to bet with: chips, coins, sweets or matchsticks. Give everyone the same.',
    ),
  ],
  setup: [
    'Pick a dealer. The dealer shuffles and doesn\'t bet; they play for the house.',
    'Everyone else puts a bet in front of them before any cards come out.',
    'The dealer gives everyone one card face up, one to themselves face up, then a second card face up to every '
        'player and a second to themselves face down.',
  ],
  play: [
    'Count your hand: 2 to 10 are their number, Jack, Queen and King are 10, and an Ace is 1 or 11, whichever '
        'helps you.',
    'The aim is to get closer to 21 than the dealer without going over. Over 21 is a bust: you lose your bet at '
        'once.',
    'Starting on the dealer\'s left, each player in turn says "hit" for another card, as many times as they like, '
        'or "stand" to stop.',
    'Double: with your first two cards, double your bet and take exactly one more card.',
    'Split: with two cards of the same value, put in a second bet and play them as two hands, one card each.',
    'When everyone is done, the dealer turns over their face-down card. The dealer must hit until they have 17 or '
        'more, then stand. They have no choices.',
  ],
  win: [
    'Closer to 21 than the dealer, or the dealer busts: you win as much as you bet.',
    'Same total as the dealer: you get your bet back. Lower: the dealer takes it.',
    'Blackjack is an Ace and a 10, Jack, Queen or King as your first two cards. It beats any other 21 and pays one '
        'and a half times your bet.',
    'Play as many hands as you like. Whoever has the most chips at the end wins. Take turns being the dealer.',
  ],
);
