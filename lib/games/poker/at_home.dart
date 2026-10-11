import 'package:flutter/material.dart';

import '../../core/help/home_guide.dart';

/// Texas Hold'em with a real deck.
const holdemAtHome = HomeGuide(
  needs: [
    (Icons.style_rounded, standardDeck),
    (Icons.groups_rounded, '2 to 10 players. It plays best with 4 to 6.'),
    (
      Icons.toll_rounded,
      'Something to bet with: poker chips, coins, buttons or sweets. Give everyone the same amount, say 50 each. '
          'It is only for keeping score.',
    ),
    (Icons.circle_outlined, 'A coin or small object to mark the dealer (the "button").'),
  ],
  setup: [
    'Sit around a table. Give everyone the same pile of chips.',
    'Pick someone to deal first and put the button in front of them. After every hand it moves one seat to the '
        'left, so everyone takes a turn.',
    'The two players to the left of the button put in forced bets called blinds: the first puts in 1 chip (the '
        'small blind), the next puts in 2 (the big blind). This makes sure there is something to win.',
    'The dealer shuffles and deals two cards face down to each player, one at a time, going left around the '
        'table. Look at your two cards without showing anyone. They are yours alone.',
  ],
  play: [
    'First round of betting. Starting with the player left of the big blind and going left, each player chooses: '
        'Fold (give up this hand: slide your cards to the middle face down), Call (put in chips to match the '
        'biggest bet so far) or Raise (match it and add more). Keep going round until everyone left has put in '
        'the same amount.',
    'The flop: the dealer puts the top card aside face down (this is called burning a card), then turns three '
        'cards face up in the middle. These are shared: every player can use them.',
    'Second round of betting, starting with the first player still in to the left of the button. If nobody has '
        'bet yet, you may Check (stay in without betting).',
    'The turn: burn one card, then turn a fourth shared card face up. Bet again.',
    'The river: burn one card, then turn the fifth and last shared card face up. Last round of betting.',
    'After each round, push all the bets into the middle. That pile is the pot.',
    'Showdown: everyone still in turns their two cards face up.',
  ],
  win: [
    'Your hand is the best five cards you can make out of your two cards and the five shared ones. You can use '
        'both of yours, one, or none.',
    'Best hands first: Royal flush (A K Q J 10, all one suit). Straight flush (five in a row, one suit). Four of '
        'a kind. Full house (three of a kind plus a pair). Flush (any five of one suit). Straight (five in a row, '
        'any suits). Three of a kind. Two pair. One pair. High card (nothing: your highest card counts).',
    'Ace is the highest card, but it can also be low in the straight A 2 3 4 5.',
    'The best hand takes the pot. If two hands are exactly as good, they split it. If everyone else folds, the '
        'last player in wins the pot without showing their cards.',
    'Move the button one seat left, put in new blinds and deal the next hand. If you run out of chips you are '
        'out. The last player with chips wins the game.',
    'Tip: double the blinds every 10 hands or so, so the game does not go on forever.',
  ],
);
