# Duel — notes for Claude

Read this first. Duel is a platform for card games: mostly online against
another player on the app, sometimes against a bot. Built on the same
build and release pipeline as Luca's other app, Darkroom
(github.com/Delectible/Darkroom).

**The user story is in `docs/VISION.md`**: one-on-one card / table games
with a friend (or a bot), connect once into a party and move between games
together, GamePigeon-easy. Let it guide design and development choices.

## The person and how we work

- Owner: Luca. Keep replies short and plain.
- For big revisions, ask clarifying questions first, then implement.
- Keep changes focused, don't gold-plate.
- **Batch workflow (differs from Darkroom):** we work out the details
  together, Claude writes the code, and changes collect until Luca says
  **"push to main"**. Only then does it all go to `main` together, which
  makes one build. Never push to `main` without that.
  - Meanwhile commit to the session's work branch (not `main`) and push it
    as a backup: containers are ephemeral, and only `main` pushes build.
  - Run `flutter analyze` + `flutter test` before every commit; keep the
    batch green so "push to main" is just a merge.
  - On "push to main": fast-forward or merge the work branch into `main`,
    push, and report what went in.
- After every push to `main` that builds, wait for the run; once its `play` job has
  uploaded, wait ~2 more minutes, then send Luca a push notification
  (PushNotification) that the build is on Google Play: version, build
  number, one-line what's new. If the build or the upload fails, notify
  that instead.
- Every batch with user-visible changes: bump `version` in `pubspec.yaml`
  once per batch (raise the `+build` number too) and `AppInfo.version` to
  match (a test checks), set `AppInfo.latest` in `lib/core/app_info.dart`
  to the batch's changes in plain words (it's Play's "What's new"), and when a main idea lands add a
  few-word bullet to the newest `AppInfo.revisions` entry (About shows
  them as bullets; keep them short).
- **Release roadmap:** `docs/RELEASE.md` is the checklist to the public
  Play / App Store release, including the one-time Play Console setup;
  tick items as they land.
- **Change log:** `docs/CHANGELOG.md` tracks every requested change by item
  number. Mark items `[~]` when starting and `[x] → version · date · commit`
  when they land; add new requests there.

## Build & release pipeline

- Pushes to `main` only on Luca's "push to main" (see the batch workflow
  above). Don't push half-done work to `main`.
- Push to `main` → `.github/workflows/build-apk.yml` runs `flutter analyze` + `flutter
  test`, builds `Duel-N.apk`, `Duel-N.aab` and an unsigned `Duel-N.ipa`, and
  publishes them under **Releases** (`build-N`). Other branches don't
  build on push; started by hand from the Actions tab they build as a
  pre-release (no Play upload). Nothing is published unless the checks pass.
- iOS build runs on a macOS runner. The repo is public, so it runs on every
  build (on a private repo it would only run with `[ios]` in the commit
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

Flutter stable (≥ 3.47, Dart ≥ 3.12), Material 3. One package: `shared_preferences`
(saves the account; SPM on iOS). State is ChangeNotifier + InheritedNotifier; the online backend (provider,
sign-in) is still to be chosen. Font: Fredoka (assets/fonts, OFL), static
weights cut from the variable font.

## App layout

- `lib/main.dart`: `DuelApp` (loads the `Account`, applies light / dark,
  `AccountScope` + `PlaySetupScope`).
- `lib/core/account/`: `Account` (name, avatar, pips balance (may go
  negative: debt), currency display, theme, per-game stats; saved by
  `PrefsStore`), `stake.dart` (`StakeTicket`: the stake is taken at Play!
  and settled once per game; `StakeBadge`, `StakeResult`, `confirmLeave`
  forfeits). Win = stake back + stake x opponents x difficulty rate.
- `lib/core/avatars/faces.dart`: `Avatar` (colour, head shape, face, hat;
  the first `Avatar.choices` of each are pickable, the rest are bots' /
  later unlocks), `Persona`, `Face` (painted from the parts). Poker maps
  bot `Look`s to `BotStyle`s.
- `lib/core/table/table_bits.dart`: what every game table shares:
  `GameLayout` (upright: top bar / commentary / table / controls; on its
  side: table left, the rest in a right-hand `SidePanel`;
  `GameLayout.wide(context)` for table code), `GameTopBar`,
  `CommentaryStrip`, `SpeechBubble`, `GameOverCard`, `FlyingCards`,
  `FeltPanel`, `DealIn`, `Pop`, `SuitConfetti`.
- **Landscape:** every screen must work both ways (tests run each phone
  upright and on its side: `phones` in `test/screens.dart`).
  `core/theme/split_page.dart` (`SplitPage`: two columns on its side) for
  menus; `core/theme/rotation_fade.dart` fades the layout in on a turn.
  `test/sweep_test.dart` renders every screen light / dark, both ways.
- `lib/features/profile/`, `lib/features/settings/`: the two buttons atop
  home.
- `lib/core/app_info.dart`: version, `latest` (Play's What's new),
  `revisions` (About).
- `lib/core/session/`: `PlaySetup` (the connection bar: Bots / Friend,
  `Difficulty`, bot count, party pick rule), shared by every screen.
- `lib/core/theme/toon.dart`: the cartoon look (`Toon` colours, `ToonBox`,
  `ToonButton` with hold-to-repeat, `chips()` formatting). Use these, not
  stock Material buttons. **Dark mode:** `Toon.ink/fg/paper/card/muted/grey`
  are getters that follow `Toon.dark`, so never put them in `const`;
  `Toon.text` inherits its colour (ToonBox / ToonButton pick a readable
  one); on a bright fill use `Toon.on(color)`. Cards stay white
  (`cardFace`).
- `lib/core/cards/`: `PlayingCard` / `Deck` and `CardView` (suits are drawn
  paths; Fredoka has no suit glyphs). Shared by every card game.
- `lib/games/catalog.dart`: the game picker's list (`GameInfo`: player
  range, tile art, sample `board` (`previews.dart`), `rules`, `minutes`
  per player count, `open`; null `open` = "Soon"; `blocked(setup)` says
  why Play! is off). Adding a game: its folder in `lib/games/` plus one
  entry here.
