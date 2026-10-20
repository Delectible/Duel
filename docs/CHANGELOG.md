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
- [x] **13.2 Aces only wild from your hand** (2026-10-18; undone by 13.5): an Ace in a
  castle is just an Ace, so only another Ace can strike (or fortify) it;
  an Ace from your hand still matches anything, face down too. Guides
  updated. → 0.8.2 · 2026-10-18
- [x] **13.3 Bubbles don't hide cards** (2026-10-18): Blitz's speech
  bubbles ("Strike!", "-1"…) sit over the player's face instead of their
  castle, and fade out after 2.5 s. → 0.8.2 · 2026-10-18
- [x] **13.4 War scene** (2026-10-18): a war covers the felt: "WAR! over
  7s", the fighters' faces with crossed swords that swing in and clash
  (two face off; three to six stand in a ring round the swords), then
  whoever lost a card tumbles off the bottom (-1) while the rest hold
  their ground (shield), with a line saying who lost what. "Nobody
  falls" when it's everyone's last card; several wars play one after
  another. The game waits for it (`fighting`). `WarScene`,
  `war_scene_test.dart`. → 0.8.2 · 2026-10-18
- [x] **13.5 Aces wild in castles again** (2026-10-18): 13.2 was a
  misremembered rule; back to the original: any card strikes (or
  fortifies onto) an Ace, and an Ace from your hand matches anything.
  → 0.8.3 · 2026-10-18
- [x] **13.6 Castle cards move, not pop** (2026-10-18): a card that goes
  lifts off and fades while the row slides together; a new card drops in;
  a card turning over flips. A war's result waits for its scene: the
  table shows the castles as they stood before the fight (`War.before`,
  `BlitzController.castle`) until it's over. → 0.8.3 · 2026-10-18
- [x] **13.7 New game pictures** (2026-10-18): the home tiles get little
  scenes (`lib/games/tile_art.dart`): Blitz a fighter plane firing cards,
  Hold'em pocket Aces with a chip stack, Crazy Eights an 8 with the four
  suits whirling round it, Go Fish a fish that's caught a card, Four in a
  Row a disc dropping into the board, Spades a garden spade whose blade is
  a spade. The picture now grows to fill its tile. → 0.8.3 · 2026-10-18
- [x] **13.8 Face builder: only the changed box swaps** (2026-10-18):
  each part box was keyed by the whole face, so changing one part popped
  all four; now each is keyed by its own part. → 0.8.3 · 2026-10-18
- [x] **13.9 Never more than 5 in hand** (2026-10-18): every turn uses one
  card (draw to 5, end on 4). With nothing to hit, scout or fortify you
  used to pass and keep all five (then draw a sixth); now you throw a card
  of your choice away (`Discard`; bots pick their least useful). A test
  checks the hand sizes through 60 bot games. → 0.8.3 · 2026-10-18

### 14. Texas Hold'em, more fun with bots (requested 2026-10-18)

- [x] **14.1 Chips**: stacks of round chips with depth, edge stripes
  and a shine, coloured by value (yellow 1,000, purple 500, black 100,
  green 25, red 5, white 1; `ui/chips.dart`); bets slide out from the
  player each time they put more in; the pot is up to three stacks.
- [x] **14.2 The deal**: cards spin out from the dealer one at a time,
  round the table from the dealer's left, twice; yours flip over as they
  land (`PokerController.dealGap`).
- [x] **14.3 Bots take their time**: 2–10 s a move, mostly 2–4, longer
  when there's a lot to call; a "…" bubble while they think; **Skip**
  hurries them until it's your move or the next hand (offline only).
- [x] **14.4 Table talk**: each bot look has a voice (rookie nervous, rock
  terse, shark smug, maniac loud) and now and then says something after
  an all-in, a big raise, folding to you, winning, losing, a lucky
  win or being knocked out (`ui/table_talk.dart`).
- [x] **14.5 All-in drama**: when it's all in the cards turn up with each
  hand's chance to win (`duel_engine/poker/odds.dart`), an ALL IN!
  banner, and the board deals slowly with the chances updating.
- [x] **14.6 Big pots**: "BIG WIN!" / "HUGE POT!" slams in, chips rain,
  and stacks count up to their new size.
