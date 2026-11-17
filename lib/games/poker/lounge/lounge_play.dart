import 'package:flutter/material.dart';

import 'package:duel_engine/poker/tournament.dart';

import '../../../core/account/account.dart';
import '../../../core/account/stake.dart';
import '../../../core/avatars/faces.dart';
import '../../../core/sound/sound.dart';
import '../../../core/theme/toon.dart';
import '../ui/lounge_games.dart';
import '../ui/poker_screen.dart';
import 'lounge_modes.dart';

/// Opens a lounge game: a new one ([stake] taken now), or the saved one.
Future<void> openLoungeGame(BuildContext context, LoungeGame game, {int? stake, double pace = 1}) {
  final account = AccountScope.read(context);
  final ticket = stake == null
      ? null
      : StakeTicket(
          account: account,
          gameId: game.gameId,
          stake: account.placeStake(stake),
          opponents: game.boss != null ? 3 : tournamentPlayers - 1,
          difficulty: game.boss?.tableDifficulty ?? game.tier!.difficulty,
        );
  if (game.tier == TournamentTier.freeroll && game.saved == null) account.enterFreeroll();
  Sound.play(Sfx.tap, gain: 0.6);
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PokerScreen.lounge(lounge: game, stake: ticket, pace: pace),
    ),
  );
}

/// The Tournament page: pick a buy-in.
class TournamentScreen extends StatelessWidget {
  const TournamentScreen({super.key, this.pace = 1});

  final double pace;

  @override
  Widget build(BuildContext context) => LoungeModeScreen(
    mode: LoungeMode.tournament,
    play: _Tiers(pace: pace),
  );
}

/// The Boss Tables page: the ladder.
class BossTablesScreen extends StatelessWidget {
  const BossTablesScreen({super.key, this.pace = 1});

  final double pace;

  @override
  Widget build(BuildContext context) => LoungeModeScreen(
    mode: LoungeMode.bosses,
    play: _Ladder(pace: pace),
  );
}

TextStyle _text(double size, {FontWeight weight = FontWeight.w600, Color color = Lounge.cream}) =>
    TextStyle(fontFamily: 'Fredoka', fontSize: size, fontWeight: weight, color: color, height: 1.3);

/// A row to pick: a face or icon, name and details, and its button (or why
/// not).
class _Row extends StatelessWidget {
  const _Row({
    required this.id,
    required this.leading,
    required this.name,
    required this.lines,
    required this.button,
    required this.onPlay,
    this.locked = false,
    this.done = false,
    this.color = Lounge.gold,
  });

  final String id;
  final Widget leading;
  final String name;
  final List<String> lines;
  final String button;
  final VoidCallback? onPlay;
  final bool locked, done;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    key: Key('lounge row $id'),
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Lounge.night,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: done ? Lounge.gold : color.withValues(alpha: locked ? 0.25 : 0.6), width: 2),
    ),
    child: Row(
      children: [
        Opacity(opacity: locked ? 0.45 : 1, child: leading),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      style: _text(17, weight: FontWeight.w700, color: locked ? Lounge.dim : Lounge.lamp),
                    ),
                  ),
                  if (done) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.emoji_events_rounded, size: 18, color: Lounge.gold),
                  ],
                ],
              ),
              for (final l in lines)
                Text(
                  l,
                  style: _text(13, weight: FontWeight.w500, color: Lounge.dim),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: ToonButton(
            key: Key('play $id'),
            color: onPlay == null ? Lounge.panel : Lounge.gold,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            onPressed: onPlay,
            child: Text(
              button,
              textAlign: TextAlign.center,
              style: _text(14, weight: FontWeight.w700, color: onPlay == null ? Lounge.dim : Lounge.night),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Tiers extends StatelessWidget {
  const _Tiers({required this.pace});

  final double pace;

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    final busy = account.loungeGame != null;
    final mainOpen = account.tourneyRecord(TournamentTier.regular.name).cashes > 0;
    return Column(
      key: const Key('tournament tiers'),
      children: [
        ContinueLoungeGame(pace: pace),
        for (final tier in TournamentTier.values)
          () {
            final rec = account.tourneyRecord(tier.name);
            final locked = tier == TournamentTier.main && !mainOpen;
            final today = tier == TournamentTier.freeroll && account.freerollPlayed;
            final short = account.balance < tier.buyIn;
            final why = busy
                ? 'Finish your game first'
                : locked
                ? 'Cash in a Regular first'
                : today
                ? 'Back tomorrow'
                : short
                ? 'Not enough ${account.currency.noun}'
                : null;
            return _Row(
              id: tier.name,
              color: Lounge.sky,
              locked: locked,
              done: rec.wins > 0,
              leading: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Lounge.sky,
                  shape: BoxShape.circle,
                  border: Border.all(color: Lounge.night, width: 2.5),
                ),
                child: const Icon(Icons.emoji_events_rounded, color: Lounge.night),
              ),
              name: tier.label,
              lines: [
                '${tier.buyIn == 0 ? 'Free' : 'Buy-in ${account.money(tier.buyIn)}'} · pool ${account.money(tier.pool)}',
                'Top 3: ${[for (var p = 1; p <= 3; p++) account.money(Tournament.prize(tier.pool, p))].join(' / ')}',
                if (rec.played > 0)
                  'Played ${rec.played} · in the money ${rec.cashes} · best ${_ordinal(rec.best)}'
                else if (tier == TournamentTier.freeroll)
                  'Once a day'
                else if (locked)
                  'Unlocks once you finish top 3 in a Regular',
              ],
              button: why ?? (tier.buyIn == 0 ? 'Play free' : 'Buy in'),
              onPlay: why != null
                  ? null
                  : () => openLoungeGame(context, LoungeGame.tournament(tier), stake: tier.buyIn, pace: pace),
            );
          }(),
      ],
    );
  }
}

