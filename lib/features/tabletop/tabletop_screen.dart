import 'package:flutter/material.dart';

import '../../core/help/home_guide.dart';
import '../../core/session/play_setup.dart';
import '../../core/sound/sound.dart';
import '../../core/theme/toon.dart';
import '../../games/bank/ui/bank_companion.dart';
import '../../games/catalog.dart';
import '../home/home_screen.dart';
import 'scorer/scorer_screen.dart';

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
    final setup = PlaySetupScope.of(context);
    final wide = MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                sliver: SliverGrid.count(
                  crossAxisCount: wide ? 4 : 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: wide ? 1.0 : 0.82,
                  children: [
                    for (final g in games)
                      if (g.tabletop) GameTile(game: g, setup: setup),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: _Feature(
                    key: const Key('bank helper'),
                    color: Toon.purple,
                    icon: Icons.savings_rounded,
                    title: 'Bank! table helper',
                    body: 'Playing Bank! with real dice? Roll on the phone, or just keep the scores.',
                    onTap: () => Navigator.of(
                      context,
                    ).push(MaterialPageRoute<void>(builder: (_) => const BankCompanionSetup())),
                  ),
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
