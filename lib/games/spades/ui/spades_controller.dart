import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/avatars/faces.dart';
import 'package:duel_engine/cards.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/spades/spades.dart';
import 'package:duel_engine/spades/spades_bot.dart';
import '../../../core/online/online_link.dart';

enum SpadesStage {
  /// Cards going out (four players).
  dealing,

  /// Two-handed: drawing your 13.
  drawing,
  bidding,
  playing,

  /// A trick just ended: it stays on the table a moment, then goes to the
  /// winner.
  trickDone,

  /// Scores are up; waiting for Next hand.
  handOver,
  over,
}

/// Runs a game of Spades against bots for the table screen. Seat 0 is you;
/// with four players seat 2 is your partner.
class SpadesController extends ChangeNotifier {
  SpadesController({
    required int bots,
    required this.difficulty,
    this.target = 250,
    Random? rng,
    this.pace = 1,
    this.you = const Persona.you(),
    this.link,
  }) : _rng = rng ?? Random(),
       assert(bots == 1 || bots == 3) {
    final link = this.link;
    if (link != null) {
      personas = link.personas(you);
      _bots = List.filled(link.n, null);
      _startOnline(link);
      return;
    }
    personas = [you, ...Persona.bots(bots, _rng)];
    _bots = [for (var p = 0; p <= bots; p++) p == 0 ? null : SpadesBot(difficulty: difficulty, rng: _rng)];
    _start();
  }

  /// Online: the party's game (the others' moves come from the server).
  final OnlineLink? link;

  /// Online: partners came down to a coin toss.
  bool get tossed => link?.state['tossed'] == true;

  void _startOnline(OnlineLink link) {
    final t = link.options['target'];
    game = Spades(players: link.n, target: t is int ? t : 250, rng: link.rng, dealer: link.localDealer);
    // Coming back to it: everything so far, at once (the server deals the
    // next hand as soon as one ends).
    for (var m = link.next(); m != null; m = link.next()) {
      if (game.phase == SpadesPhase.handOver) game.nextHand();
      link.cursor++;
      _apply(m);
    }
    _newHand();
  }

  /// A move from the server's log.
  void _apply(Map<String, Object?> m) {
    final p = m['p']! as int;
    switch (m['kind']) {
      case 'draw':
        game.draw(p, keep: m['keep'] == true);
      case 'bid':
        game.bid(p, m['tricks']! as int);
      case 'play':
        game.play(p, PlayingCard.parse('${m['card']}'));
    }
  }

  /// Online: plays the server's next move for whoever is to go (you too,
  /// if it played for you). True if it's handling the turn.
  bool _online(int p) {
    final link = this.link;
    if (link == null) return false;
    final m = link.next();
    if (m == null) {
      if (p != 0) link.waiting = _step;
      return true;
    }
    _after(p == 0 ? 0 : 700, () {
      link.cursor++;
      if (m['kind'] == 'play') {
        _played(p, PlayingCard.parse('${m['card']}'));
      } else {
        _apply(m);
        _step();
      }
    });
    return true;
  }

  final Difficulty difficulty;
  final int target;
  final double pace;
  final Persona you;
  final Random _rng;

  late List<Persona> personas;
  late List<SpadesBot?> _bots;
  late Spades game;

  SpadesStage stage = SpadesStage.dealing;

  /// Bumped each new game and hand (keys that restart deal animations).
  int round = 0;

  /// The trick that just ended, shown until it's swept away.
  TrickWon? lastTrick;

  /// The finished trick is flying to its winner.
  var sweeping = false;

  /// Your bid in the picker (starts at a suggestion).
  int yourBid = 1;

  /// Two-handed: the card you got on your last draw.
  PlayingCard? justTook;

  Timer? _timer;
  var _disposed = false;

  int get players => game.players;
  bool get teams => players == 4;

  bool get yourTurn => game.turn == 0 && !game.isOver;
  bool get yourDraw => stage == SpadesStage.drawing && yourTurn;
  bool get yourBidTurn => stage == SpadesStage.bidding && yourTurn;
  bool get yourPlay => stage == SpadesStage.playing && yourTurn;

  List<PlayingCard> get yourPlayable => yourPlay ? game.legal(0) : const [];

  /// What your cards look like they'd win.
  int get suggestedBid => SpadesBot.suggest(game.hands[0], game.players);

  void _start() {
    game = Spades(players: personas.length, target: target, rng: _rng, dealer: _rng.nextInt(personas.length));
    _newHand();
  }

  void _newHand() {
    round++;
    lastTrick = null;
    sweeping = false;
    justTook = null;
    stage = teams ? SpadesStage.dealing : SpadesStage.drawing;
    _notify();
    _after(teams ? 1600 : 500, _step);
  }

  void playAgain() {
    _timer?.cancel();
    _start();
  }

  void nextHand() {
    if (stage != SpadesStage.handOver) return;
    game.nextHand();
    _newHand();
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
    final g = game;
    switch (g.phase) {
      case SpadesPhase.gameOver:
        stage = SpadesStage.over;
        _notify();
      case SpadesPhase.handOver:
        stage = SpadesStage.handOver;
        _notify();
      case SpadesPhase.draw:
        stage = SpadesStage.drawing;
        _notify();
        final p = g.turn;
        if (_online(p)) return;
        final bot = _bots[p];
        if (bot == null) return;
        _after(380, () {
          g.draw(p, keep: bot.keep(g, p, g.offered!));
          _step();
        });
      case SpadesPhase.bid:
        stage = SpadesStage.bidding;
        if (g.turn == 0) yourBid = suggestedBid;
        _notify();
        final p = g.turn;
        if (_online(p)) return;
        final bot = _bots[p];
        if (bot == null) return;
        _after(800 + _rng.nextInt(500), () {
          g.bid(p, bot.bid(g, p));
          _step();
        });
      case SpadesPhase.play:
        stage = SpadesStage.playing;
        _notify();
        final p = g.turn;
        if (_online(p)) return;
        final bot = _bots[p];
        if (bot == null) return;
        _after(650 + _rng.nextInt(450), () => _played(p, bot.play(g, p)));
    }
  }

