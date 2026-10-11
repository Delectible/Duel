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

## Platform

**Firebase** (Google) for accounts, parties and live sync, plus a small
**Dart referee** on Cloud Run that runs the same game engines as the app.

- Accounts: Firebase Auth, anonymous (no sign-up). Later: link Google /
  Apple sign-in to keep a profile across phones.
- Live state: Firestore, region `australia-southeast1` (Sydney). Clients
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

## Roadmap

### Phase 0: ready the app (no backend)
- [ ] Game states and moves serialise to JSON (engines stay pure Dart).
- [ ] A `GameSession` layer: `LocalSession` (bots, today) and
      `RemoteSession` (online), same events into the existing controllers.
- [ ] Deterministic, seeded deals so the referee and tests agree.
- [ ] Shared `duel_engine` package used by both app and referee.

### Phase 1: accounts and parties
- [ ] Test iOS build with Firebase via Swift Package Manager.
- [ ] Anonymous sign-in; profile (name, face) synced.
- [ ] Server wallet; one-time carry-over of local pips.
- [ ] Party: create / join by 6-letter code, QR, or share link; who's here
      (presence). Friend mode on home goes live.
- [ ] Privacy policy + Play Data safety updated; in-app account deletion.

### Phase 2: first online game, Four in a Row
- [ ] Referee on Cloud Run; moves, rematch.
- [ ] Reconnect / resume after the app is backgrounded.
- [ ] Turn timer (live: ~45 s, then an auto-move; repeated: forfeit).
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
