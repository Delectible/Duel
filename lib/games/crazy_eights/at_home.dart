import 'package:flutter/material.dart';

import '../../core/help/home_guide.dart';

/// Crazy Eights with a real deck.
const eightsAtHome = HomeGuide(
  needs: [
    (Icons.style_rounded, standardDeck),
    (Icons.groups_rounded, '2 to 5 players. With more, shuffle two decks together.'),
  ],
  setup: [
    'Pick someone to deal and have them shuffle the cards.',
    'Deal the cards face down one at a time, going left around the table: 7 cards each with two players, 5 each '
        'with three or more. Pick up your cards and keep them hidden.',
    'Put the rest of the deck face down in the middle. This is the draw pile.',
    'Turn the top card of the draw pile face up next to it to start the discard pile. If it is an 8, push it back '
        'into the middle of the draw pile and turn over another.',
    'The player to the left of the dealer goes first. Turns go to the left, round and round.',
  ],
  play: [
    'On your turn, put one card from your hand face up on the discard pile. It has to match the top card in suit '
        '(any heart on a heart) or in number or picture (any 7 on a 7, any Queen on a Queen).',
    'Eights are wild: you can play an 8 on anything. When you do, say a suit out loud. The next player has to '
        'play that suit (or another 8).',
    'If you can not play, or do not want to, take one card from the draw pile. If it fits you may play it '
        'straight away. If not, keep it and your turn is over.',
    'If the draw pile runs out, leave the top card of the discard pile where it is, shuffle the rest, and turn '
        'them face down as a new draw pile.',
    'Be friendly: say "last card" when you have one card left, so nobody is surprised.',
  ],
  win: [
    'The first player to get rid of every card in their hand wins the round.',
    'Playing a few rounds? The winner scores points for the cards everyone else is still holding: 50 for each 8, '
        '10 for each Jack, Queen or King, 1 for each Ace, and the number on the card for the rest.',
    'First to 100 points wins the game.',
  ],
);
