import 'dart:async';

import 'package:duel/core/account/account.dart';
import 'package:duel/core/online/party.dart';
import 'package:duel/core/session/play_setup.dart';
import 'package:duel/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';
import 'fake_server.dart';

/// One phone on screen (Luca's), the friend's (Sam's) driven by its party
/// service, both on the real referee in memory.
void main() {
  for (final MapEntry(key: phone, value: size) in phones.entries) {
    testWidgets(
      timeout: const Timeout(Duration(seconds: 60)),
      'online on $phone: party by code, host starts, play, rematch, back to party',
      (tester) async {
        usePhone(tester, size);
        final server = FakeServer();
        final account = Account()..name = 'Luca';
        final party = PartyService(server.player('luca'), account: account);
        final sam = PartyService(server.player('sam'), account: Account()..name = 'Sam');
        final setup = PlaySetup(party: party);

        // Everything runs on the test's clock (the store's queue lives there).
        Future<void> wait([int ms = 300]) async {
          for (var i = 0; i < 4; i++) {
            unawaited(server.publish());
            await tester.pump(Duration(milliseconds: ms ~/ 4));
          }
        }

        /// Sam's phone does something; Luca's screen keeps ticking meanwhile.
        Future<T> onSam<T>(Future<T> Function() f) async {
          late T result;
          var done = false;
          unawaited(
            f().then((v) {
              result = v;
              done = true;
            }),
          );
          for (var i = 0; i < 40 && !done; i++) {
            await tester.pump(const Duration(milliseconds: 20));
          }
          expect(done, isTrue);
          return result;
        }

        await tester.pumpWidget(DuelApp(account: account, setup: setup, party: party));
        await wait();

        // Friend mode: every game is greyed out until a friend is here.
        await tester.tap(find.text('Friend'));
        await wait();
        expect(find.textContaining('invite a friend'), findsOneWidget);
        await tester.tap(find.textContaining('Party ·'));
        await wait();
        await shot(tester, 'online_start_$phone');

        await tester.tap(find.byKey(const Key('create party')));
        await wait();
        final code = party.code!;
        expect(find.text(code), findsOneWidget);
        expect(find.text('Waiting for a friend…'), findsOneWidget);
        await shot(tester, 'online_waiting_$phone');

        // Sam types the code on their phone.
        expect(await onSam(() => sam.join(code)), isNull);
        await wait();
        expect(find.byKey(const Key('member Sam')), findsOneWidget);
        expect(find.byKey(const Key('crown')), findsOneWidget);
        expect(find.text('Waiting for a friend…'), findsNothing);
        await shot(tester, 'online_party_$phone');

        // Pick a game: home, Four in a Row is open, the others say soon.
        await tester.ensureVisible(find.byKey(const Key('pick game')));
        await tester.tap(find.byKey(const Key('pick game')));
        await wait(600);
        expect(find.textContaining('you pick the game'), findsOneWidget);
        await tester.tap(find.text('Four in a Row'));
        await wait(600);
        await tester.tap(find.byKey(const Key('play')));
        await wait(800);

        // The game is on, on both phones.
        expect(sam.playing, isTrue);
        expect(find.textContaining('You vs Sam'), findsOneWidget);
        await shot(tester, 'online_game_$phone');

        Future<void> samMoves(int col) async {
          expect(await onSam(() => sam.move({'column': col})), isNull);
          await wait(700);
        }

        Future<void> lucaMoves(int col) async {
          await tester.tap(find.byKey(Key('col $col')));
          await wait(700);
        }

        // Whoever starts wins down their column.
        final lucaFirst = party.match!['turn'] == party.seat;
        for (var i = 0; i < 7; i++) {
          final lucaTurn = (i % 2 == 0) == lucaFirst;
          final col = (i % 2 == 0) ? 0 : 1;
          if (lucaTurn) {
            await lucaMoves(col);
          } else {
            await samMoves(col);
          }
        }
        expect(party.playing, isFalse);
        await wait(2000);
        expect(find.text(lucaFirst ? 'You won!' : 'Sam won'), findsOneWidget);
        expect(find.text('Rematch'), findsOneWidget);
        await shot(tester, 'online_over_$phone');

        await tester.tap(find.byKey(const Key('again')));
        await wait();
        expect(find.text('Waiting for Sam…'), findsOneWidget);
        expect(await onSam(sam.rematch), isNull);
        await wait(800);
        expect(party.playing, isTrue);
        expect(find.text('Rematch'), findsNothing);
        expect(find.textContaining('You vs Sam'), findsOneWidget);

        // Leaving mid-game: confirm, Sam wins, back home still in the party.
        await tester.tap(find.byTooltip('Leave game'));
        await wait();
        await tester.tap(find.byKey(const Key('leave')));
        await wait(800);
        expect(sam.match!['result'], containsPair('reason', 'forfeit'));
        expect(find.text('Pick a game'), findsOneWidget);
        expect(party.size, 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
