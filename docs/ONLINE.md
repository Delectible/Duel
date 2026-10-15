# Online play: plan

How Duel goes online. Priorities, in order: **stability, ease of use, speed**.
Tick items as they land (and log them in `CHANGELOG.md` as usual).

## Decisions (2026-10-11)

- **Live first, async later.** Games are mainly played live (both players in
  the app). Keep the door open to GamePigeon-style play-by-turn: game state
  lives in the database, so a game can wait hours for a move; only timers
  and notifications differ.
- **Money works like bot games.** Free to play; stake pips to win more. Online
  the wallet moves to the server (a phone-only wallet can be faked). The
  pips already on a phone carry over once, on first sign-in.
- **Apple Developer account ($99 USD/yr): likely.** Unlocks iOS push
  notifications ("your turn", invites), TestFlight instead of Sideloadly
  (no 7-day expiry), and the App Store release.
- **Region `us-east4` (2026-10-15).** Luca and friends are mostly in New
  York: ~20-40 ms there, ~250 ms from Australia (fine for turn games).

## Platform

**Firebase** (Google) for accounts, parties and live sync, plus a small
**Dart referee** on Cloud Run that runs the same game engines as the app.

- Accounts: Firebase Auth, anonymous (no sign-up). Later: link Google /
  Apple sign-in to keep a profile across phones.
- Live state: Firestore, region `us-east4` (Northern Virginia, near New York). Clients
  listen; only the referee writes game state. Each player's hand is a
  private document only they can read.
- Referee: Dart on Cloud Run, stateless, one warm instance (no cold
  starts). Checks every move with the shared engine, deals, runs bots,
  settles stakes.
- Push: Firebase Cloud Messaging (iOS needs the Apple account).
- Expected move-to-screen time: ~0.3–0.6 s.

### A move, end to end

1. Your phone sends "play 7♥" to the referee.
2. The referee loads the game, checks the move with the engine, applies it.
3. It writes the new public table, each private hand, and the events (the
   same event lists the animations and commentary use today).
4. Every phone's listener updates; the app animates the events.

### Limitations accepted

- iOS plugins must come as Swift Packages (no Podfile). Recent
  `firebase_core` reportedly supports SPM; not every Firebase plugin did.
  Prove it with a test iOS build before anything else.
- Turn-based only: fine for cards and Four in a Row, not twitch games.
- Anonymous accounts live on the phone until linked to a sign-in.
- Google lock-in for database / sync; the game logic stays plain Dart.
- Cost: about $0–10/month at friends-and-testers scale (pay-as-you-go plan
  with a budget alert).

### Alternatives considered

- Supabase: pure-Dart client, but free projects pause after a week idle and
  server functions are TypeScript (rules written twice).
- Nakama: parties / friends / matchmaking built in, but we'd host it and its
  server logic isn't Dart.
- Own Dart WebSocket server: fastest (~0.1 s) but we'd own reconnects,
  storage and scaling: worse for stability.

## Your steps (Luca)

What only you can do: the accounts and the clicks. About 30 minutes.
Everything after this deploys by itself from `main`.

