import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/avatars/faces.dart';
import 'package:duel_engine/cards.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/go_fish/fish_bot.dart';
import 'package:duel_engine/go_fish/go_fish.dart';
import '../../../core/online/online_link.dart';

enum FishPhase { dealing, playing, over }

/// Cards moving across the table, for the animations.
class Flight {
  const Flight(this.id, {required this.from, required this.to, required this.cards, this.faceUp = false});

  final int id;

  /// Seats; -1 = the pond.
  final int from;
  final int to;
  final List<PlayingCard> cards;
  final bool faceUp;
}

/// Runs a game of Go Fish against bots. Seat 0 is you.
class FishController extends ChangeNotifier {
  FishController({
    required int bots,
    required this.difficulty,
    Random? rng,
    this.pace = 1,
    this.you = const Persona.you(),
    this.link,
  }) : _rng = rng ?? Random(),
       assert(bots >= 1 && bots <= 5) {
    _start(bots);
  }

  final Difficulty difficulty;
  final double pace;
  final Persona you;
  final Random _rng;

  late List<Persona> personas;
  late GoFish game;
  late List<FishBot?> _bots;

  FishPhase phase = FishPhase.dealing;
  int round = 0;

  /// Your chosen rank, waiting for you to pick who to ask.
  int? selected;

  /// What each seat is saying ("Got any 7s?", "Go fish!").
  final Map<int, String> speech = {};

  /// Bumped each time anyone speaks (bubble animations).
  int speechId = 0;

  /// An ask on its way: shown as a question before it's answered.
  (int, int, int)? asking;

  final List<Flight> flights = [];
  var _flightId = 0;

  /// The last book made, for the "Book of 7s!" pop.
  Booked? lastBook;

  Timer? _timer;
  var _disposed = false;

  int get players => game.players;

  bool get yourTurn => phase == FishPhase.playing && game.turn == 0 && asking == null && !game.isOver;

  bool get youMustFish => yourTurn && game.mustFish;

  /// Online: the party's game (the others' moves come from the server).
  final OnlineLink? link;

  void _start(int bots) {
    final link = this.link;
    if (link != null) {
      personas = link.personas(you);
      game = GoFish(players: link.n, rng: link.rng, dealer: link.localDealer);
      _bots = List.filled(link.n, null);
      // Coming back to it: everything so far, at once.
      for (var m = link.next(); m != null; m = link.next()) {
        link.cursor++;
        final p = m['p']! as int;
        if (m['kind'] == 'ask') {
          game.ask(p, link.local(m['target']! as int), m['rank']! as int);
        } else {
          game.fish(p);
        }
      }
      selected = null;
      asking = null;
      speech.clear();
      flights.clear();
      lastBook = null;
      round++;
      phase = FishPhase.dealing;
      _seenEvents = game.events.length;
      _after(1400, _step);
      return;
    }
    personas = [you, ...Persona.bots(bots, _rng)];
    game = GoFish(players: bots + 1, rng: _rng);
    _bots = [
      for (var p = 0; p <= bots; p++) p == 0 ? null : FishBot(me: p, difficulty: difficulty, rng: _rng),
    ];
    selected = null;
    asking = null;
    speech.clear();
    flights.clear();
    lastBook = null;
    round++;
    phase = FishPhase.dealing;
    _seenEvents = game.events.length;
    _after(1400, _step);
  }

  void playAgain() {
    _timer?.cancel();
    _start(players - 1);
    _notify();
  }

