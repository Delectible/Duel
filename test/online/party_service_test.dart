import 'package:duel/core/account/account.dart';
import 'package:duel/core/app_info.dart';
import 'package:duel/core/avatars/faces.dart';
import 'package:duel/core/online/party.dart';
import 'package:duel/games/four_in_a_row/ui/online_row.dart';
import 'package:duel_server/duel_server.dart' show Player;
import 'package:flutter_test/flutter_test.dart';

import 'fake_server.dart';

void main() {
  late FakeServer server;
  late PartyService luca, sam;

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await server.publish();
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() {
    server = FakeServer();
    luca = PartyService(server.player('luca'), account: Account()..name = 'Luca');
    sam = PartyService(server.player('sam'), account: Account()..name = 'Sam');
  });

  /// Plays [cols] taking turns, whoever is to move.
  Future<void> play(List<int> cols) async {
    for (final c in cols) {
      final turn = luca.match!['turn'] == luca.seat ? luca : sam;
      expect(await turn.move({'column': c}), isNull);
      await settle();
    }
  }

  test('make a party, join by code, host starts, play, rematch, leave', () async {
    expect(await luca.create(), isNull);
    expect(luca.isHost, isTrue);
    expect(luca.code, hasLength(6));
    expect(luca.account.partyId, luca.partyId);

    expect(await sam.join('nope'), contains('6 letters'));
    expect(await sam.join('ZZZZZZ'), 'No party with that code');
    expect(await sam.join(luca.code!.toLowerCase()), isNull);
    await settle();
    expect(luca.size, 2);
    expect(luca.members.first.host, isTrue);
    expect(luca.members.map((m) => m.persona.name), ['You', 'Sam']);
    expect(sam.members.map((m) => m.persona.name), ['Luca', 'You']);
    expect(sam.isHost, isFalse);
    expect(sam.hostName, 'Luca');

    expect(await sam.start('connect4'), "Only the host can start a game");
    expect(await luca.start('connect4', stake: 5), isNull);
    await settle();
    expect(luca.playing && sam.playing, isTrue);
    expect(sam.match!['stake'], 5);
    expect({luca.seat, sam.seat}, {0, 1});

    // A stale move is turned down with a reason.
    final waiting = luca.match!['turn'] == luca.seat ? sam : luca;
    expect(await waiting.move({'column': 0}), 'Not your turn');

    await play([0, 1, 0, 1, 0, 1, 0]);
    expect(luca.playing, isFalse);
    expect(luca.match!['result'], isNotNull);
    final first = luca.match!['id'];

    expect(await luca.rematch(), isNull);
    await settle();
    expect(luca.match!['id'], first, reason: 'waiting for Sam');
    expect(await sam.rematch(), isNull);
    await settle();
    expect(luca.match!['id'], isNot(first));
    expect(sam.match!['id'], luca.match!['id']);
    expect(luca.playing, isTrue);

    // Leaving mid-game gives it up; the other stays in the party, now host.
    expect(await luca.leave(), isNull);
    await settle();
    expect(luca.inParty, isFalse);
    expect(luca.account.partyId, isNull);
    expect(sam.playing, isFalse);
    expect(sam.match!['result'], containsPair('reason', 'forfeit'));
    expect(sam.size, 1);
    expect(sam.isHost, isTrue);
  });

  test('a newer x.Y in the party is noticed (to tell this player to update)', () async {
    expect(await luca.create(), isNull);
    expect(await sam.join(luca.code!), isNull);
    await settle();
    expect(luca.party!['versions'], {'luca': AppInfo.version, 'sam': AppInfo.version});
    expect(luca.newerVersion, isNull);
    final parts = AppInfo.version.split('.').map(int.parse).toList();
    final newer = '${parts[0]}.${parts[1] + 1}.0';
    await server.referee.joinParty(Player(uid: 'kit', name: 'Kit', version: newer), luca.code!);
    await settle();
    expect(luca.newerVersion, newer);
    expect(sam.newerVersion, newer);
  });

  test('reopening the app goes back to the party', () async {
    await luca.create();
    await sam.join(luca.code!);
    await settle();
    final again = PartyService(server.player('sam'), account: sam.account);
    await settle();
    expect(again.inParty, isTrue);
    expect(again.partyId, luca.partyId);
  });

  test('no network: a plain message, nothing changes', () async {
    server.offline = true;
    expect(await luca.create(), contains("Couldn't reach the server"));
    expect(luca.inParty, isFalse);
    expect(luca.busy, isFalse);
  });

  test('a turn that runs out: the other phone claims it, the referee moves', () async {
    var now = DateTime(2026);
    await luca.create();
    await sam.join(luca.code!);
    await luca.start('connect4');
    await settle();
    final idle = luca.match!['turn'] == luca.seat ? luca : sam;
    final watcher = idle == luca ? sam : luca;
    final table = OnlineRowController(watcher, you: const Persona.you(), clock: () => now);
    expect(table.thinking, isTrue);
    expect(table.secondsLeft, 45);
    now = now.add(const Duration(seconds: 30));
    expect(table.secondsLeft, 15);

    // Out of time (on the server too): the watcher's phone claims it.
    now = now.add(const Duration(seconds: 17));
    server.now = server.now.add(const Duration(seconds: 47));
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await settle();
    expect((luca.match!['state']! as Map)['moves'], hasLength(1), reason: 'a move was made for them');
    expect(table.yourTurn, isTrue);
    expect(table.secondsLeft, 45, reason: 'a fresh turn');
    table.dispose();
  });
}
