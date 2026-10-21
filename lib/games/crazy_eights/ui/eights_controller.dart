import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:duel_engine/cards.dart';
import 'package:duel_engine/difficulty.dart';
import '../../../core/avatars/faces.dart';
import 'package:duel_engine/crazy_eights/crazy_eights.dart';
import 'package:duel_engine/crazy_eights/eights_bot.dart';
import '../../../core/online/online_link.dart';
import '../../../core/sound/sound.dart';

enum EightsPhase {
  /// Cards going out.
  dealing,

  /// Someone's turn (yours: waiting for you).
  playing,

  /// You played an eight: pick the suit.
  pickSuit,

  /// Someone went out.
  over,
}

/// Runs a game of Crazy Eights against bots for the table screen. Seat 0 is
/// you.
class EightsController extends ChangeNotifier {
  EightsController({
    required int bots,
    required this.difficulty,
    Random? rng,
    this.pace = 1,
    this.you = const Persona.you(),
    this.link,
  }) : _rng = rng ?? Random(),
       assert(bots >= 1 && bots <= 3) {
    _start(bots);
  }

  /// Online: the party's game (the others' moves come from the server).
  final OnlineLink? link;

  final Difficulty difficulty;

  /// Your face and name at the table.
  final Persona you;

  /// Multiplies every delay (tests).
  final double pace;
  final Random _rng;

  late List<Persona> personas;
  late CrazyEights game;
  late List<EightsBot?> _bots;

  EightsPhase phase = EightsPhase.dealing;

  /// Bumped each new game (keys that restart deal animations).
  int round = 0;

  /// The eight you're about to play while you pick its suit.
  PlayingCard? pendingEight;

  /// Cards drawn, for the deck-to-hand flights: (event index, player).
  final List<(int, int)> draws = [];

  Timer? _timer;
  var _disposed = false;

  int get players => game.players;

  bool get yourTurn => phase == EightsPhase.playing && game.turn == 0 && !game.isOver;

  List<PlayingCard> get yourPlayable => yourTurn ? game.playable(0) : const [];

  void _start(int bots) {
    final link = this.link;
    if (link != null) {
      personas = link.personas(you);
      game = CrazyEights(players: link.n, rng: link.rng, dealer: link.localDealer);
      _bots = List.filled(link.n, null);
      draws.clear();
      round++;
      phase = EightsPhase.dealing;
      // Coming back to it: everything so far, at once.
      final caughtUp = link.cursor < link.moves.length;
      for (var m = link.next(); m != null; m = link.next()) {
        link.cursor++;
        _apply(m);
      }
      draws.clear();
      _heard = game.events.length;
      if (!caughtUp) Sound.deal(8);
      _after(caughtUp ? 300 : 1400, _step);
      return;
    }
    personas = [you, ...Persona.bots(bots, _rng)];
    game = CrazyEights(players: bots + 1, rng: _rng);
    _bots = [for (var p = 0; p <= bots; p++) p == 0 ? null : EightsBot(difficulty: difficulty, rng: _rng)];
    draws.clear();
    pendingEight = null;
    round++;
    phase = EightsPhase.dealing;
    _heard = game.events.length;
    Sound.deal(8);
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

  void _step() {
    if (game.isOver) {
      if (phase != EightsPhase.over) Sound.play(game.winner == 0 ? Sfx.winBig : Sfx.loseBig);
      phase = EightsPhase.over;
      _notify();
      return;
    }
    phase = EightsPhase.playing;
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
      _after(p == 0 ? 0 : 700 + _rng.nextInt(500), () {
        link.cursor++;
        _apply(m);
        _afterMove();
      });
      return;
    }
    final bot = _bots[p];
    if (bot == null) return; // your turn
    _after(700 + _rng.nextInt(600), () {
      switch (bot.decide(game, p)) {
        case PlayCard(:final card, :final suit):
          game.play(p, card, chose: suit);
        case DrawCard():
          game.draw(p);
          draws.add((game.events.length, p));
        case PassTurn():
          game.pass(p);
      }
      _afterMove();
    });
  }

  /// A move from the server's log.
  void _apply(Map<String, Object?> m) {
    final p = m['p']! as int;
    switch (m['kind']) {
      case 'play':
        final card = PlayingCard.parse('${m['card']}');
        final suit = m['suit'] is int ? Suit.values[m['suit']! as int] : null;
        game.play(p, card, chose: card.rank == 8 ? (suit ?? card.suit) : null);
      case 'draw':
        game.draw(p);
        draws.add((game.events.length, p));
      case 'pass':
        game.pass(p);
    }
  }

  /// Events already heard.
  var _heard = 0;

