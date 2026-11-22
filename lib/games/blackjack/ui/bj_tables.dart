import 'dart:math';

import 'package:duel_engine/blackjack/bj_tables.dart';

import '../../../core/avatars/faces.dart';
import 'bj_controller.dart';

export 'package:duel_engine/blackjack/bj_tables.dart';

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
