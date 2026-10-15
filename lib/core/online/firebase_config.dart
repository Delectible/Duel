import 'package:firebase_core/firebase_core.dart';

/// The Firebase project's app settings (public identifiers, safe to commit:
/// access is guarded by Firebase Auth, App Check and the security rules).
///
/// Empty until the project exists. Fill in from the Firebase console:
/// Project settings > Your apps > (Android / iOS app) > SDK setup and
/// configuration. See docs/ONLINE.md, "Your steps". While these are null
/// the app stays offline: bot games only.
abstract final class FirebaseConfig {
  static const FirebaseOptions? android = null;
  static const FirebaseOptions? ios = null;

  /// The referee's address on Cloud Run (the deploy prints it), e.g.
  /// `https://duel-referee-xxxxx-ts.a.run.app`.
  static const String? referee = null;
}
