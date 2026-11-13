import 'package:flutter/material.dart';

import '../../../core/account/account.dart';
import '../../../core/account/achievements.dart';
import '../../../core/avatars/faces.dart';
import '../../../core/help/home_guide.dart';
import '../../../core/session/play_setup.dart';
import '../../../core/sound/sound.dart';
import '../../../core/theme/toon.dart';
import '../../../features/home/connection_bar.dart';
import '../../../features/preview/game_preview_screen.dart';
import '../../catalog.dart';
import '../ui/hand_chart.dart';
import '../ui/rivals.dart';
import 'lounge_modes.dart';

/// The Poker Lounge: Duel's back room. The ways to play poker (Sit & Go
/// now; cash games, tournaments and boss tables to come), your record, the
/// rivals' board, the achievements, and a few things to read. The
/// connection bar is here too, so you always know who you're playing with.
class LoungeScreen extends StatelessWidget {
  const LoungeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    final setup = PlaySetupScope.of(context);
    final holdem = games.firstWhere((g) => g.id == 'holdem');
    final left = [
      _Header(account: account),
      const SizedBox(height: 12),
      // Who you're playing with, as on home (it keeps its own colours).
      const ConnectionBar(),
      const SizedBox(height: 18),
      const _Heading('Tables'),
      _Modes(holdem: holdem, setup: setup),
      const SizedBox(height: 18),
      const _Heading('Lounge corner'),
      _Corner(holdem: holdem),
    ];
    final right = [
      const _Heading('Your poker'),
      _Record(account: account),
      const SizedBox(height: 18),
      const _Heading('Rivals'),
      _Rivals(account: account),
      const SizedBox(height: 18),
      _Heading('Achievements  ${account.earned.length} / ${Achievement.values.length}'),
      _Achievements(account: account),
    ];
    return Scaffold(
      backgroundColor: Lounge.navy,
      body: DefaultTextStyle.merge(
        style: const TextStyle(color: Lounge.cream),
        child: Container(
          // The lamp over the table.
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -1.1),
              radius: 1.3,
              colors: [Color(0xFF2B3F6B), Lounge.navy, Lounge.night],
              stops: [0, 0.55, 1],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, box) {
                if (box.maxWidth > box.maxHeight * 1.15 && box.maxWidth >= 600) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 8, 24), children: left),
                      ),
                      Expanded(
                        child: ListView(padding: const EdgeInsets.fromLTRB(8, 12, 16, 24), children: right),
                      ),
                    ],
                  );
                }
                return ListView(
                  key: const Key('lounge'),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [...left, const SizedBox(height: 18), ...right],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Text(
          text,
          style: Toon.text(20, weight: FontWeight.w700, color: Lounge.gold),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 2, color: Lounge.gold.withValues(alpha: 0.35))),
      ],
    ),
  );
}

/// A card in the lounge: dark panel, gold rim.
class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(12)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Lounge.panel,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Lounge.gold.withValues(alpha: 0.55), width: 2),
      boxShadow: const [BoxShadow(color: Lounge.night, offset: Offset(0, 4))],
    ),
    child: child,
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      ToonButton(
        key: const Key('lounge back'),
        color: Lounge.panel,
        padding: const EdgeInsets.all(8),
        tooltip: 'Back to the games',
        onPressed: () => Navigator.of(context).pop(),
        child: const Icon(Icons.arrow_back_rounded, size: 24, color: Lounge.cream),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Poker Lounge',
              style: Toon.text(28, weight: FontWeight.w700, color: Lounge.gold),
            ),
            Text(
              "Texas Hold'em, every way",
              style: Toon.text(14, weight: FontWeight.w500, color: Lounge.dim),
            ),
          ],
        ),
      ),
      Container(
        key: const Key('lounge balance'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Lounge.night,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Lounge.gold, width: 2),
        ),
        child: Text(
          account.money(account.balance),
          style: Toon.text(15, weight: FontWeight.w700, color: Lounge.lamp),
        ),
      ),
    ],
  );
}

/// The four ways to play: Sit & Go opens its preview (bots or your party);
/// the rest show what they'll be.
class _Modes extends StatelessWidget {
  const _Modes({required this.holdem, required this.setup});

