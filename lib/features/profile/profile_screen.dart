import 'package:flutter/material.dart';

import '../../core/account/account.dart';
import '../../core/avatars/faces.dart';
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
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
                child: Face(account.persona, size: 104),
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
            Text('Face', style: Toon.text(16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final (i, (look, skin)) in avatars.indexed)
                  GestureDetector(
                    key: Key('avatar $i'),
                    onTap: () => account.avatar = i,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: account.avatar == i ? Toon.yellow : Toon.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: Toon.ink, width: 2.5),
                      ),
                      child: Face(Persona(name: '', look: look, skin: skin), size: 54),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _Wallet(account: account),
            const SizedBox(height: 20),
            Text('Your games', style: Toon.text(20, weight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final g in games.where((g) => g.available))
              _StatsRow(game: g, stats: account.stats(g.id), account: account),
          ],
        ),
      ),
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
