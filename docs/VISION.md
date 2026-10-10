# Duel — the user story

Luca's description of what Duel is for (2026-10-10). Design and
development choices should serve it; when a choice conflicts with it,
raise it with Luca.

## The story

> Duel is a platform for playing card games, or any kind of table game,
> with one specific person (groups maybe later; one-on-one first).
>
> - A **home page** where you pick a game.
> - Before the game picker, a choice of **real opponent or bot**.
> - A way to **find and connect to your friend**, who also has the app.
> - Once connected, you **navigate the menus and pick games together**,
>   staying connected: jump from one game to the next, synchronised,
>   without reconnecting every time.
> - Games that don't fit the number of players you have are **greyed out**.
> - Connecting should feel as easy as **GamePigeon** on iOS.

## What it means for the design

- **The party is the unit, not the match.** Two players connect once into
  a party (a room). The party holds who's in it and what screen it's on;
  games start and end inside it. Leaving a game returns both players to
  the party's game picker, still connected.
- **Shared menus.** In a party, both phones show the same picker. Picking
  a game is a party action both see (proposal + accept, or host picks: to
  decide).
- **Games are plug-ins.** Each game declares its name, min / max players,
  whether it has a bot, and its rules engine. The picker greys out games
  whose player range doesn't include the party size. Adding a game should
  touch only that game's folder plus one registry line.
- **Rules run the same for bot and online.** A game's rules are pure Dart
  (state + move -> new state); the bot is just another player feeding
  moves, and online play syncs moves. One engine, tested without a phone.
- **Turn-based first.** Card and table games are turn-based, so a
  synced document store with realtime listeners is enough; no real-time
  game server needed.
- **GamePigeon-easy connecting.** No sign-up form before playing. Connect
  by sending an invite (share sheet: link or short code into any chat);
  tapping it opens Duel and joins the party. A friends list (play again
  with one tap) comes later.
- **Hidden cards.** Card games hide hands. First version can trust both
  clients (friends playing friends); before going public, dealing and
  hands move server-side so a phone never receives the other hand.
- **Reconnects are normal.** Phones sleep and switch networks; the party
  and game state live on the server, so a player who drops comes back to
  where they were.

## Phases

1. **Local** (0.2.0): home page, game picker with player counts, the game
   plug-in interface, a first game against bots (Texas Hold'em).
2. **Online party:** anonymous sign-in, create a party, invite by link /
   code, shared picker, play that game online, back to the picker.
3. **Friends:** usernames, friends list, invites and "your turn"
   notifications, match history.
4. Later: groups (3+ players), more games, server-side hidden hands.