  void _after(int ms, VoidCallback f) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: (ms * pace).round()), () {
      if (!_disposed) f();
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _say(int seat, String text) {
    speech[seat] = text;
    speechId++;
  }

  void _step() {
    if (game.isOver) {
      phase = FishPhase.over;
      _notify();
      return;
    }
    phase = FishPhase.playing;
    _notify();
    final p = game.turn;
    final link = this.link;
    if (link != null) {
      // The server's next move (yours too, if it played for you).
      final m = link.next();
      if (m == null) {
        if (p != 0) link.waiting = _step;
        return;
      }
      _after(p == 0 ? 0 : 800, () {
        link.cursor++;
        if (m['kind'] == 'ask') {
          _ask(p, link.local(m['target']! as int), m['rank']! as int);
        } else {
          _fish(p);
        }
      });
      return;
    }
    final bot = _bots[p];
    if (bot == null) return; // you
    _after(800 + _rng.nextInt(500), () {
      if (game.mustFish) {
        _fish(p);
      } else {
        final (t, r) = bot.decide(game);
        _ask(p, t, r);
      }
    });
  }

  /// Tap a rank in your hand. Heads-up there's only one player to ask.
  void pick(int rank) {
    if (!yourTurn || game.mustFish || !game.askable(0).contains(rank)) return;
    final targets = game.targets(0);
    if (targets.length == 1) {
      link?.send({'kind': 'ask', 'target': link!.pos(targets.single), 'rank': rank});
      _ask(0, targets.single, rank);
      return;
    }
    selected = selected == rank ? null : rank;
    _notify();
  }

  /// Tap a player to ask them for your selected rank.
  void askPlayer(int target) {
    final r = selected;
    if (!yourTurn || r == null || !game.targets(0).contains(target)) return;
    selected = null;
    link?.send({'kind': 'ask', 'target': link!.pos(target), 'rank': r});
    _ask(0, target, r);
  }

  /// Tap the pond after a miss.
  void fish() {
    if (!youMustFish) return;
    link?.send({'kind': 'fish'});
    _fish(0);
  }

  void _ask(int p, int target, int rank) {
    speech.clear();
    asking = (p, target, rank);
    _say(p, '${personas[target].name}, got any ${rankPlural(rank)}?');
    _notify();
    // A beat for the question, then the answer.
    _after(900, () {
      asking = null;
      final got = game.ask(p, target, rank);
      if (got > 0) {
        _say(target, got == 1 ? 'Here, one ${rankName(rank)}.' : 'Here, $got ${rankPlural(rank)}.');
      } else {
        _say(target, 'Go fish!');
      }
      _readEvents();
      _notify();
      _after(got > 0 ? 900 : 700, _step);
    });
  }

  void _fish(int p) {
    game.fish(p);
    _readEvents();
    _notify();
    _after(800, _step);
  }

  var _seenEvents = 0;

  /// Turns new events into flights and the book pop.
  void _readEvents() {
    for (final e in game.events.skip(_seenEvents)) {
      switch (e) {
        case Asked(:final player, :final target, :final cards) when cards.isNotEmpty:
          flights.add(Flight(_flightId++, from: target, to: player, cards: cards, faceUp: true));
        case Fished(:final player, :final card, :final lucky):
          flights.add(Flight(_flightId++, from: -1, to: player, cards: [card], faceUp: lucky || player == 0));
          if (lucky) _say(player, 'Got one: a ${rankName(card.rank)}! Go again.');
        case Booked():
          lastBook = e;
        case Asked() || SatOut() || GameEnded():
          break;
      }
    }
    _seenEvents = game.events.length;
    if (flights.length > 8) flights.removeRange(0, flights.length - 8);
  }

  String _name(int p) => p == 0 ? 'You' : personas[p].name;

  /// One line on what's happening and what you can do.
  String commentary() {
    final g = game;
    if (phase == FishPhase.dealing) {
      return 'Dealing ${g.players <= 3 ? 7 : 5} cards each. ${_name(g.turn)} ${g.turn == 0 ? 'go' : 'goes'} first.';
    }
    if (g.isOver) {
      final w = g.winners!;
      final books = g.books[w.first].length;
      if (w.length > 1) {
        return '${w.contains(0) ? "It's a tie" : 'A tie'}: ${w.map(_name).join(' & ')} with $books books each.';
      }
      return w.single == 0 ? 'You win with $books books!' : '${_name(w.single)} wins with $books books.';
    }
    final a = asking;
    if (a != null) {
      final (asker, target, rank) = a;
      return '${_name(asker)} ${asker == 0 ? 'ask' : 'asks'} ${target == 0 ? 'you' : _name(target)} for '
          '${rankPlural(rank)}…';
    }
    if (yourTurn) {
      if (g.mustFish) {
        final miss = g.events.whereType<Asked>().last;
        return '${_name(miss.target)} has no ${rankPlural(miss.rank)}: go fish! Tap the pond to draw.';
      }
      final last = g.events.isEmpty ? null : g.events.last;
      final again =
          last is Asked && last.player == 0 && last.given > 0 ||
          last is Fished && last.player == 0 && last.lucky;
      final start = again ? 'Go again! ' : 'Your turn: ';
      if (selected != null) return '${start}ask who for ${rankPlural(selected!)}? Tap a player.';
      return g.targets(0).length == 1
          ? '${start}tap a rank in your hand to ask ${personas[g.targets(0).single].name} for it.'
          : '${start}tap a rank in your hand, then who to ask.';
    }
    final news = lastNews();
    final thinking = g.mustFish ? '${_name(g.turn)} is fishing…' : '${_name(g.turn)} is thinking…';
    return news == null ? thinking : '$news  ·  $thinking';
  }

  /// The latest thing that happened, in words.
  String? lastNews() {
    for (final e in game.events.reversed) {
      switch (e) {
        case Booked(:final player, :final rank):
          return '${_name(player)} made a book of ${rankPlural(rank)}';
        case Asked(:final player, :final target, :final rank, :final given):
          final who = target == 0 ? 'you' : _name(target);
          return given > 0
              ? '${_name(player)} got $given ${given == 1 ? rankName(rank) : rankPlural(rank)} from $who'
              : '${_name(player)} asked $who for ${rankPlural(rank)}: go fish';
        case Fished(:final player, :final lucky):
          return lucky
              ? '${_name(player)} fished what they asked for'
              : '${_name(player)} drew from the pond';
        case SatOut(:final player):
          return '${_name(player)} is out of cards';
        case GameEnded():
          return null;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
