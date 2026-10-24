import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'auth.dart';
import 'referee.dart';
import 'store.dart';

/// The referee over HTTP. Every call but /health needs a Firebase ID
/// token (`Authorization: Bearer …`); bodies and answers are JSON.
///
/// - POST /v1/parties                {name, avatar, version} -> party
/// - POST /v1/parties/join           {code, name, avatar, version} -> party
/// - POST /v1/parties/<id>/bots      {bots: [{name, look, difficulty}]} -> party
/// - POST /v1/parties/<id>/leave                             -> {}
/// - POST /v1/parties/<id>/start     {game, stake}           -> match
/// - POST /v1/matches/<id>/move      {version, move}         -> match
/// - POST /v1/matches/<id>/timeout                           -> match
/// - POST /v1/matches/<id>/forfeit                           -> match
/// - POST /v1/matches/<id>/rematch                           -> match
///
/// Errors: {error: "…"} with 400 (bad move), 401 (sign in), 403, 404, 409.
Handler api(Referee referee, TokenVerifier verifier) {
  final r = Router()..get('/health', (Request _) => Response.ok('ok'));

  Future<Response> call(Request req, Future<Object?> Function(Player p, Doc body) body) async {
    final auth = req.headers['authorization'] ?? '';
    final token = auth.startsWith('Bearer ') ? auth.substring(7) : '';
    final uid = await verifier.uid(token);
    if (uid == null) return _json(401, {'error': 'Sign in first'});
    Doc json;
    try {
      final text = await req.readAsString();
      json = text.isEmpty ? {} : (jsonDecode(text) as Map).cast<String, Object?>();
    } on Object {
      return _json(400, {'error': 'Body must be JSON'});
    }
    final avatar = json['avatar'];
    final player = Player(
      uid: uid,
      name: json['name'] is String ? json['name']! as String : 'Player',
      avatar: avatar is Map ? avatar.cast<String, Object?>() : const {},
      version: json['version'] is String ? (json['version']! as String) : '',
    );
    try {
      return _json(200, await body(player, json) ?? {});
    } on RefereeError catch (e) {
      return _json(e.status, {'error': e.message});
    }
  }

  r
    ..post(
      '/v1/parties',
      (Request q) => call(q, (p, b) => referee.createParty(p, mode: '${b['mode'] ?? 'host'}')),
    )
    ..post('/v1/parties/join', (Request q) => call(q, (p, b) => referee.joinParty(p, '${b['code'] ?? ''}')))
    ..post(
      '/v1/parties/<id>/bots',
      (Request q, String id) => call(q, (p, b) {
        final bots = b['bots'];
        if (bots is! List) throw const RefereeError(400, 'Send {bots: [...]}');
        return referee.setBots(p, id, bots);
      }),
    )
    ..post('/v1/parties/<id>/leave', (Request q, String id) => call(q, (p, _) => referee.leaveParty(p, id)))
    ..post(
      '/v1/parties/<id>/start',
      (Request q, String id) => call(
        q,
        (p, b) => referee.startMatch(
          p,
          id,
          '${b['game'] ?? ''}',
          stake: b['stake'] is int ? b['stake']! as int : 0,
          options: b['options'] is Map ? (b['options']! as Map).cast<String, Object?>() : const {},
        ),
      ),
    )
    ..post(
      '/v1/parties/<id>/vote',
      (Request q, String id) => call(
        q,
        (p, b) => referee.vote(
          p,
          id,
          '${b['game'] ?? ''}',
          stake: b['stake'] is int ? b['stake']! as int : 0,
          options: b['options'] is Map ? (b['options']! as Map).cast<String, Object?>() : const {},
        ),
      ),
    )
    ..post(
      '/v1/matches/<id>/move',
      (Request q, String id) => call(q, (p, b) {
        final version = b['version'];
        final move = b['move'];
        if (version is! int || move is! Map) throw const RefereeError(400, 'Send {version, move}');
        return referee.move(p, id, version, move.cast<String, Object?>());
      }),
    )
    ..post(
      '/v1/matches/<id>/timeout',
      (Request q, String id) => call(q, (p, _) => referee.claimTimeout(p, id)),
    )
    ..post('/v1/matches/<id>/forfeit', (Request q, String id) => call(q, (p, _) => referee.forfeit(p, id)))
    ..post('/v1/matches/<id>/rematch', (Request q, String id) => call(q, (p, _) => referee.rematch(p, id)))
    ..post('/v1/matches/<id>/rejoin', (Request q, String id) => call(q, (p, _) => referee.rejoin(p, id)))
    ..post('/v1/matches/<id>/end', (Request q, String id) => call(q, (p, _) => referee.endMatch(p, id)))
    ..post(
      '/v1/matches/<id>/decide',
      (Request q, String id) => call(q, (p, b) => referee.decide(p, id, '${b['choice'] ?? ''}')),
    );

  return const Pipeline().addMiddleware(_errors).addHandler(r.call);
}

Response _json(int status, Object? body) => Response(
  status,
  body: jsonEncode(body, toEncodable: encodeTime),
  headers: {'content-type': 'application/json'},
);

/// Anything unexpected: log it, answer 500 without details.
Handler _errors(Handler inner) => (req) async {
  try {
    return await inner(req);
  } on Object catch (e, st) {
    // Cloud Run collects stderr into Cloud Logging.
    // ignore: avoid_print
    print('ERROR ${req.method} ${req.url}: $e\n$st');
    return _json(500, {'error': 'Something went wrong'});
  }
};
