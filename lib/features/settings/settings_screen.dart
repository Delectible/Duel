import 'package:flutter/material.dart';

import '../../core/account/account.dart';
import '../../core/account/stake.dart';
import '../../core/app_info.dart';
import '../../core/theme/split_page.dart';
import '../../core/theme/toon.dart';
import '../home/home_screen.dart';
import '../../core/sound/sound.dart';

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
          const SizedBox(height: 16),
          Text('Sound', style: Toon.text(18, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          ToonButton(
            key: const Key('sound'),
            color: account.sound ? Toon.yellow : Toon.card,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            onPressed: () => account.sound = !account.sound,
            child: Row(
              children: [
                Icon(account.sound ? Icons.volume_up_rounded : Icons.volume_off_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sound effects',
                    textAlign: TextAlign.start,
                    style: Toon.text(16, color: Toon.on(account.sound ? Toon.yellow : Toon.card)),
                  ),
                ),
                Text(
                  account.sound ? 'On' : 'Off',
                  style: Toon.text(
                    16,
                    weight: FontWeight.w700,
                    color: Toon.on(account.sound ? Toon.yellow : Toon.card),
                  ),
                ),
              ],
            ),
          ),
          if (account.sound)
            Row(
              children: [
                const Icon(Icons.volume_down_rounded),
                Expanded(
                  child: Slider(
                    key: const Key('volume'),
                    value: account.volume,
                    activeColor: Toon.purple,
                    onChanged: (v) => account.volume = v,
                    onChangeEnd: (_) => Sound.play(Sfx.chips),
                  ),
                ),
                const Icon(Icons.volume_up_rounded),
              ],
            ),
          const SizedBox(height: 16),
          Text("Hold'em", style: Toon.text(18, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          ToonButton(
            key: const Key('poker odds'),
            color: account.pokerOdds ? Toon.yellow : Toon.card,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            onPressed: () => account.pokerOdds = !account.pokerOdds,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Pot odds and outs',
                    textAlign: TextAlign.start,
                    style: Toon.text(16, color: Toon.on(account.pokerOdds ? Toon.yellow : Toon.card)),
                  ),
                ),
                Text(
                  account.pokerOdds ? 'On' : 'Off',
                  style: Toon.text(
                    16,
                    weight: FontWeight.w700,
                    color: Toon.on(account.pokerOdds ? Toon.yellow : Toon.card),
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Shown by your buttons: what a call costs against the pot, and the cards that would help you.',
            style: Toon.text(14, weight: FontWeight.w500, color: Toon.muted),
          ),
          const SizedBox(height: 16),
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
        // Upright these come after the currencies; on its side, under Look.
        after: [
          const SizedBox(height: 8),
          Text('How money works', style: Toon.text(18, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          const StakeRules(),
          const SizedBox(height: 16),
          ToonButton(
            key: const Key('about'),
            color: Toon.card,
            onPressed: () => showAboutSheet(context),
            child: const Text('About ${AppInfo.name} ${AppInfo.version}'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
