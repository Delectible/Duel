/// Things to chase in Hold'em against bots. Earned ones are kept in the
/// [Account] (id -> when); the profile lists them all.
enum Achievement {
  firstWin('First table', 'Win a Hold\'em game against bots.'),
  fullTable('Full house party', 'Win against five bots.'),
  hardWin('Shark tank', 'Win a game on Hard.'),
  sevenDeuce('Seven-deuce glory', 'Win a pot holding 7 and 2, the worst hand there is.'),
  bluffRock('Moved the Rock', 'Bluff the Rock off a pot: win with little while the Rock folds.'),
  underdog('Underdog', 'Win an all-in with under 25% to win.'),
  comeback('Back from the dead', 'Win a game after dropping to 2 big blinds or less.'),
  bounty('Bounty hunter', 'Knock out the bounty bot.'),
  rival('Settled the score', 'Finish ahead of a rival.'),
  quads('Four of a kind', 'Win a showdown with four of a kind.'),
  royal('Royal flush', 'Win with the best hand in poker.');

  const Achievement(this.title, this.text);

  final String title;
  final String text;
}
