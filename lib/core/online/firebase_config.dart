import 'package:firebase_core/firebase_core.dart';

/// The Firebase project's app settings (public identifiers, safe to commit:
/// access is guarded by Firebase Auth, App Check and the security rules).
///
/// Project `dingo-duel`. From the Firebase console:
/// Project settings > Your apps > (Android / iOS app) > SDK setup and
/// configuration. See docs/ONLINE.md, "Your steps". Online stays off
/// (bot games only) until [referee] is set too.
abstract final class FirebaseConfig {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAhfArKUtca12ULpDxe0t9P0m12Yj87lQ0',
    appId: '1:790990305285:android:8092bac9905b9c5646846c',
    messagingSenderId: '790990305285',
    projectId: 'dingo-duel',
    storageBucket: 'dingo-duel.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDesxdkcQ-8wMweBvMM-HFBK6Kj2JjEpVs',
    appId: '1:790990305285:ios:7be139c21937720a46846c',
    messagingSenderId: '790990305285',
    projectId: 'dingo-duel',
    storageBucket: 'dingo-duel.firebasestorage.app',
    iosBundleId: 'com.dingo.duel',
  );

  /// The referee's address on Cloud Run (the deploy prints it), e.g.
  /// `https://duel-referee-xxxxx-ts.a.run.app`.
  static const String? referee = 'https://duel-referee-790990305285.us-east4.run.app';
}
