import 'dart:async';

import 'package:duel/core/account/account.dart';
import 'package:duel/core/online/party.dart';
import 'package:duel/core/session/play_setup.dart';
import 'package:duel/features/party/party_screen.dart';
import 'package:duel/games/crazy_eights/ui/eights_screen.dart';
import 'package:duel/games/four_in_a_row/ui/row_screen.dart';
import 'package:duel/games/poker/ui/table_view.dart';
import 'package:duel/main.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';
import 'fake_server.dart';

/// Continuity: whatever the other phone does (leaves a game, starts a
/// different one, ends it, leaves the party), Sam's phone follows the
/// party: never stuck on an old game.
void main() {
  late FakeServer srv;
  late WidgetTester t;

  Future<void> wait([int ms = 300]) async {
    for (var i = 0; i < 6; i++) {
      unawaited(srv.publish());
      await t.pump(Duration(milliseconds: ms ~/ 6));
    }
  }

  Future<T> run<T>(Future<T> Function() f) async {
    late T result;
    var done = false;
    unawaited(
      f().then((v) {
        result = v;
        done = true;
      }),
    );
    for (var i = 0; i < 200 && !done; i++) {
      unawaited(srv.publish());
      await t.pump(const Duration(milliseconds: 20));
    }
    expect(done, isTrue);
    return result;
  }

  testWidgets('the host leaves, then starts other games: Sam always follows', (tester) async {
    t = tester;
    usePhone(tester, phones['pixel9pro']!);
    srv = FakeServer(seed: 2);
    final sam = Account()..name = 'Sam';
    final luca = PartyService(srv.player('luca'), account: Account()..name = 'Luca');
    final samP = PartyService(srv.player('sam'), account: sam);
    await tester.pumpWidget(
      DuelApp(
        account: sam,
        setup: PlaySetup(party: samP),
        party: samP,
      ),
    );
    await wait();
    expect(await run(luca.create), isNull);
    expect(await run(() => samP.join(luca.code!)), isNull);

    // Four in a Row, then Luca walks out: Sam wins and sees it.
    expect(await run(() => luca.start('connect4')), isNull);
    await wait(1500);
    expect(find.byType(RowScreen), findsOneWidget);
    expect(await run(luca.forfeit), isNull);
    await wait(2500);
    expect(find.byType(RowScreen), findsOneWidget, reason: 'the result stays up');

    // Sam is still looking at it when Luca starts Crazy Eights.
    expect(await run(() => luca.start('crazy8')), isNull);
    await wait(2500);
    expect(find.byType(RowScreen), findsNothing, reason: 'the old game is gone');
    expect(find.byType(EightsScreen), findsOneWidget, reason: 'the new one opened');

    // Luca ends it: Sam is told, then Hold'em starts and Sam is in it.
    expect(await run(luca.endGame), isNull);
    await wait(1500);
    expect(find.text('Game ended'), findsOneWidget);
    expect(await run(() => luca.start('holdem')), isNull);
    await wait(2500);
    expect(find.byType(EightsScreen), findsNothing);
    expect(find.byType(TableView), findsOneWidget);

    // Luca leaves the party mid-game: Sam isn't left at a dead table: he's
    // told he won, and goes back to the party from there.
    expect(await run(luca.leave), isNull);
    await wait(3000);
    expect(find.text('You win!'), findsOneWidget);
    await tester.tap(find.text('Back to party'));
    await wait(1500);
    expect(find.byType(TableView), findsNothing);
    expect(find.byType(PartyScreen), findsNothing, reason: 'home, with the party still on');
    expect(samP.inParty, isTrue);
    expect(tester.takeException(), isNull);
  });
}