- [x] **14.7 Shuffle quips**: past 10 shuffles "Not random enough for
  you?", past 20 "The cards are getting dizzy…", past 30 "They're
  shuffled. Promise."
- [x] **14.8 Fixes**: money under names was black on dark grey in dark
  mode (now white like the name; checked every game, two icons fixed
  too); the yellow outline on winning cards is a ring with rounded corners
  that fits the card; folded cards slide off to the middle; the seats
  keep their animations when the pot or a banner appears.
  → 0.8.3 · 2026-10-18

### 15. Party games: leaving and coming back (requested 2026-10-19)

- [x] **15.1 Leaving ends or pauses, never limps on**: with only one
  person left (among bots) the game ends: whoever left loses their stake,
  the rest get theirs back. A one-on-one with no bots: the one who stays
  wins. Two or more still in: the game pauses (nobody can move) and the
  host chooses **Bring in a bot** (it plays the seat from where it is) or
  **End the game**; after 30 s any phone brings in the bot. If the host
  left, the next person still playing becomes host and decides.
- [x] **15.2 Game In Progress**: whoever left sees it on that game's Play
  button (and Rejoin on the party screen): they take their seat back as it
  stands (from the bot, or straight back during the pause), and the stake
  they lost by leaving comes back (`Account.leftGame` / `takeBack`). The
  game no longer pulls a leaver back in by itself.
- [x] **15.3 One game at a time**: no new game while one is live (the
  others say "In progress"); the host can end it for everyone from the
  party screen (**End game**, stakes back); one untouched for 10 minutes
  is ended when a new one starts. Leaving the party leaves its game too.
  A rematch is for those who stayed.
- [x] **15.4 Every phone sees the same**: it's all on the server's match
  (`left`, `standIns`, `paused`), the phones only show it. Referee:
  `decide`, `rejoin`, `endMatch` (+ routes); tests: `server/test/
  lobby_test.dart` (incl. random leaving / rejoining / deciding), the
  Firestore emulator, and `test/online/lobby_flow_test.dart` (three
  phones). → 0.8.5 · 2026-10-19

### 16. Hold'em like a real table (requested 2026-10-20)

- [x] **16.1 Bots that think like players** (`duel_engine/poker/bot.dart`):
  they put each opponent on a range of hands (from position, raises,
  calls, and what they've seen them do this game) and weigh their cards
  against it; open wider late, steal blinds, 3-bet, defend; c-bet,
  double-barrel, check-raise, slow-play, semi-bluff draws; bet sizes in
  their own way; tighten up near the money and push / fold when short.
  Hard reads you fully, Easy plays loose and doesn't read at all (Hard
  beats Easy about 2 games in 3 in `tool/poker/simulate.dart`).
- [x] **16.2 They study you** (`poker/reads.dart`, `TableReads`): every
  action is noted (hands played, raises, aggression, folds to bets,
  showdowns, bluffs caught, big-bet sizing honesty); bots exploit what
  they see (bluff the folders, call the bluffers, believe honest bettors).
- [x] **16.3 Tells and tilt**: each bot's thinking time follows its own
  pattern (some tank with a bluff, some with a monster, some are
  unreadable); losing a big pot puts them on tilt for a while.
- [x] **16.4 Nine personalities, hidden**: Rookie, Rock, Shark, Maniac,
  plus Grinder, Fish, Trapper, Bully, Sheriff, each with its own voice.
  Bots get random names (120) and random faces; you work out who's who
  from play. The summary reveals them.
- [x] **16.5 Read cards**: tap any player (or yourself) for their numbers
  and notes in plain words ("Folds to bets often: a good one to bluff").
- [x] **16.6 Table info**: your place, your stack in big blinds, the
  average stack, a trophy on the chip leader, and **Hands**: the last 20
  hands, action by action, with the cards that were shown.
