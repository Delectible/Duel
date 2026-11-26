import 'dart:async';
import 'dart:math';

import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/liars/liars.dart';
import 'package:duel_engine/liars/liars_bot.dart';
import 'package:flutter/foundation.dart';

import '../../../core/avatars/faces.dart';
import '../../../core/online/online_link.dart';
import '../../../core/sound/sound.dart';

enum LiarsPhase {
  /// Cups rattling: a new round.
  shaking,

  /// Bids going round.
  bidding,

  /// Someone called: the cups come up and the dice are counted.
  reveal,

  over,
}

/// Runs Liar's Dice: with your party (the referee rolls and keeps the log;
/// this table plays it back) or against bots here. Seat 0 is you.
class LiarsController extends ChangeNotifier {
  LiarsController({
    int bots = 2,
    this.difficulty = Difficulty.normal,
    this.rules = const LiarsRules(),
    this.pace = 1,
    this.you = const Persona.you(),
    Random? rng,
    this.link,
  }) : _rng = rng ?? Random() {
    final l = link;
    if (l != null) {
      personas = l.personas(you);
      rulesNow = LiarsRules.fromJson(l.state['rules'] as Map?);
      game = LiarsGame(players: l.n, rules: rulesNow, first: l.local(l.state['first']! as int));
      final bots = (l.party.match?['bots'] as List?) ?? const [];
      _botSeats = {
        for (var p = 0; p < l.n; p++)
          if (bots.length > l.order![l.pos(p)] && bots[l.order![l.pos(p)]] != null) p,
      };
      l.party.addListener(_heard);
      _catchUp();
    } else {
      personas = [you, ...Persona.bots(bots, _rng)];
      rulesNow = rules;
      _start();
    }
    _after(600, _step);
  }

  final Difficulty difficulty;
  final LiarsRules rules;
  final double pace;
  final Persona you;
  final OnlineLink? link;
  final Random _rng;

  late LiarsRules rulesNow;
  late List<Persona> personas;
  late LiarsGame game;
  late List<LiarsBot?> _bots;
  late LiarsReads _reads;
  Set<int> _botSeats = {};

  LiarsPhase phase = LiarsPhase.shaking;

  /// Bumped when the cups shake (animations).
  int shakes = 0;

  /// Your cup's up (you're looking at your dice).
  bool peeking = true;

  /// What you're about to bid.
  int pickCount = 1;
  int pickFace = 2;

  /// The reveal: dice counted so far (they light up one by one), and
  /// whether the verdict is out.
  int counted = 0;
  bool verdict = false;

  /// The die flying off the loser's cup (or onto the winner's).
  int? lostBy, gainedBy;

  /// The last thing each seat said (a bid, "Liar!").
  final Map<int, String> speech = {};
  int speechId = 0;

  /// Your move's on its way to the referee.
  bool _sent = false;

  Timer? _timer;
  var _disposed = false;

  int get players => game.players;
  bool get online => link != null;

  bool get yourTurn => phase == LiarsPhase.bidding && game.turn == 0 && game.isIn(0) && !_sent && !_pending;

  /// Online: moves are waiting to be shown (it isn't really your turn yet).
  bool get _pending => link != null && link!.next() != null;

  void _start() {
    game = LiarsGame(players: personas.length, rules: rulesNow, first: _rng.nextInt(personas.length));
    _reads = LiarsReads(personas.length);
    _bots = [
      for (var p = 0; p < personas.length; p++)
        p == 0
            ? null
            : LiarsBot(
                me: p,
                difficulty: difficulty,
                style: LiarsStyle.values[(p + _rng.nextInt(3)) % 3],
                rng: _rng,
                reads: _reads,
              ),
    ];
    _botSeats = {for (var p = 1; p < personas.length; p++) p};
  }

