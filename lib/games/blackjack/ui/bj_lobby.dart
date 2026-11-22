import 'dart:math';

import 'package:duel_engine/blackjack/blackjack.dart';
import 'package:flutter/material.dart';

import '../../../core/account/account.dart';
import '../../../core/avatars/faces.dart';
import '../../../core/sound/sound.dart';
import '../../../core/table/felts.dart';
import '../../../core/theme/toon.dart';
import 'bj_screen.dart';
import 'bj_tables.dart';

/// The casino floor's own colours (like the Poker Lounge has its own).
abstract final class Casino {
  static const floor = Color(0xFF0E2F24);
  static const panel = Color(0xFF16473A);
  static const night = Color(0xFF0A2219);
  static const gold = Color(0xFFF2C14E);
  static const cream = Color(0xFFFFF4DC);
  static const dim = Color(0xFF9DBFAF);
}

/// Blackjack Tables: the casino floor. Every table's open with its limits
/// and who's sitting there (bots now; people when tables go online, like
/// the cash games), your record, and the house rules you play by. Bets
/// come straight off your balance.
class BjLobby extends StatefulWidget {
  const BjLobby({super.key, this.pace = 1, this.seed, this.now});

  final double pace;
  final int? seed;

  /// The clock (tests).
  final int Function()? now;

  @override
  State<BjLobby> createState() => _BjLobbyState();
}

class _BjLobbyState extends State<BjLobby> {
  late List<List<BjSitter?>> _tables = LocalBjTables.at(_now());

  int _now() => widget.now?.call() ?? DateTime.now().millisecondsSinceEpoch;

