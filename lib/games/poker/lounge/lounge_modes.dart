import 'package:flutter/material.dart';

import '../../../core/account/account.dart';
import '../../../core/avatars/characters.dart';
import '../../../core/avatars/faces.dart';
import '../../../core/theme/toon.dart';

/// The Poker Lounge's own look: the back room of Duel. Deep navy and felt
/// green under a warm lamp, gold trim; the same chunky buttons and font.
abstract final class Lounge {
  static const navy = Color(0xFF14213D);
  static const night = Color(0xFF0E1830);
  static const felt = Color(0xFF1F6B4E);
  static const gold = Color(0xFFF2C14E);
  static const lamp = Color(0xFFFFE8A3);
  static const cream = Color(0xFFF7F1E3);
  static const dim = Color(0xFFB9C2D6);
  static const panel = Color(0xFF22325A);
  static const ruby = Color(0xFFE0525E);
  static const sky = Color(0xFF5B9BF0);
}

/// One way to play in the lounge. Sit & Go is the Hold'em game the app
/// already has; the others are explained here so the direction is agreed
/// before they're built.
class LoungeMode {
  const LoungeMode({
    required this.id,
    required this.name,
    required this.tagline,
    required this.icon,
    required this.color,
    required this.how,
    this.tableTitle,
    this.table = const [],
    this.notes = const [],
    this.open = false,
  });

  final String id;
  final String name;
  final String tagline;
  final IconData icon;
  final Color color;

  /// How it works, a few lines.
  final List<String> how;

  /// A table of what's on offer (stakes, bosses), with its heading.
  final String? tableTitle;
  final List<({String name, String detail, String note})> table;

  /// Still to settle, or worth knowing.
  final List<String> notes;

  /// Playable now (Sit & Go).
  final bool open;

  static const sitAndGo = LoungeMode(
    id: 'sitgo',
    name: 'Sit & Go',
    tagline: 'One table, everyone starts equal, last one standing wins.',
    icon: Icons.style_rounded,
    color: Lounge.felt,
    open: true,
    how: [],
  );

  static const cash = LoungeMode(
    id: 'cash',
    name: 'Cash Games',
    tagline: 'Pull up a chair at a table that never closes.',
    icon: Icons.paid_rounded,
    color: Lounge.gold,
    open: true,
    how: [
      'One table at each stake, always running with bots, shared by everyone with Duel: anyone can sit '
          'down at any time, so you can join your friends (the lobby shows who\'s at each table).',
      'Sit down in an open seat, or a bot gets up for you. Bots come and go, and keep playing while you\'re '
          'away: come back later and the table has moved on.',
      'Your balance is your chips. Sit down with 50 to 100 big blinds from it (no credit here), and '
          'top up between hands.',
      'Cash out whenever you like and your chips go straight back to your balance. Mid-hand, what you\'ve '
          'already bet stays in the pot.',
      'No house cut: everything you win comes from another player or a bot, and everything you lose goes to '
          'one.',
      'A table unlocks once your balance covers its full buy-in. The bots get tougher as the stakes rise.',
      'No connection? The tables play on this phone instead (marked Local): everything works, but friends '
          'can\'t join you there.',
    ],
    tableTitle: 'The tables',
    table: [
      (
        name: 'Kitchen Table',
        detail: 'Blinds 5 / 10 · buy in {500}–{1000} · easy bots',
        note: 'Open to everyone',
      ),
      (
        name: 'Back Room',
        detail: 'Blinds 25 / 50 · buy in {2500}–{5000} · normal bots',
        note: 'Unlocks at {5000}',
      ),
      (
        name: 'High Rollers',
        detail: 'Blinds 100 / 200 · buy in {10000}–{20000} · hard bots',
        note: 'Unlocks at {20000}',
      ),
      (
        name: 'The Penthouse',
        detail: 'Blinds 500 / 1,000 · buy in {50000}–{100000} · hard bots',
        note: 'Unlocks at {100000}',
      ),
    ],
  );

  static const tournament = LoungeMode(
    id: 'tournament',
    name: 'Tournament',
    tagline: 'Eighteen players, three tables, one champion.',
    icon: Icons.emoji_events_rounded,
    color: Lounge.sky,
    how: [
      'Pay the buy-in and take a seat: you and 17 bots across three tables of six.',
      'Everyone starts with the same stack. The blinds go up together at every table.',
      'As players go out, tables break up and players move to fill the empty seats, until the last six '
          'meet at the final table.',
      'The top three are paid from the prize pool: 50%, 30% and 20%. The bots pay their buy-ins too (from '
          'the bank), so the pool is worth chasing.',
      'The other tables play on in the background; between hands you can see the standings and how many '
          'are left.',
      'Leave and you\'re out (your chips are blinded away), as in a real tournament.',
    ],
    tableTitle: 'Buy-ins',
    table: [
      (name: 'Daily Freeroll', detail: 'Free · prize pool from the bank', note: 'Once a day'),
      (name: 'Regular', detail: 'Buy-in {500} · pool {9000}', note: 'Any time'),
      (name: 'Main Event', detail: 'Buy-in {5000} · pool {90000}', note: 'Unlocks after a Regular cash'),
    ],
    notes: ['Later: the same with friends, everyone in the party at the tables.'],
  );

