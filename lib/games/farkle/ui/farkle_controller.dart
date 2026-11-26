import 'dart:async';
import 'dart:math';

import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/farkle/farkle.dart';
import 'package:duel_engine/farkle/farkle_bot.dart';
import 'package:flutter/foundation.dart';

import '../../../core/avatars/faces.dart';
import '../../../core/sound/sound.dart';
import '../../bank/thrown_dice.dart';

enum FarklePhase {
  /// Waiting for a roll (yours: swipe; a bot's: in a moment).
  ready,

  /// Dice in the air.
  tumbling,

  /// Landed: pick what to keep.
  choosing,

  /// Nothing scored: the turn's lost.
  farkle,

  over,
}

/// Runs Farkle against bots. Seat 0 is you.
class FarkleController extends ChangeNotifier {
  FarkleController({
    required int bots,
    required this.difficulty,
    this.target = 10000,
    Random? rng,
    this.pace = 1,
    this.you = const Persona.you(),
  }) : _rng = rng ?? Random() {
    personas = [you, ...Persona.bots(bots, _rng)];
    _start();
  }

  final Difficulty difficulty;
  final int target;
  final double pace;
  final Persona you;
  final Random _rng;

  late List<Persona> personas;
  late FarkleGame game;
  late List<FarkleBot?> _bots;

  FarklePhase phase = FarklePhase.ready;

  /// Bumped every throw.
  int rollId = 0;

  /// The dice you've picked from this roll.
  final Set<int> picked = {};

  /// This turn's kept dice, roll by roll (the shelf).
  final List<List<int>> shelf = [];

  /// Each seat's last line.
  final Map<int, String> speech = {};
  int speechId = 0;

  /// The last turn's result, for a pop on the scoreboard.
  FarkleTurn? lastTurn;

  Timer? _timer;
  var _disposed = false;

  int get players => game.players;
  bool get yours => game.turn == 0;

  bool get canRoll => yours && phase == FarklePhase.ready && !game.isOver;
  bool get canPick => yours && phase == FarklePhase.choosing;

  /// What the picked dice score (null: they don't all count).
  int? get pickedScore => picked.isEmpty ? null : game.keepScore(picked);

  /// Dice left to roll if you keep what's picked (6 after hot dice).
  int get afterKeep {
    final left = game.rolled.length - picked.length;
    return left == 0 ? 6 : left;
  }

  bool get canKeepAndRoll => canPick && pickedScore != null;
  bool get canKeepAndBank {
    final s = pickedScore;
    if (!canPick || s == null) return false;
    final pts = game.turnPoints + s;
    return game.scores[0] > 0 || pts >= game.entry;
  }

  /// Bank without rolling again (after hot dice, before rolling six).
  bool get canBankNow => yours && phase == FarklePhase.ready && !game.isOver && game.canBank;

  /// Dice in this roll that score on their own (the rest are dimmed).
  Set<int> get scoring {
    final r = game.rolled;
    final (best, _) = farkleBestKeep(r);
    return best.toSet();
  }

  void _start() {
    game = FarkleGame(players: personas.length, target: target, first: _rng.nextInt(personas.length));
    _bots = [
      for (var p = 0; p < personas.length; p++)
        p == 0
            ? null
            : FarkleBot(
                me: p,
                difficulty: difficulty,
                style: FarkleStyle.values[(p + _rng.nextInt(3)) % 3],
                rng: _rng,
              ),
    ];
    phase = FarklePhase.ready;
    shelf.clear();
    picked.clear();
    speech.clear();
    lastTurn = null;
    _after(700, _turn);
  }

