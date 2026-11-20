import 'package:flutter/material.dart';

import '../../core/help/home_guide.dart';

/// Bank! with two dice.
const bankAtHome = HomeGuide(
  needs: [
    (Icons.casino_rounded, 'Two ordinary six-sided dice.'),
    (Icons.groups_rounded, '2 or more players. The more, the louder.'),
    (Icons.edit_rounded, 'Pen and paper for the scores, and one person to keep the bank total.'),
  ],
  setup: [
    'Agree how many rounds to play: 10, 15 or 20.',
    'Write everyone\'s name down with a score of 0.',
    'Pick who rolls first. The dice pass to the left after every roll.',
  ],
  play: [
    'Each round starts with an empty bank. Players take turns rolling both dice, and every roll adds to the bank.',
    'The first three rolls of a round are safe. A 7 adds 70 to the bank. Doubles add the total of the dice, like '
        'any other roll.',
    'From the fourth roll on, the danger starts. Rolling a 7 ends the round, and the bank is lost.',
    'Doubles from the fourth roll on double the whole bank.',
    'At any time, even when it isn\'t your turn, you can shout "Bank!" You add the bank\'s total to your score and '
        'sit out the rest of the round. The bank keeps going for everyone else.',
    'The round ends when someone rolls a 7 (after the first three rolls) or when everyone has banked.',
  ],
  win: [
    'Anyone who didn\'t bank before the 7 gets nothing that round.',
    'After the last round, the highest score wins.',
    'Tip: the bank grows fast, and so does the risk. One roll in six is a 7.',
  ],
);
