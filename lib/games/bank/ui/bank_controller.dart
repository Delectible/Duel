import 'dart:async';
import 'dart:math';

import 'package:duel_engine/bank/bank.dart';
import 'package:duel_engine/bank/bank_bot.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:flutter/foundation.dart';

import '../../../core/avatars/faces.dart';
import '../../../core/sound/sound.dart';
import 'bank_bits.dart';

enum BankPhase { rolling, roundOver, over }

/// Runs Bank! against bots. Seat 0 is you. Bots roll by themselves; you tap
/// Roll on your turn. After every roll there's a moment to bank: the bots
/// decide one by one, and you can tap BANK! any time you're in.
class BankController extends ChangeNotifier {
  BankController({
    required int bots,
    required this.difficulty,
    required this.rounds,
    Random? rng,
    this.pace = 1,
    this.you = const Persona.you(),
  }) : _rng = rng ?? Random() {
    personas = [you, ...Persona.bots(bots, _rng)];
    _start();
  }

  final Difficulty difficulty;
  final int rounds;
  final double pace;
  final Persona you;
  final Random _rng;

  late List<Persona> personas;
  late BankGame game;
  late List<BankBot?> _bots;

  BankPhase phase = BankPhase.rolling;

  /// Bumped on each roll (dice tumble, pops).
  int rollId = 0;

  /// Rolling: the dice are in the air.
  bool tumbling = false;

  final Map<int, String> speech = {};
  int speechId = 0;

  /// Who banked last, for the "Bank!" flash on their seat.
  final Map<int, int> bankedAtRoll = {};

  Timer? _timer;
  final List<Timer> _quick = [];
  var _disposed = false;

  int get players => game.players;

  bool get yourRoll =>
      phase == BankPhase.rolling && !tumbling && game.roller == 0 && !game.banked[0] && !game.roundOver;

  bool get canBank => phase == BankPhase.rolling && !tumbling && game.canBank(0);

