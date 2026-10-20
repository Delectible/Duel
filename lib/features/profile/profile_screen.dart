import 'dart:math';

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

/// Build your face: a tab per part, every option drawn on your own face
/// (tap to wear it), and Surprise me.
class _AvatarPicker extends StatefulWidget {
  const _AvatarPicker({required this.account});

  final Account account;

  @override
  State<_AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<_AvatarPicker> {
  var _part = FacePart.color;

  static const _tabs = <(FacePart, String, IconData, List<Enum>)>[
    (FacePart.color, 'Skin', Icons.palette_rounded, AvatarColor.values),
    (FacePart.shape, 'Head', Icons.circle_outlined, HeadShape.values),
    (FacePart.eyes, 'Eyes', Icons.visibility_rounded, Eyes.values),
    (FacePart.nose, 'Nose', Icons.water_drop_rounded, Nose.values),
    (FacePart.mouth, 'Mouth', Icons.mood_rounded, Mouth.values),
    (FacePart.hat, 'Hair & hats', Icons.checkroom_rounded, Hat.values),
    (FacePart.extra, 'Extras', Icons.auto_awesome_rounded, Extra.values),
  ];

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final a = account.avatar;
    final (_, _, _, values) = _tabs.firstWhere((t) => t.$1 == _part);
    // Close-ups for the small parts; the whole face for the rest.
    final closeUp = const {FacePart.eyes, FacePart.nose, FacePart.mouth}.contains(_part);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Your face', style: Toon.text(20, weight: FontWeight.w700)),
            ),
            ToonButton(
              key: const Key('surprise me'),
              color: Toon.yellow,
              radius: 12,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              onPressed: () => account.avatar = Avatar.random(Random()),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.casino_rounded, size: 20),
                  const SizedBox(width: 6),
                  Text('Surprise me', style: Toon.text(15)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (part, label, icon, _) in _tabs)
              ToonButton(
                key: Key('tab ${part.name}'),
                color: part == _part ? Toon.yellow : Toon.card,
                radius: 12,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                onPressed: () => setState(() => _part = part),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: Toon.on(part == _part ? Toon.yellow : Toon.card)),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: Toon.text(14, color: Toon.on(part == _part ? Toon.yellow : Toon.card)),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, box) {
            final cols = max(4, (box.maxWidth / 84).floor());
            final size = (box.maxWidth - 8 * (cols - 1)) / cols;
            return Wrap(
              key: Key('grid ${_part.name}'),
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in values)
                  () {
                    final option = a.withPart(_part, v);
                    final on = a.partValue(_part) == v;
                    return GestureDetector(
                      key: Key('pick ${_part.name} ${v.name}'),
                      onTap: () => account.avatar = option,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: size,
                        height: size,
                        padding: const EdgeInsets.all(4),
                        decoration: Toon.box(on ? Toon.yellow : Toon.card, radius: 14, shadow: on ? 0 : 3),
                        child: Semantics(
                          label: v.name,
                          selected: on,
                          child: Stack(
                            children: [
                              if (closeUp)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Face.part(option, _part, size: size - 8),
                                )
                              else
                                Face.of(option, size: size - 8),
                              if (v.name == 'none')
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5),
                                    decoration: Toon.box(Toon.paper, radius: 6, shadow: 0),
                                    child: Text('None', style: Toon.text(10)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }(),
              ],
            );
          },
        ),
      ],
    );
  }
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
