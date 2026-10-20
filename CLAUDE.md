# Duel — notes for Claude

Read this first. Duel is a platform for card games: mostly online against
another player on the app, sometimes against a bot. Built on the same
build and release pipeline as Luca's other app, Darkroom
(github.com/Delectible/Darkroom).

**Online plan: `docs/ONLINE.md`** (Firebase + a Dart referee on Cloud Run;
decisions and phased roadmap). **The user story is in `docs/VISION.md`**: one-on-one card / table games
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
  pre-release (no Play upload). Nothing is published unless the checks pass
  and the `launch` job has opened the release APK on an emulator ("Duel:
  first frame" in its log; keep that line in `main.dart`).
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
  (and `ios`) to fill in the rest (it never overwrites existing files),
  then restores `pubspec.lock` (`flutter create` upgrades packages; that
  once shipped a broken plugin) and runs `flutter pub get
  --enforce-lockfile`. `android-smoke.yml` (by hand) launches main's and a
  branch's release APK on an emulator and saves the logs.
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

Flutter stable (≥ 3.47, Dart ≥ 3.12), Material 3. Packages: `shared_preferences`
(saves the account) and Firebase (`firebase_core`, `firebase_auth`, `cloud_firestore`), all SPM on iOS.
State is ChangeNotifier + InheritedNotifier. Font: Fredoka (assets/fonts, OFL), static
weights cut from the variable font.

## Online (plan and Luca's setup steps: `docs/ONLINE.md`)

- App: `lib/core/online/`: `FirebaseConfig` (Android / iOS options and
  the referee's URL), `Online.start()` in `main.dart` (never blocks the
  app if Firebase fails; then `PartyScope` is null and Friend mode says
  so). `party.dart`: `PartyService` (sign-in, create / join / leave /
  start, match calls; follows the live party + match docs, keeps the
  newest `version`; `Account.partyId` rejoins on launch) over an
  `OnlineBackend` (`firebase_backend.dart`; tests: `test/online/
  fake_server.dart` = the real referee + routes in memory, run on the
  test clock, never in `runAsync`).
- Friend mode: `features/party/party_screen.dart` (start / join by code,
  members, crown on the host). The host's Play! in the preview calls
  `party.start`; home's `_MatchWatcher` opens `GameInfo.openOnline` on
  every phone. `blocked()` greys games without `openOnline` ("Online
  soon") and, for guests, says the host picks. Each phone puts in and
  settles the match's `stake` locally (server wallet: later).
- Leaving and coming back (`features/party/lobby.dart`, all from the
  server's match: `left`, `standIns`, `paused`): one person left among
  bots → the game ends (`reason: ended`, stakes back for those in); a
  one-on-one with no bots → the other wins; 2+ still in → `paused` until
  the host (or the next person playing, made host) picks bot / end
  (`PausedCard`; any phone brings in the bot after 30 s). Leavers see Game
  In Progress (preview) / Rejoin (`NowPlaying` on the party screen); the
  stake they lost comes back (`Account.leftGame` / `takeBack`). One live
  game per party; the host can end it (`endMatch`). The watcher only opens
  a game for `party.inGame`.
- Online Four in a Row: `RowScreen.online` with `OnlineRowController`
  (implements `RowTable`, like the bot's `RowController`): you're always
  red (seats remapped), your drop shows at once, turn ring counted from
  `turnAt`, either phone claims a turn that ran out, Rematch / Back to
  party.
- Bots online: the host sets `party.bots` (`PartyBot`: name, look,
  difficulty; party screen), they take seats (`bot:N`) and the referee
  plays them. Online Hold'em: `PokerScreen.online` +
  `OnlinePokerController` (part of `poker_controller.dart`; replays the
  server's moves through the same table via the controller's hooks:
  `_canDeal`, `_nextDeck` (`Deck.lazy`), `_canAdvance`, `_actFor`; you at
  seat 0, seats turned round). Your cards: `party.mine`.
- Referee: `server/` (own Dart package, excluded from the app's analyze):
  `Referee` (parties, matches, moves with a `version` check, timeouts,
  forfeit, rematch) over a `Store` (`MemoryStore` in tests,
  `FirestoreStore` on Firestore REST), `api.dart` (shelf routes, Firebase
  ID token check), `games.dart` (`OnlineGame` per game: Four in a Row,
  `poker_game.dart` Hold'em; full state in `secrets/{id}`, public in the
  match, `private` per player in `matches/{id}/hands/{uid}`). Players only
  read Firestore; only the referee writes.
  Every write goes through `_put`, which stamps `expireAt` (games a day
  after the last move, parties 30 days); Firestore TTL deletes them.
- `firebase/`: `firestore.rules` (+ emulator config). Test locally from
  `firebase/`: `firebase emulators:exec --only firestore --project
  demo-duel "cd ../server && dart test"`.
- `.github/workflows/online.yml`: checks server/ (analyze, format, tests on
  the emulator, image build) on every push touching it; on `main` also
  deploys the rules and the referee (Cloud Run, us-east4) if
  secret `GCP_DEPLOY_KEY` and variable `FIREBASE_PROJECT` exist (made by
  `tool/online/setup_gcp.sh`). Server-only changes don't build the app.

## App layout

- **Game rules and bots** live in `packages/duel_engine/` (pure Dart path
  package, no Flutter: `cards.dart`, `difficulty.dart`, `<game>/…`), shared
  by the app and the online referee (`server/`). Below, a game's
  `engine/x.dart` means `packages/duel_engine/lib/<game>/x.dart`; import it
  as `package:duel_engine/<game>/x.dart`. Never import Flutter there.

- `lib/main.dart`: `DuelApp` (loads the `Account`, applies light / dark,
  `AccountScope` + `PlaySetupScope`).
- `lib/core/account/`: `Account` (name, avatar, pips balance (may go
  negative: debt), currency display, theme, per-game stats; saved by
  `PrefsStore`), `stake.dart` (`StakeTicket`: the stake is taken at Play!
  and settled once per game; `StakeBadge`, `StakeResult`, `confirmLeave`
  forfeits). Win = stake back + stake x opponents x difficulty rate.
- `lib/core/avatars/faces.dart`: `Avatar` (skin, head, eyes, nose,
  mouth, hat (hair and hats), extra; all open for now; `withPart` /
  `partValue` by `FacePart`; `Avatar.random`, `Avatar.forName` (online
  bots: same face on every phone); `toJson` keeps the old `face` key for
  older apps, `fromJson` maps it back), `Persona` (`Persona.bots`: random
  names from `botNames`, random faces), `Face` (`Face.part`: one part or
  a close-up, for the profile's tabbed builder). Drawn by `FacePainter`
  in `face_art.dart` (part file: outlines, shading, ears; `_fit` keeps
  tall / wide hats in the box; `_rise` / `_halfWidth` per hat). Offline poker
  deals each bot a random hidden `BotStyle`; online, the referee maps
  party bots' `Look`s to styles.
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
  `Difficulty`, bot count; `party` and `partySize`), shared by every screen.
- `lib/core/theme/toon.dart`: the cartoon look (`Toon` colours, `ToonBox`,
  `ToonButton` with hold-to-repeat, `chips()` formatting). Use these, not
  stock Material buttons. **Dark mode:** `Toon.ink/fg/paper/card/muted/grey`
  are getters that follow `Toon.dark`, so never put them in `const`;
  `Toon.text` inherits its colour (ToonBox / ToonButton pick a readable
  one); on a bright fill use `Toon.on(color)`. Cards stay white
  (`cardFace`).
- `lib/core/cards/` (+ `duel_engine/cards.dart`): `PlayingCard` / `Deck` and `CardView` (suits are drawn
  paths; Fredoka has no suit glyphs). Shared by every card game.
- `lib/games/catalog.dart`: the game picker's list (`GameInfo`: player
  range, tile art (`tile_art.dart`: a small painted scene per game, about
  84 x 64, scaled to the tile), sample `board` (`previews.dart`), `rules`, `minutes`
  per player count, `open`; null `open` = "Soon"; `blocked(setup)` says
  why Play! is off). Adding a game: its folder in `lib/games/` plus one
  entry here.
- `lib/features/preview/`: every game tile opens `GamePreviewScreen`
  (rules, time, sample board, Play! / Nevermind). Only Play! counts; in a
  party it will be the vote / pick, browsing never is.
- poker engine (`packages/duel_engine/lib/poker/`): `hand_eval.dart`
  (best five of seven, descriptions), `poker_hand.dart` (one no-limit hand:
  blinds, betting rules incl. incomplete all-in raises, side pots, odd
  chips), `sit_and_go.dart` (button, blind levels per table size, places),
  `bot.dart` (9 `BotStyle`s: ranges per opponent, position, c-bets /
  barrels / check-raises / traps, `Sizing`, timing `Tell`s via
  `think()` → `Decision.tempo`, tilt, ICM; `classify`, `outs`,
  `preflopRank`), `reads.dart` (`TableReads`: per-player stats from every
  action (call `observe` before `apply`), tilt, sizing tells, the last 20
  hands; bots read it, the app shows it).
  `dart run tool/poker/simulate.dart [n] [easy|normal|hard]` plays bot-only
  Sit & Gos for tuning.
- `lib/games/poker/ui/`: `PokerController` (paces the table: deals, bots
  think 2–10 s from their tempo (`hurry()` = Skip); `styles` hidden and
  random per bot; `reads`; `lineup`), collect, payout; `pace` 0.05 in tests;
  `talk` (bots' lines, `table_talk.dart`), `odds` when all in
  (`duel_engine/poker/odds.dart`), `bigWin`), `chips.dart` (`ChipPile`:
  3D chips by value), `table_view.dart` (seats
  around the felt, clockwise from you at the bottom; chips fly to the pot
  and winners), `action_bar.dart`, `hand_chart.dart` (the hands cheat sheet, opened from your hand's
  name; `handRanks`), `shuffle_deck.dart` (your deal: the controller's
  `TablePhase.shuffle` waits for a shuffle and Deal; tests use
  `shuffleAndDeal`), `table_stats.dart` (`TableInfo` strip, read cards
  (tap a seat), hand history, `oddsLine` (`Account.pokerOdds`),
  `GameSummary` with `pickQuotes`). Showdown results wait for Next hand
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
- `lib/games/spades/`: `engine/spades.dart` (two-handed draw or partners,
  bids incl. Nil, tricks, scoring with bags, events), `engine/spades_bot.dart`
  (`estimate` / `suggest` calibrated by `tool/spades/simulate.dart`);
  `ui/spades_controller.dart` (pacing, trick pause + sweep, commentary),
  `ui/spades_screen.dart` (`spadesGuide`). `GameInfo.choice` (play to
  150/250/500), `playerCounts` {2, 4}, `opponentsFor` (team stakes).
- `lib/games/blitz/`: a house game (castles of cards). `engine/blitz.dart`
  (moves: `Strike`, `Scout`, `Fortify`, `Pair`, `BlitzAttack`, `PassTurn`;
  `moves(p)` lists what's legal; events; wars; `decksFor(players)`),
  `engine/blitz_bot.dart` (scores moves; `tool/blitz/simulate.dart`),
  `ui/blitz_controller.dart` (pick up a card, `moveAt` lights its targets),
  `ui/blitz_screen.dart` (a strip per player: face + castle; two columns on
  its side with 4+ players; your hand + Pair / BLITZ in the controls,
  `blitzGuide`, `blitzWarsInfo`, `WarScene`: a war's clash over the felt
  while the controller is `fighting`). `GameChoice` Wars (on / off, `info` (i),
  `showValues: false`), `GameInfo.note` (decks chip).
- `lib/core/help/home_guide.dart`: "Play at home" (preview button):
  `HomeGuide` (what you need, setup, gameplay, winning) per game in
  `lib/games/<game>/at_home.dart`, `GameInfo.atHome`. Written for someone
  who has never played cards; every game needs one.
- `lib/core/help/game_guide.dart`: the mid-game "How to play" sheet
  (`GuideStage`s, `GuideButton` in every game's top bar, "You are here").
  Every game needs one; keep players told what's happening (commentary,
  bubbles, status lines).
- `lib/features/home/`: home (connection bar + game grid, About),
  `lib/features/party/`: party screen, `vote.dart` (`tallyVotes`,
  `tossCoin`) and `coin_toss.dart` (tie-break animation; takes the
  result), kept for when Vote / First come arrive (host picks for now).
- Tests: engine rules in `test/<game>/`; screens at Pixel 9 Pro and 360 dp
  with the real fonts (`test/flutter_test_config.dart`); `SHOTS=dir flutter
  test` saves PNGs of the screens (`test/screens.dart`) to check layouts
  without a phone.