  void _afterMove() {
    final news = game.events.skip(_heard);
    _heard = game.events.length;
    if (news.any((e) => e is Reshuffled)) Sound.play(Sfx.shuffle);
    if (news.any((e) => e is Played)) Sound.play(Sfx.place);
    if (news.any((e) => e is Drew)) Sound.play(Sfx.deal);
    _notify();
    // Time for the card to fly before the next player goes.
    _after(500, _step);
  }

  /// Tap a card in your hand.
  void play(PlayingCard card) {
    if (!yourPlayable.contains(card)) return;
    if (card.rank == 8) {
      pendingEight = card;
      phase = EightsPhase.pickSuit;
      _notify();
      return;
    }
    game.play(0, card);
    link?.send({'kind': 'play', 'card': '$card'});
    _afterMove();
  }

  void chooseSuit(Suit suit) {
    final eight = pendingEight;
    if (phase != EightsPhase.pickSuit || eight == null) return;
    pendingEight = null;
    phase = EightsPhase.playing;
    game.play(0, eight, chose: suit);
    link?.send({'kind': 'play', 'card': '$eight', 'suit': suit.index});
    _afterMove();
  }

  void cancelEight() {
    if (phase != EightsPhase.pickSuit) return;
    pendingEight = null;
    phase = EightsPhase.playing;
    _notify();
  }

  void draw() {
    if (!yourTurn || !game.canDraw) return;
    game.draw(0);
    link?.send({'kind': 'draw'});
    draws.add((game.events.length, 0));
    if (game.turn == 0) {
      _heard = game.events.length;
      Sound.play(Sfx.deal);
      _notify(); // it fits: play it or keep it
    } else {
      _afterMove(); // didn't fit: turn over
    }
  }

  /// Keep the card you drew (or pass with nothing to draw).
  void pass() {
    if (!yourTurn || !game.canPass) return;
    game.pass(0);
    link?.send({'kind': 'pass'});
    _afterMove();
  }

  /// One line on what's going on and what you can do.
  String commentary() {
    final g = game;
    if (phase == EightsPhase.dealing) {
      return 'Dealing ${g.players == 2 ? 7 : 5} cards each. ${_name(g.turn)} ${g.turn == 0 ? 'go' : 'goes'} first.';
    }
    if (g.isOver) {
      final w = g.winner!;
      final blocked = (g.events.last as Won).blocked;
      if (blocked) return 'Nobody can go: ${w == 0 ? 'you win' : '${_name(w)} wins'} with the fewest cards.';
      return w == 0 ? 'You played your last card. You win!' : '${_name(w)} played their last card and wins.';
    }
    if (phase == EightsPhase.pickSuit) return 'Eights are wild: pick the suit the next player has to follow.';
    if (yourTurn) {
      final d = g.drawn;
      if (d != null) return 'You drew ${cardName(d)} and it fits: play it, or keep it.';
      final options = g.playable(0);
      final follow = _follow();
      if (options.isEmpty) {
        return g.canDraw
            ? 'Nothing fits $follow. Tap the deck to draw a card.'
            : 'Nothing fits and the deck is empty: pass.';
      }
      final eight = options.any((c) => c.rank == 8) ? ', or an 8 (wild)' : '';
      return 'Your turn: play $follow$eight. Lifted cards fit.';
    }
    final last = lastNews();
    final thinking = '${_name(g.turn)} is thinking…';
    return last == null ? thinking : '$last  ·  $thinking';
  }

  /// "a heart or a 7" (or just "a heart" after an eight).
  String _follow() {
    final g = game;
    final suit = suitName(g.suit, plural: false);
    if (g.top.rank == 8) return 'a $suit (${_name(_eightBy())} chose ${suitName(g.suit)})';
    final rank = rankWord(g.top.rank);
    return 'a $suit or ${rank == 'Ace' ? 'an' : 'a'} $rank';
  }

  int _eightBy() {
    for (final e in game.events.reversed) {
      if (e is Played && e.card.rank == 8) return e.player;
    }
    return 0;
  }

  /// The latest thing another player did, in words.
  String? lastNews() {
    final events = game.events;
    for (var i = events.length - 1; i >= 0; i--) {
      final e = events[i];
      final who = _name(e.player);
      switch (e) {
        case Played(:final card, :final chose):
          return chose != null
              ? '$who played an 8 and chose ${suitName(chose)}'
              : '$who played ${cardName(card)}';
        case Passed():
          final before = i > 0 ? events[i - 1] : null;
          if (before is Drew && before.player == e.player) {
            return before.playable ? '$who drew and kept it' : '$who couldn\'t match and drew a card';
          }
          return '$who passed';
        case Drew():
          return '$who drew a card';
        case Reshuffled():
          continue;
        case Won():
          return null;
      }
    }
    return null;
  }

  String _name(int p) => p == 0 ? 'You' : personas[p].name;

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
