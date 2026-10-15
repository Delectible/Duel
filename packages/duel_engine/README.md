# duel_engine

Duel's game rules and bots in pure Dart: no Flutter, no I/O. The app uses
them for bot games; the online referee (`server/`) runs the same code to
check every move, so the two can never disagree.

- `cards.dart`, `difficulty.dart`
- `poker/`, `crazy_eights/`, `go_fish/`, `four_in_a_row/`, `spades/`: each
  game's rules (with an event list for commentary and animations) and bot.

Tests live in the app's `test/<game>/`.