  final GameInfo holdem;
  final PlaySetup setup;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final cols = box.maxWidth >= 520 ? 4 : 2;
      final w = (box.maxWidth - (cols - 1) * 10) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final m in LoungeMode.all)
            SizedBox(
              width: w,
              child: _ModeCard(
                mode: m,
                badge: m.open ? holdem.blocked(setup)?.$1 : 'Soon',
                onTap: () {
                  Sound.play(Sfx.tap, gain: 0.6);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => m.open ? GamePreviewScreen(game: holdem) : LoungeModeScreen(mode: m),
                    ),
                  );
                },
              ),
            ),
        ],
      );
    },
  );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode, required this.onTap, this.badge});

  final LoungeMode mode;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${mode.name}${badge == null ? '' : ', $badge'}',
    child: GestureDetector(
      key: Key('lounge ${mode.id}'),
      onTap: onTap,
      child: Container(
        height: 150,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: mode.open ? Lounge.felt : Lounge.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: mode.open ? Lounge.gold : mode.color.withValues(alpha: 0.7), width: 2.5),
          boxShadow: const [BoxShadow(color: Lounge.night, offset: Offset(0, 4))],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: mode.open ? Lounge.gold : mode.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Lounge.night, width: 2.5),
                  ),
                  child: Icon(mode.icon, size: 26, color: Lounge.night),
                ),
                const Spacer(),
                Text(
                  mode.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Toon.text(17, weight: FontWeight.w700, color: Lounge.cream),
                ),
                const SizedBox(height: 2),
                Text(
                  mode.tagline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Toon.text(12, weight: FontWeight.w500, color: Lounge.dim),
                ),
              ],
            ),
            if (badge != null)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: Lounge.gold, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    badge!,
                    style: Toon.text(11, weight: FontWeight.w700, color: Lounge.night),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Your Hold'em record (every Sit & Go, bots and online).
class _Record extends StatelessWidget {
  const _Record({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final s = account.stats('holdem');
    final rate = s.played == 0 ? '–' : '${(100 * s.won / s.played).round()}%';
    var best = (name: '', diff: -1 << 30);
    for (final r in Rival.all) {
      final rec = account.rivalRecord(r.name);
      if (rec.wins + rec.losses > 0 && rec.wins - rec.losses > best.diff) {
        best = (name: r.name, diff: rec.wins - rec.losses);
      }
    }
    Widget number(String value, String label, {Color color = Lounge.cream}) => Expanded(
      child: Column(
        children: [
          FittedBox(
            child: Text(
              value,
              style: Toon.text(20, weight: FontWeight.w800, color: color),
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Toon.text(11, weight: FontWeight.w600, color: Lounge.dim),
          ),
        ],
      ),
    );
    return _Panel(
      child: Column(
        children: [
          Row(
            key: const Key('lounge record'),
            children: [
              number('${s.played}', 'games'),
              number('${s.won}', 'wins'),
              number(rate, 'win rate'),
              number(
                s.net == 0 ? '–' : '${s.net > 0 ? '+' : '−'}${chips(s.net.abs())}',
                'pips won',
                color: s.net > 0 ? Toon.green : (s.net < 0 ? Lounge.ruby : Lounge.cream),
              ),
            ],
          ),
          if (best.name.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              best.diff > 0
                  ? 'You have ${best.name}\'s number.'
                  : best.diff == 0
                  ? 'Dead even with ${best.name}.'
                  : '${best.name} has your number. For now.',
              style: Toon.text(13, weight: FontWeight.w500, color: Lounge.lamp),
            ),
          ],
        ],
      ),
    );
  }
}

/// The rivals' board, best record first.
class _Rivals extends StatelessWidget {
  const _Rivals({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final list = [...Rival.all]
      ..sort((a, b) {
        final ra = account.rivalRecord(a.name), rb = account.rivalRecord(b.name);
        return (rb.wins - rb.losses).compareTo(ra.wins - ra.losses);
      });
    return _Panel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        key: const Key('lounge rivals'),
        children: [
          for (final r in list)
            () {
              final rec = account.rivalRecord(r.name);
              final met = rec.wins + rec.losses > 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Face(r.persona, size: 38),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.name,
                            style: Toon.text(16, weight: FontWeight.w700, color: Lounge.cream),
                          ),
                          Text(
                            met ? 'Plays like a ${r.style.label}' : 'Sits in at a Sit & Go soon',
                            style: Toon.text(12, weight: FontWeight.w500, color: Lounge.dim),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      met ? '${rec.wins}–${rec.losses}' : '–',
                      style: Toon.text(
                        18,
                        weight: FontWeight.w800,
                        color: !met || rec.wins == rec.losses
                            ? Lounge.dim
                            : (rec.wins > rec.losses ? Toon.green : Lounge.ruby),
                      ),
                    ),
                  ],
                ),
              );
            }(),
        ],
      ),
    );
  }
}

