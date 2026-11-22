import 'package:duel/core/account/account.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:duel/games/bank/ui/bank_companion.dart';
import 'package:duel/games/bank/ui/bank_screen.dart';
import 'package:duel/games/blackjack/ui/bj_lobby.dart';
import 'package:duel/games/blackjack/ui/bj_screen.dart';
import 'package:duel/games/blackjack/ui/bj_tables.dart';
import 'package:duel/games/goofspiel/ui/gops_screen.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screens.dart';

/// Goofspiel, Blackjack and Bank! in dark mode, both ways round: nothing
/// overflows, and the shots show the contrast.
void main() {
  setUp(() => Toon.dark = true);
  tearDown(() => Toon.dark = false);
  final screens = <String, Widget>{
    'gops': const GopsScreen(bots: 2, difficulty: Difficulty.normal, pace: 0.05, seed: 1),
    'bj_lobby': const BjLobby(),
    'bj': BjScreen(table: bjTables.first, bots: 5, difficulty: Difficulty.normal, pace: 0.05, seed: 3),
    'bank': const BankScreen(bots: 3, difficulty: Difficulty.normal, pace: 0.05, seed: 1),
    'bank_home_setup': const BankCompanionSetup(),
    'bank_home': const BankCompanion(names: ['Ann', 'Bo', 'Cy', 'Di'], rounds: 10, dice: true, seed: 1),
    'bank_home_scores': const BankCompanion(names: ['Ann', 'Bo'], rounds: 10, dice: false),
  };
  for (final MapEntry(key: phone, value: size) in phones.entries) {
    for (final MapEntry(key: name, value: home) in screens.entries) {
      testWidgets('$name dark on $phone', (tester) async {
        usePhone(tester, size);
        await tester.pumpWidget(
          AccountScope(
            account: Account()..setBalance(1000),
            child: MaterialApp(debugShowCheckedModeBanner: false, theme: Toon.theme(), home: home),
          ),
        );
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        if (name == 'bj') {
          await tester.tap(find.byKey(const Key('deal')));
          for (var i = 0; i < 60; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
        }
        expect(tester.takeException(), isNull);
        await shot(tester, 'dark_${name}_$phone');
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
      });
    }
  }
}
