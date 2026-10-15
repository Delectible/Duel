/// How good the bots are, for every game.
enum Difficulty {
  easy('Easy'),
  normal('Normal'),
  hard('Hard');

  const Difficulty(this.label);

  final String label;
}