class _Achievements extends StatelessWidget {
  const _Achievements({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final a in Achievement.values)
        () {
          final earned = account.earned.containsKey(a);
          return Container(
            key: Key('achievement ${a.name}'),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: earned ? Lounge.gold : Lounge.panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: earned ? Lounge.lamp : Lounge.gold.withValues(alpha: 0.3), width: 2),
            ),
            child: Row(
              children: [
                Icon(
                  earned ? Icons.emoji_events_rounded : Icons.lock_rounded,
                  size: 22,
                  color: earned ? Lounge.night : Lounge.dim,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        style: Toon.text(
                          15,
                          weight: FontWeight.w700,
                          color: earned ? Lounge.night : Lounge.cream,
                        ),
                      ),
                      Text(
                        a.text,
                        style: Toon.text(
                          12,
                          weight: FontWeight.w500,
                          color: earned ? Lounge.night : Lounge.dim,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }(),
    ],
  );
}

/// Things to read between games: the hands, learning at home, and a tip
/// that changes every day.
class _Corner extends StatelessWidget {
  const _Corner({required this.holdem});

  final GameInfo holdem;

  static const tips = [
    'Position is power: the later you act, the more hands you can play.',
    'Fold more before the flop than feels natural. Most hands lose money.',
    'Raise or fold before the flop; just calling lets everyone in cheaply.',
    'Bet about half to three quarters of the pot: big enough to matter, small enough to risk.',
    'A bluff needs a story. Bet like you have the hand the board shows.',
    'Short stack (under 10 big blinds)? Push or fold, nothing in between.',
    'Watch how long the bots take. Some think hard only when they\'re strong.',
    'The Rock rarely bluffs: when it bets big, believe it.',
    'Against a Maniac, let it bet into you and call down with good hands.',
    'Count your outs: about 4% each with two cards to come, 2% with one.',
    'Pot odds: if a call is a quarter of the final pot, you need to win one time in four.',
    'Don\'t chase every draw. Only call when the price is right.',
    'After a bad beat, take a breath. Tilt costs more chips than bad luck.',
    'Show a bluff now and then: the bots will call you lighter next time.',
    'Pocket pairs flop a set about one time in eight.',
  ];

  @override
  Widget build(BuildContext context) {
    final day = DateTime.now().difference(DateTime(2026)).inDays;
    Widget button(String key, IconData icon, String label, VoidCallback onTap) => Expanded(
      child: ToonButton(
        key: Key(key),
        color: Lounge.panel,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        onPressed: onTap,
        child: Column(
          children: [
            Icon(icon, size: 24, color: Lounge.gold),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(label, maxLines: 1, style: Toon.text(14, color: Lounge.cream)),
            ),
          ],
        ),
      ),
    );
    return Column(
      children: [
        _Panel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_rounded, color: Lounge.lamp, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tip of the day',
                      style: Toon.text(15, weight: FontWeight.w700, color: Lounge.lamp),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tips[day % tips.length],
                      key: const Key('lounge tip'),
                      style: Toon.text(14, weight: FontWeight.w500, color: Lounge.cream),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            button(
              'lounge hands',
              Icons.format_list_numbered_rounded,
              'The hands',
              () => showHandChart(context),
            ),
            const SizedBox(width: 10),
            button(
              'lounge at home',
              Icons.home_rounded,
              'Play at home',
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      HomeGuideScreen(name: holdem.name, color: holdem.color, guide: holdem.atHome),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
