import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'nested_lists.dart';
import 'party.dart';

/// [OnlineBackend] on Firebase: anonymous sign-in, Firestore for the live
/// party and game, HTTPS calls to the referee on Cloud Run.
class FirebaseBackend implements OnlineBackend {
  FirebaseBackend(this.referee, {http.Client? client}) : _http = client ?? http.Client();

  /// The referee's address (FirebaseConfig.referee).
  final String referee;
  final http.Client _http;

  @override
  Future<String> signIn() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser ?? (await auth.signInAnonymously()).user;
    if (user == null) throw const OnlineError("Couldn't sign in. Try again in a moment.");
    return user.uid;
  }

  @override
  Stream<Doc?> watch(String path) => FirebaseFirestore.instance
      .doc(path)
      .snapshots()
      .map(
        // Lists inside lists come stored as {_list: [...]}.
        (s) => s.exists ? unnestLists(s.data()) as Doc : null,
      );

  @override
  Future<Doc> call(String path, [Doc body = const {}]) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw const OnlineError("You're not signed in yet. Try again.");
    final res = await _http
        .post(
          Uri.parse('$referee$path'),
          headers: {'authorization': 'Bearer $token', 'content-type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    Object? json;
    try {
      json = jsonDecode(res.body);
    } on FormatException {
      json = null;
    }
    if (res.statusCode != 200) {
      final error = json is Map ? json['error'] : null;
      throw OnlineError(error is String ? error : 'The server had a problem (${res.statusCode}). Try again.');
    }
    return (json! as Map).cast<String, Object?>();
  }
}
