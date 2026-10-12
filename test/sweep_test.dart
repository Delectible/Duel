import 'package:duel/core/account/account.dart';
import 'package:duel/core/session/difficulty.dart';
import 'package:duel/core/session/play_setup.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:duel/features/home/home_screen.dart';
import 'package:duel/features/profile/profile_screen.dart';
import 'package:duel/features/settings/settings_screen.dart';
import 'package:duel/games/crazy_eights/ui/eights_screen.dart';
import 'package:duel/games/four_in_a_row/ui/row_screen.dart';
import 'package:duel/games/go_fish/ui/fish_screen.dart';
import 'package:duel/games/poker/ui/poker_screen.dart';
import 'package:duel/games/spades/ui/spades_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screens.dart';

/// Every screen and game, light and dark, upright and on its side: no
/// layout errors, and with SHOTS set a picture of each to look over.
Widget _wrap(Widget home, Account a) => AccountScope(
  account: a,
  child: PlaySetupScope(
    setup: PlaySetup(),
    child: MaterialApp(debugShowCheckedModeBanner: false, theme: Toon.theme(), home: home),
  ),
);

void main() {
  for (final dark in [false, true]) {
    final look = dark ? 'dark' : 'light';
    setUp(() => Toon.dark = dark);
    tearDown(() => Toon.dark = false);

    for (final MapEntry(key: phone, value: size) in phones.entries) {
      for (final (name, screen) in [
        ('home', const HomeScreen()),
        ('profile', const ProfileScreen()),
        ('settings', const SettingsScreen()),
      ]) {
        testWidgets('$name, $look, $phone', (tester) async {
          usePhone(tester, size);
          await tester.pumpWidget(_wrap(screen, Account()));
          await tester.pumpAndSettle();
          await shot(tester, 'sweep_${name}_${look}_$phone');
          expect(tester.takeException(), isNull);
        });
      }

      for (final (name, screen) in [
        ('poker', const PokerScreen(bots: 5, difficulty: Difficulty.normal, pace: 0.2, seed: 2)),
        ('eights', const EightsScreen(bots: 3, difficulty: Difficulty.normal, pace: 0.2, seed: 2)),
        ('fish', const FishScreen(bots: 5, difficulty: Difficulty.normal, pace: 0.2, seed: 2)),
        ('row', const RowScreen(difficulty: Difficulty.normal, pace: 0.2, seed: 2)),
        ('spades', const SpadesScreen(bots: 3, difficulty: Difficulty.normal, pace: 0.2, seed: 2)),
      ]) {
        testWidgets('$name, $look, $phone', (tester) async {
          usePhone(tester, size);
          await tester.pumpWidget(_wrap(screen, Account()));
          for (var i = 0; i < 80; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
          await shot(tester, 'sweep_${name}_${look}_$phone');
          await tester.tap(find.byKey(const Key('guide')));
          for (var i = 0; i < 20; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
          expect(find.text('You are here'), findsWidgets);
          await shot(tester, 'sweep_${name}_guide_${look}_$phone');
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
