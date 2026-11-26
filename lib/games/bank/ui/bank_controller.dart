import 'dart:async';
import 'dart:math';

import 'package:duel_engine/bank/bank.dart';
import 'package:duel_engine/bank/bank_bot.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:flutter/foundation.dart';

import '../../../core/avatars/faces.dart';
import '../../../core/online/online_link.dart';
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
    this.link,
  }) : _rng = rng ?? Random() {
    final l = link;
    personas = l == null ? [you, ...Persona.bots(bots, _rng)] : l.personas(you);
    _start();
  }

  /// With your party, online: the referee rolls the dice and keeps who
  /// banked; this table plays its log back.
  final OnlineLink? link;

  /// Online: your roll or bank is on its way.
  bool _sent = false;

  /// Online: a word from the referee (a bank that came too late).
  String? news;

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
      phase == BankPhase.rolling &&
      !tumbling &&
      !_sent &&
      game.roller == 0 &&
      !game.banked[0] &&
      !game.roundOver &&
      (link == null || link!.next() == null);

  bool get canBank => phase == BankPhase.rolling && !tumbling && !_sent && game.canBank(0);

  void _start() {
    final l = link;
    game = l == null
        ? BankGame(players: personas.length, rounds: rounds, firstRoller: _rng.nextInt(personas.length))
        : BankGame(
            players: l.n,
            rounds: l.state['rounds']! as int,
            firstRoller: l.local(l.state['first']! as int),
          );
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
    // Online, back at a game already going: straight to where it is.
    if (l != null && l.cursor == 0 && l.moves.isNotEmpty) {
      for (var m = l.next(); m != null; m = l.next()) {
        l.cursor++;
        if (game.roundOver && !game.isOver) game.nextRound();
        if (m['k'] == 'roll') {
          game.roll(m['a']! as int, m['b']! as int);
        } else {
          game.bankFor(m['p']! as int);
        }
      }
      if (game.roundOver && !game.isOver) game.nextRound();
    }
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
    if (link != null) return;
    speech[seat] = text;
    speechId++;
  }

  /// Someone's roll: a bot rolls by itself; you get the Roll button.
  void _nextRoll() {
    if (game.roundOver) return _endRound();
    if (link != null) return _step();
    _notify();
    if (game.roller == 0) {
      Sound.play(Sfx.yourTurn, gain: 0.7);
      return;
    }
    _after(700 + _rng.nextInt(500), () => _roll());
  }

  /// Online: the next thing in the referee's log (a roll, a bank), or wait
  /// for it.
  void _step() {
    final l = link!;
    final m = l.next();
    if (m == null) {
      l.waiting = _step;
      if (game.roller == 0 && !game.banked[0] && !_sent) Sound.play(Sfx.yourTurn, gain: 0.7);
      _notify();
      return;
    }
    l.cursor++;
    final p = m['p']! as int;
    if (p == 0) _sent = false;
    if (m['k'] == 'roll') {
      _roll(m['a']! as int, m['b']! as int);
    } else {
      if (game.canBank(p)) _bank(p);
      if (!game.roundOver) _after(p == 0 ? 200 : 350, _step);
    }
  }

  /// Your roll.
  void roll() {
    if (!yourRoll) return;
    final l = link;
    if (l != null) return _send({'k': 'roll'});
    _roll();
  }

  void _send(Map<String, Object?> move) {
    _sent = true;
    news = null;
    _notify();
    unawaited(
      link!.party.move(move).then((e) {
        if (_disposed || e == null) return;
        _sent = false;
        news = move['k'] == 'bank' ? 'Too late: the dice rolled on.' : e;
        _notify();
      }),
    );
  }

  void _roll([int? da, int? db]) {
    tumbling = true;
    rollId++;
    speech.clear();
    final a = da ?? 1 + _rng.nextInt(6), b = db ?? 1 + _rng.nextInt(6);
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
    if (link != null) return _after(250, _step);
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
    if (link != null) return;
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
    if (link != null) return _send({'k': 'bank', 'at': game.rolls, 'round': game.round});
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
    if (p != 0 && link == null) {
      _say(p, game.bank >= 300 ? _pick(['BANK!', 'Bank! I\'m out!', 'Bank, bank, bank!']) : 'Bank!');
    }
    _notify();
    if (game.roundOver) {
      _cancel();
      _after(1000, _endRound);
    } else if (wasRoller && p == 0 && link == null) {
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
    final n = news;
    if (n != null && phase == BankPhase.rolling && !tumbling) return n;
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
