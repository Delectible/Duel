import 'dart:async';
import 'dart:math';

import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/goofspiel/goofspiel.dart';
import 'package:duel_engine/goofspiel/gops_bot.dart';
import 'package:flutter/foundation.dart';

import '../../../core/avatars/faces.dart';
import '../../../core/sound/sound.dart';

enum GopsPhase { dealing, bidding, revealing, over }

/// Runs a game of Goofspiel against one or two bots. Seat 0 is you.
class GopsController extends ChangeNotifier {
  GopsController({
    required int bots,
    required this.difficulty,
    Random? rng,
    this.pace = 1,
    this.you = const Persona.you(),
  }) : _rng = rng ?? Random(),
       assert(bots >= 1 && bots <= 2) {
    personas = [you, ...Persona.bots(bots, _rng)];
    _start();
  }

  final Difficulty difficulty;
  final double pace;
  final Persona you;
  final Random _rng;

  late List<Persona> personas;
  late Goofspiel game;
  late List<GopsBot?> _bots;

  GopsPhase phase = GopsPhase.dealing;
  int round = 0;

  /// Your card lifted, waiting for Bid.
  int? selected;

  /// Your bid, face down until the reveal.
  int? yourBid;

  /// Seats that have bid this prize (face-down cards on the table).
  final Set<int> ready = {};

  /// The prize just played out, shown face up until the next one.
  GopsRound? shown;

  /// Lines said at the table.
  final Map<int, String> speech = {};
  int speechId = 0;

  /// Bumped on each reveal (animations).
  int reveals = 0;

  Timer? _timer;
  final List<Timer> _botTimers = [];
  var _disposed = false;

  int get players => game.players;

  bool get canBid => phase == GopsPhase.bidding && yourBid == null;

  void _start() {
    game = Goofspiel(players: personas.length, rng: _rng);
    _bots = [
      for (var p = 0; p < personas.length; p++)
        p == 0 ? null : GopsBot(me: p, difficulty: difficulty, rng: _rng),
    ];
    selected = null;
    yourBid = null;
    ready.clear();
    shown = null;
    speech.clear();
    round++;
    phase = GopsPhase.dealing;
    Sound.deal(13, gapMs: 60);
    _after(1300, _nextPrize);
  }

  void playAgain() {
    _cancel();
    _start();
    _notify();
  }