  void _start() {
    game = BankGame(players: personas.length, rounds: rounds, firstRoller: _rng.nextInt(personas.length));
    _bots = [
      for (var p = 0; p < personas.length; p++)
        p == 0
            ? null
            : BankBot(
                me: p,
                style: BankStyle.values[(p + _rng.nextInt(3)) % 3],
                difficulty: difficulty,
                rng: _rng,
              ),
    ];
    phase = BankPhase.rolling;
    speech.clear();
    bankedAtRoll.clear();
    rollId = 0;
    _after(900, _nextRoll);
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
    for (final t in _quick) {
      t.cancel();
    }
    _quick.clear();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _say(int seat, String text) {
    speech[seat] = text;
    speechId++;
  }

  /// Someone's roll: a bot rolls by itself; you get the Roll button.
  void _nextRoll() {
    if (game.roundOver) return _endRound();
    _notify();
    if (game.roller == 0) {
      Sound.play(Sfx.yourTurn, gain: 0.7);
      return;
    }
    _after(700 + _rng.nextInt(500), () => _roll());
  }

  /// Your roll.
  void roll() {
    if (!yourRoll) return;
    _roll();
  }

  void _roll() {
    tumbling = true;
    rollId++;
    speech.clear();
    final a = 1 + _rng.nextInt(6), b = 1 + _rng.nextInt(6);
    final r = game.roll(a, b);
    Sound.play(Sfx.shuffle);
    _notify();
    // The dice land, then the news.
    _after(diceRollMs + 30, () {
      tumbling = false;
      _land(r);
    });
  }

  void _land(BankRoll r) {
    Sound.play(Sfx.drop);
    switch (r.kind) {
      case BankRollKind.safeSeven:
        Sound.play(Sfx.chips);
      case BankRollKind.doubled:
        Sound.later(r.after >= 400 ? Sfx.winMedium : Sfx.collect, 120);
        _react(
          r.after >= 400 ? ['WHOA!', 'Doubled!', 'Here we go!', 'Keep rolling!'] : ['Doubles!', 'Nice.'],
        );
      case BankRollKind.bust:
        // Your bank lost: small or medium, as a lost hand in poker.
        if (game.banked[0] || r.before == 0) {
          Sound.later(Sfx.clash, 120);
        } else {
          Sound.later(r.before >= 300 ? Sfx.loseMedium : Sfx.loseSmall, 120);
        }
        final hurt = [
          for (final p in game.stillIn)
            if (p != 0) p,
        ];
        if (hurt.isNotEmpty && r.before >= 100) {
          _say(
            hurt[_rng.nextInt(hurt.length)],
            r.before >= 300
                ? _pick(['NOOO!', 'All of it?!', 'Why did I wait?!'])
                : _pick(['Ugh.', 'Should\'ve banked.', 'Typical.']),
          );
        }
        final safe = [
          for (var p = 1; p < players; p++)
            if (game.banked[p]) p,
        ];
        if (safe.isNotEmpty && r.before >= 200 && _rng.nextBool()) {
          _say(safe[_rng.nextInt(safe.length)], _pick(['Called it.', 'Glad I banked!', 'Ha!']));
        }
      case BankRollKind.add:
        break;
    }
    _notify();
    if (game.roundOver) {
      _after(r.kind == BankRollKind.bust ? 1900 : 900, _endRound);
      return;
    }
    // The bots have their moment to bank, one at a time.
    final order = [
      for (final p in game.stillIn)
        if (p != 0) p,
    ]..shuffle(_rng);
    var t = 250;
    for (final p in order) {
      t += 150 + _rng.nextInt(400);
      _quick.add(
        Timer(Duration(milliseconds: (t * pace).round()), () {
          if (_disposed || game.roundOver || !game.canBank(p)) return;
          if (_bots[p]!.wantsToBank(game)) _bank(p);
        }),
      );
    }
    _after(t + 700, _nextRoll);
  }

  String _pick(List<String> lines) => lines[_rng.nextInt(lines.length)];

  void _react(List<String> lines) {
    final in_ = [
      for (final p in game.stillIn)
        if (p != 0) p,
    ];
    if (in_.isEmpty || _rng.nextDouble() > 0.6) return;
    _say(in_[_rng.nextInt(in_.length)], _pick(lines));
  }

  /// Tap BANK!
  void bank() {
    if (!canBank) return;
    _bank(0);
  }

  void _bank(int p) {
    final wasRoller = game.roller == p;
    game.bankFor(p);
    bankedAtRoll[p] = game.rolls;
    if (p == 0) {
      Sound.play(Sfx.pot);
      Sound.later(game.bankedAt[0]! >= 300 ? Sfx.winMedium : Sfx.winSmall, 250);
    } else {
      Sound.play(Sfx.chips, gain: 0.7);
    }
    if (p != 0) {
      _say(p, game.bank >= 300 ? _pick(['BANK!', 'Bank! I\'m out!', 'Bank, bank, bank!']) : 'Bank!');
    }
    _notify();
    if (game.roundOver) {
      _cancel();
      _after(1000, _endRound);
    } else if (wasRoller && p == 0) {
      // You banked on your own roll: the next player takes the dice.
      _after(600, _nextRoll);
    }
  }

  void _endRound() {
    _cancel();
    if (game.isOver) {
      phase = BankPhase.over;
      final w = game.winners;
      Sound.play(w.contains(0) ? Sfx.winBig : Sfx.loseBig);
      _notify();
      return;
    }
    phase = BankPhase.roundOver;
    _notify();
    _after(2000, () {
      game.nextRound();
      bankedAtRoll.clear();
      speech.clear();
      phase = BankPhase.rolling;
      _notify();
      _after(600, _nextRoll);
    });
  }

  String _name(int p) => p == 0 ? 'You' : personas[p].name;

  String commentary() {
    final g = game;
    if (phase == BankPhase.over) {
      final w = g.winners;
      final top = g.scores[w.first];
      if (w.length > 1) return 'A tie on $top: ${w.map(_name).join(' & ')}.';
      return w.single == 0 ? 'You win with $top!' : '${_name(w.single)} wins with $top.';
    }
    if (phase == BankPhase.roundOver) {
      final r = g.last;
      final lost = [for (final p in g.stillIn) _name(p)];
      if (r != null && r.kind == BankRollKind.bust) {
        return lost.isEmpty
            ? 'A seven, but everyone had banked. Round ${g.round} done.'
            : 'Seven! ${lost.join(', ')} ${lost.length == 1 && lost.single == 'You' ? 'get' : 'got'} nothing this round.';
      }
      return 'Everyone banked. Round ${g.round} done.';
    }
    if (tumbling) return '${_name(g.roller)} ${g.roller == 0 ? 'roll' : 'rolls'}…';
    final r = g.last;
    final what = r == null
        ? 'Round ${g.round} of ${g.rounds}.'
        : switch (r.kind) {
            BankRollKind.safeSeven => 'A safe 7: +70!',
            BankRollKind.doubled => 'Doubles: the bank doubles to ${r.after}!',
            BankRollKind.add => '${r.a} and ${r.b}: +${r.sum}.',
            BankRollKind.bust => '',
          };
    if (g.banked[0]) return '$what You banked ${g.bankedAt[0]}. Watching the others…';
    if (yourRoll) return '$what Your roll${g.rolls > 0 ? ', or BANK! to keep ${g.bank}' : ''}.';
    if (canBank) return '$what Bank ${g.bank} now, or ride it?';
    return '$what ${_name(g.roller)} to roll.';
  }

  @override
  void dispose() {
    _disposed = true;
    _cancel();
    super.dispose();
  }
}
