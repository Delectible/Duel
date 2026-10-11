import 'package:flutter/material.dart';

import '../../core/help/home_guide.dart';

/// Four in a Row with a real board, or paper.
const rowAtHome = HomeGuide(
  needs: [
    (
      Icons.grid_on_rounded,
      'A Connect Four set: a standing frame with 7 columns and 6 rows, and 21 discs in each of two colours. No '
          'cards needed.',
    ),
    (Icons.edit_rounded, 'No set? Pen and paper works: draw a grid 7 squares wide and 6 squares tall.'),
    (Icons.groups_rounded, 'Exactly 2 players.'),
  ],
  setup: [
    'Stand the frame up with the slots at the top and make sure the bottom is closed so the discs stay in.',
    'Each player takes all the discs of one colour.',
    'On paper: one player is X and the other is O. "Dropping a disc" means drawing your mark in the lowest empty '
        'square of a column.',
    'Toss a coin to see who goes first. Next game, the other player starts.',
  ],
  play: [
    'Take turns. On your turn, drop one disc into the top of any column that is not full. It falls to the lowest '
        'empty space in that column.',
    'You must play every turn, and once a disc is in, it stays there.',
    'Keep an eye on your opponent. If they have three in a line with an empty space at the end, put your disc '
        'there to block them.',
  ],
  win: [
    'The first player to get four of their discs in a line wins: across, up and down, or diagonally.',
    'If every space fills up and nobody has four in a line, it is a draw.',
    'Tip: the middle column is the strongest place to play, because it is part of the most lines of four.',
  ],
);
