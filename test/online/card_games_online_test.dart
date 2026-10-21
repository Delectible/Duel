import 'dart:async';
import 'dart:math';

import 'package:duel/core/account/account.dart';
import 'package:duel/core/avatars/faces.dart';
import 'package:duel/core/online/party.dart';
import 'package:duel/core/session/play_setup.dart';
import 'package:duel/main.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:duel_server/duel_server.dart' as server;
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';
import 'fake_server.dart';

/// Crazy Eights, Go Fish and Spades with the party: Luca's phone on screen
/// rebuilds the table from the server's log while both people's moves are
/// made on the server (as a timed-out turn would be), to the end.
void main() {
  for (final (game, bots) in [('crazy8', 0), ('gofish', 1), ('spades', 2)]) {
    testWidgets(timeout: const Timeout(Duration(seconds: 120)), '$game online plays to the end', (
      tester,
    ) async {
      usePhone(tester, phones['pixel9pro']!);
      final srv = FakeServer(seed: 2);
      final account = Account()..name = 'Luca';
      final party = PartyService(srv.player('luca'), account: account);
      final sam = PartyService(srv.player('sam'), account: Account()..name = 'Sam');

      Future<void> wait([int ms = 300]) async {
        for (var i = 0; i < 4; i++) {
          unawaited(srv.publish());
          await tester.pump(Duration(milliseconds: ms ~/ 4));
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
        for (var i = 0; i < 400 && !done; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(done, isTrue);
        return result;
      }

      await tester.pumpWidget(
        DuelApp(
          account: account,
          setup: PlaySetup(party: party),
          party: party,
        ),
      );
      await wait();
      await run(party.create);
      await run(() => sam.join(party.code!));
      if (bots > 0) {
        await run(
          () => party.setBots([
            for (var b = 0; b < bots; b++)
              PartyBot(name: 'Bot$b', look: Look.cap, difficulty: Difficulty.easy),
          ]),
        );
      }
      expect(await run(() => party.start(game, options: const {'target': 150})), isNull);
      await wait(1500);
      final id = party.match!['id']! as String;
      final rng = Random(1);
      // People's turns: what an Easy bot would do, sent as that person.
      for (var step = 0; step < 4000 && party.match!['status'] == 'live'; step++) {
        final m = (await run(() => srv.store.get('matches/$id')))!;
        final turn = m['turn'] as int?;
        if (turn == null || m['status'] != 'live') break;
        final uid = (m['seats']! as List)[turn];
        final secret = (await run(() => srv.store.get('secrets/$id')))!['state']! as Map<String, Object?>;
        final move = server.onlineGames[game]!.autoMove(secret, turn, rng);
        await run(
          () => srv.referee.move(server.Player(uid: '$uid', name: '$uid'), id, m['version']! as int, move),
        );
        await wait(step % 20 == 0 ? 1500 : 200);
        expect(tester.takeException(), isNull);
      }
      expect(party.match!['status'], 'over');
      await wait(3000);
      expect(tester.takeException(), isNull);
      await shot(tester, 'online_${game}_over');
    });
  }
}
