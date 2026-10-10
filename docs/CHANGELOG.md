# Duel change log

Running list of requested changes and when each one landed.

**How to read it**

- `[ ]` planned · `[~]` in progress · `[x]` done · `[-]` dropped
- Done items end with `→ version · date · commit`.
- Item numbers (e.g. **1.2**) stay fixed, so you can say "do 1.2 next".
- New requests go at the bottom of the current revision, or into a new
  revision section.

---

## Revision v0.1 (requested 2026-10-10)

### 1. Setup

- [x] **1.1 Pipeline:** the same build and release pipeline as Darkroom:
  APK, AAB and ad-hoc signed IPA under Releases (`build-N`), `main` builds
  to Play internal testing, promote-to-closed workflow, store listing from
  `fastlane/`, release signing from repo secrets. → 0.1.0 · 2026-10-10
- [x] **1.2 Placeholder app:** home screen with Play online / Play vs bot
  (coming soon) and About. → 0.1.0 · 2026-10-10
- [x] **1.3 Privacy policy:** `docs/PRIVACY.md`, written for online play
  (accounts, usernames, match data) with the backend still to be chosen.
  → 0.1.0 · 2026-10-10
- [ ] **1.4 Play Console setup:** Luca's one-time steps in
  `docs/RELEASE.md` section 1.

### 2. Games

- [x] **2.0 User story:** recorded in `docs/VISION.md` (party model,
  shared menus, games as plug-ins, GamePigeon-easy invites, phases).

- [ ] **2.1 Pick the backend and sign-in** for online play, then update
  `docs/PRIVACY.md` and the Data safety form to match.
- [x] **2.2 First card game** vs a bot: Texas Hold'em (see 3.4).
  → 0.2.0 · 2026-10-10
- [ ] **2.3 First card game** online.

## Revision v0.2 (requested 2026-10-10)

Ships as app version **0.2.0**.

### 3. Platform and poker

- [x] **3.1 Connection bar** at the top: Bots | Friend. Bots: difficulty
  (Easy / Normal / Hard, mixed personalities) and bot count 1-5. Friend:
  Party button. → 0.2.0 · 2026-10-10
- [x] **3.2 Game picker** greys out games that don't fit the player count
  (you + bots, or your party). Hold'em, plus Crazy Eights, Go Fish and
  Four in a Row as "Soon". → 0.2.0 · 2026-10-10
- [x] **3.3 Party screen** (online later): you as host, Invite a friend,
  "Who picks the game": Host decides / Vote / First come.
  → 0.2.0 · 2026-10-10
- [x] **3.4 Texas Hold'em Sit & Go vs bots**, 2-6 players, no-limit:
  1,500 chips; blinds up every 6 hands heads-up, 8 at 3-4 players, 10 at
  5-6. Side pots, all-ins, splits, proper heads-up blinds. Fold / Check or
  Call / Raise with - and + in big blinds (hold to repeat), Min, 1/2 Pot,
  Pot, All-in. Bots: Rookie, Rock, Shark, Maniac. → 0.2.0 · 2026-10-10
- [x] **3.5 Cartoon look:** Fredoka font, thick outlines, chunky buttons,
  drawn suits, card backs and bot faces. → 0.2.0 · 2026-10-10
- [ ] **3.6 Later:** progressive currency across games (replaces the
  fixed buy-in).

## Revision v0.3 (requested 2026-10-10)

Ships as app version **0.3.0**.

### 4. Poker feel

- [x] **4.1 Hand cheat sheet:** the hand name under your cards is bigger
  and tappable; it opens all ten hands, best first, with examples, your
  row outlined ("You") and scrolled to, your best five on top.
  → 0.3.0 · 2026-10-10
- [x] **4.2 Your deal:** when the button reaches you, tap or swipe the
  deck to riffle-shuffle (animation + haptics), then Deal (after at least
  one shuffle). → 0.3.0 · 2026-10-10
- [x] **4.3 Fix:** "Blinds up!" notice never showed. → 0.3.0 · 2026-10-10

