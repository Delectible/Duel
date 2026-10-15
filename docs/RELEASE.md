# Release roadmap

Where Duel stands on the way to a public release on Google Play and the
App Store. Tick items as they land (`[x]`), note who does what (L = Luca in
a console / on a phone, C = Claude in the repo).

## 1. One-time Google Play setup

Do these in this order: the first .aab has to be signed with the real
upload key, because whatever key signs the first upload becomes the app's
upload key on Play.

- [x] **1.1 Repo secrets and variable** (L). GitHub > Delectible/Duel >
  Settings > Secrets and variables > Actions.
  - Secrets tab > New repository secret:
    - `ANDROID_KEYSTORE_BASE64`: the whole contents of
      `ANDROID_KEYSTORE_BASE64.txt` (one long line).
    - `ANDROID_KEYSTORE_PASSWORD`: the password Claude gave you.
  - Variables tab > New repository variable: `PLAY_RELEASE_STATUS` =
    `completed`.
  - Keep `duel-upload.jks` and its password somewhere safe (password
    manager / Drive). Never put it in the repo. If it's ever lost, Play
    Console > Test and release > App integrity > "Request upload key
    reset" fixes it (Play App Signing holds the real signing key).
  - Then tell Claude, who starts a build signed with that key.
- [ ] **1.2 Create the app** (L). Play Console > Home > Create app: name
  **Duel**, default language English (Australia) – en-AU, **App**, **Free**,
  tick the declarations > Create app. The package name is set by the
  first upload (`com.dingo.duel`; it can never change).
- [x] **1.3 First .aab by hand** (L). Test and release > Testing >
  Internal testing > Create new release > (accept Play App Signing if
  asked) > upload `Duel-N.aab` from the signed build in 1.1 > release
  name/notes are filled in > Next > Save and publish (or "Roll out").
  Testers tab: add an email list with your own Google account and open the
  "Join on the web" link once on your phone. If Play won't roll out yet,
  it lists what's missing under Dashboard > "Set up your app" (usually
  items from 1.6).
- [x] **1.4 Give the service account the app** (L). Play Console (account
  level, not inside the app) > Users and permissions > find Darkroom's
  service account (`…@….iam.gserviceaccount.com`) > Manage > App
  permissions > Add app > **Duel** > tick: View app information;
  Release apps to testing tracks; Manage testing tracks and edit tester
  lists; Edit store listing, pricing & distribution > Apply > Save changes.
  (If it already has account-wide permissions it covers Duel too.)
- [x] **1.5 Secret `PLAY_SERVICE_ACCOUNT_JSON`** (L): same place as 1.1,
  paste the full JSON key file of that service account (the one used for
  Darkroom; GitHub can't show Darkroom's copy back, so if you don't have
  the file: Google Cloud Console > IAM & Admin > Service accounts > that
  account > Keys > Add key > Create new key > JSON). From now on every
  `main` build goes to internal testing by itself. If the `play` job says
  "Only releases with status draft may be created on draft app", set
  `PLAY_RELEASE_STATUS` to `draft` until 1.3 is rolled out, then back to
  `completed`.
- [ ] **1.6 App content** (L). Play Console > Duel > Policy and programs >
  App content. Answers for Duel as planned (online play, accounts):
  - **Privacy policy:**
    `https://github.com/Delectible/Duel/blob/main/docs/PRIVACY.md`
  - **Ads:** No.
  - **App access:** All functionality is available without special
    access (until sign-in exists; then add a test account here).
  - **Content rating:** start questionnaire > email > category **Game** >
    violence, sex, language, drugs, crude humour: No. Simulated gambling:
    **No** (change to Yes if casino-style games with betting are added,
    e.g. poker with chips). Users can interact or exchange content: **Yes**
    (online play). Shares location: No. Digital purchases: No. Save >
    Submit.
  - **Target audience:** 13–15, 16–17, 18 and over (not under 13: that
    brings in the Families policy). Appeals to children: No.
  - **Data safety:** collects data: Yes; encrypted in transit: Yes;
    account creation: pick the sign-in method once chosen; delete-account
    URL:
    `https://github.com/Delectible/Duel/blob/main/docs/PRIVACY.md#deleting-your-account`.
    Data types (all "Collected", not shared, not ephemeral):
    - Personal info > **User IDs** (username, account ID): required; App
      functionality, Account management.
    - Personal info > **Email address**: optional; App functionality,
      Account management (drop it if sign-in ends up username-only).
    - App activity > **App interactions** (matches, moves, results):
      required; App functionality.
    - Device or other IDs (notification token): optional; App
      functionality.
  - **Government apps / Financial features / Health / News:** No / none.
- [ ] **1.7 Store listing** (L, C). Run Actions > "Play Store listing" >
  Run workflow: it uploads the title, descriptions, icon and feature
  graphic from `fastlane/metadata/android/en-AU/`. Store settings: category
  **Games > Card**, contact email. Play needs at least 2 phone screenshots
  before closed testing / production: upload them in Main store listing
  (C can stage them from screen tests later).
- [ ] **1.8 Closed testing** (L). _Later: internal testing only for now (Luca, 2026-10-10)._ Test and release > Testing > Closed
  testing > the "Closed testing - Alpha" track > Manage track:
  - Testers > Google Groups: `darkroom-closed-testing@googlegroups.com`;
    feedback email or URL > Save.
  - Countries / regions: add Australia (or all) > Save.
  - Then Actions > "Promote to closed testing" > Run workflow (empty build
    number = newest internal build), and Publishing overview > Send for
    review. Testers join at
    https://play.google.com/apps/testing/com.dingo.duel.

## 2. Google Play, towards production

- [ ] **12+ testers opted in to closed testing for 14 days in a row**
  (Google's rule for new personal developer accounts, per app). Then
  Dashboard > "Apply for production access". (L)
- [ ] Real screenshots and art. (C / L)
- [ ] Production release with a staged rollout. (L)

## 3. App Store (iPhone)

- [ ] First run of the sideloaded .ipa on an iPhone. (L)
- [ ] Apple Developer Program membership, App ID `com.dingo.duel`, CI
  signing + TestFlight upload from the macOS runner. (L creates the key,
  C wires CI)
- [ ] App Store Connect listing, privacy labels matching
  `docs/PRIVACY.md`, App Review. (L / C)

## Log

- 2026-10-10: repo, placeholder app and pipeline set up (build 1).
- 2026-10-10: build 1 (public test key) was the first upload, so Play
  registered the test key as upload key (SHA1 9C:9E:EA…). Upload key reset
  to the private key (SHA1 43:F2:1B…) requested 2026-10-11; valid from
  2026-10-12 14:00 UTC. `play` uploads fail until then; afterwards re-run
  build 2's `play` job.
- 2026-10-12: upload key reset done. Build 8 (0.5.0) re-run at 14:17 UTC:
  `play` uploaded to internal testing. Automatic uploads work from here
  (builds 3–7 never reached Play; 8 includes everything).
