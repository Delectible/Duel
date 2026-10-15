import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

/// Turns the `Authorization: Bearer <token>` a player sends into their uid,
/// or null if the token isn't valid.
abstract interface class TokenVerifier {
  Future<String?> uid(String token);
}

/// Checks Firebase Auth ID tokens: signed by Google (keys fetched and
/// cached), for this project, not expired, with a user id.
/// https://firebase.google.com/docs/auth/admin/verify-id-tokens
class FirebaseTokenVerifier implements TokenVerifier {
  FirebaseTokenVerifier(this.projectId, {http.Client? client}) : _client = client ?? http.Client();

  final String projectId;
  final http.Client _client;

  static final _keysUrl = Uri.parse(
    'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com',
  );

  Map<String, String> _certs = {};
  DateTime _certsExpire = DateTime.fromMillisecondsSinceEpoch(0);

  Future<Map<String, String>> _keys() async {
    if (DateTime.now().isBefore(_certsExpire) && _certs.isNotEmpty) return _certs;
    final res = await _client.get(_keysUrl);
    if (res.statusCode != 200) throw StateError('Could not fetch Firebase signing keys (${res.statusCode})');
    _certs = (jsonDecode(res.body) as Map).cast<String, String>();
    // Cache as long as Google says (max-age), else an hour.
    final maxAge = RegExp(r'max-age=(\d+)').firstMatch(res.headers['cache-control'] ?? '')?.group(1);
    _certsExpire = DateTime.now().add(Duration(seconds: int.tryParse(maxAge ?? '') ?? 3600));
    return _certs;
  }

  @override
  Future<String?> uid(String token) async {
    try {
      final unverified = JWT.decode(token);
      final kid = unverified.header?['kid'];
      final cert = kid is String ? (await _keys())[kid] : null;
      if (cert == null) return null;
      final jwt = JWT.verify(
        token,
        RSAPublicKey.cert(cert),
        audience: Audience.one(projectId),
        issuer: 'https://securetoken.google.com/$projectId',
      );
      final sub = (jwt.payload as Map)['sub'];
      return sub is String && sub.isNotEmpty ? sub : null;
    } on Object {
      return null;
    }
  }
}

/// Tests and the local emulator: the token is the uid.
class TrustingVerifier implements TokenVerifier {
  const TrustingVerifier();

  @override
  Future<String?> uid(String token) async => token.isEmpty ? null : token;
}