  void playAgain() {
    if (online) return;
    _timer?.cancel();
    speech.clear();
    _start();
    phase = LiarsPhase.shaking;
    _after(400, _step);
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

  bool isBot(int p) => _botSeats.contains(p);

  /// Online, back at a game already going: straight to where it is (the
  /// finished rounds from the public cups, this one with your cup).
  void _catchUp() {
    final l = link!;
    if (l.moves.isEmpty) return;
    final cups = (l.state['cups'] as List?) ?? const [];
    List<List<int>> real(int round) => [
      for (var q = 0; q < players; q++)
        [for (final d in (cups[round] as List)[l.order![l.pos(q)]] as List) d as int],
    ];
    for (var m = l.next(); m != null; m = l.next()) {
      if (game.needsRoll) {
        if (game.round < cups.length) {
          game.roll(real(game.round));
        } else {
          final mine = _cupFromServer();
          if (mine == null) return;
          game.roll([for (var p = 0; p < players; p++) p == 0 ? mine : List.filled(game.counts[p], 0)]);
        }
      }
      l.cursor++;
      final p = m['p']! as int;
      if (m['kind'] == 'bid') {
        game.raise(p, LiarsBid(m['count']! as int, m['face']! as int));
      } else {
        game.challenge(p, LiarsCall.values.byName(m['kind']! as String));
      }
    }
    if (!game.needsRoll) phase = LiarsPhase.bidding;
  }

  // --- The table moves on ------------------------------------------------------

  /// Online: something new from the referee (a move, your cup).
  void _heard() {
    if (_disposed) return;
    if (_waitingForCup && _cupFromServer() != null) {
      _waitingForCup = false;
      _step();
    } else {
      _notify();
    }
  }

  bool _waitingForCup = false;

  /// Online: your cup for the round about to start, or null until it's in.
  List<int>? _cupFromServer() {
    final mine = link!.party.mine;
    if (mine == null || mine['round'] != game.round + 1) return null;
    return [for (final d in (mine['dice'] as List?) ?? const []) d as int];
  }

  void _step() {
    if (_disposed) return;
    if (game.isOver) return _finish();
    if (game.needsRoll) return _roll();
    final l = link;
    if (l != null) {
      final m = l.next();
      if (m == null) {
        l.waiting = _step;
        if (game.turn == 0) _yourTurn();
        _notify();
        return;
      }
      l.cursor++;
      final p = m['p']! as int;
      if (p == 0) {
        // Ours, already shown (a reset: replay it).
        if (game.turn == 0) _apply(0, m);
        return _after(150, _step);
      }
      // Bots seem to think (their tempo); people already took their time.
      final think = isBot(p) ? 900 + ((m['tempo'] as int? ?? 50) * 28) : 350;
      _thinking = p;
      _notify();
      _after(think, () {
        _thinking = null;
        _apply(p, m);
      });
      return;
    }
    // Here: a bot's turn, or yours.
    final p = game.turn;
    if (p == 0) {
      _yourTurn();
      _notify();
      return;
    }
    final move = _bots[p]!.decide(game);
    _thinking = p;
    _notify();
    _after(900 + (move.tempo * 2800).round(), () {
      _thinking = null;
      _apply(p, move.toJson());
    });
  }

  /// Who's thinking (a bubble of dots over them).
  int? get thinking => _thinking;
  int? _thinking;

  void _yourTurn() {
    phase = LiarsPhase.bidding;
    Sound.play(Sfx.yourTurn, gain: 0.7);
    _suggest();
  }

  /// Starts the next round: everyone shakes.
  void _roll() {
    final l = link;
    List<List<int>> cups;
    if (l != null) {
      final mine = _cupFromServer();
      if (mine == null) {
        _waitingForCup = true;
        return;
      }
      cups = [for (var p = 0; p < players; p++) p == 0 ? mine : List.filled(game.counts[p], 0)];
    } else {
      cups = game.rollFor(_rng);
    }
    game.roll(cups);
    phase = LiarsPhase.shaking;
    shakes++;
    peeking = false;
    counted = 0;
    verdict = false;
    lostBy = null;
    gainedBy = null;
    speech.clear();
    Sound.play(Sfx.shuffle);
    _notify();
    _after(1400, () {
      Sound.play(Sfx.drop);
      peeking = true;
      phase = LiarsPhase.bidding;
      _notify();
      _after(500, _step);
    });
  }

  /// Plays a move (any seat's, local seat numbers).
  void _apply(int p, Map<String, Object?> m) {
    final kind = m['kind'];
    if (kind == 'bid') {
      final b = LiarsBid(m['count']! as int, m['face']! as int);
      game.raise(p, b);
      _say(p, bidWords(b));
      Sound.play(Sfx.chips, gain: 0.6);
      _notify();
      _after(450, _step);
      return;
    }
    // A call: everyone's real dice (online, from the public cups).
    final l = link;
    if (l != null) {
      final cups = (l.state['cups'] as List?) ?? const [];
      final round = game.round - 1;
      if (round < cups.length) {
        final real = cups[round] as List;
        for (var q = 0; q < players; q++) {
          game.dice[q]
            ..clear()
            ..addAll([for (final d in real[l.order![l.pos(q)]] as List) d as int]);
        }
      }
    }
    final call = LiarsCall.values.byName(kind! as String);
    _say(p, call == LiarsCall.liar ? 'Liar!' : 'Spot on!');
    Sound.play(Sfx.tension);
    final r = game.challenge(p, call);
    if (!online) _reads.saw(r);
    _revealing(r);
  }

  /// The cups come up; the dice that count light up one at a time; then the
  /// verdict, and a die goes.
  void _revealing(LiarsReveal r) {
    phase = LiarsPhase.reveal;
    peeking = true;
    counted = 0;
    verdict = false;
    _notify();
    final total = r.found;
    void tick() {
      if (counted < total) {
        counted++;
        Sound.play(Sfx.place, gain: 0.5);
        _notify();
        _after(counted < 4 ? 320 : 220, tick);
        return;
      }
      verdict = true;
      lostBy = r.loser;
      gainedBy = r.gainer;
      if (r.loser == 0) {
        Sound.play(Sfx.loseSmall);
      } else if (r.gainer == 0 || (r.loser != null && (r.caller == 0 || r.bidder == 0))) {
        Sound.play(Sfx.winSmall);
      } else {
        Sound.play(Sfx.clash);
      }
      _react(r);
      _notify();
      _after(2600, _step);
    }

    _after(1100, tick);
  }

  void _react(LiarsReveal r) {
    String pick(List<String> lines) => lines[_rng.nextInt(lines.length)];
    final loser = r.loser;
    if (loser != null && isBot(loser) && _rng.nextDouble() < 0.7) {
      _say(
        loser,
        game.counts[loser] == 0
            ? pick(['I\'m out!', 'Well played.', 'Next time…'])
            : r.call == LiarsCall.liar && r.bidder == loser
            ? pick(['Caught.', 'Worth a try!', 'Hmph.'])
            : pick(['How?!', 'No way!', 'Unbelievable.']),
      );
    }
    final winner = loser == r.caller ? r.bidder : r.caller;
    if (r.gainer != null && isBot(r.gainer!)) {
      _say(r.gainer!, pick(['Spot on!', 'Called it exactly.', 'Read you like a book.']));
    } else if (loser != null && winner != loser && isBot(winner) && _rng.nextDouble() < 0.5) {
      _say(winner, pick(['Told you.', 'Ha!', 'Never doubt me.']));
    }
  }

  void _finish() {
    phase = LiarsPhase.over;
    Sound.play(game.winner == 0 ? Sfx.winBig : Sfx.loseBig);
    _notify();
  }

  // --- Your turn -----------------------------------------------------------------

  /// The bid to start from: the lowest that beats the standing one, on your
  /// most common face.
  void _suggest() {
    var best = rulesNow.lowFace, most = -1;
    for (var f = rulesNow.lowFace; f <= 6; f++) {
      final n = game.mine(0, f);
      if (n > most) {
        most = n;
        best = f;
      }
    }
    final low = game.lowest(best) ?? _anyLowest();
    if (low != null) {
      pickCount = low.count;
      pickFace = low.face;
    }
  }

  LiarsBid? _anyLowest() {
    for (var f = rulesNow.lowFace; f <= 6; f++) {
      final b = game.lowest(f);
      if (b != null) return b;
    }
    return null;
  }

  LiarsBid get picked => LiarsBid(pickCount, pickFace);
  bool get pickOk => game.beats(picked);

  void setFace(int f) {
    pickFace = f;
    // Keep the count legal: up to the lowest on this face.
    final low = game.lowest(f);
    if (low != null && pickCount < low.count) pickCount = low.count;
    _notify();
  }

  void setCount(int n) {
    pickCount = n.clamp(1, game.totalDice);
    _notify();
  }

  bool canFace(int f) => game.lowest(f) != null;

  void bid() {
    if (!yourTurn || !pickOk) return;
    _mine({'kind': 'bid', 'count': pickCount, 'face': pickFace});
  }

  bool get canCall => yourTurn && game.canCall;
  bool get canSpotOn => canCall && rulesNow.spotOn;

  void callLiar() {
    if (canCall) _mine({'kind': 'liar'});
  }

  void callSpotOn() {
    if (canSpotOn) _mine({'kind': 'spotOn'});
  }

  void _mine(Map<String, Object?> m) {
    final l = link;
    if (l == null) {
      _apply(0, m);
      return;
    }
    if (m['kind'] == 'bid') {
      // Shown now; the referee agrees in a moment.
      l.send(m);
      _apply(0, m);
    } else {
      // A call needs the cups from the referee: wait for it to come back.
      _sent = true;
      _notify();
      unawaited(
        l.party.move(m).then((e) {
          _sent = false;
          if (e != null && !_disposed) l.onReset?.call();
        }),
      );
    }
  }

  void togglePeek() {
    if (phase != LiarsPhase.bidding) return;
    peeking = !peeking;
    _notify();
  }

  /// How likely the standing bid is, from your cup (a hint for you).
  double? get odds {
    final b = game.bid;
    if (b == null || !game.isIn(0)) return null;
    return game.oddsFor(0, b);
  }

  /// How likely your picked bid is.
  double get pickOdds => game.oddsFor(0, picked);

  // --- Words ---------------------------------------------------------------------------

  String _name(int p) => p == 0 ? 'You' : personas[p].name;

  String commentary() {
    final g = game;
    switch (phase) {
      case LiarsPhase.over:
        return g.winner == 0
            ? 'Last cup standing: you win!'
            : '${_name(g.winner!)} wins: the last with dice.';
      case LiarsPhase.shaking:
        return g.round <= 1 ? 'Everyone shakes their cup…' : 'Round ${g.round}: shake!';
      case LiarsPhase.reveal:
        final r = g.reveal;
        if (r == null) return '';
        final call = r.call == LiarsCall.liar ? 'calls ${_name(r.bidder)} a liar' : 'says spot on';
        if (!verdict) {
          return '${_name(r.caller)} $call: counting ${faceNames[r.bid.face]}… $counted';
        }
        final there = 'There ${r.found == 1 ? 'was' : 'were'} ${r.found}';
        if (r.gainer != null) {
          return '$there: spot on! ${_name(r.gainer!)} ${r.gainer == 0 ? 'win' : 'wins'} a die back.';
        }
        if (r.loser == null) return '$there: spot on!';
        final out = g.counts[r.loser!] == 0;
        return '$there. ${_name(r.loser!)} ${r.loser == 0 ? 'lose' : 'loses'} a die${out ? ' and ${r.loser == 0 ? 'are' : 'is'} out' : ''}.';
      case LiarsPhase.bidding:
        if (!g.isIn(0)) return 'You\'re out: watching ${_name(g.turn)}…';
        final b = g.bid;
        if (_sent) return 'Calling…';
        if (yourTurn) {
          if (b == null) return 'You start: bid on what you think is under all the cups.';
          return '${_name(g.bidder!)} bid ${bidWords(b)}. Raise it, or call Liar!';
        }
        final t = _thinking ?? g.turn;
        return b == null
            ? '${_name(t)} starts…'
            : '${bidWords(b)} from ${_name(g.bidder!)}. ${_name(t)} to go…';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    link?.party.removeListener(_heard);
    super.dispose();
  }
}

const faceNames = ['', 'ones', 'twos', 'threes', 'fours', 'fives', 'sixes'];

/// "Three 5s", "One 2".
String bidWords(LiarsBid b) {
  const words = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten'];
  final n = b.count < words.length ? words[b.count] : '${b.count}';
  return '$n ${b.face}${b.count == 1 ? '' : 's'}';
}
