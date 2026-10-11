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
- [x] **3.6 Later:** progressive currency across games (replaces the
  fixed buy-in). → pips, see 6.3 · 0.4.0

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
- [x] **4.4 Read the result:** after a showdown the table waits for **Next
  hand** (bot games: no time limit; `resultTimeout` 10 s for online games,
  with a countdown on the button). Hands won by folds move on by
  themselves. → 0.3.0 · 2026-10-10
- [x] **4.5 Vote ties → coin toss:** in an online party with Vote on, a
  tie is settled by a coin toss: a gold coin with a tied game on each face
  flips, spins and lands on the winner ("Crazy Eights it is!"). Decided
  before the toss (server-side online) so every phone shows the same
  result. `tallyVotes` / `tossCoin` in `features/party/vote.dart`; party
  screen has "Try the coin toss" until online play exists.
  → 0.3.0 · 2026-10-10
- [x] **4.6 Game previews:** tapping any game opens a preview first: the
  basic rules, an estimated time for your player count, a sample board,
  and Play! / Nevermind. Only Play! counts (in a party it will be your
  vote / pick; previews never vote or start a coin toss). Games that can't
  start yet still preview, with the reason over a greyed Play!.
  → 0.3.0 · 2026-10-10

### 5. Crazy Eights and help

- [x] **5.1 Crazy Eights vs bots** (you + 1-3 bots): classic rules (match
  suit or number, eights wild + name a suit, draw one if stuck and play it
  if it fits, first out wins; 7 cards heads-up, 5 with 3-4; reshuffle when
  the deck runs out; blocked game: fewest cards wins). Bots: Easy (any
  card), Normal (saves eights, steers to its long suit), Hard (also plays
  into suits a nearly-out player lacks). → 0.3.0 · 2026-10-10
- [x] **5.2 Animations:** deal, cards fly to the pile from whoever played,
  draws fly from the deck, the named suit pops up after an eight, "Last
  card!", suit confetti when you win. → 0.3.0 · 2026-10-10
- [x] **5.3 Commentary:** a line under the top bar says what just happened
  and what you can do ("Your turn: play a heart or a 7, or an 8 (wild)"),
  with the suit to follow; playable cards lift and glow. → 0.3.0 · 2026-10-10
- [x] **5.4 How to play in every game:** a ? button in the top bar opens
  the game's guide by stage, "You are here" on the current one (poker:
  deal, preflop, board, betting tools, showdown, winning). → 0.3.0 · 2026-10-10

## Revision v0.4 (requested 2026-10-10)

Ships as app version **0.4.0**.

### 6. Two more games, money, profile, settings

- [x] **6.1 Go Fish vs bots** (you + 1-5 bots): ask a player for a rank
  you hold, take all they have and go again, else fish from the pond (go
  again if you fish what you asked for); four of a kind is a book; most
  books wins. Speech bubbles, cards fly between hands and from the pond,
  book pops, commentary, guide. Bots: Easy (random asks), Normal (recent
  memory), Hard (remembers every ask). → 0.4.0 · 2026-10-10
- [x] **6.2 Four in a Row vs a bot:** 7 x 6 board, discs drop and
  bounce, the winning four glow; hints mark a column you can win in (star)
  or must block (arrow). Bot looks ahead with minimax: Easy 2 moves (and
  slips), Normal 4, Hard 7. First move alternates. → 0.4.0 · 2026-10-10
- [x] **6.3 Pips (universal currency):** start with 100. Free games win
  nothing; stake on a game (picked in the preview) and a win pays the
  stake back plus stake x opponents (Easy x0.5, Normal x1, Hard x1.5); a
  loss or leaving early costs the stake; a tie returns it. Out of money:
  stake 1 anyway and go into debt, paid back from winnings (no time
  limit). → 0.4.0 · 2026-10-10
- [x] **6.4 Profile:** name, face (8 to pick), wallet, and your record
  per game. Button top-left on home. → 0.4.0 · 2026-10-10
- [x] **6.5 Settings** (gear next to the profile): Match phone / Light /
  Dark, every screen and game follows; money shown as pips (Duel's own),
  US dollar, euro, pound, yen or Australian dollar (display only).
  → 0.4.0 · 2026-10-10
- [x] **6.6 Harder bots:** Hard plays tight in every game (see 6.1, 6.2).
  → 0.4.0 · 2026-10-10

### 7. Faces and landscape

- [x] **7.1 Build your face:** in the profile pick a colour, head shape,
  face and hat, four of each (more to unlock later). Bots keep their own
  looks. → 0.4.0 · 2026-10-11
- [x] **7.2 Landscape:** every screen and game works with the phone on its
  side and follows the phone's auto-rotate setting (Android
  `screenOrientation="user"`; iOS honours the rotation lock). Games put
  the table on the left and the top bar, commentary and buttons in a
  panel on the right; menus split into two columns. → 0.4.0 · 2026-10-11
- [x] **7.3 Rotation fade:** turning the phone fades the new layout in.
  → 0.4.0 · 2026-10-11
- [~] **7.4 Glitch sweep:** `test/sweep_test.dart` renders every screen
  and game light / dark, upright / on its side, with the How to play
  sheet. More testing to come.

## Revision v0.4.1 (requested 2026-10-11)

Ships as app version **0.4.1**.

### 8. Staking fixes

- [x] **8.1 Fix:** holding the stake − down to Free left the button stuck
  down and + / − dead. A button switched off while held now lets go
  (`ToonButton`; also covers the poker raise ±). → 0.4.1 · 2026-10-11
- [x] **8.2 Stake row labelled:** "Your stake" with what you have (or your
  debt) and an (i) that opens "How staking works" (`stakeRules`, shared
  with Settings). → 0.4.1 · 2026-10-11
- [x] **8.3 Dark mode suits:** black suits off the cards (Crazy Eights
  suit picker, suit burst, confetti) get a light outline in dark mode;
  on cards and light chips they stay plain (`SuitIcon(onLight:)`).
  → 0.4.1 · 2026-10-11

### 9. Spades

- [x] **9.1 Blank template:** Spades on the picker as "Soon" (2–4
  players, rules, time, sample board in the preview). `lib/games/spades/`:
  `engine/spades.dart` (deals 13 each, two-handed or partners; bids and
  tricks to come), `ui/spades_screen.dart` (`SpadesScreen` on the shared
  `GameLayout`, shows your hand; `spadesGuide`). Switch it on with an
  `open` in its catalog entry. → 0.4.1 · 2026-10-11
- [ ] **9.2 Spades vs bots:** bidding, trick play, scoring to 500, bots,
  animations and commentary.

### 10. Play at home

- [x] **10.1 Play at home:** a yellow "Play at home" button in every
  game's preview opens a follow-along guide for playing with your own
  cards (or board): What you need (which deck and how many, how many
  players, extras like chips or paper), then Setup / Gameplay / Winning as
  numbered steps, written for someone who has never played. Next walks
  through the parts. `HomeGuide` / `HomeGuideScreen` in
  `core/help/home_guide.dart`; each game's text in its folder
  (`at_home.dart`), `GameInfo.atHome`. → 0.4.1 · 2026-10-11
