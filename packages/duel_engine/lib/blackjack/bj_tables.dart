import '../difficulty.dart';
import 'blackjack.dart';

/// Seats at a blackjack table (the dealer aside).
const bjSeatCount = 5;

/// A blackjack table: its limits, how well its bots play, and (online,
/// where everyone at a table plays alike) its own house rules. Local
/// tables play your house rules instead.
class BjTable {
  const BjTable(this.id, this.name, this.min, this.max, this.difficulty, this.onlineRules);

  /// Its name online (`bj/{id}`).
  final String id;
  final String name;
  final int min;
  final int max;

  /// How well the bots here play (and count).
  final Difficulty difficulty;

  /// The rules at the shared table.
  final BjRules onlineRules;

  /// Open once your balance covers a max bet (the first is always open).
  int get unlock => this == bjTables.first ? 0 : max;

  bool openFor(int balance) => balance >= unlock;

  /// Chips to bet with at this table.
  List<int> get chips => [min, min * 5, min * 10];

  static BjTable? byId(String id) {
    for (final t in bjTables) {
      if (t.id == id) return t;
    }
    return null;
  }
}

/// The tables, cheapest first. Online, the cheap table plays the cheap
/// casino's rules (6:5, H17, 8 decks) and the high-limit rooms the
/// friendlier ones (fewer decks, surrender).
const bjTables = [
  BjTable(
    'corner',
    'Corner table',
    10,
    100,
    Difficulty.easy,
    BjRules(decks: 8, hitSoft17: true, sixToFive: true),
  ),
  BjTable('main', 'Main floor', 50, 500, Difficulty.normal, BjRules()),
  BjTable('high', 'High limit', 250, 2500, Difficulty.hard, BjRules(decks: 2, surrender: true)),
  BjTable(
    'vault',
    'The vault',
    1000,
    10000,
    Difficulty.hard,
    BjRules(decks: 1, surrender: true, doubleAfterSplit: false),
  ),
];
