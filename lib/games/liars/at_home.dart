import 'package:flutter/material.dart';

import '../../core/help/home_guide.dart';

/// Liar's Dice with real cups.
const liarsAtHome = HomeGuide(
  needs: [
    (Icons.casino_rounded, 'Five ordinary dice for each player.'),
    (Icons.local_drink_rounded, 'A cup for each player that you can\'t see through (a mug works).'),
    (Icons.groups_rounded, '2 to 6 players. Best with 3 or more.'),
  ],
  setup: [
    'Everyone puts their five dice in their cup.',
    'Decide who starts. Turns go round to the left.',
  ],
  play: [
    'Everyone shakes their cup and slams it upside down on the table. Peek at your own dice without letting anyone '
        'else see.',
    'The first player makes a bid about ALL the dice on the table: for example "four 3s" means "I think there are at '
        'least four dice showing 3 under all the cups together". 1s are wild: they count as any number.',
    'The next player must either bid higher, or call "Liar!". Higher means more dice ("five 3s"), or the same number '
        'of dice on a bigger face ("four 5s").',
    'When someone calls "Liar!", everyone lifts their cup and counts. If there are fewer dice than the bid, the '
        'bidder loses one die. If there are at least as many, the caller loses one.',
    'Variation: instead of "Liar!" you can say "Spot on" if you think the bid is exactly right. If you\'re right you '
        'get a die back; if not, you lose one.',
    'The player who lost a die starts the next round. Everyone shakes again.',
  ],
  win: [
    'When you lose your last die, you\'re out.',
    'The last player with dice wins.',
    'Tip: a typical die matches a face one time in three (counting wild 1s). Count what you can see, then guess the rest.',
  ],
);