class _Ladder extends StatelessWidget {
  const _Ladder({required this.pace});

  final double pace;

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    final busy = account.loungeGame != null;
    return Column(
      key: const Key('boss ladder'),
      children: [
        ContinueLoungeGame(pace: pace),
        for (final b in Boss.ladder)
          () {
            final rec = account.rivalRecord(b.name);
            final beaten = account.bossesBeaten > b.rung;
            final locked = b.rung > account.bossesBeaten;
            final short = account.balance < b.stake;
            final why = busy
                ? 'Finish your game first'
                : locked
                ? 'Locked'
                : short
                ? 'Not enough ${account.currency.noun}'
                : null;
            return _Row(
              id: 'boss ${b.rung}',
              color: Lounge.ruby,
              locked: locked,
              done: beaten,
              leading: Face(b.rival.persona, size: 46),
              name: '${b.rung + 1}. ${b.name}',
              lines: [
                b.habit,
                'Stake ${account.money(b.stake)} · beat them for ${account.money(b.prize)}',
                if (rec.wins + rec.losses > 0)
                  'You ${rec.wins}–${rec.losses} ${b.name}'
                else if (locked)
                  'Beat ${Boss.ladder[b.rung - 1].name} to unlock',
              ],
              button: why ?? (beaten ? 'Rematch' : 'Challenge'),
              onPlay: why != null
                  ? null
                  : () => openLoungeGame(context, LoungeGame.boss(b), stake: b.stake, pace: pace),
            );
          }(),
      ],
    );
  }
}

/// "Continue" for the lounge game left mid-way (the app closed): on the
/// lounge and on its mode's page.
class ContinueLoungeGame extends StatelessWidget {
  const ContinueLoungeGame({super.key, this.pace = 1});

  final double pace;

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    final game = LoungeGame.fromSave(account.loungeGame);
    if (game == null) return const SizedBox.shrink();
    final left = game.tier != null && game.saved != null ? Tournament.fromJson(game.saved!).left : null;
    return Container(
      key: const Key('lounge continue'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Lounge.felt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Lounge.gold, width: 2.5),
        boxShadow: const [BoxShadow(color: Lounge.night, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          if (game.boss case final b?)
            Face(b.rival.persona, size: 44)
          else
            const Icon(Icons.emoji_events_rounded, color: Lounge.gold, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Game in progress', style: _text(13, color: Lounge.lamp)),
                Text(
                  game.boss != null ? 'vs ${game.label}' : game.label,
                  style: _text(17, weight: FontWeight.w700),
                ),
                if (left != null) Text('$left players left', style: _text(13, color: Lounge.dim)),
              ],
            ),
          ),
          ToonButton(
            key: const Key('continue lounge game'),
            color: Lounge.gold,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            onPressed: () => openLoungeGame(context, game, pace: pace),
            child: Text(
              'Continue',
              style: _text(15, weight: FontWeight.w700, color: Lounge.night),
            ),
          ),
        ],
      ),
    );
  }
}

/// The trophy shelf: a trophy for each boss beaten and each tournament
/// you've finished in the money (gold, silver, bronze: your best).
class TrophyShelf extends StatelessWidget {
  const TrophyShelf({super.key});

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    Widget slot({required Widget child, required String label, required bool lit, Key? key}) => SizedBox(
      key: key,
      width: 64,
      child: Column(
        children: [
          Opacity(opacity: lit ? 1 : 0.3, child: child),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: _text(10, weight: FontWeight.w600, color: lit ? Lounge.lamp : Lounge.dim),
          ),
        ],
      ),
    );
    Color medal(int best) => switch (best) {
      1 => Lounge.gold,
      2 => const Color(0xFFD7DEE8),
      3 => const Color(0xFFD08A4E),
      _ => Lounge.dim,
    };
    return Container(
      key: const Key('trophy shelf'),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
      decoration: BoxDecoration(
        color: Lounge.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Lounge.gold.withValues(alpha: 0.55), width: 2),
        boxShadow: const [BoxShadow(color: Lounge.night, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            runSpacing: 8,
            children: [
              for (final b in Boss.ladder)
                slot(
                  key: Key('trophy ${b.rung}'),
                  lit: account.bossesBeaten > b.rung,
                  label: b.name,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Face(b.rival.persona, size: 40),
                      if (account.bossesBeaten > b.rung)
                        const Icon(Icons.emoji_events_rounded, size: 18, color: Lounge.gold),
                    ],
                  ),
                ),
              for (final t in TournamentTier.values)
                () {
                  final best = account.tourneyRecord(t.name).best;
                  final cashed = best >= 1 && best <= 3;
                  return slot(
                    key: Key('trophy ${t.name}'),
                    lit: cashed,
                    label: t.label,
                    child: Icon(
                      Icons.emoji_events_rounded,
                      size: 40,
                      color: cashed ? medal(best) : Lounge.dim,
                    ),
                  );
                }(),
            ],
          ),
          // A plank under the trophies.
          Container(
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: const Color(0xFF6B4A2B), borderRadius: BorderRadius.circular(3)),
          ),
        ],
      ),
    );
  }
}

String _ordinal(int n) => switch (n) {
  1 => '1st',
  2 => '2nd',
  3 => '3rd',
  _ => '${n}th',
};
