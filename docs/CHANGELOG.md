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
- [x] **9.2 Spades vs bots** (v0.5): two-handed (draw your 13: keep the
  top card or pass for the next) or four players in teams (bot partner
  opposite). Bids with Nil (+/-100), spades break, bags (10 cost 100),
  -200 loses; play to 150 / 250 / 500, picked in the preview
  (`GameChoice`). Spades only takes 2 or 4 players (`playerCounts`);
  stakes count the other team only (`opponentsFor`). Bots: Easy (rough
  bids, some random cards), Normal (calibrated bids, cheap wins, lets a
  winning partner have it), Hard (card memory, knows who's out of a suit,
  covers a partner's Nil and busts opponents', ducks bags).
  `tool/spades/simulate.dart` for tuning. → 0.5.0 · 2026-10-12

### 10. Play at home

- [x] **10.1 Play at home:** a yellow "Play at home" button in every
  game's preview opens a follow-along guide for playing with your own
  cards (or board): What you need (which deck and how many, how many
  players, extras like chips or paper), then Setup / Gameplay / Winning as
  numbered steps, written for someone who has never played. Next walks
  through the parts. `HomeGuide` / `HomeGuideScreen` in
  `core/help/home_guide.dart`; each game's text in its folder
  (`at_home.dart`), `GameInfo.atHome`. → 0.4.1 · 2026-10-11

### 11. Online

- [~] **11.1 Online plan:** platform, roadmap, problems and limitations in
  `docs/ONLINE.md`. Decided: live first (play-by-turn later), money works
  like bot games (free, optional stakes; server wallet), Apple Developer
  account likely.
- [x] **11.2 Online foundations** (requested 2026-10-15: "do whatever you
  can on your end, then tell me what I have to do"): shared rules package
  (`packages/duel_engine`), Firebase in the app (off until configured;
  iOS + Android builds checked), the referee (`server/`: parties, Four in a
  Row moves, turn timer, rematch; tested on the Firestore emulator),
  security rules, deploy pipeline (`online.yml`, `setup_gcp.sh`). Luca's
  steps: `docs/ONLINE.md`, "Your steps".

- [x] **11.3 Play with a friend** (requested 2026-10-16): Friend mode
  goes live. Start a party (6-letter code, Copy invite) or join with a
  code; who's here, a crown on the host. The host picks games from home
  (only Four in a Row online so far; the others say "Online soon"); Play!
  opens it on both phones. Four in a Row online: your disc drops at once,
  45 s turns with a ring round the face, auto-move / forfeit on time,
  Rematch (both tap) or Back to party; leaving mid-game gives it up.
  Stakes: the host sets one, each phone puts it in and settles it (server
  wallet later). Reopening the app goes back to your party. Later: invite
  links, QR code, vote / first come. → 0.6.0 · 2026-10-16
- [x] **11.4 Face builder, simpler** (2026-10-16): your face on top, then
  a 2x2 of Colour / Shape / Face / Hat, each showing just that part with
  ‹ › arrows (was a grid of whole faces). → 0.6.0 · 2026-10-16

- [x] **11.5 Bots in online games + Texas Hold'em online** (2026-10-16):
  the host adds bots on the party screen (each with its own Easy / Normal
  / Hard, up to a table of 6); the server plays them. Hold'em goes online
  first: the server keeps the deck, each phone gets only its own two
  cards, everyone else's show at a showdown. Same table and animations as
  against bots, a 45 s turn clock, leaving folds you out while the rest
  play on, Rematch when the table's done. Decided for later: Spades
  partners: the host is asked who their teammate is. → 0.7.0 · 2026-10-16
- [x] **11.6 Everyone's out but the bots** (2026-10-16): when the last
  person busts, the bots aren't played out: they're ranked by their
  chances (each place drawn with odds by stack), so the game ends with a
  real 1st-to-last lineup. The game-over card shows the lineup (filling in
  while others still play) and says when bots were placed that way.
  → 0.7.0 · 2026-10-16

- [x] **11.7 Old games clean themselves up** (2026-10-16): every server
  document carries `expireAt`; Firestore's auto-delete (TTL, switched on
  by `online.yml`) removes games, their secret deck and private hands a
  day after the last move, and parties (with their codes) 30 days after
  the last change. Server only.

### 13. Blitz (a house game by a friend of Luca's)

- [x] **13.1 Blitz vs bots** (requested 2026-10-18): castles of 7 (face
  down, top face up), hands of 4; draw, then strike / scout / fortify /
  pair (once a turn, then go again) / BLITZ (five of a colour knocks down
  every face-up card in a castle, then another whole turn). Aces wild
  values (and hit face-down cards), own colour for a Blitz. Wars as an
  on / off choice with an (i): the smallest castle keeps its card, ties
  all lose, never your last card. 2–4 players one deck, 5–6 two (shown
  in the preview and the game). Bots by difficulty (`tool/blitz/
  simulate.dart`: Hard wins most, 30–60 turns a game, no stalls). Liberties
  taken: you must act (Pass only when nothing is possible); a pair needs
  two real values (Aces don't pair anything); a fortify puts the face-down
  card on, then the face-up one on top; Aces don't fight in wars; a Blitz
  spends your lowest five of the colour (keeping Aces and pairs); over 400
  turns the biggest castle wins. Online next. → 0.8.0 · 2026-10-18

### 12. Fixes

- [x] **12.2 Fix: stuck on the splash screen** (reported 2026-10-18,
  0.8.0): the app waited for Firebase to start before showing anything,
  so a slow or stuck start held it on the splash. Now the app shows at
  once; Firebase starts in the background (15 s limit) and Friend mode
  switches on when it's up (`PlaySetup.party` is settable, `DuelApp`
  follows it). → 0.8.1 · 2026-10-18
- [x] **12.1 Fix: Four in a Row bot never moved** (Normal / Hard, real
  speed): its background look-ahead sent a closure that dragged the
  controller (and its timer) into the isolate, which can't be sent, so the
  bot sat on "Thinking…" forever. Now only plain data crosses, with a
  fallback to thinking on the main thread; `row_isolate_test.dart` runs it
  at real speed. → 0.5.0 · 2026-10-12
