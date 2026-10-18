import 'package:flutter/material.dart';

import '../../core/account/account.dart';
import '../../core/app_info.dart';
import '../../core/avatars/faces.dart';
import '../../core/online/party.dart';
import '../../core/session/play_setup.dart';
import '../../core/theme/toon.dart';
import '../../games/catalog.dart';
import '../preview/game_preview_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';
import 'connection_bar.dart';

/// The connection bar, then the games. Games that don't fit the table
/// (you + bots, or your party) are greyed out.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final setup = PlaySetupScope.of(context);
    final header = [
      const _TopBar(),
      const SizedBox(height: 12),
      const ConnectionBar(),
      const SizedBox(height: 18),
      Text('Pick a game', style: Toon.text(26, weight: FontWeight.w700)),
      Text(
        setup.mode == PlayMode.bots
            ? 'You + ${setup.botCount} ${setup.botCount == 1 ? 'bot' : 'bots'} · ${setup.players} players'
            : setup.partySize < 2
            ? 'Party of ${setup.partySize}: invite a friend to play'
            : 'Party of ${setup.partySize} · ${setup.party!.isHost ? 'you pick the game' : '${setup.party!.hostName} picks the game'}',
        style: Toon.text(15, weight: FontWeight.w500, color: Toon.muted),
      ),
      const SizedBox(height: 12),
    ];
    // Landscape tiles are squarer so two rows fit the short screen.
    Widget grid(
      double width, {
      EdgeInsets padding = const EdgeInsets.fromLTRB(16, 0, 16, 24),
      bool wide = false,
    }) => SliverPadding(
      padding: padding,
      sliver: SliverGrid.count(
        crossAxisCount: ((width - 32) / (wide ? 150 : 200)).floor().clamp(2, 4),
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: wide ? 1.0 : 0.82,
        children: [for (final g in games) _GameTile(game: g, setup: setup)],
      ),
    );
    return _MatchWatcher(
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              // On its side: you and the connection bar on the left, the
              // games on the right.
              if (box.maxWidth > box.maxHeight * 1.15 && box.maxWidth >= 600) {
                final side = (box.maxWidth * 0.42).clamp(340.0, 400.0);
                return Row(
                  children: [
                    SizedBox(
                      width: side,
                      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 8, 16), children: header),
                    ),
                    Expanded(
                      child: CustomScrollView(
                        slivers: [
                          grid(
                            box.maxWidth - side,
                            padding: const EdgeInsets.fromLTRB(8, 14, 16, 24),
                            wide: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverList.list(children: header),
                  ),
                  grid(box.maxWidth),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Your profile (face, name, money) and the settings gear.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: ToonButton(
              key: const Key('profile'),
              color: Toon.card,
              padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
              tooltip: 'Profile',
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen())),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Face(account.persona, size: 40),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Toon.text(16),
                        ),
                        Text(
                          account.inDebt
                              ? 'Debt ${account.money(-account.balance)}'
                              : account.money(account.balance),
                          style: Toon.text(
                            14,
                            weight: FontWeight.w700,
                            color: account.inDebt ? Toon.red : Toon.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        ToonButton(
          key: const Key('settings'),
          color: Toon.card,
          padding: const EdgeInsets.all(10),
          tooltip: 'Settings',
          onPressed: () =>
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
          child: const Icon(Icons.settings_rounded, size: 26),
        ),
      ],
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({required this.game, required this.setup});

  final GameInfo game;
  final PlaySetup setup;

  @override
  Widget build(BuildContext context) {
    final blocked = game.blocked(setup);
    final playable = blocked == null;
    final why = blocked?.$1;

    // Every game opens its preview first; only Play! there starts it.
    void tap() =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GamePreviewScreen(game: game)));

    return Semantics(
      button: true,
      enabled: playable,
      label: '${game.name}, ${game.playersLabel}${why == null ? '' : ', $why'}',
      child: GestureDetector(
        onTap: tap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: playable ? 1 : 0.5,
          child: ToonBox(
            color: playable ? game.color : Toon.grey,
            padding: const EdgeInsets.all(10),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Toon.paper.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        // The picture grows with the tile.
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: FittedBox(child: game.art(context)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      game.name,
                      style: Toon.text(17, weight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(game.playersLabel, style: Toon.text(13, weight: FontWeight.w500)),
                  ],
                ),
                if (why != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: Toon.box(Toon.card, radius: 8, shadow: 2),
                      child: Text(why, style: Toon.text(12)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Version and what's new in each version.
void showAboutSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Toon.paper,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          Text('${AppInfo.name} ${AppInfo.version}', style: Toon.text(22, weight: FontWeight.w700)),
          const SizedBox(height: 12),
          for (final (version, notes) in AppInfo.revisions) ...[
            Text(version, style: Toon.text(16)),
            for (final note in notes) Text('• $note', style: Toon.text(15, weight: FontWeight.w500)),
            const SizedBox(height: 8),
          ],
        ],
      ),
    ),
  );
}

/// When the host starts a game, every phone in the party goes to it (over
/// whatever screen is open), once.
class _MatchWatcher extends StatefulWidget {
  const _MatchWatcher({required this.child});

  final Widget child;

  @override
  State<_MatchWatcher> createState() => _MatchWatcherState();
}

class _MatchWatcherState extends State<_MatchWatcher> {
  PartyService? _party;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Depends on the scope: online can come up after home is showing.
    final party = PartyScope.of(context);
    if (party == _party) return;
    _party?.removeListener(_check);
    _party = party?..addListener(_check);
    _check();
  }

  @override
  void dispose() {
    _party?.removeListener(_check);
    super.dispose();
  }

  void _check() {
    final party = _party;
    if (party == null || !party.playing || party.onScreen || party.seat < 0) return;
    final game = games.where((g) => g.id == party.match!['game']).firstOrNull;
    final open = game?.openOnline;
    if (open == null) return;
    party.onScreen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PlaySetupScope.read(context)?.mode = PlayMode.friends;
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => open(party)));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