  static const bosses = LoungeMode(
    id: 'bosses',
    name: 'Boss Tables',
    tagline: 'Beat the boss, climb the ladder.',
    icon: Icons.local_fire_department_rounded,
    color: Lounge.ruby,
    how: [
      'A ladder of five bosses, each a named shark with a quirk you can learn to beat.',
      'Each boss table is a Sit & Go: the boss plus a few bots. Finish ahead of the boss to beat them and '
          'unlock the next.',
      'Every boss has a stake to sit down and a prize for beating them, a trophy on your lounge shelf and an '
          'achievement.',
      'Bosses talk: they taunt you before the game and remember how you beat them.',
    ],
    tableTitle: 'The bosses',
    table: [
      (name: 'Lucky Lou', detail: 'Calls every river. Never folds a draw.', note: 'Boss 1'),
      (name: 'Granny Gold', detail: 'Never bluffs, but traps with monsters.', note: 'Boss 2'),
      (name: 'Captain Chaos', detail: 'Raises almost every hand.', note: 'Boss 3'),
      (name: 'The Mime', detail: 'No tells at all: always takes the same time.', note: 'Boss 4'),
      (name: 'Madame Nine', detail: 'Studies how you play and adapts mid-game.', note: 'Final boss'),
    ],
  );

  static const all = [sitAndGo, cash, tournament, bosses];
}

/// What a mode will be: how it works and what's on offer, in the lounge's
/// colours, with "Coming soon".
class LoungeModeScreen extends StatelessWidget {
  const LoungeModeScreen({super.key, required this.mode});

  final LoungeMode mode;

  /// Amounts written {5000} in the text, in your currency ("5,000 pips",
  /// "\$5,000"); a range {500}–{1000} says the unit once for pips.
  static String inCurrency(String text, Account account) => text
      .replaceAllMapped(
        RegExp(r'\{(\d+)\}–\{(\d+)\}'),
        (m) => account.currency == CurrencyChoice.pips
            ? '${chips(int.parse(m[1]!))}–${chips(int.parse(m[2]!))} pips'
            : '${account.money(int.parse(m[1]!))}–${account.money(int.parse(m[2]!))}',
      )
      .replaceAllMapped(RegExp(r'\{(\d+)\}'), (m) => account.money(int.parse(m[1]!)));

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.maybeRead(context) ?? Account();
    String m(String t) => inCurrency(t, account);
    TextStyle text(double size, {FontWeight weight = FontWeight.w600, Color color = Lounge.cream}) =>
        TextStyle(fontFamily: 'Fredoka', fontSize: size, fontWeight: weight, color: color, height: 1.3);
    Widget panel({required List<Widget> children}) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Lounge.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Lounge.gold.withValues(alpha: 0.6), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
    return Scaffold(
      backgroundColor: Lounge.navy,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              key: Key('mode ${mode.id}'),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                Row(
                  children: [
                    IconButton(
                      key: const Key('mode back'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded, color: Lounge.cream, size: 28),
                    ),
                    const Spacer(),
                    if (!mode.open)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Lounge.gold,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Coming soon',
                          style: text(13, weight: FontWeight.w700, color: Lounge.night),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: mode.color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Lounge.night, width: 3),
                      ),
                      child: Icon(mode.icon, size: 36, color: Lounge.night),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mode.name,
                            style: text(30, weight: FontWeight.w700, color: Lounge.gold),
                          ),
                          Text(mode.tagline, style: text(15, color: Lounge.dim)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                panel(
                  children: [
                    Text('How it works', style: text(19, weight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    for (final line in mode.how)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 7, right: 10),
                              decoration: BoxDecoration(color: mode.color, shape: BoxShape.circle),
                            ),
                            Expanded(
                              child: Text(m(line), style: text(15, weight: FontWeight.w500)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (mode.table.isNotEmpty)
                  panel(
                    children: [
                      Text(mode.tableTitle ?? '', style: text(19, weight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      for (final row in mode.table)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Lounge.night,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              if (CharacterFaces.byName[row.name] case final face?) ...[
                                Face(Persona(name: row.name, look: Look.cap, avatar: face), size: 40),
                                const SizedBox(width: 10),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      row.name,
                                      style: text(16, weight: FontWeight.w700, color: Lounge.lamp),
                                    ),
                                    Text(
                                      m(row.detail),
                                      style: text(13, weight: FontWeight.w500, color: Lounge.dim),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                m(row.note),
                                textAlign: TextAlign.right,
                                style: text(12, color: mode.color),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                if (mode.notes.isNotEmpty)
                  panel(
                    children: [
                      Text('To agree on', style: text(19, weight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      for (final n in mode.notes)
                        Text(
                          '• $n',
                          style: text(14, weight: FontWeight.w500, color: Lounge.dim),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
