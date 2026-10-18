import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_config.dart';

/// Whether this build can go online, and starting Firebase if so.
///
/// Online play needs the Firebase project's settings in [FirebaseConfig].
/// Without them (or if Firebase fails to start, e.g. no network on first
/// launch) the app runs exactly as before: bot games, nothing online.
abstract final class Online {
  static var _ready = false;

  /// Firebase started: online features can be offered.
  static bool get ready => _ready;

  static FirebaseOptions? get _options => switch (defaultTargetPlatform) {
    TargetPlatform.android => FirebaseConfig.android,
    TargetPlatform.iOS => FirebaseConfig.ios,
    _ => null,
  };

  static bool get configured => !kIsWeb && _options != null;

  static Future<void> start() async {
    final options = _options;
    if (options == null || kIsWeb) return;
    try {
      // Never hang on it: after a while the app just stays offline.
      await Firebase.initializeApp(options: options).timeout(const Duration(seconds: 15));
      _ready = true;
    } on Object catch (e) {
      debugPrint('Online off: Firebase did not start ($e)');
    }
  }
}
