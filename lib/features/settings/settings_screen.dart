import 'package:flutter/material.dart';

import '../../core/account/account.dart';
import '../../core/app_info.dart';
import '../../core/theme/split_page.dart';
import '../../core/theme/toon.dart';
import '../home/home_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
              Text('Settings', style: Toon.text(26, weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 20),
          Text('Look', style: Toon.text(18, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final t in ThemeChoice.values) ...[
                if (t != ThemeChoice.values.first) const SizedBox(width: 8),
                Expanded(
                  child: ToonButton(
                    key: Key('theme ${t.name}'),
                    color: account.theme == t ? Toon.yellow : Toon.card,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    onPressed: () => account.theme = t,
                    child: Column(
                      children: [
                        Icon(switch (t) {
                          ThemeChoice.system => Icons.brightness_auto_rounded,
                          ThemeChoice.light => Icons.light_mode_rounded,
                          ThemeChoice.dark => Icons.dark_mode_rounded,
                        }),
                        const SizedBox(height: 2),
                        FittedBox(
                          child: Text(
                            t.label,
                            style: Toon.text(
                              15,
                              color: Toon.on(account.theme == t ? Toon.yellow : Toon.card),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          Text('How money works', style: Toon.text(18, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'Free games win nothing. Stake on a game and a win pays your stake back plus stake × opponents '
            '(Easy bots pay half, Hard bots one and a half). A loss, or leaving early, costs the stake. '
            'Out of money? You can always stake 1; it goes on your debt, which winnings pay off.',
            style: Toon.text(15, weight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
          ToonButton(
            key: const Key('about'),
            color: Toon.card,
            onPressed: () => showAboutSheet(context),
            child: const Text('About ${AppInfo.name} ${AppInfo.version}'),
          ),
          const SizedBox(height: 24),
        ],
        right: [
          Text('Money shown as', style: Toon.text(18, weight: FontWeight.w700)),
          Text(
            'Display only: one pip is one dollar, one euro, one yen.',
            style: Toon.text(14, weight: FontWeight.w500, color: Toon.muted),
          ),
          const SizedBox(height: 8),
          for (final c in CurrencyChoice.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ToonButton(
                key: Key('currency ${c.name}'),
                color: account.currency == c ? Toon.yellow : Toon.card,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                onPressed: () => account.currency = c,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        c == CurrencyChoice.pips ? 'Pips (Duel’s own)' : c.label,
                        textAlign: TextAlign.start,
                        style: Toon.text(16, color: Toon.on(account.currency == c ? Toon.yellow : Toon.card)),
                      ),
                    ),
                    Text(
                      c.format(1240),
                      style: Toon.text(
                        16,
                        weight: FontWeight.w700,
                        color: Toon.on(account.currency == c ? Toon.yellow : Toon.card),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
