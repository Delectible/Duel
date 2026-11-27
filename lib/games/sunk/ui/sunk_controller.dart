import 'dart:async';
import 'dart:math';

import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/sunk/sunk.dart';
import 'package:duel_engine/sunk/sunk_bot.dart';
import 'package:flutter/foundation.dart';

import '../../../core/avatars/faces.dart';
import '../../../core/online/online_link.dart';
import '../../../core/sound/sound.dart';

/// What the ghost (Captain Boo, keeper of the wreck) is doing.
enum GhostMood { idle, watching, laughing, spooking, sulking, cheering }

/// Runs Sunk: against bots here, or with your party (the referee deals the
/// sea; this table replays its log from the cards drawn so far). Seat 0 is
/// you. Every move's events are shown one at a time: a card rising from
/// the wreck, a bust, the ghost's Boo!, a hook, a cut line.
class SunkController extends ChangeNotifier {
  SunkController({
    int bots = 2,
    this.difficulty = Difficulty.normal,
    this.target = 120,
    this.pace = 1,
    this.you = const Persona.you(),
    Random? rng,
    this.link,
  }) : _rng = rng ?? Random() {
    final l = link;
    if (l != null) {
      personas = l.personas(you);
      final n = l.n;
      game = SunkGame(
        players: n,
        sea: const [],
        target: l.state['target'] as int? ?? 120,
        first: l.local(l.state['first']! as int),
      );
      game.source = _fromServer;
      game.peekAt = _peekFromServer;
      final bots = (l.party.match?['bots'] as List?) ?? const [];
      _botSeats = {
        for (var p = 0; p < n; p++)
          if (bots.length > l.order![l.pos(p)] && bots[l.order![l.pos(p)]] != null) p,
      };
      l.party.addListener(_heard);
      // Back at a game already going: straight to where it is.
      for (var m = l.next(); m != null; m = l.next()) {
        l.cursor++;
        _apply(m);
      }
      game.events.clear();
    } else {
      personas = [you, ...Persona.bots(bots, _rng)];
      _start();
    }
    _after(700, _step);
  }

  final Difficulty difficulty;
  final int target;
  final double pace;
  final Persona you;
  final OnlineLink? link;
  final Random _rng;

  late List<Persona> personas;
  late SunkGame game;
  late List<SunkBot?> _bots;
  Set<int> _botSeats = {};

  /// The card on show (rising from the wreck), and who it's for.
  SunkCard? reveal;
  int? revealFor;
  bool revealForced = false;
  int reveals = 0;

  /// A bust, a save, a boo, a hook or a cut on show (the table's banner).
  SunkEvent? showing;
  int shows = 0;

  GhostMood mood = GhostMood.idle;
  String? ghostSays;
  int ghostSaid = 0;

  /// Who's thinking.
  int? thinking;

  /// Each seat's last line.
  final Map<int, String> speech = {};
  int speechId = 0;

  /// Busy showing what happened.
  bool _playing = false;

  /// Your move's on its way.
  bool _sent = false;

  Timer? _timer;
  var _disposed = false;

  int get players => game.players;
  bool get online => link != null;
  bool isBot(int p) => _botSeats.contains(p);

  bool get yourTurn =>
      !game.isOver &&
      game.turn == 0 &&
      game.diving(0) &&
      !_playing &&
      !_sent &&
      (link == null || link!.next() == null);

  bool get canDive => yourTurn && game.pending == null;
  bool get aiming => yourTurn && (game.pending == SunkKind.hook || game.pending == SunkKind.cut);
  bool get charting => yourTurn && game.pending == SunkKind.map;