- [x] **16.7 Pot odds and outs** by your buttons ("Pot odds 3.0 : 1 · you
  need 25%", "9 outs · 35% to hit by the river"); Settings can hide it.
- [x] **16.8 Game summary**: your hands won, biggest pot, best bluff and
  hands played, then the whole lineup in finishing order, each with a line
  picked from their most stand-out stat ("Caught bluffing 3 times, never
  blushed.") and what each bot really was. → 0.8.6 · 2026-10-20
- [x] **16.9 Online bots on the new brain** (2026-10-20): the referee
  rebuilds the table's memory (`TableReads`) as it replays each hand, so
  party bots read everyone like offline. Every seat gets a hidden random
  style at the start (no two alike; matches started earlier still play by
  look), revealed in the summary once it's over. Each bot move carries
  its thinking time (`[kind, amount, tempo%]`, only for bots); phones
  show it (1–4 s, `onlineThinkMs`) while you're in the hand, and the next
  person's clock allows for it. → 0.8.7 · 2026-10-20

### 17. Faces, redrawn (requested 2026-10-20)

- [x] **17.1 More parts, all open**: skin (16 tones), head (6 shapes),
  eyes (14), nose (7), mouth (14), hair & hats (28: afro, bob, bun,
  mohawk, beanie, cowboy, top hat, wizard, party hat, chef, viking, halo,
  horns, bunny and cat ears, pirate, headphones…) and extras (15:
  glasses, shades, monocle, eyepatch, beard, goatee, mustache, scar,
  earrings…). Unlocks can come later; everything is open for now.
- [x] **17.2 Polished look**: same thick outlines, now with ears, soft
  shading and highlights; each face is fitted so tall hats and wide hair
  stay in the circle (`core/avatars/face_art.dart`).
- [x] **17.3 Face builder**: a tab per part and a grid of every option
  drawn on your own face (close-ups for eyes, nose and mouth), plus
  **Surprise me**.
- [x] **17.4 Bots wear them too**: random faces offline; online bots get a
  face from their name, the same on every phone. Faces saved by older
  versions come back as the nearest new ones, and older apps still see a
  sensible face. → 0.8.6 · 2026-10-20

### 12. Fixes

- [x] **12.5 Fix: online Hold'em could stall** (found 2026-10-20 by the
  fuzz test): a hand can finish with no moves at all (a short stack all in
  on the blinds against one other player), and the referee only dealt the
  next hand after a move, so nobody was to act. It now keeps dealing until
  someone has to act. → 0.8.7 · 2026-10-20

- [x] **12.4 Fix: Blitz buttons hidden behind your hand** (found
  2026-10-20 by a test): on a small phone on its side, with Pair and
  BLITZ both on offer, the second button wrapped onto a new line under
  your cards and couldn't be tapped. They now stay on one line, shrunk to
  fit. → 0.8.6 · 2026-10-20

- [x] **12.3 Fix: online Hold'em "Something went wrong"** (reported
  2026-10-19): Firestore can't store a list directly inside a list, and
  Hold'em keeps its moves as `[kind, amount]` pairs in per-hand lists, so
  the referee's first write of a Hold'em game failed (Four in a Row, the
  only game tested on the emulator, has none). `FirestoreStore` now stores
  an inner list as `{_list: [...]}` and unwraps it on reading; the app
  unwraps it too (`unnestLists`). The emulator test now plays a whole
  Hold'em game with two people and two bots, and a fuzz test plays 40
  random ones on the referee. → 0.8.4 · 2026-10-19

- [x] **12.2 Fix: stuck on the splash screen** (reported 2026-10-18,
  0.8.0). Cause (found on an emulator, `android-smoke.yml`): CI's
  `flutter create .` re-resolves packages and ignored `pubspec.lock`, so
  build 13 shipped shared_preferences_android 2.5.0 (out the day before,
  now JNI-based), whose `getAll` call fails in release builds; reading the
  saved account threw before the app drew anything. Now CI puts the
  committed lockfile back after `flutter create` (`pub get
  --enforce-lockfile`), a failed account read falls back to an unsaved
  one, and the app no longer waits for Firebase either (starts in the
  background, 15 s limit; Friend mode switches on when it's up).
  → 0.8.1 · 2026-10-18
- [x] **12.1 Fix: Four in a Row bot never moved** (Normal / Hard, real
  speed): its background look-ahead sent a closure that dragged the
  controller (and its timer) into the isolate, which can't be sent, so the
  bot sat on "Thinking…" forever. Now only plain data crosses, with a
  fallback to thinking on the main thread; `row_isolate_test.dart` runs it
  at real speed. → 0.5.0 · 2026-10-12