- `lib/features/preview/`: every game tile opens `GamePreviewScreen`
  (rules, time, sample board, Play! / Nevermind). Only Play! counts; in a
  party it will be the vote / pick, browsing never is.
- `lib/games/poker/engine/`: pure Dart, no Flutter. `hand_eval.dart`
  (best five of seven, descriptions), `poker_hand.dart` (one no-limit hand:
  blinds, betting rules incl. incomplete all-in raises, side pots, odd
  chips), `sit_and_go.dart` (button, blind levels per table size, places),
  `bot.dart` (Monte Carlo equity + `BotStyle` personalities).
  `dart run tool/poker/simulate.dart [n] [easy|normal|hard]` plays bot-only
  Sit & Gos for tuning.
- `lib/games/poker/ui/`: `PokerController` (paces the table: deals, bots
  think, collect, payout; `pace` 0.05 in tests), `table_view.dart` (seats
  around the felt, clockwise from you at the bottom; chips fly to the pot
  and winners), `action_bar.dart`, `hand_chart.dart` (the hands cheat sheet, opened from your hand's
  name; `handRanks`), `shuffle_deck.dart` (your deal: the controller's
  `TablePhase.shuffle` waits for a shuffle and Deal; tests use
  `shuffleAndDeal`). Showdown results wait for Next hand
  (`waitingForYou` / `nextHand()`); `resultTimeout` (online: 10 s) moves
  on by itself with a countdown.
- `lib/games/crazy_eights/`: `engine/crazy_eights.dart` (rules + an event
  list the commentary and animations read), `engine/eights_bot.dart`;
  `ui/eights_controller.dart` (pacing, `commentary()`), `ui/eights_screen.dart`
  (table, hand, piles, flights, suit burst, `eightsGuide`).
- `lib/games/go_fish/`: `engine/go_fish.dart` (rules + events),
  `engine/fish_bot.dart` (memory of asks by difficulty);
  `ui/fish_controller.dart` (pacing, speech bubbles, flights, commentary),
  `ui/fish_screen.dart` (`fishGuide`).
- `lib/games/four_in_a_row/`: `engine/four_in_a_row.dart` (board +
  `RowBot`: negamax with alpha-beta, depth 2 / 4 / 7), `ui/row_controller.dart`
  (bot thinks in an isolate), `ui/row_screen.dart` (drop animation, win /
  block hints, `rowGuide`).
- `lib/games/spades/`: blank template ("Soon" on the picker): engine
  deals only, `SpadesScreen` shows your hand, `spadesGuide`; no `open` in
  the catalog yet.
- `lib/core/help/game_guide.dart`: the mid-game "How to play" sheet
  (`GuideStage`s, `GuideButton` in every game's top bar, "You are here").
  Every game needs one; keep players told what's happening (commentary,
  bubbles, status lines).
- `lib/features/home/`: home (connection bar + game grid, About),
  `lib/features/party/`: party screen, `vote.dart` (`tallyVotes`,
  `tossCoin`), `coin_toss.dart` (tie-break animation; takes the result,
  so online it plays what the server tossed).
- Tests: engine rules in `test/<game>/`; screens at Pixel 9 Pro and 360 dp
  with the real fonts (`test/flutter_test_config.dart`); `SHOTS=dir flutter
  test` saves PNGs of the screens (`test/screens.dart`) to check layouts
  without a phone.