  void _after(int ms, VoidCallback f) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: (ms * pace).round()), () {
      if (!_disposed) f();
    });
  }

  void _cancel() {
    _timer?.cancel();
    for (final t in _botTimers) {
      t.cancel();
    }
    _botTimers.clear();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _say(int seat, String text) {
    speech[seat] = text;
    speechId++;
  }

  /// A new prize is up: the bots think and bid in their own time.
  void _nextPrize() {
    if (game.isOver) return _finish();
    phase = GopsPhase.bidding;
    selected = null;
    yourBid = null;
    ready.clear();
    speech.clear();
    Sound.play(Sfx.place);
    final big = game.potWorth >= 15;
    for (var p = 1; p < players; p++) {
      final think = 700 + _rng.nextInt(big ? 2200 : 1400);
      _botTimers.add(
        Timer(Duration(milliseconds: (think * pace).round()), () {
          if (_disposed || phase != GopsPhase.bidding) return;
          ready.add(p);
          Sound.play(Sfx.deal);
          _maybeReveal();
          _notify();
        }),
      );
    }
    _notify();
  }

  /// Tap a card in your hand: lifts it (tap again to put it back).
  void pick(int value) {
    if (!canBid || !game.hands[0].contains(value)) return;
    selected = selected == value ? null : value;
    _notify();
  }

  /// Puts your lifted card down as your bid.
  void bid() {
    final v = selected;
    if (!canBid || v == null) return;
    yourBid = v;
    selected = null;
    ready.add(0);
    Sound.play(Sfx.place);
    _maybeReveal();
    _notify();
  }

  void _maybeReveal() {
    if (ready.length < players || phase != GopsPhase.bidding) return;
    phase = GopsPhase.revealing;
    // A breath before the cards turn; longer when a lot is riding on it.
    final worth = game.potWorth;
    if (worth >= 20) Sound.play(Sfx.tension);
    _after(worth >= 20 ? 1300 : 700, _reveal);
  }

  void _reveal() {
    final pot = game.potWorth;
    GopsRound? r;
    for (var p = 0; p < players; p++) {
      final v = p == 0 ? yourBid! : _bots[p]!.decide(game);
      r = game.bid(p, v);
    }
    shown = r;
    reveals++;
    final w = r!.winner;
    if (w == null) {
      Sound.play(Sfx.clash);
      _react(null, pot, r);
    } else {
      Sound.later(w == 0 ? Sfx.collect : Sfx.pot, 350);
      if (w == 0 && pot >= 20) Sound.later(Sfx.winSmall, 600);
      _react(w, pot, r);
    }
    _notify();
    _after(w == null ? 2300 : (pot >= 20 ? 2400 : 1800), () {
      shown = null;
      _nextPrize();
    });
  }

  /// Bots say something when it's worth saying.
  void _react(int? winner, int pot, GopsRound r) {
    final bots = [for (var p = 1; p < players; p++) p];
    String pickOne(List<String> lines) => lines[_rng.nextInt(lines.length)];
    if (winner == null) {
      final p = bots[_rng.nextInt(bots.length)];
      if (_rng.nextDouble() < 0.7) {
        _say(p, pickOne(['A tie! It rolls over.', 'Great minds…', 'Nobody? Then more for later.', 'Snap!']));
      }
      return;
    }
    final bid = r.bids[winner];
    final second = ([...r.bids]..sort()).reversed.elementAt(1);
    if (winner == 0) {
      if (pot >= 18 && _rng.nextDouble() < 0.8) {
        _say(
          bots[_rng.nextInt(bots.length)],
          pickOne(['Ouch. That was a big one.', 'Fine, take it.', 'I wanted that!']),
        );
      } else if (bid - second >= 6 && _rng.nextDouble() < 0.6) {
        _say(bots.first, pickOne(['You overpaid for that one.', 'All that for $pot?', 'Bit much, no?']));
      }
      return;
    }
    if (pot >= 15 || bid - second <= 1) {
      if (_rng.nextDouble() < 0.75) {
        _say(
          winner,
          bid - second <= 1
              ? pickOne(['By a hair!', 'Just enough.', 'Squeaked it.'])
              : pickOne(['Mine!', 'Thank you very much.', 'Into the bank.', 'Called it.']),
        );
      }
    } else if (bid <= 3 && _rng.nextDouble() < 0.6) {
      _say(winner, pickOne(['Cheap!', 'A bargain.', 'Didn\'t even try.']));
    }
  }

  void _finish() {
    phase = GopsPhase.over;
    final w = game.winners;
    Sound.play(w.contains(0) && w.length == 1 ? Sfx.winBig : (w.contains(0) ? Sfx.winSmall : Sfx.loseBig));
    _notify();
  }

  String _name(int p) => p == 0 ? 'You' : personas[p].name;

  /// One line on what's happening and what to do.
  String commentary() {
    final g = game;
    if (phase == GopsPhase.dealing) return 'Shuffling the diamonds. Everyone takes a suit, Ace to King.';
    if (phase == GopsPhase.over) {
      final w = g.winners;
      final top = g.scores[w.first];
      if (w.length > 1)
        return '${w.contains(0) ? "It's a tie" : 'A tie'}: ${w.map(_name).join(' & ')} on $top.';
      return w.single == 0 ? 'You win with $top points!' : '${_name(w.single)} wins with $top points.';
    }
    final s = shown;
    if (s != null) {
      final bids = [for (var p = 0; p < players; p++) '${_name(p)} ${gopsLabel(s.bids[p])}'].join(', ');
      if (s.winner == null) {
        return 'Tie at the top ($bids): the ${s.worth} carries over to the next prize.';
      }
      return '${_name(s.winner!)} ${s.winner == 0 ? 'take' : 'takes'} ${s.worth} point${s.worth == 1 ? '' : 's'} ($bids).';
    }
    final worth = g.potWorth;
    final carried = g.pot.length > 1 ? ' (carried over: ${g.pot.length} prizes)' : '';
    if (phase == GopsPhase.revealing) return 'Everyone\'s in. Turning the bids over…';
    if (yourBid != null) {
      final waiting = [
        for (var p = 1; p < players; p++)
          if (!ready.contains(p)) _name(p),
      ];
      return 'You bid ${gopsLabel(yourBid!)}. Waiting for ${waiting.join(' and ')}…';
    }
    if (selected != null)
      return 'Bid ${gopsLabel(selected!)} for $worth$carried? Tap Bid, or pick another card.';
    return 'Up for grabs: $worth point${worth == 1 ? '' : 's'}$carried. Pick a card to bid.';
  }

  @override
  void dispose() {
    _disposed = true;
    _cancel();
    super.dispose();
  }
}

/// "A", "2"…"10", "J", "Q", "K".
String gopsLabel(int value) => switch (value) {
  1 => 'A',
  11 => 'J',
  12 => 'Q',
  13 => 'K',
  _ => '$value',
};
