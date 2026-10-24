import 'dart:async';

import 'package:duel/core/account/account.dart';
import 'package:duel/core/app_info.dart';
import 'package:duel/core/online/party.dart';
import 'package:duel/core/session/play_setup.dart';
import 'package:duel/main.dart';
import 'package:duel_server/duel_server.dart' as server;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens.dart';
import 'fake_server.dart';

/// Someone with a newer Duel (x.Y) joins: this phone says so once, offers
/// Update / Ignore, and blocks nothing.
void main() {
  testWidgets('a newer version in the party: told once, Ignore dismisses', (tester) async {
    usePhone(tester, phones['pixel9pro']!);
    final srv = FakeServer();
    final account = Account()..name = 'Luca';
    final party = PartyService(srv.player('luca'), account: account);

    Future<void> run(Future<Object?> Function() f) async {
      var done = false;
      unawaited(f().then((_) => done = true));
      for (var i = 0; i < 200 && !done; i++) {
        unawaited(srv.publish());
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(done, isTrue);
    }

    await tester.pumpWidget(
      DuelApp(
        account: account,
        setup: PlaySetup(party: party),
        party: party,
      ),
    );
    await run(party.create);
    expect(find.byKey(const Key('version notice')), findsNothing);

    final parts = AppInfo.version.split('.').map(int.parse).toList();
    final newer = '${parts[0]}.${parts[1] + 1}.0';
    await run(
      () => srv.referee.joinParty(server.Player(uid: 'kit', name: 'Kit', version: newer), party.code!),
    );
    for (var i = 0; i < 10; i++) {
      unawaited(srv.publish());
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byKey(const Key('version notice')), findsOneWidget);
    expect(find.textContaining('Duel $newer'), findsOneWidget);
    await shot(tester, 'version_notice');
    await tester.tap(find.byKey(const Key('ignore version')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('version notice')), findsNothing);

    // Not again for the same version.
    for (var i = 0; i < 10; i++) {
      unawaited(srv.publish());
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byKey(const Key('version notice')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
