import 'package:flutter/material.dart';

import '../../core/help/home_guide.dart';

/// Goofspiel (GOPS) with a real deck.
const goofspielAtHome = HomeGuide(
  needs: [
    (Icons.style_rounded, standardDeck),
    (Icons.groups_rounded, '2 or 3 players.'),
    (Icons.edit_rounded, 'Pen and paper to keep score (or just keep the prizes you win in a pile).'),
  ],
  setup: [
    'Take out all 13 diamonds. Shuffle them and put them face down in the middle: these are the prizes.',
    'Each player takes one of the other suits: all 13 cards of it, Ace to King. These are your bids.',
    'Pick up your bids and hold them so nobody else can see. With 2 players, put the fourth suit away.',
  ],
  play: [
    'Turn the top prize face up so everyone can see it. Ace is worth 1, 2 to 10 their number, Jack 11, Queen 12, '
        'King 13.',
    'Everyone secretly picks one card from their hand as a bid and puts it face down on the table.',
    'When everyone is ready, turn the bids over together. The highest bid wins the prize. Card values are the '
        'same as the prizes: Ace is the lowest, King the highest.',
    'Bids are used up: put them aside, face up, so everyone can see what has gone.',
    'A tie for the highest bid? Nobody wins that prize. Leave it out, turn over the next prize, and whoever wins '
        'the next one takes both.',
    'Keep going until all 13 prizes have been played.',
  ],
  win: [
    'Add up the prizes you won. The highest total wins.',
    'All the prizes add up to 91, so 46 or more always wins with 2 players.',
    'Tip: you can\'t win everything. Let small prizes go cheaply and save your Kings and Queens for the big ones.',
  ],
);
