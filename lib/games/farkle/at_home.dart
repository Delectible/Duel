import 'package:flutter/material.dart';

import '../../core/help/home_guide.dart';

/// Farkle with six dice.
const farkleAtHome = HomeGuide(
  needs: [
    (Icons.casino_rounded, 'Six ordinary six-sided dice (a cup to roll them from helps).'),
    (Icons.groups_rounded, '2 or more players.'),
    (Icons.edit_rounded, 'Pen and paper for the scores, or the Score counter in Tabletop.'),
  ],
  setup: [
    'Write everyone\'s name down with a score of 0. The goal is 10,000 points.',
    'Pick who goes first. Turns go round to the left.',
  ],
  play: [
    'On your turn, roll all six dice.',
    'Set aside at least one die that scores. A 1 is 100 and a 5 is 50. Three of a kind is the face times 100 '
        '(three 1s are 1000). Four of a kind is 1000, five is 2000, six is 3000. A straight from 1 to 6 or three '
        'pairs is 1500, and two sets of three is 2500. Every die you set aside has to score.',
    'Now choose: stop and write down your points for the turn, or roll the dice you didn\'t set aside to add more.',
    'If a roll has nothing that scores, that\'s a Farkle: you lose all the points from this turn and the dice pass on.',
    'If you manage to set aside all six dice, you have "hot dice": pick all six up and keep rolling.',
  ],
  win: [
    'The first player to reach 10,000 sets the score to beat. Everyone else gets one more turn to pass it.',
    'The highest score wins.',
    'Tip: with one or two dice left, a Farkle is likely. Know when to stop.',
  ],
);
