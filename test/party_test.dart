import 'dart:math';

import 'package:duel/core/account/account.dart';
import 'package:duel/core/session/play_setup.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:duel/features/party/coin_toss.dart';
import 'package:duel/features/party/party_screen.dart';
import 'package:duel/features/party/vote.dart';
import 'package:duel/games/catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screens.dart';

void main() {
  test('votes: most wins, a tie lists the tied games', () {
    expect(tallyVotes({'luca': 'holdem', 'sam': 'holdem'}).winner, 'holdem');
    final tie = tallyVotes({'luca': 'holdem', 'sam': 'crazy8'});
    expect(tie.isTie, isTrue);
    expect(tie.leaders, ['holdem', 'crazy8']);
    final three = tallyVotes({'a': 'x', 'b': 'y', 'c': 'x'});
    expect(three.winner, 'x');
    final rng = Random(1);
    final picks = {for (var i = 0; i < 50; i++) tossCoin(tie.leaders, rng)};
    expect(picks, {0, 1}, reason: 'both sides come up');
  });

  for (final winner in [0, 1]) {
    for (final MapEntry(key: phone, value: size) in phones.entries) {
      testWidgets('coin lands on ${winner == 0 ? 'heads' : 'tails'} on $phone', (tester) async {
        usePhone(tester, size);
        var done = false;
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: Toon.theme(),
            home: Scaffold(
              backgroundColor: Toon.ink,
              body: Center(
                child: CoinToss(heads: games[0], tails: games[1], winner: winner, onDone: () => done = true),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 650));
        if (winner == 0) await shot(tester, 'coin_air_$phone');
        await tester.pump(const Duration(milliseconds: 90));
        if (winner == 0) await shot(tester, 'coin_air2_$phone');
        expect(find.text('Let\'s play'), findsOneWidget);
        await tester.pumpAndSettle();
        final won = games[winner];
        expect(find.text('${won.name} it is!'), findsOneWidget);
        // The face up is the winner's.
        expect(find.text(won.name), findsOneWidget);
        expect(find.text(winner == 0 ? 'HEADS' : 'TAILS'), findsOneWidget);
        if (winner == 1) await shot(tester, 'coin_landed_$phone');
        await tester.tap(find.byKey(const Key('coin done')));
        expect(done, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('party screen: Vote offers a try of the coin toss', (tester) async {
    usePhone(tester, phones['small']!);
    final setup = PlaySetup();
    await tester.pumpWidget(
      AccountScope(
        account: Account(),
        child: PlaySetupScope(
          setup: setup,
          child: MaterialApp(theme: Toon.theme(), home: const PartyScreen()),
        ),
      ),
    );
    expect(find.byKey(const Key('try coin')), findsNothing);
    await tester.tap(find.text('Vote'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('try coin')));
    await tester.pumpAndSettle();
    expect(find.textContaining('it is!'), findsOneWidget);
    await tester.tap(find.byKey(const Key('coin done')));
    await tester.pumpAndSettle();
    expect(find.byType(CoinToss), findsNothing);
  });
}
