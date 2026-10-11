import 'package:flutter/material.dart';

import '../../core/help/home_guide.dart';

/// Spades with a real deck (the four-player partnership game).
const spadesAtHome = HomeGuide(
  needs: [
    (Icons.style_rounded, standardDeck),
    (
      Icons.groups_rounded,
      '4 players in two teams of two. Partners sit across the table from each other. (There is a two-player '
          'version, but learn this one first.)',
    ),
    (Icons.edit_rounded, 'Pen and paper to write down bids and scores.'),
  ],
  setup: [
    'Sit so that you and your partner face each other, with an opponent on each side of you.',
    'Pick someone to deal. They shuffle and deal out the whole deck face down, one card at a time, going left, '
        'so everyone has 13 cards.',
    'Pick up your cards and sort them by suit. Spades are special in this game: they beat every other suit.',
  ],
  play: [
    'Bidding: starting with the player left of the dealer and going left, everyone says how many tricks they '
        'think they will win, from 0 to 13. Write the bids down. Your team\'s bid is your two bids added together.',
    'What is a trick? One player leads by playing any card face up in the middle. Going left, everyone else plays '
        'one card. Those four cards are a trick.',
    'You must follow suit: if a heart was led, you must play a heart if you have one. If you have none, you may '
        'play any card, including a spade.',
    'Who wins the trick: if any spades were played, the highest spade wins. If not, the highest card of the suit '
        'that was led wins. Ace is the highest card. The winner stacks the trick face down in front of them and '
        'leads the next one.',
    'You can not lead a spade until someone has played a spade on another suit. (Unless spades are all you have '
        'left.)',
    'The player left of the dealer leads the first trick. Keep going until all 13 tricks have been played.',
  ],
  win: [
    'Count how many tricks your team won.',
    'Made your bid (won at least as many as you bid)? Score 10 points for every trick you bid, plus 1 point for '
        'each extra trick. Extra tricks are called bags.',
    'Missed your bid? Lose 10 points for every trick you bid.',
    'Watch your bags: every time a team collects 10 of them, it loses 100 points.',
    'Pass the deal to the left and play another hand. The first team to reach 500 points wins.',
  ],
);