1. **Firebase project.** console.firebase.google.com > Create a project,
   name it `Duel` (note the project id it gives, e.g. `duel-1a2b3`).
   Google Analytics: off (we don't need it; less in the privacy policy).
2. **Blaze plan** (pay as you go; Cloud Run needs billing). Project
   settings (gear) > Usage and billing > Modify plan > Blaze. Then set a
   budget alert: console.cloud.google.com > Billing > Budgets & alerts >
   Create budget, AUD 10 a month, alerts at 50 / 90 / 100 %. At our size
   it should cost roughly nothing (free tiers), the alert is the safety net.
3. **Sign-in.** Build > Authentication > Get started > Sign-in method >
   Anonymous > Enable.
4. **Database.** Build > Firestore Database > Create database > Standard
   edition, **location `us-east4` (Northern Virginia, near New York)**: this can never be
   changed. Start in **production mode** (our rules replace the defaults).
5. **The apps.** Project overview > Add app:
   - Android: package name `com.dingo.duel`, nickname Duel. Download
     `google-services.json`. Skip the remaining steps (no Gradle edits:
     I wire it in code).
   - iOS: bundle id `com.dingo.duel`. Download `GoogleService-Info.plist`.
     Skip the rest.
   Send me both files (or paste their contents). They're public
   identifiers, not secrets; I put the values in
   `lib/core/online/firebase_config.dart`.
6. **Server accounts.** console.cloud.google.com with the Duel project
   selected > the `>_` button (Cloud Shell) top right. Run:
   ```
   curl -sL https://raw.githubusercontent.com/Delectible/Duel/main/tool/online/setup_gcp.sh | bash -s YOUR-PROJECT-ID
   ```
   (or paste the script's contents from `tool/online/setup_gcp.sh` if it
   isn't on `main` yet). It ends by printing a key between two lines.
7. **GitHub.** Delectible/Duel > Settings > Secrets and variables >
   Actions:
   - Secrets > New repository secret: `GCP_DEPLOY_KEY` = the key from
     step 6 (everything between the lines, braces included).
   - Variables > New repository variable: `FIREBASE_PROJECT` = the
     project id.
   Then Actions > Online > Run workflow (branch `main`). When it's green,
   its summary shows the referee's address: send it to me.
8. **Later, not now:** the Apple Developer account (USD 99 a year) when we
   get to push notifications ("your turn", invites) and TestFlight. App
   Check (stops fake clients) comes with it.

What's already done on my side: the shared rules package, the referee
(parties, moves, timeouts, rematch) tested against a local Firestore,
the security rules, the deploy pipeline, Firebase in the app (switched
off until step 5's values are in), and the iPhone / Android builds
checked with Firebase.

## Roadmap

### Phase 0: ready the app (no backend)
- [ ] Game states and moves serialise to JSON (engines stay pure Dart).
- [ ] A `GameSession` layer: `LocalSession` (bots, today) and
      `RemoteSession` (online), same events into the existing controllers.
- [ ] Deterministic, seeded deals so the referee and tests agree.
- [x] Shared `duel_engine` package used by both app and referee.

### Phase 1: accounts and parties
- [x] Test iOS build with Firebase via Swift Package Manager (build 9:
      iOS and Android green with firebase_core / auth / cloud_firestore).
- [ ] Anonymous sign-in; profile (name, face) synced.
- [ ] Server wallet; one-time carry-over of local pips.
- [ ] Party: create / join by 6-letter code, QR, or share link; who's here
      (presence). Friend mode on home goes live.
- [ ] Privacy policy + Play Data safety updated; in-app account deletion.

### Phase 2: first online game, Four in a Row
- [x] Referee (`server/`): parties, moves, rematch, tested on the
      Firestore emulator; deploys to Cloud Run (`online.yml`).
- [x] Security rules (`firebase/firestore.rules`): players only read
      their own parties / games, only write their own name and face.
- [ ] Reconnect / resume after the app is backgrounded.
- [x] Turn timer (live: 45 s, then an auto-move; twice: forfeit)
      (referee side; the app's countdown comes with the online UI).
- [ ] Stakes settled on the server.

### Phase 3: card games online
- [ ] Crazy Eights, Go Fish (server deals; private hands).
- [ ] Poker: several humans plus server bots; the 10 s showdown timeout.
- [ ] Spades (once the game itself is built).

### Phase 4: the party flow
- [ ] Host pick / vote / first come; coin toss decided on the server.
- [ ] Moving between games together.

### Phase 5: polish
- [ ] Push: invites, "your turn" (needs the Apple account on iOS).
- [ ] Version check and "update to play".
- [ ] Crash reporting; App Check against fake clients.
- [ ] Name filter; preset emotes instead of chat.

### Later
- [ ] Play-by-turn mode (long timers + push).
- [ ] Friends list; Google / Apple sign-in.
- [ ] Matchmaking with strangers (maybe).

## Problems to expect

- **Hidden cards / cheating:** the server deals and checks every move.
- **Phones leaving the app:** connections drop; resume from the database,
  turn timers, auto-move, forfeit.
- **Different app versions:** protocol version check, "update to play".
- **Two-device testing:** Firebase emulator for automated tests; two
  phones for the real thing.
