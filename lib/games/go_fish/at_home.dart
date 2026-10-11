import 'package:flutter/material.dart';

import '../../core/help/home_guide.dart';

/// Go Fish with a real deck.
const fishAtHome = HomeGuide(
  needs: [(Icons.style_rounded, standardDeck), (Icons.groups_rounded, '2 to 6 players. Great for kids.')],
  setup: [
    'Pick someone to deal and have them shuffle the cards.',
    'Deal the cards face down one at a time: 7 cards each with two or three players, 5 each with four or more.',
    'Spread the rest face down in a messy pile in the middle of the table. This is the pond.',
    'Pick up your cards and hold them so nobody else can see. It helps to put cards of the same rank together: '
        'all your 7s side by side, all your Kings side by side, and so on. "Rank" means the number or picture, '
        'whatever the suit.',
    'The player to the left of the dealer goes first. Turns go to the left.',
  ],
  play: [
    'On your turn, pick another player and ask them for a rank you already have at least one of. For example: '
        '"Sam, do you have any 7s?"',
    'If they have any, they must hand over all of them. You get to ask again: anyone, for any rank you hold.',
    'If they have none, they say "Go fish!" Take one card from the pond. If it is the rank you asked for, show '
        'everyone and go again. If not, keep it and your turn is over.',
    'When you have all four cards of one rank (all four 7s, say), that is a book. Put it face up in front of you.',
    'If you run out of cards, take one from the pond and keep playing. If the pond is empty too, you sit out the '
        'rest of the game.',
  ],
  win: [
    'The game ends when all 13 books have been made.',
    'Whoever has the most books wins. If two players have the same, they share the win.',
    'Tip: listen to what everyone asks for. If someone asks for Kings, they must have a King, so you can ask them '
        'for it later.',
  ],
);
