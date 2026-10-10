/// Version and revision history (shown in About).
class AppInfo {
  const AppInfo._();

  static const name = 'Duel';
  static const version = '0.1.0';

  /// What changed in this build, in plain words: Google Play's "What's new"
  /// (tool/play/whats_new.py). Replace it every build.
  static const latest = 'First build: the home screen. Games are on the way.';

  /// About: the main ideas of each version, a few words each.
  static const revisions = <(String, List<String>)>[
    ('0.1', ['First build: home screen and release pipeline']),
  ];
}
