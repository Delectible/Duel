import 'dart:math';

import 'package:duel_engine/difficulty.dart';

import '../../../core/avatars/faces.dart';
import 'bj_controller.dart';

/// A blackjack table's limits.
class BjTable {
  const BjTable(this.name, this.min, this.max, this.difficulty);

  final String name;
  final int min;
  final int max;

  /// How well the bots here play (and count).
  final Difficulty difficulty;

  /// Open once your balance covers a max bet (the first is always open).
  int get unlock => this == bjTables.first ? 0 : max;

  bool openFor(int balance) => balance >= unlock;

  /// Chips to bet with at this table.
  List<int> get chips => [min, min * 5, min * 10];
}

const bjTables = [
  BjTable('Corner table', 10, 100, Difficulty.easy),
  BjTable('Main floor', 50, 500, Difficulty.normal),
  BjTable('High limit', 250, 2500, Difficulty.hard),
  BjTable('The vault', 1000, 10000, Difficulty.hard),
];

/// Who sits at a table: a bot, or (online, later) a person.
class BjSitter {
  const BjSitter(this.persona, {this.bot = true});

  final Persona persona;
  final bool bot;
}

/// The tables as this phone sees them: who's sitting where, changing every
/// so often (worked out from the clock, so it's the same while you look
/// and different when you come back). The middle seat is yours when you
/// sit, so a bot there slides over. Built like the cash tables' lobby so
/// shared online tables can slot in later.
abstract final class LocalBjTables {
  /// A new crowd every 20 minutes.
  static const _window = 20 * 60 * 1000;

  static List<List<BjSitter?>> at(int now) => [
    for (final (i, _) in bjTables.indexed)
      () {
        final rng = Random(i * 7919 + now ~/ _window);
        // One to four bots; never a full table.
        final n = 1 + rng.nextInt(4);
        final seats = [for (var s = 0; s < BjController.seatCount; s++) s]..shuffle(rng);
        final taken = seats.take(n).toSet();
        final people = Persona.bots(n, rng);
        var p = 0;
        return [
          for (var s = 0; s < BjController.seatCount; s++) taken.contains(s) ? BjSitter(people[p++]) : null,
        ];
      }(),
  ];
}