  Future<void> _sit(BjTable t, List<BjSitter?> seated) async {
    Sound.play(Sfx.tap, gain: 0.6);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BjScreen(table: t, seated: seated, pace: widget.pace, seed: widget.seed),
      ),
    );
    // Back on the floor: the crowd may have moved on.
    if (mounted) setState(() => _tables = LocalBjTables.at(_now()));
  }

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    return Scaffold(
      backgroundColor: Casino.floor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              key: const Key('bj lobby'),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                Row(
                  children: [
                    ToonButton(
                      key: const Key('lobby back'),
                      color: Casino.panel,
                      padding: const EdgeInsets.all(8),
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.arrow_back_rounded, size: 24, color: Casino.cream),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Blackjack Tables',
                            style: Toon.text(26, weight: FontWeight.w700, color: Casino.gold),
                          ),
                          Text(
                            'Sit anywhere, leave whenever',
                            style: Toon.text(14, weight: FontWeight.w500, color: Casino.dim),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Record(account: account),
                const SizedBox(height: 12),
                _HouseRules(account: account),
                const SizedBox(height: 16),
                Text(
                  'Tables',
                  style: Toon.text(18, weight: FontWeight.w700, color: Casino.cream),
                ),
                const SizedBox(height: 8),
                for (final (i, t) in bjTables.indexed)
                  _TableCard(
                    table: t,
                    level: i,
                    seated: _tables[i],
                    account: account,
                    onSit: () => _sit(t, _tables[i]),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Your balance and how blackjack has gone for you.
class _Record extends StatelessWidget {
  const _Record({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final st = account.stats('blackjack');
    final rate = st.played == 0 ? '–' : '${(100 * st.won / st.played).round()}%';
    final m = account.money;
    Widget stat(String label, String value, {Color color = Casino.cream, Key? key}) => Expanded(
      child: Column(
        children: [
          FittedBox(
            child: Text(
              value,
              key: key,
              style: Toon.text(18, weight: FontWeight.w700, color: color),
            ),
          ),
          Text(
            label,
            style: Toon.text(12, weight: FontWeight.w600, color: Casino.dim),
          ),
        ],
      ),
    );
    return Container(
      key: const Key('bj record'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Casino.night,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Casino.gold, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: Casino.gold, size: 20),
              const SizedBox(width: 8),
              Text(
                account.currency == CurrencyChoice.pips ? 'Your pips' : 'Your money',
                style: Toon.text(14, weight: FontWeight.w600, color: Casino.dim),
              ),
              const Spacer(),
              Text(
                m(account.balance),
                key: const Key('lobby balance'),
                style: Toon.text(18, weight: FontWeight.w700, color: Casino.gold),
              ),
            ],
          ),
          const Divider(color: Casino.panel, height: 18, thickness: 2),
          Row(
            children: [
              stat('Hands', '${st.played}'),
              stat('Won', rate),
              stat(
                'Net',
                st.net == 0 ? '–' : '${st.net > 0 ? '+' : ''}${m(st.net)}',
                color: st.net > 0 ? Toon.green : (st.net < 0 ? Toon.red : Casino.cream),
              ),
              stat('Blackjacks', '${account.bjBlackjacks}'),
              stat('Best win', account.bjBest == 0 ? '–' : m(account.bjBest)),
            ],
          ),
        ],
      ),
    );
  }
}

/// The house rules you play by, and Change.
class _HouseRules extends StatelessWidget {
  const _HouseRules({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const Key('house rules'),
    onTap: () => showHouseRules(context, account),
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: Casino.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Casino.night, width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.gavel_rounded, color: Casino.gold, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'House rules',
                  style: Toon.text(15, weight: FontWeight.w700, color: Casino.cream),
                ),
                Text(
                  account.bjRules.summary,
                  key: const Key('rules summary'),
                  style: Toon.text(13, weight: FontWeight.w500, color: Casino.dim),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: Casino.gold, borderRadius: BorderRadius.circular(10)),
            child: Text(
              'Change',
              style: Toon.text(13, weight: FontWeight.w700, color: Casino.night),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The house rules sheet: each rule, the usual choice marked.
Future<void> showHouseRules(BuildContext context, Account account) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  backgroundColor: Casino.floor,
  builder: (context) => ListenableBuilder(
    listenable: account,
    builder: (context, _) {
      final r = account.bjRules;
      void set(BjRules next) => account.bjRules = next;
      return SafeArea(
        child: SingleChildScrollView(
          key: const Key('rules sheet'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'House rules',
                style: Toon.text(22, weight: FontWeight.w700, color: Casino.gold),
              ),
              Text(
                'For every table, from the next shoe. ★ is the usual rule.',
                style: Toon.text(14, weight: FontWeight.w500, color: Casino.dim),
              ),
              const SizedBox(height: 12),
              _RuleRow(
                id: 'h17',
                title: 'Dealer on soft 17',
                help: 'Standing is better for you.',
                options: const ['Stands ★', 'Hits'],
                picked: r.hitSoft17 ? 1 : 0,
                onPick: (i) => set(r.copyWith(hitSoft17: i == 1)),
              ),
              _RuleRow(
                id: 'pays',
                title: 'Blackjack pays',
                help: '6 to 5 pays less: on a 10 bet, 12 instead of 15.',
                options: const ['3 to 2 ★', '6 to 5'],
                picked: r.sixToFive ? 1 : 0,
                onPick: (i) => set(r.copyWith(sixToFive: i == 1)),
              ),
              _RuleRow(
                id: 'decks',
                title: 'Decks in the shoe',
                help: 'Fewer decks are easier to count.',
                options: [for (final d in BjRules.deckChoices) d == shoeDecks ? '$d ★' : '$d'],
                picked: BjRules.deckChoices.indexOf(r.decks),
                onPick: (i) => set(r.copyWith(decks: BjRules.deckChoices[i])),
              ),
              _RuleRow(
                id: 'das',
                title: 'Double after a split',
                help: 'Double down on a hand you split.',
                options: const ['On ★', 'Off'],
                picked: r.doubleAfterSplit ? 0 : 1,
                onPick: (i) => set(r.copyWith(doubleAfterSplit: i == 0)),
              ),
              _RuleRow(
                id: 'ins',
                title: 'Insurance',
                help: 'Offered when the dealer shows an Ace.',
                options: const ['On ★', 'Off'],
                picked: r.insurance ? 0 : 1,
                onPick: (i) => set(r.copyWith(insurance: i == 0)),
              ),
              _RuleRow(
                id: 'sur',
                title: 'Surrender',
                help: 'Give up a bad start for half your bet back.',
                options: const ['Off ★', 'On'],
                picked: r.surrender ? 1 : 0,
                onPick: (i) => set(r.copyWith(surrender: i == 1)),
              ),
              const SizedBox(height: 4),
              TextButton(
                key: const Key('rules reset'),
                onPressed: r == const BjRules() ? null : () => set(const BjRules()),
                child: Text(
                  'Back to the usual',
                  style: Toon.text(
                    15,
                    weight: FontWeight.w700,
                    color: r == const BjRules() ? Casino.dim : Casino.gold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  ),
);

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.id,
    required this.title,
    required this.help,
    required this.options,
    required this.picked,
    required this.onPick,
  });

  final String id;
  final String title;
  final String help;
  final List<String> options;
  final int picked;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Toon.text(16, weight: FontWeight.w700, color: Casino.cream),
        ),
        Text(
          help,
          style: Toon.text(13, weight: FontWeight.w500, color: Casino.dim),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final (i, o) in options.indexed)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ToonButton(
                    key: Key('rule $id $i'),
                    color: i == picked ? Casino.gold : Casino.panel,
                    radius: 10,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    onPressed: () => onPick(i),
                    child: FittedBox(
                      child: Text(
                        o,
                        style: Toon.text(
                          15,
                          weight: FontWeight.w700,
                          color: i == picked ? Casino.night : Casino.cream,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

/// One table: its felt, limits, who's sitting (faces round a half moon,
/// open seats outlined), and Sit.
class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.table,
    required this.level,
    required this.seated,
    required this.account,
    required this.onSit,
  });

  final BjTable table;
  final int level;
  final List<BjSitter?> seated;
  final Account account;
  final VoidCallback onSit;

  @override
  Widget build(BuildContext context) {
    final m = account.money;
    final felt = Felt.forLevel(level, bjTables.length);
    final open = table.openFor(account.balance);
    final bots = seated.nonNulls.where((s) => s.bot).length;
    final people = seated.nonNulls.where((s) => !s.bot).toList();
    return Opacity(
      opacity: open ? 1 : 0.55,
      child: GestureDetector(
        key: Key('table ${table.min}'),
        onTap: open ? onSit : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Casino.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: open ? Casino.gold : Casino.dim.withValues(alpha: 0.4), width: 2),
            boxShadow: const [BoxShadow(color: Casino.night, offset: Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          table.name,
                          style: Toon.text(19, weight: FontWeight.w700, color: Casino.cream),
                        ),
                        Text(
                          'Bets ${m(table.min)}–${m(table.max)} · ${table.difficulty.label} bots',
                          style: Toon.text(13, weight: FontWeight.w500, color: Casino.dim),
                        ),
                      ],
                    ),
                  ),
                  if (open)
                    Container(
                      key: Key('sit ${table.min}'),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Casino.gold, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        'Sit down',
                        style: Toon.text(14, weight: FontWeight.w700, color: Casino.night),
                      ),
                    )
                  else
                    Row(
                      key: Key('locked ${table.min}'),
                      children: [
                        const Icon(Icons.lock_rounded, size: 16, color: Casino.gold),
                        const SizedBox(width: 4),
                        Text(
                          'Opens at ${m(table.unlock)}',
                          style: Toon.text(13, weight: FontWeight.w700, color: Casino.gold),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 92,
                child: _MiniTable(felt: felt, seated: seated),
              ),
              const SizedBox(height: 6),
              Text(
                people.isEmpty
                    ? '$bots at the table · all bots'
                    : '${people.length} ${people.length == 1 ? 'person' : 'people'} here: '
                          '${people.map((p) => p.persona.name).join(', ')}',
                key: Key('table ${table.min} people'),
                style: Toon.text(
                  13,
                  weight: FontWeight.w600,
                  color: people.isEmpty ? Casino.dim : Casino.gold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A half-moon table from above: the dealer's side flat at the top, five
/// seats round the curve, faces where someone sits.
class _MiniTable extends StatelessWidget {
  const _MiniTable({required this.felt, required this.seated});

  final Felt felt;
  final List<BjSitter?> seated;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final w = min(box.maxWidth, 340.0), h = box.maxHeight;
      const face = 30.0;
      // Round the curve, left to right.
      Offset spot(int i) {
        final a = pi - (i + 0.5) * pi / seated.length;
        return Offset(w / 2 + cos(a) * w * 0.40, 8 + sin(a) * (h - face / 2 - 12));
      }

      return Center(
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: w * 0.06,
                right: w * 0.06,
                top: 0,
                height: h - 10,
                child: CustomPaint(painter: _HalfMoon(felt)),
              ),
              for (var i = 0; i < seated.length; i++)
                Positioned(
                  left: spot(i).dx - face / 2,
                  top: spot(i).dy - face / 2,
                  child: seated[i] == null
                      ? Container(
                          width: face,
                          height: face,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.15),
                            border: Border.all(color: felt.line.withValues(alpha: 0.6), width: 2),
                          ),
                        )
                      : Container(
                          decoration: seated[i]!.bot
                              ? null
                              : BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Casino.gold, width: 2.5),
                                ),
                          child: Face(seated[i]!.persona, size: face),
                        ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _HalfMoon extends CustomPainter {
  _HalfMoon(this.felt);

  final Felt felt;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    Path moon(double inset) => Path()
      ..moveTo(inset, 0)
      ..lineTo(w - inset, 0)
      ..arcToPoint(Offset(inset, 0), radius: Radius.elliptical(w / 2 - inset, h - inset), clockwise: true)
      ..close();
    final path = moon(0);
    canvas.drawPath(path, Paint()..color = felt.rail);
    canvas.drawPath(moon(6), Paint()..color = felt.felt);
    // The printed arc.
    canvas.drawPath(
      moon(w * 0.2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = felt.line.withValues(alpha: 0.6),
    );
    // The dealer's chip tray.
    final tray = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w / 2, 6), width: 54, height: 9),
      const Radius.circular(3),
    );
    canvas.drawRRect(tray, Paint()..color = Colors.black.withValues(alpha: 0.35));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Casino.night,
    );
  }

  @override
  bool shouldRepaint(_HalfMoon old) => old.felt != felt;
}
