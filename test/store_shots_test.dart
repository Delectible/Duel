import 'dart:io';
import 'dart:ui' as ui;

import 'package:duel/core/account/account.dart';
import 'package:duel/core/session/play_setup.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:duel/features/home/home_screen.dart';
import 'package:duel/features/profile/profile_screen.dart';
import 'package:duel/games/crazy_eights/ui/eights_screen.dart';
import 'package:duel/games/four_in_a_row/ui/row_screen.dart';
import 'package:duel/games/go_fish/ui/fish_screen.dart';
import 'package:duel/games/poker/ui/poker_screen.dart';
import 'package:duel/games/spades/ui/spades_screen.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'poker/poker_screen_test.dart' show shuffleAndDeal, yourTurn;

/// Store screenshots: `STORE=dir flutter test test/store_shots_test.dart`
/// saves 1080 x 1920 phone shots (9:16, as Play wants) as dir/N_name.png,
/// ready for fastlane/metadata/android/en-AU/images/phoneScreenshots/.
/// Skipped without STORE.
void main() {
  final dir = Platform.environment['STORE'];

  Widget wrap(Widget home) => AccountScope(
    account: Account()..name = 'Luca',
    child: PlaySetupScope(
      // One bot: every game's tile is open (Four in a Row is for two).
      setup: PlaySetup()..botCount = 1,
      child: MaterialApp(debugShowCheckedModeBanner: false, theme: Toon.theme(), home: home),
    ),
  );

  Future<void> save(WidgetTester tester, String name) async {
    final image = await captureImage(tester.element(find.byType(MaterialApp)));
    final bytes = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
    Directory(dir!).createSync(recursive: true);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  Future<void> pumpFor(WidgetTester tester, int ms) async {
    for (var t = 0; t < ms; t += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  setUp(() {
    // 360 x 640 at 3x: 1080 x 1920.
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 1920);
    view.devicePixelRatio = 3;
  });

  testWidgets('store screenshots', skip: dir == null, (tester) async {
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(const HomeScreen()));
    await tester.pumpAndSettle();
    await save(tester, '1_home');

    // Hold'em on your turn, a few hands in.
    await tester.pumpWidget(
      wrap(const PokerScreen(bots: 5, difficulty: Difficulty.normal, pace: 0.2, seed: 3)),
    );
    var turns = 0;
    for (var i = 0; i < 20000 && turns < 3; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (await shuffleAndDeal(tester)) continue;
      if (yourTurn()) {
        turns++;
        await pumpFor(tester, 400);
        if (turns == 3) break;
        await tester.tap(find.byKey(const Key('call')));
      }
    }
    await save(tester, '2_holdem');

    await tester.pumpWidget(
      wrap(const EightsScreen(bots: 3, difficulty: Difficulty.normal, pace: 0.2, seed: 2)),
    );
    await pumpFor(tester, 4000);
    await save(tester, '3_crazy_eights');

    await tester.pumpWidget(
      wrap(const FishScreen(bots: 2, difficulty: Difficulty.normal, pace: 0.2, seed: 2)),
    );
    await pumpFor(tester, 4000);
    await save(tester, '4_go_fish');

    await tester.pumpWidget(
      wrap(const SpadesScreen(bots: 3, difficulty: Difficulty.normal, pace: 0.2, seed: 2)),
    );
    await pumpFor(tester, 4000);
    await save(tester, '5_spades');

    await tester.pumpWidget(wrap(const RowScreen(difficulty: Difficulty.normal, pace: 0.2, seed: 2)));
    await pumpFor(tester, 800);
    // A few discs in.
    for (final col in [3, 2, 4, 3]) {
      await tester.tap(find.byKey(Key('col $col')));
      await pumpFor(tester, 2500);
    }
    await save(tester, '6_four_in_a_row');

    await tester.pumpWidget(wrap(const ProfileScreen()));
    await tester.pumpAndSettle();
    await save(tester, '7_profile');
  });
}
