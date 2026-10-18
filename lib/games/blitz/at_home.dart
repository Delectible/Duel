import 'package:flutter/material.dart';

import '../../core/help/home_guide.dart';

/// Blitz with real cards (a house game: invented by a friend of Luca's).
const blitzAtHome = HomeGuide(
  needs: [
    (Icons.style_rounded, standardDeck),
    (
      Icons.groups_rounded,
      '2 to 6 players. With 5 or 6, shuffle two decks together so there are enough cards.',
    ),
    (Icons.table_restaurant_rounded, 'A table with room for everyone to lay out a row of 7 cards.'),
  ],
  setup: [
    'Shuffle and deal each player 7 cards face down, one at a time.',
    'Without looking, everyone lays their 7 cards in a row in front of them, face down. This row is your castle: '
        'every card in it is a life.',
    'Turn the last card of your row face up. That end is the top of your castle. Whenever the top card goes, turn '
        'the next one face up.',
    'Deal everyone 4 more cards. This is your hand: keep it secret.',
    'Put the rest of the deck face down in the middle. Thrown-away cards go face up next to it. If the deck runs '
        'out, shuffle the thrown-away cards to make a new one.',
  ],
  play: [
    'Pick someone to start; turns go to the left.',
    'On your turn, first draw a card from the deck (you now have 5). Then you must do one of these, which uses a '
        'card, so you end your turn with 4:',
    'Strike: show a card from your hand with the same number as a face-up card in someone else\'s castle (a 9 '
        'on a 9). Throw both away. They just lost a life.',
    'Scout: throw any card from your hand away, and turn one of someone else\'s face-down castle cards face up. '
        'Now anyone can strike it.',
    'Fortify: match one of the face-up cards in your own castle with the same number from your hand. Throw both '
        'away, then add two cards from the deck to your castle: one face down, then one face up on top.',
    'Pair: throw away two cards of the same number from your hand, draw two new cards, and then do one more of '
        'these. Only one pair a turn.',
    'Blitz: if you have 5 cards of the same colour (all red or all black), throw them away and knock down every '
        'face-up card in one player\'s castle. Draw 5 new cards and take another whole turn.',
    'Nothing you can do? Throw one card from your hand away instead.',
    'Aces are wild numbers: an Ace matches anything and anything matches an Ace. An Ace from your hand can even '
        'strike a face-down card. For a Blitz an Ace only counts as its own colour.',
    'Wars (optional, for a faster game): whenever two castles show the same number face up, those cards fight '
        'straight away. The player with fewer castle cards keeps theirs; the others lose theirs. Same number of '
        'castle cards? They all lose it. Nobody can lose their last card to a war.',
  ],
  win: [
    'When your castle has no cards left, you\'re out. Put your hand on the thrown-away pile.',
    'The last player with cards in their castle wins.',
  ],
);
