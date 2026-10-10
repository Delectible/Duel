# Duel — notes for Claude

Read this first. Duel is a platform for card games: mostly online against
another player on the app, sometimes against a bot. Built on the same
build and release pipeline as Luca's other app, Darkroom
(github.com/Delectible/Darkroom).

## The person and how we work

- Owner: Luca. Keep replies short and plain.
- For big revisions, ask clarifying questions first, then implement.
- Keep changes focused, don't gold-plate.
- After every push that builds, wait for the run; once its `play` job has
  uploaded, wait ~2 more minutes, then send Luca a push notification
  (PushNotification) that the build is on Google Play: version, build
  number, one-line what's new. If the build or the upload fails, notify
  that instead.
- Every user-visible change: bump `version` in `pubspec.yaml` (raise the
  `+build` number too) and `AppInfo.version` to match (a test checks), set
  `AppInfo.latest` in `lib/core/app_info.dart` to this build's change in
  plain words (it's Play's "What's new"), and when a main idea lands add a
  few-word bullet to the newest `AppInfo.revisions` entry (About shows
  them as bullets; keep them short).
- **Release roadmap:** `docs/RELEASE.md` is the checklist to the public
  Play / App Store release, including the one-time Play Console setup;
  tick items as they land.
- **Change log:** `docs/CHANGELOG.md` tracks every requested change by item
  number. Mark items `[~]` when starting and `[x] → version · date · commit`
  when they land; add new requests there.

## Build & release pipeline

- Unless Luca says otherwise, **commit and push finished changes straight to
  `main`** so a new build gets made. Don't push half-done work.
- Push → `.github/workflows/build-apk.yml` runs `flutter analyze` + `flutter
  test`, builds `Duel-N.apk`, `Duel-N.aab` and an unsigned `Duel-N.ipa`, and
  publishes them under **Releases** (`build-N`; non-`main` branches are
  marked pre-release). Nothing is published unless the checks pass.
- iOS build runs on a macOS runner. The repo is public, so it runs on every
  push (on a private repo it would only run with `[ios]` in the commit
  message or when started by hand: Mac minutes cost 10x). The .ipa is
  unsigned apart from an ad-hoc signature (Sideloadly's signer fails on
  never-signed binaries); Luca signs and installs it with Sideloadly + a
  free Apple ID (expires every 7 days).
- iOS: deployment target 15.0 (patched into the generated Xcode project by
  CI). **No Podfile**: plugins must be Swift Packages; adding a Podfile
  makes Flutter run CocoaPods and the build dies with "sandbox is not in
  sync with the Podfile.lock". `ios/` holds only Info.plist and the AppIcon
  set; CI generates the rest (AppDelegate, SceneDelegate, Xcode project).
- `android/` and `ios/` only contain the files we customised. CI runs
  `flutter create --org com.dingo --project-name duel --platforms android .`
  (and `ios`) to fill in the rest (it never overwrites existing files).
  Don't delete `AndroidManifest.xml`, `android/app/build.gradle.kts` or
  `MainActivity.kt`. Locally, run the same command (`--platforms
  android,ios`) before `flutter run`; don't commit what it generates.
- `applicationId` / `namespace` = `com.dingo.duel` (the id registered on
  Google Play; can never change); must match the package of
  `MainActivity.kt`. iOS bundle id is the same.
- **Google Play**: the `play` job in the workflow uploads every `main`
  build's .aab to **internal testing** (secret `PLAY_SERVICE_ACCOUNT_JSON`,
  Darkroom's service account; repo variable `PLAY_RELEASE_STATUS`, default
  `completed`). Play's "What's new" = version + **`AppInfo.latest`**
  (`tool/play/whats_new.py`). Without the secret the job just says so.
  **Closed testing** (other testers, Google Group
  darkroom-closed-testing@googlegroups.com, opt-in at
  https://play.google.com/apps/testing/com.dingo.duel) is the slow path:
  the `promote-closed.yml` workflow (Actions tab, run by hand, optional
  build number) promotes a build already on internal testing to the closed
  track (`alpha`), which Play reviews.
  The store listing (title, descriptions, icon, feature graphic) lives in
  `fastlane/metadata/android/en-AU/`; `play-listing.yml` publishes it when
  it changes (fastlane supply, same service account). Icon and feature
  graphic come from `tool/icon/make_icons.py` (placeholder art). Privacy
  policy for the listing: `docs/PRIVACY.md` — update it (and Play's Data
  safety form) whenever what the app collects changes.
- Release builds are signed with Luca's **private upload key** (alias
  `upload`), which CI decodes from the repo secrets `ANDROID_KEYSTORE_BASE64`
  and `ANDROID_KEYSTORE_PASSWORD`. **Never commit it.** Without the secrets
  (local builds) they fall back to the public test key
  (`android/app/duel-test.jks`, password `duel-test`), which won't install over
  a private-key build. versionCode = CI run number (the `+N` in pubspec is
  only for local builds). Play App Signing: once installed from Play, the
  phone only takes updates from Play.
- Checks: `flutter analyze` and `flutter test`. If the session has no
  Flutter SDK, just push and read the GitHub Actions result.
  `pubspec.lock` is committed.

## Stack

Flutter stable (≥ 3.47, Dart ≥ 3.12), Material 3. No packages yet; the
online backend (provider, sign-in) is still to be chosen.

## App layout

- `lib/main.dart`: `DuelApp` (theme: card-table green).
- `lib/core/app_info.dart`: version, `latest` (Play's What's new),
  `revisions` (About).
- `lib/features/home/`: home screen (Play online / Play vs bot, both
  "coming soon"), About sheet.
