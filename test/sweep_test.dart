import 'package:duel/core/account/account.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:duel/core/session/play_setup.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:duel/features/home/home_screen.dart';
import 'package:duel/features/profile/profile_screen.dart';
import 'package:duel/features/settings/settings_screen.dart';
import 'package:duel/features/tabletop/scorer/scorer_screen.dart';
import 'package:duel/features/tabletop/tabletop_screen.dart';
import 'package:duel/games/bank/ui/bank_screen.dart';
import 'package:duel/games/farkle/ui/farkle_screen.dart';
import 'package:duel/games/liars/ui/liars_screen.dart';
import 'package:duel/games/sunk/ui/sunk_screen.dart';
import 'package:duel/games/blackjack/ui/bj_lobby.dart';
import 'package:duel/games/blackjack/ui/bj_screen.dart';
import 'package:duel/games/blitz/ui/blitz_screen.dart';
import 'package:duel/games/crazy_eights/ui/eights_screen.dart';
import 'package:duel/games/goofspiel/ui/gops_screen.dart';
import 'package:duel/games/poker/lounge/cash_lobby.dart';
import 'package:duel/games/poker/lounge/lounge_screen.dart';
import 'package:duel_engine/blackjack/bj_tables.dart';
import 'package:duel/games/four_in_a_row/ui/row_screen.dart';
import 'package:duel/games/go_fish/ui/fish_screen.dart';
import 'package:duel/games/poker/ui/poker_screen.dart';
import 'package:duel/games/spades/ui/spades_screen.dart';
import 'package:duel/features/store/store_screen.dart';
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
        ('store', const StoreScreen(tab: StoreTab.face)),
        ('lounge', const LoungeScreen()),
        ('cash_lobby', CashLobbyScreen(now: () => 0)),
        ('bj_lobby', BjLobby(seed: 2, now: () => 0)),
        ('tabletop', const TabletopScreen()),
        ('scorer', const ScorerHome()),
        ('scorer_setup', const ScorerSetup()),
      ]) {
        testWidgets('$name, $look, $phone', (tester) async {
          usePhone(tester, size);
          await tester.pumpWidget(_wrap(screen, Account()));
          for (var i = 0; i < 40; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
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
        ('blackjack', BjScreen(table: bjTables.first, bots: 4, pace: 0.2, seed: 2)),
        ('bank', const BankScreen(bots: 5, difficulty: Difficulty.normal, pace: 0.2, seed: 2)),
        ('gops', const GopsScreen(bots: 2, difficulty: Difficulty.normal, pace: 0.2, seed: 2)),
        ('blitz', const BlitzScreen(bots: 3, difficulty: Difficulty.normal, pace: 0.2, seed: 2)),
        ('farkle', const FarkleScreen(bots: 3, difficulty: Difficulty.normal, pace: 0.2, seed: 2)),
        ('liars', const LiarsScreen(bots: 3, pace: 0.2, seed: 2)),
        ('sunk', const SunkScreen(bots: 3, pace: 0.2, seed: 2)),
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