  void _start() {
    game = SunkGame(
      players: personas.length,
      sea: sunkDeck()..shuffle(_rng),
      target: target,
      first: _rng.nextInt(personas.length),
    )..reshuffle = (c) => c.shuffle(_rng);
    _bots = [
      for (var p = 0; p < personas.length; p++)
        p == 0
            ? null
            : SunkBot(
                me: p,
                difficulty: difficulty,
                style: SunkStyle.values[(p + _rng.nextInt(3)) % 3],
                rng: _rng,
              ),
    ];
    _botSeats = {for (var p = 1; p < personas.length; p++) p};
    speech.clear();
    reveal = null;
    showing = null;
    mood = GhostMood.idle;
    _say(_pick(['Welcome to my wreck…', 'Treasure? Oh, there\'s treasure.', 'Dive, if you dare!']));
  }

  void playAgain() {
    if (online) return;
    _timer?.cancel();
    _start();
    _after(600, _step);
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

  String _pick(List<String> lines) => lines[_rng.nextInt(lines.length)];

  void _say(String s) {
    ghostSays = s;
    ghostSaid++;
  }

  void _speak(int p, String s) {
    speech[p] = s;
    speechId++;
  }

  String name(int p) => p == 0 ? 'You' : personas[p].name;

  // --- Online ----------------------------------------------------------------------

  int _takenAt = 0;

  SunkCard? _fromServer() {
    final taken = (link!.state['taken'] as List?) ?? const [];
    if (_takenAt >= taken.length) return null;
    final id = taken[_takenAt++];
    return id == null ? null : SunkCard.parse(id as String);
  }

  SunkCard? _peekFromServer() {
    final mine = link!.party.mine;
    if (mine == null || mine['at'] != link!.cursor || game.turn != 0) return null;
    final id = mine['peek'];
    return id is String ? SunkCard.parse(id) : null;
  }

  void _heard() {
    if (_disposed) return;
    _notify();
  }

  /// Plays a logged move (local seats).
  void _apply(Map<String, Object?> m) {
    final p = m['p']! as int;
    switch (m['kind']) {
      case 'draw':
        game.draw(p);
      case 'surface':
        game.surface(p);
      case 'aim':
        game.aim(p, link!.local(m['target']! as int));
      case 'chart':
        game.chart(p, take: m['take'] == true);
    }
  }

  // --- The table moves on ------------------------------------------------------

  void _step() {
    if (_disposed) return;
    if (game.isOver) return _finish();
    final l = link;
    if (l != null) {
      final m = l.next();
      if (m == null) {
        l.waiting = _step;
        if (game.turn == 0 && game.diving(0)) _yourTurn();
        _notify();
        return;
      }
      final p = m['p']! as int;
      final think = isBot(p) ? 700 + ((m['tempo'] as int? ?? 40) * 18) : 250;
      thinking = p == 0 ? null : p;
      _notify();
      _after(p == 0 ? 0 : think, () {
        thinking = null;
        l.cursor++;
        _sent = false;
        final before = game.events.length;
        _apply(m);
        _play(before);
      });
      return;
    }
    final p = game.turn;
    if (p == 0) {
      _yourTurn();
      _notify();
      return;
    }
    final bot = _bots[p]!;
    final choice = bot.decide(game);
    thinking = p;
    _notify();
    _after(600 + (bot.tempo(game) * 1600).round(), () {
      thinking = null;
      if (choice.kind == 'surface' && game.worth(p) >= 20 && _rng.nextDouble() < 0.5) {
        _speak(p, _pick(['I\'m out!', 'Up I go.', 'Enough for me.']));
      }
      final before = game.events.length;
      sunkPlay(game, choice);
      _play(before);
    });
  }

  void _yourTurn() {
    mood = GhostMood.watching;
    Sound.play(Sfx.yourTurn, gain: 0.6);
  }

  /// Shows the events from [from] on, one at a time, then moves on.
  void _play(int from) {
    _playing = true;
    final list = game.events.sublist(from);
    var i = 0;
    void next() {
      if (_disposed) return;
      if (i >= list.length) {
        _playing = false;
        reveal = null;
        _notify();
        _after(350, _step);
        return;
      }
      final e = list[i++];
      final ms = _show(e);
      _notify();
      _after(ms, next);
    }

    next();
  }

  /// Puts [e] on show; how long it stays.
  int _show(SunkEvent e) {
    switch (e) {
      case SunkDrew(:final card, :final forced, :final player):
        reveal = card;
        revealFor = player;
        revealForced = forced;
        reveals++;
        showing = null;
        Sound.play(Sfx.deal);
        if (card.kind == SunkKind.air) Sound.later(Sfx.collect, 250);
        if (card.isTreasure && card.value >= 7) mood = GhostMood.sulking;
        return forced ? 650 : 900;
      case SunkBusted(:final player, :final lost):
        showing = e;
        shows++;
        mood = GhostMood.laughing;
        _say(
          lost >= 20
              ? _pick(['HA! It\'s mine again!', 'Glug glug glug…', 'Back to the deep with you!'])
              : _pick(['Hehehe.', 'Sunk!', 'Too greedy!']),
        );
        Sound.play(player == 0 ? Sfx.loseSmall : Sfx.clash);
        if (player != 0 && isBot(player) && _rng.nextDouble() < 0.6) {
          _speak(player, _pick(['NO!', 'Ugh, a ${(e).card.value}!', 'Glub.']));
        }
        return 1500;
      case SunkSaved():
        showing = e;
        shows++;
        Sound.play(Sfx.pot, gain: 0.7);
        _say(_pick(['A spare tank? Cheater…', 'Lucky breath.']));
        return 1100;
      case SunkSurfaced(:final player, :final points, :final haul):
        showing = e;
        shows++;
        mood = haul ? GhostMood.sulking : GhostMood.idle;
        if (haul) _say(_pick(['My treasure! All of it!', 'A full haul?! Rude.']));
        Sound.play(player == 0 ? (points >= 30 ? Sfx.winMedium : Sfx.winSmall) : Sfx.chips);
        return haul ? 1500 : 900;
      case SunkBoo(:final victims):
        showing = e;
        shows++;
        mood = GhostMood.spooking;
        _say('BOO!');
        Sound.play(Sfx.tension);
        return victims.isEmpty ? 900 : 1200;
      case SunkHooked(:final from):
        showing = e;
        shows++;
        Sound.play(Sfx.place);
        if (isBot(from) && _rng.nextDouble() < 0.6) {
          _speak(from, _pick(['Hey!', 'Give that back!', 'Thief!']));
        }
        return 1200;
      case SunkCut(:final target):
        showing = e;
        shows++;
        mood = GhostMood.cheering;
        Sound.play(Sfx.fall);
        if (isBot(target) && _rng.nextDouble() < 0.6) _speak(target, _pick(['My line!', 'Rude!', 'Noooo.']));
        return 1200;
      case SunkPeeked():
        return 300;
      case SunkRoundOver():
        showing = e;
        shows++;
        mood = GhostMood.idle;
        reveal = null;
        speech.clear();
        if (!game.isOver) _say(_pick(['Again! Dive again!', 'Back down you come…', 'Round ${game.round}…']));
        Sound.play(Sfx.shuffle, gain: 0.6);
        return 1700;
    }
  }

  void _finish() {
    mood = game.winners.contains(0) ? GhostMood.sulking : GhostMood.cheering;
    _say(game.winners.contains(0) ? 'You\'ve emptied my wreck…' : 'The deep wins again!');
    Sound.play(game.winners.contains(0) ? Sfx.winBig : Sfx.loseBig);
    _notify();
  }

  // --- Your moves -----------------------------------------------------------------

  void dive() {
    if (canDive) _mine({'kind': 'draw'});
  }

  void surface() {
    if (canDive && game.bags[0].isNotEmpty) _mine({'kind': 'surface'});
  }

  void aim(int target) {
    if (aiming && game.targets.contains(target)) _mine({'kind': 'aim', 'target': target});
  }

  void chart({required bool take}) {
    if (charting) _mine({'kind': 'chart', 'take': take});
  }

  void _mine(Map<String, Object?> m) {
    mood = GhostMood.idle;
    final l = link;
    if (l == null) {
      final before = game.events.length;
      sunkPlay(game, switch (m['kind']) {
        'draw' => const SunkChoice.draw(),
        'surface' => const SunkChoice.surface(),
        'aim' => SunkChoice.aim(m['target']! as int),
        _ => SunkChoice.chart(take: m['take'] == true),
      });
      _play(before);
      return;
    }
    // Online the referee draws the card: wait for it to come back.
    _sent = true;
    _notify();
    final out = {...m};
    if (m['target'] is int) out['target'] = l.pos(m['target']! as int);
    unawaited(
      l.party.move(out).then((e) {
        if (e != null && !_disposed) {
          _sent = false;
          l.onReset?.call();
        }
      }),
    );
  }

  /// The chance your next card sinks you.
  double get risk => game.bustChance(0);

  // --- Words ---------------------------------------------------------------------

  String commentary() {
    final g = game;
    if (g.isOver) {
      final w = g.winners;
      if (w.length > 1) return 'A tie on ${g.scores[w.first]}: ${w.map(name).join(' & ')}.';
      return w.single == 0
          ? 'You win with ${g.scores[0]}!'
          : '${name(w.single)} wins with ${g.scores[w.single]}.';
    }
    final s = showing;
    if (_playing && s != null) {
      return switch (s) {
        SunkBusted(:final player, :final card, :final lost) =>
          '${name(player)} drew a second ${card.value}: sunk! ${lost > 0 ? '$lost lost.' : ''}',
        SunkSaved(:final player) =>
          '${name(player)} ${player == 0 ? 'breathe' : 'breathes'} from a Spare Air tank: saved!',
        SunkSurfaced(:final player, :final points, :final haul, :final run) =>
          '${name(player)} ${player == 0 ? 'surface' : 'surfaces'} with $points${haul
              ? ' (a full haul!)'
              : run
              ? ' (with a run)'
              : ''}.',
        SunkBoo(:final victims) =>
          victims.isEmpty ? 'Boo! Nobody else is down there.' : 'Boo! Everyone else still diving draws one!',
        SunkHooked(:final player, :final from, :final card) =>
          '${name(player)} ${player == 0 ? 'hook' : 'hooks'} ${from == 0 ? 'your' : '${name(from)}\'s'} ${card?.value ?? ''}.',
        SunkCut(:final player, :final target, :final card) =>
          '${name(player)} ${player == 0 ? 'cut' : 'cuts'} ${target == 0 ? 'your' : '${name(target)}\'s'} line: the ${card?.value ?? ''} sinks.',
        SunkRoundOver() => 'Everyone\'s up. Round ${g.round}!',
        _ => '',
      };
    }
    if (_sent) return 'Diving…';
    if (!g.diving(0)) {
      return g.state[0] == SunkState.busted
          ? 'You sank. Watching the others…'
          : 'You\'re up. Watching the others…';
    }
    if (aiming) return '${g.pending == SunkKind.hook ? 'Hook' : 'Cut Line'}: tap a diver.';
    if (charting) {
      final c = g.peeked;
      return c == null ? 'Reading the map…' : 'The map shows ${_label(c)}. Take it or leave it?';
    }
    if (yourTurn) {
      final w = g.worth(0);
      return w == 0
          ? 'Your turn: dive for treasure.'
          : 'Bag: $w. ${(risk * 100).round()}% chance the next card sinks you. Dive or surface?';
    }
    final t = thinking ?? g.turn;
    return '${name(t)} ${t == 0 ? 'are' : 'is'} diving…';
  }

  static String _label(SunkCard c) => switch (c.kind) {
    SunkKind.treasure => 'a ${c.value}',
    SunkKind.air => 'Spare Air',
    SunkKind.boo => 'the ghost',
    SunkKind.hook => 'a Hook',
    SunkKind.cut => 'a Cut Line',
    SunkKind.map => 'another Map',
  };

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    link?.party.removeListener(_heard);
    super.dispose();
  }
}
