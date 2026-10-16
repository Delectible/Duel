import 'dart:convert';
import 'dart:math';

import 'package:duel_server/duel_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late Handler handler;

  setUp(() => handler = api(Referee(MemoryStore(), rng: Random(2)), const TrustingVerifier()));

  Future<(int, Map<String, Object?>)> post(String path, {String? as, Object? body}) async {
    final res = await handler(
      Request(
        'POST',
        Uri.parse('http://referee$path'),
        headers: {if (as != null) 'authorization': 'Bearer $as'},
        body: body == null ? '' : jsonEncode(body),
      ),
    );
    return (res.statusCode, (jsonDecode(await res.readAsString()) as Map).cast<String, Object?>());
  }

  test('sign in first', () async {
    final (status, body) = await post('/v1/parties');
    expect(status, 401);
    expect(body['error'], isNotNull);
  });

  test('two players over HTTP: party, game, a move, errors as JSON', () async {
    final (_, party) = await post(
      '/v1/parties',
      as: 'luca',
      body: {
        'name': 'Luca',
        'avatar': {'hat': 'crown'},
      },
    );
    final (s1, joined) = await post(
      '/v1/parties/join',
      as: 'sam',
      body: {'code': party['code'], 'name': 'Sam'},
    );
    expect(s1, 200);
    expect(joined['members'], ['luca', 'sam']);
    final (s2, match) = await post(
      '/v1/parties/${party['id']}/start',
      as: 'luca',
      body: {'game': 'connect4'},
    );
    expect(s2, 200);
    final turn = (match['seats']! as List)[match['turn']! as int] as String;
    final (s3, after) = await post(
      '/v1/matches/${match['id']}/move',
      as: turn,
      body: {
        'version': match['version'],
        'move': {'column': 3},
      },
    );
    expect(s3, 200);
    expect((after['state']! as Map)['moves'], [3]);
    final (s4, err) = await post('/v1/matches/${match['id']}/move', as: turn, body: {'version': 1});
    expect(s4, 400);
    expect(err['error'], contains('version'));
  });

  test('health check needs no sign-in', () async {
    final res = await handler(Request('GET', Uri.parse('http://referee/health')));
    expect(res.statusCode, 200);
  });
}
