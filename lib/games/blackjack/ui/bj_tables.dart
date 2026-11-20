/// A blackjack table's limits.
class BjTable {
  const BjTable(this.name, this.min, this.max);

  final String name;
  final int min;
  final int max;

  /// Open once your balance covers a max bet (the first is always open).
  int get unlock => this == bjTables.first ? 0 : max;

  bool openFor(int balance) => balance >= unlock;

  /// Chips to bet with at this table.
  List<int> get chips => [min, min * 5, min * 10];
}

const bjTables = [
  BjTable('Corner table', 10, 100),
  BjTable('Main floor', 50, 500),
  BjTable('High limit', 250, 2500),
  BjTable('The vault', 1000, 10000),
];