  void _played(int p, PlayingCard card) {
    game.play(p, card);
    final last = game.events.lastWhere((e) => e is Played || e is TrickWon);
    if (last is TrickWon) {
      // Leave the trick up a moment, then sweep it to the winner.
      lastTrick = last;
      stage = SpadesStage.trickDone;
      _notify();
      _after(1100, () {
        sweeping = true;
        _notify();
        _after(450, () {
          lastTrick = null;
          sweeping = false;
          _step();
        });
      });
      return;
    }
    _notify();
    _after(250, _step);
  }

  // --- You -------------------------------------------------------------------

  /// Two-handed draw: keep the card on top, or pass and take the next.
  void draw({required bool keep}) {
    if (!yourDraw) return;
    justTook = game.draw(0, keep: keep);
    link?.send({'kind': 'draw', 'keep': keep});
    _step();
  }

  void setBid(int n) {
    if (!yourBidTurn) return;
    yourBid = n.clamp(0, 13);
    _notify();
  }

  void bid() {
    if (!yourBidTurn) return;
    game.bid(0, yourBid);
    link?.send({'kind': 'bid', 'tricks': yourBid});
    _step();
  }

  void play(PlayingCard card) {
    if (!yourPlayable.contains(card)) return;
    link?.send({'kind': 'play', 'card': '$card'});
    _played(0, card);
  }

  // --- Words -------------------------------------------------------------------

  String name(int p) => p == 0 ? 'You' : personas[p].name;

  String teamName(int t) {
    if (!teams) return t == 0 ? 'You' : personas[1].name;
    return t == 0 ? 'You & ${personas[2].name}' : '${personas[1].name} & ${personas[3].name}';
  }

  String bidWord(int b) => b == 0 ? 'Nil' : '$b';

  /// One line on what's going on and what you can do.
  String commentary() {
    final g = game;
    switch (stage) {
      case SpadesStage.dealing:
        return 'Dealing 13 cards each. ${personas[2].name} is your partner, sitting opposite.';
      case SpadesStage.drawing:
        final have = g.hands[0].length;
        final took = justTook;
        final start = took == null ? '' : 'You took ${cardName(took)}. ';
        if (yourDraw) {
          return '$start${have == 0 ? 'Draw your 13 cards: k' : 'You have $have of 13. K'}eep '
              '${cardName(g.offered!)}, or pass and take the next card instead.';
        }
        return '$start${name(g.turn)} is drawing… (you have $have of 13)';
      case SpadesStage.bidding:
        final said = [
          for (var p = 0; p < players; p++)
            if (p != 0 && g.bids[p] != null) '${name(p)} ${bidWord(g.bids[p]!)}',
        ];
        final sofar = said.isEmpty ? '' : 'Bids: ${said.join(', ')}. ';
        if (yourBidTurn) {
          return '${sofar}Your bid: how many tricks will you win?';
        }
        return '$sofar${name(g.turn)} is bidding…';
      case SpadesStage.trickDone:
        final t = lastTrick!;
        final card = t.cards.firstWhere((c) => c.$1 == t.player).$2;
        final who = t.player == 0 ? 'You win' : '${name(t.player)} wins';
        return '$who the trick with ${cardName(card)}.${_brokeNote(t)}';
      case SpadesStage.playing:
        if (yourPlay) return _yourPlayLine();
        return '${name(g.turn)} is thinking…';
      case SpadesStage.handOver:
        return 'Hand over: here are the scores.';
      case SpadesStage.over:
        final w = g.winner!;
        return w == 0
            ? '${teams ? 'You and ${personas[2].name} win' : 'You win'}, ${g.scores[0]} to ${g.scores[1]}!'
            : '${teamName(1)} ${teams ? 'win' : 'wins'}, ${g.scores[1]} to ${g.scores[0]}.';
    }
  }

  /// " Spades are broken!" on the first trick of the hand with a spade in it.
  String _brokeNote(TrickWon t) {
    final first = game.handEvents.whereType<TrickWon>().where(
      (e) => e.cards.any((c) => c.$2.suit == Suit.spades),
    );
    return first.isNotEmpty && identical(first.first, t) ? ' Spades are broken!' : '';
  }

  String _yourPlayLine() {
    final g = game;
    final need = g.bids[0] == 0
        ? 'You bid Nil: try not to win any trick.'
        : 'You need ${max(0, g.teamBid(0) - g.teamTricks(0))} more trick${g.teamBid(0) - g.teamTricks(0) == 1 ? '' : 's'}.';
    final led = g.ledSuit;
    if (led == null) {
      final lead = g.spadesBroken || g.hands[0].every((c) => c.suit == Suit.spades)
          ? 'Your lead: play any card.'
          : "Your lead: any card but a spade (they're not broken yet).";
      return '$lead $need';
    }
    final has = g.hands[0].any((c) => c.suit == led);
    final follow = has
        ? 'Follow ${suitName(led)}.'
        : 'No ${suitName(led)}: play anything. A spade will win it.';
    return '$follow $need';
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
