import 'package:flutter/material.dart';

import '../../core/help/home_guide.dart';
import '../../core/sound/sound.dart';
import '../../core/theme/toon.dart';
import '../../games/bank/ui/bank_companion.dart';
import '../../games/catalog.dart';
import 'scorer/scorer_screen.dart';
import 'tools/card_dealer.dart';
import 'tools/chip_bank.dart';
import 'tools/dice_tray.dart';
import 'tools/flip_spin.dart';
import 'tools/team_picker.dart';
import 'tools/turn_picker.dart';

enum TabletopTab {
  hybrid('Dice & tools', Icons.casino_rounded),
  atHome('Play at home', Icons.menu_book_rounded);

  const TabletopTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Games at a real table: the dice games and tools where the phone helps
/// (the Score counter, Liar's Dice, Farkle, Bank!'s table helper), and
/// every game's Play at home guide in one list.
class TabletopScreen extends StatefulWidget {
  const TabletopScreen({super.key, this.tab = TabletopTab.hybrid});

  final TabletopTab tab;

  @override
  State<TabletopScreen> createState() => _TabletopScreenState();
}

class _TabletopScreenState extends State<TabletopScreen> {
  late var _tab = widget.tab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              sliver: SliverList.list(
                children: [
                  Row(
                    children: [
                      ToonButton(
                        color: Toon.card,
                        padding: const EdgeInsets.all(8),
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tabletop', style: Toon.text(26, weight: FontWeight.w700)),
                            Text(
                              'Real dice and cards, with your phone on the table',
                              maxLines: 2,
                              style: Toon.text(14, weight: FontWeight.w500, color: Toon.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final t in TabletopTab.values)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: t == TabletopTab.hybrid ? 8 : 0),
                            child: ToonButton(
                              key: Key('tabletop ${t.name}'),
                              color: t == _tab ? Toon.yellow : Toon.card,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              onPressed: () => setState(() => _tab = t),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(t.icon, size: 20, color: t == _tab ? Toon.inkLight : null),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      t.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: t == _tab ? Toon.inkLight : null),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
            if (_tab == TabletopTab.hybrid) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: _Feature(
                    key: const Key('score counter'),
                    color: Toon.blue,
                    icon: Icons.scoreboard_rounded,
                    title: 'Score counter',
                    body:
                        'Keep score for any game: tap counters or round-by-round tables, with presets for Hearts, '
                        'Spades, Cribbage, Euchre, Farkle and more. Share one board with your party.',
                    onTap: () => Navigator.of(
                      context,
                    ).push(MaterialPageRoute<void>(builder: (_) => const ScorerHome())),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid.count(
                  crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.25,
                  children: [
                    for (final (key, color, icon, title, line, page)
                        in <(String, Color, IconData, String, String, Widget)>[
                          (
                            'first',
                            Toon.red,
                            Icons.touch_app_rounded,
                            'Who goes first',
                            'Fingers on the screen',
                            const TurnPicker(),
                          ),
                          (
                            'teams',
                            Toon.green,
                            Icons.groups_rounded,
                            'Team picker',
                            'Fair teams at random',
                            const TeamPicker(),
                          ),
                          (
                            'dice',
                            const Color(0xFF8A2B3A),
                            Icons.casino_rounded,
                            'Dice tray',
                            'Up to 8 dice, keep some',
                            const DiceTray(),
                          ),
                          (
                            'coin',
                            const Color(0xFFD9A441),
                            Icons.monetization_on_rounded,
                            'Coin flip',
                            'Heads or tails',
                            const FlipSpin(),
                          ),
                          (
                            'wheel',
                            Toon.purple,
                            Icons.donut_large_rounded,
                            'Spinner',
                            'Your own choices',
                            const FlipSpin(wheel: true),
                          ),
                          (
                            'dealer',
                            const Color(0xFF2E7D5B),
                            Icons.style_rounded,
                            'Card dealer',
                            'A deck, hands kept secret',
                            const CardDealer(),
                          ),
                          (
                            'chips',
                            Toon.blue,
                            Icons.toll_rounded,
                            'Chip bank',
                            'Home poker: who owes whom',
                            const ChipBank(),
                          ),
                          (
                            'bank helper',
                            const Color(0xFF7B5CD6),
                            Icons.savings_rounded,
                            'Bank! helper',
                            'Real dice, phone scores',
                            const BankCompanionSetup(),
                          ),
                        ])
                      _Tool(
                        key: Key('tool $key'),
                        color: color,
                        icon: icon,
                        title: title,
                        line: line,
                        onTap: () =>
                            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
                      ),
                  ],
                ),
              ),
            ] else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.list(
                  children: [
                    Text(
                      'How to play each game with your own cards or dice, step by step, written for someone who has '
                      'never played.',
                      style: Toon.text(14, color: Toon.muted),
                    ),
                    const SizedBox(height: 10),
                    for (final g in [...games]..sort((a, b) => a.name.compareTo(b.name)))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          key: Key('guide ${g.id}'),
                          onTap: () {
                            Sound.play(Sfx.tap, gain: 0.6);
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    HomeGuideScreen(name: g.name, color: g.color, guide: g.atHome),
                              ),
                            );
                          },
                          child: ToonBox(
                            color: Toon.card,
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                Container(
                                  width: 64,
                                  height: 50,
                                  padding: const EdgeInsets.all(3),
                                  decoration: Toon.box(g.color, radius: 10, shadow: 0),
                                  child: FittedBox(child: g.art(context)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(g.name, style: Toon.text(17, weight: FontWeight.w700)),
                                      Text(
                                        g.atHome.needs.first.$2,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Toon.text(13, color: Toon.muted),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String title, body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      Sound.play(Sfx.tap, gain: 0.6);
      onTap();
    },
    child: ToonBox(
      color: color,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, size: 40, color: Toon.on(color)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Toon.text(19, weight: FontWeight.w700, color: Toon.on(color)),
                ),
                const SizedBox(height: 2),
                Text(body, style: Toon.text(13, color: Toon.on(color))),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Toon.on(color)),
        ],
      ),
    ),
  );
}

/// A tool's tile: a colour, an icon, a name and a line.
class _Tool extends StatelessWidget {
  const _Tool({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    required this.line,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String title, line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      Sound.play(Sfx.tap, gain: 0.6);
      onTap();
    },
    child: ToonBox(
      color: color,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 32, color: Toon.on(color)),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              maxLines: 1,
              style: Toon.text(17, weight: FontWeight.w700, color: Toon.on(color)),
            ),
          ),
          Text(
            line,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Toon.text(12, weight: FontWeight.w500, color: Toon.on(color).withValues(alpha: 0.85)),
          ),
        ],
      ),
    ),
  );
}
