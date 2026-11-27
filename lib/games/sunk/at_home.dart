import 'package:flutter/material.dart';

import '../../core/help/home_guide.dart';

/// Sunk with homemade cards.
const sunkAtHome = HomeGuide(
  needs: [
    (
      Icons.style_rounded,
      'A deck of 61 homemade cards (index cards work): treasures 1 ×8, 2 ×7, 3 ×7, 4 ×6, 5 ×6, 6 ×5, 7 ×4, 8 ×3; and '
          'Spare Air ×4, Boo! ×3, Hook ×3, Cut Line ×3, Map ×3.',
    ),
    (Icons.groups_rounded, '2 to 6 players.'),
    (Icons.edit_rounded, 'Pen and paper for the scores, or the Score counter in Tabletop.'),
  ],
  setup: [
    'Shuffle the deck and put it face down in the middle: that\'s the sea.',
    'The first to 120 points at the end of a round wins. Pick who dives first.',
  ],
  play: [
    'On your turn, draw the top card (dive) or stop and bank your treasure (surface). Treasures stay face up in front '
        'of you: that\'s your bag.',
    'If you draw a treasure with the same number as one in your bag, you sink: your bag goes to the discard pile and '
        'you\'re out for the round. A Spare Air card you\'re holding saves you once (discard both).',
    'Surfacing banks the total of your bag. Three numbers in a row (like 4, 5, 6) add 10. Six different numbers and '
        'you surface straight away with 20 more.',
    'Boo!: everyone else still diving must draw one card right now (specials drawn this way are just discarded, but '
        'Spare Air is kept). Hook: take another diver\'s best treasure that you don\'t already have. Cut Line: another '
        'diver\'s best treasure goes under the sea pile. Map: look at the top card, then take it or leave it.',
    'When everyone has surfaced or sunk, the round ends. Clear the bags into the discard pile; the next player starts.',
    'When the sea runs out, shuffle the discard pile to make a new sea.',
  ],
  win: [
    'At the end of a round where someone has 120 or more, the highest score wins.',
    'Tip: count what\'s gone. If two 8s are out, the last 8 is a safe hope… or a trap.',
  ],
);
