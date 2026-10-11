import 'package:flutter/material.dart';

import '../../core/account/account.dart';
import '../../core/avatars/faces.dart';
import '../../core/theme/split_page.dart';
import '../../core/theme/toon.dart';
import '../../games/catalog.dart';

/// Your name, your face, your money and how each game has gone.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _name = TextEditingController(text: AccountScope.read(context).name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    return Scaffold(
      body: SplitPage(
        left: [
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
              Text('Profile', style: Toon.text(26, weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Toon.card,
                shape: BoxShape.circle,
                border: Border.all(color: Toon.ink, width: 3),
                boxShadow: [BoxShadow(color: Toon.ink, offset: const Offset(0, 4))],
              ),
              child: TweenAnimationBuilder<double>(
                key: ValueKey(account.avatar),
                tween: Tween(begin: 0.85, end: 1),
                duration: const Duration(milliseconds: 380),
                curve: Curves.elasticOut,
                builder: (context, t, child) => Transform.scale(scale: t, child: child),
                child: Face(account.persona, size: 104),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text('Name', style: Toon.text(16)),
          const SizedBox(height: 6),
          ToonBox(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shadow: 3,
            child: TextField(
              key: const Key('name'),
              controller: _name,
              maxLength: 14,
              textCapitalization: TextCapitalization.words,
              style: Toon.text(20),
              cursorColor: Toon.fg,
              decoration: const InputDecoration(
                border: InputBorder.none,
                counterText: '',
                hintText: 'Your name',
              ),
              onChanged: (v) => account.name = v,
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 16),
        ],
        right: [
          _AvatarPicker(account: account),
          const SizedBox(height: 10),
        ],
        after: [
          _Wallet(account: account),
          const SizedBox(height: 20),
          Text('Your games', style: Toon.text(20, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final g in games.where((g) => g.available))
            _StatsRow(game: g, stats: account.stats(g.id), account: account),
        ],
      ),
    );
  }
}

/// Build your face: four of each part (more unlock later).
class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final a = account.avatar;
    Widget row(String label, String key, List<Avatar> options) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Toon.text(16)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final (i, o) in options.indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _PartTile(
                    key: Key('$key $i'),
                    avatar: o,
                    selected: o == a,
                    onTap: () => account.avatar = o,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
    const n = Avatar.choices;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row('Colour', 'color', [for (final c in AvatarColor.values.take(n)) a.copyWith(color: c)]),
        row('Shape', 'shape', [for (final s in HeadShape.values.take(n)) a.copyWith(shape: s)]),
        row('Face', 'face', [for (final f in Expression.values.take(n)) a.copyWith(face: f)]),
        row('Hat', 'hat', [for (final h in Hat.values.take(n)) a.copyWith(hat: h)]),
      ],
    );
  }
}

class _PartTile extends StatelessWidget {
  const _PartTile({super.key, required this.avatar, required this.selected, required this.onTap});

  final Avatar avatar;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 72,
      transform: Matrix4.translationValues(0, selected ? 2 : 0, 0),
      decoration: Toon.box(selected ? Toon.yellow : Toon.card, radius: 16, shadow: selected ? 1 : 3),
      alignment: Alignment.center,
      child: LayoutBuilder(
        builder: (context, box) => Face.of(avatar, size: (box.maxWidth - 16).clamp(30, 56)),
      ),
    ),
  );
}

class _Wallet extends StatelessWidget {
  const _Wallet({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final debt = account.inDebt;
    return ToonBox(
      color: debt ? Toon.red : Toon.yellow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(debt ? 'In debt' : 'Balance', style: Toon.text(14, color: Toon.inkLight)),
          Text(
            account.money(debt ? -account.balance : account.balance),
            key: const Key('balance'),
            style: Toon.text(30, weight: FontWeight.w700, color: Toon.inkLight),
          ),
          const SizedBox(height: 4),
          Text(
            debt
                ? 'You can still stake 1 at a time. Winnings pay the debt off first, no rush.'
                : 'Stake some on a game to win more. Free games win nothing.',
            style: Toon.text(14, weight: FontWeight.w500, color: Toon.inkLight),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.game, required this.stats, required this.account});

  final GameInfo game;
  final GameStats stats;
  final Account account;

  @override
  Widget build(BuildContext context) {
    final rate = stats.played == 0 ? '–' : '${(100 * stats.won / stats.played).round()}%';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ToonBox(
        padding: const EdgeInsets.all(10),
        shadow: 3,
        child: Row(
          children: [
            Container(
              width: 12,
              height: 40,
              decoration: BoxDecoration(color: game.color, borderRadius: BorderRadius.circular(6)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(game.name, style: Toon.text(16, weight: FontWeight.w700)),
                  Text(
                    '${stats.played} played · ${stats.won} won${stats.tied > 0 ? ' · ${stats.tied} tied' : ''} · $rate',
                    style: Toon.text(13, weight: FontWeight.w500, color: Toon.muted),
                  ),
                ],
              ),
            ),
            Text(
              stats.net == 0 ? '–' : '${stats.net > 0 ? '+' : ''}${account.money(stats.net)}',
              style: Toon.text(
                15,
                weight: FontWeight.w700,
                color: stats.net > 0 ? Toon.green : (stats.net < 0 ? Toon.red : Toon.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
