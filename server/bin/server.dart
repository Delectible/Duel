import 'dart:io';

import 'package:duel_server/duel_server.dart';
// The REST client is marked deprecated in favour of
// google_cloud_firestore_v1, which is still pre-1.0; swap when it's stable.
// ignore: deprecated_member_use
import 'package:googleapis/firestore/v1.dart' as fs;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as io;

/// Starts the referee.
///
/// - `PORT`: set by Cloud Run (default 8080).
/// - `FIREBASE_PROJECT`: the Firebase / Google Cloud project id.
/// - `FIRESTORE_EMULATOR_HOST`: use the local emulator (no sign-in), and
///   trust tokens as uids (for local testing only).
Future<void> main() async {
  final env = Platform.environment;
  final project = env['FIREBASE_PROJECT'] ?? env['GOOGLE_CLOUD_PROJECT'];
  if (project == null) {
    stderr.writeln('Set FIREBASE_PROJECT to the Firebase project id.');
    exit(64);
  }
  final emulator = env['FIRESTORE_EMULATOR_HOST'];
  final http.Client client = emulator != null
      ? _EmulatorClient()
      : await clientViaApplicationDefaultCredentials(scopes: [fs.FirestoreApi.datastoreScope]);
  final store = FirestoreStore(client, projectId: project, emulatorHost: emulator);
  final verifier = emulator != null ? const TrustingVerifier() : FirebaseTokenVerifier(project);
  final server = await io.serve(
    api(Referee(store), verifier),
    InternetAddress.anyIPv4,
    int.parse(env['PORT'] ?? '8080'),
  );
  stdout.writeln('Duel referee for $project on :${server.port}${emulator != null ? ' (emulator)' : ''}');
}

/// The Firestore emulator wants "Bearer owner" for full access.
class _EmulatorClient extends http.BaseClient {
  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['authorization'] = 'Bearer owner';
    return _inner.send(request);
  }
}