  void playAgain() {
    _timer?.cancel();
    _start();
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

  void _say(int p, String s) {
    speech[p] = s;
    speechId++;
  }

  String _pick(List<String> lines) => lines[_rng.nextInt(lines.length)];

  void _turn() {
    if (game.isOver) return _finish();
    phase = FarklePhase.ready;
    _notify();
    if (yours) {
      Sound.play(Sfx.yourTurn, gain: 0.7);
      return;
    }
    _after(700 + _rng.nextInt(400), _throw);
  }

  /// Your roll (swipe up / tap the tray).
  void roll() {
    if (!canRoll) return;
    _throw();
  }

  void _throw() {
    if (game.isOver) return _finish();
    picked.clear();
    game.roll(game.rollFor(_rng));
    rollId++;
    phase = FarklePhase.tumbling;
    Sound.play(Sfx.shuffle);
    _notify();
    _after(throwMs + 40, _landed);
  }

  void _landed() {
    Sound.play(Sfx.drop);
    if (game.farkled) {
      phase = FarklePhase.farkle;
      Sound.later(game.turnPoints >= 500 ? Sfx.loseMedium : Sfx.loseSmall, 150);
      if (!yours && _rng.nextDouble() < 0.7) {
        _say(
          game.turn,
          game.turnPoints >= 1000
              ? _pick(['NOOO!', 'All of it?!', 'Ugh!'])
              : _pick(['Farkle.', 'Bah.', 'Typical.']),
        );
      }
      _notify();
      _after(2000, () {
        lastTurn = game.pass();
        shelf.clear();
        _turn();
      });
      return;
    }
    phase = FarklePhase.choosing;
    _notify();
    if (yours) return;
    // A bot picks its dice, one by one, then rolls on or banks.
    final c = _bots[game.turn]!.decide(game);
    var t = 500;
    for (final i in c.keep) {
      t += 260;
      Timer(Duration(milliseconds: (t * pace).round()), () {
        if (_disposed || phase != FarklePhase.choosing) return;
        picked.add(i);
        Sound.play(Sfx.place, gain: 0.5);
        _notify();
      });
    }
    _after(t + 600, () {
      picked
        ..clear()
        ..addAll(c.keep);
      _keep();
      if (c.rollOn || !game.canBank) {
        if (game.hotDice) _say(game.turn, _pick(['Hot dice!', 'All six again!']));
        _after(700, _throw);
      } else {
        _bank();
      }
    });
  }

  void _keep() {
    shelf.add([for (final i in picked.toList()..sort()) game.rolled[i]]);
    game.keep(picked);
    picked.clear();
    Sound.play(Sfx.chips, gain: 0.6);
    if (game.hotDice) Sound.play(Sfx.winSmall);
    phase = FarklePhase.ready;
    _notify();
  }

  void _bank() {
    final pts = game.turnPoints;
    lastTurn = game.bank();
    shelf.clear();
    Sound.play(Sfx.pot);
    if (lastTurn!.player == 0) Sound.later(pts >= 1000 ? Sfx.winMedium : Sfx.winSmall, 200);
    if (lastTurn!.player != 0 && pts >= 1000 && _rng.nextDouble() < 0.6) {
      _say(lastTurn!.player, _pick(['Into the bank!', 'I\'ll take that.', 'Lovely.']));
    }
    _notify();
    _after(900, _turn);
  }

  // --- Your choices -----------------------------------------------------------

  void tapDie(int i) {
    if (!canPick) return;
    if (!picked.remove(i)) picked.add(i);
    Sound.play(Sfx.tap, gain: 0.5);
    _notify();
  }

  /// Picks every scoring die.
  void pickBest() {
    if (!canPick) return;
    picked
      ..clear()
      ..addAll(scoring);
    _notify();
  }

  void keepAndRoll() {
    if (!canKeepAndRoll) return;
    _keep();
    _after(250, _throw);
  }

  void keepAndBank() {
    if (!canKeepAndBank) return;
    _keep();
    _bank();
  }

  void bankNow() {
    if (canBankNow) _bank();
  }

  void _finish() {
    phase = FarklePhase.over;
    final w = game.winners;
    Sound.play(w.contains(0) ? Sfx.winBig : Sfx.loseBig);
    _notify();
  }

  String _name(int p) => p == 0 ? 'You' : personas[p].name;

  String commentary() {
    final g = game;
    if (phase == FarklePhase.over) {
      final w = g.winners;
      if (w.length > 1) return 'A tie on ${g.scores[w.first]}: ${w.map(_name).join(' & ')}.';
      return w.single == 0
          ? 'You win with ${g.scores[0]}!'
          : '${_name(w.single)} wins with ${g.scores[w.single]}.';
    }
    final beat = g.toBeat;
    final last = beat != null && g.closer != g.turn ? ' Last turn: beat $beat!' : '';
    switch (phase) {
      case FarklePhase.farkle:
        return 'FARKLE! ${g.turn == 0 ? 'You lose' : '${_name(g.turn)} loses'} ${g.turnPoints} this turn.';
      case FarklePhase.tumbling:
        return '${_name(g.turn)} ${yours ? 'roll' : 'rolls'} ${g.rolled.length} ${g.rolled.length == 1 ? 'die' : 'dice'}…';
      case FarklePhase.choosing:
        if (!yours) return '${_name(g.turn)} is picking dice…';
        final s = pickedScore;
        if (picked.isEmpty) return 'Tap the dice to keep (at least one scoring die).$last';
        if (s == null) return 'Those don\'t all score: every die you keep must count.';
        return 'Keep +$s (turn: ${g.turnPoints + s}), then roll $afterKeep or bank.$last';
      case FarklePhase.ready:
        if (!yours) return '${_name(g.turn)} to roll.$last';
        if (g.hotDice) return 'Hot dice! ${g.turnPoints} this turn: roll all six, or bank.$last';
        return g.turnPoints == 0
            ? 'Your turn: swipe up to roll six dice.$last'
            : 'Roll $afterReady or bank ${g.turnPoints}.$last';
      case FarklePhase.over:
        return '';
    }
  }

  int get afterReady => game.diceLeft;

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
