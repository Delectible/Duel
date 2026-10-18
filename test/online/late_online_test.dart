import 'package:duel/core/account/account.dart';
import 'package:duel/core/online/party.dart';
import 'package:duel/core/session/play_setup.dart';
import 'package:duel/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_server.dart';

/// The app opens before Firebase has started; online joins in later.
void main() {
  testWidgets('home shows at once; Friend mode goes online when Firebase is up', (tester) async {
    final account = Account();
    final setup = PlaySetup();
    await tester.pumpWidget(DuelApp(account: account, setup: setup));
    await tester.pump();
    expect(find.text('Pick a game'), findsOneWidget, reason: 'no waiting for online');

    await tester.tap(find.text('Friend'));
    await tester.pump();
    await tester.tap(find.textContaining('Party ·'));
    await tester.pumpAndSettle();
    expect(find.textContaining('needs the internet'), findsOneWidget);

    // Firebase comes up.
    setup.party = PartyService(FakeServer().player('luca'), account: account);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('create party')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
