import 'dart:async';
import 'dart:math';

import 'package:duel_engine/blitz/blitz.dart';
import 'package:duel_engine/blitz/blitz_bot.dart';
import 'package:duel_engine/cards.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:flutter/foundation.dart';

import '../../../core/avatars/faces.dart';
import '../../../core/sound/sound.dart';

enum BlitzPhase {
  /// Castles going up.
  dealing,

  /// Someone's turn (yours: waiting for you).
  playing,

  /// You hit Blitz with more than one opponent left: pick whose castle.
  blitzTarget,

  /// One castle left standing.
  over,
}

/// Runs a game of Blitz against bots for the table screen. Seat 0 is you.
///
/// Your turn: tap a hand card to pick it up; what it can do lights up on
/// the castles (a strike, a scout, a fortify), and Pair / Blitz light up
/// when your hand allows them.
class BlitzController extends ChangeNotifier {
  BlitzController({
    required int bots,
    required this.difficulty,
    this.wars = false,
    Random? rng,
    this.pace = 1,
    this.you = const Persona.you(),
  }) : _rng = rng ?? Random(),
       assert(bots >= 1 && bots <= 5) {
    _start(bots);
  }

  final Difficulty difficulty;
  final bool wars;
  final Persona you;

  /// Multiplies every delay (tests).
  final double pace;
  final Random _rng;

  late List<Persona> personas;
  late Blitz game;
  late List<BlitzBot?> _bots;

  BlitzPhase phase = BlitzPhase.dealing;

  /// Bumped each new game (keys that restart deal animations).
  int round = 0;

  /// The hand card you've picked up.
  PlayingCard? selected;

  /// The last thing someone did, for bubbles and highlights (and a
  /// counter so each one animates once).
  BlitzEvent? lastAction;
  int actionId = 0;

  /// Wars fought by the last action.
  List<War> lastWars = const [];

  /// The war scene is playing (the table waits for it).
  bool fighting = false;

  /// How long one war's scene lasts (each war in [lastWars] plays in turn).
  Duration get warTime => Duration(milliseconds: (2600 * pace).round());

  /// [p]'s castle as the table should show it: while a war is fought, as it
  /// stood before the war (its result shows once the scene is over).
  List<CastleCard> castle(int p) {
    final before = fighting ? lastWars.first.before : const <List<CastleCard>>[];
    return before.isNotEmpty ? before[p] : game.castles[p];
  }

  int get _warPause => fighting ? 2600 * lastWars.length : 0;

  Timer? _timer;
  var _disposed = false;

  int get players => game.players;

  bool get yourTurn => phase == BlitzPhase.playing && game.turn == 0 && !game.isOver && !fighting;

  List<BlitzMove> get _yours => yourTurn ? game.moves(0) : const [];

  /// Your hand: reds then blacks, low to high (easy to count a colour).
  List<PlayingCard> get hand {
    final h = [...game.hands[0]];
    h.sort((a, b) {
      if (a.suit.isRed != b.suit.isRed) return a.suit.isRed ? -1 : 1;
      return a.rank != b.rank ? a.rank.compareTo(b.rank) : a.suit.index.compareTo(b.suit.index);
    });
    return h;
  }

  /// What the picked-up card can do to castle card ([player], [index]).
  BlitzMove? moveAt(int player, int index) {
    final s = selected;
    if (s == null) return null;
    final moves = _yours;
    BlitzMove? find(BlitzMove m) => moves.contains(m) ? m : null;
    if (player == 0) return find(Fortify(s, index));
    // An Ace on a face-down card strikes it (better than a scout).
    return find(Strike(s, player, index)) ?? find(Scout(s, player, index));
  }

  /// A pair you could play (the picked-up card's, if it's in one).
  int? get pairRank {
    final pairs = _yours.whereType<Pair>().map((p) => p.rank).toList();
    if (pairs.isEmpty) return null;
    final s = selected;
    return s != null && pairs.contains(s.rank) ? s.rank : pairs.first;
  }

  /// A Blitz you could play: the colour (the one you have more of).
  bool? get blitzRed {
    final blitz = _yours.whereType<BlitzAttack>().toList();
    if (blitz.isEmpty) return null;
    final reds = blitz.any((b) => b.red);
    final blacks = blitz.any((b) => !b.red);
    if (reds && blacks) {
      final r = game.hands[0].where((c) => c.suit.isRed).length;
      return r >= game.hands[0].length - r;
    }
    return reds;
  }

  /// Nothing at all you can do: Pass.
  bool get mustPass => _yours.length == 1 && _yours.single is PassTurn;

  /// Nothing to hit, scout or fortify: throw a card away (pick it up, then
  /// Throw away).
  bool get mustDiscard => _yours.isNotEmpty && _yours.every((m) => m is Discard);

  void throwAway() {
    final s = selected;
    if (mustDiscard && s != null) _you(Discard(s));
  }

  void _start(int bots) {
    personas = [you, ...Persona.bots(bots, _rng)];
    game = Blitz(players: bots + 1, rng: _rng, wars: wars);
    _bots = [for (var p = 0; p <= bots; p++) p == 0 ? null : BlitzBot(difficulty: difficulty, rng: _rng)];
    selected = null;
    lastAction = null;
    lastWars = const [];
    fighting = false;
    round++;
    phase = BlitzPhase.dealing;
    Sound.deal(8);
    _after(1300, _step);
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
    fighting = false;
    if (game.isOut(0) && !game.isOver) {
      // You're out: the bots settle the rest at once (for the final order).
      while (!game.isOver) {
        final p = game.turn;
        game.apply(_bots[p]!.decide(game, p));
      }
    }
    if (game.isOver) {
      if (phase != BlitzPhase.over) Sound.play(game.winner == 0 ? Sfx.winBig : Sfx.loseBig);
      phase = BlitzPhase.over;
      _notify();
      return;
    }
    phase = BlitzPhase.playing;
    _notify();
    final p = game.turn;
    final bot = _bots[p];
    if (bot == null) return; // your turn
    _after(800 + _rng.nextInt(700), () {
      _play(bot.decide(game, p));
      // A pair or a Blitz: the same bot goes again after a beat.
      _after((game.isOver ? 900 : 1100) + _warPause, _step);
    });
  }

  void _play(BlitzMove move) {
    final before = game.events.length;
    game.apply(move);
    final fresh = game.events.sublist(before);
    lastAction = fresh.firstWhere(
      (e) =>
          e is Struck ||
          e is Scouted ||
          e is Fortified ||
          e is Paired ||
          e is Blitzed ||
          e is Passed ||
          e is Discarded,
      orElse: () => fresh.first,
    );
    lastWars = fresh.whereType<War>().toList();
    fighting = lastWars.isNotEmpty;
    _sounds(fresh);
    actionId++;
    _notify();
  }

  /// A move's sounds: the card, a hit, the war's clash, someone knocked out.
  void _sounds(List<BlitzEvent> fresh) {
    if (fresh.any((e) => e is Blitzed)) {
      Sound.play(Sfx.clash);
    } else if (fresh.any((e) => e is Struck)) {
      Sound.play(Sfx.place);
      Sound.later(Sfx.fall, 250, gain: 0.7);
    } else if (fresh.any((e) => e is Scouted || e is Fortified || e is Paired || e is Discarded)) {
      Sound.play(Sfx.place);
    }
    if (fresh.any((e) => e is Drew)) Sound.later(Sfx.deal, 300, gain: 0.6);
    // Each war: the drum as it starts, the clash, then the losers fall
    // (in step with the war scene).
    for (final (i, w) in fresh.whereType<War>().indexed) {
      final at = (2600 * i * pace).round();
      Sound.later(Sfx.tension, at);
      Sound.later(Sfx.clash, at + (470 * pace).round());
      if (w.losers.isNotEmpty) Sound.later(Sfx.fall, at + (1300 * pace).round());
    }
    if (!game.isOver && fresh.any((e) => e is Out && e.player != 0)) Sound.later(Sfx.winSmall, 400);
  }

  // --- You -----------------------------------------------------------------

  /// Picks a hand card up (or puts it back).
  void select(PlayingCard card) {
    if (!yourTurn) return;
    selected = selected == card ? null : card;
    _notify();
  }

  /// Tap a castle card: plays what the picked-up card can do there.
  void tapCastle(int player, int index) {
    final m = moveAt(player, index);
    if (m == null) return;
    _you(m);
  }

  void pair() {
    final r = pairRank;
    if (r != null) _you(Pair(r));
  }

  /// Blitz: straight at the only opponent, or pick one.
  void blitz() {
    final red = blitzRed;
    if (red == null) return;
    final targets = _yours.whereType<BlitzAttack>().where((b) => b.red == red).toList();
    if (targets.length == 1) {
      _you(targets.single);
    } else {
      phase = BlitzPhase.blitzTarget;
      selected = null;
      _notify();
    }
  }

  /// While picking: may [player] be blitzed?
  bool blitzable(int player) => phase == BlitzPhase.blitzTarget && player != 0 && !game.isOut(player);

  void blitzAt(int player) {
    if (!blitzable(player)) return;
    phase = BlitzPhase.playing;
    _you(BlitzAttack(red: blitzRed!, target: player));
  }

  void cancelBlitz() {
    if (phase != BlitzPhase.blitzTarget) return;
    phase = BlitzPhase.playing;
    _notify();
  }

  void pass() {
    if (mustPass) _you(const PassTurn());
  }

  void _you(BlitzMove m) {
    if (game.turn != 0 || game.isOver) return;
    selected = null;
    _play(m);
    _after((game.turn == 0 && !game.isOver ? 300 : 700) + _warPause, _step);
  }

  // --- Words -----------------------------------------------------------------

  String _name(int p) => p == 0 ? 'You' : personas[p].name;
  String _whose(int p) => p == 0 ? 'your' : "${personas[p].name}'s";

  static String _value(PlayingCard c) => c.rank == 14 ? 'an Ace' : 'a ${rankWord(c.rank)}';

  /// What just happened, then what you can do.
  String commentary() {
    if (phase == BlitzPhase.dealing) return 'Building the castles: 7 cards each, the top one face up.';
    if (phase == BlitzPhase.over) {
      final w = game.winner!;
      return w == 0
          ? 'Your castle is the last one standing. You win!'
          : "${personas[w].name}'s castle is the last one standing.";
    }
    if (phase == BlitzPhase.blitzTarget) {
      return 'BLITZ! Tap the castle to knock down (every face-up card goes).';
    }
    final said = _said();
    if (fighting) return said ?? 'War!';
    if (!yourTurn) {
      final p = game.turn;
      return [said, '${personas[p].name} is thinking…'].whereType<String>().join('  ·  ');
    }
    final s = selected;
    String now;
    if (mustDiscard) {
      now = s == null
          ? 'Nothing to hit or scout: pick a card to throw away.'
          : 'Throw away your ${rankWord(s.rank)}? Tap Throw away (or pick another).';
    } else if (mustPass) {
      now = "Nothing you can do this turn: tap Pass.";
    } else if (s == null) {
      final extra = [if (pairRank != null) 'Pair', if (blitzRed != null) 'BLITZ'];
      now =
          'Your turn: pick up a card to see what it can hit'
          '${extra.isEmpty ? '.' : ', or play ${extra.join(' / ')}.'}';
    } else if (s.rank == 14) {
      now = 'An Ace hits any card, even face down. Tap a glowing card.';
    } else {
      now =
          'Your ${rankWord(s.rank)}: hit a glowing ${rankWord(s.rank)} or Ace, scout a face-down card, '
          'or match your own to fortify.';
    }
    return said == null ? now : '$said  ·  $now';
  }

  /// The last action in words.
  String? _said() {
    final e = lastAction;
    if (e == null) return null;
    final who = _name(e.player);
    final war = lastWars.isEmpty
        ? ''
        : ' War over ${lastWars.map((w) => '${rankWord(w.rank)}s').join(', ')}!';
    return switch (e) {
      Struck(:final card, :final target, :final hit, :final blind) =>
        blind
            ? '$who hit a face-down card in ${_whose(target)} castle with ${_value(card)}.$war'
            : '$who knocked out ${_whose(target)} ${rankWord(hit.rank)} with ${_value(card)}.$war',
      Scouted(:final target, :final revealed) =>
        '$who scouted ${_whose(target)} castle: ${_value(revealed)}.$war',
      Fortified() => '$who fortified: +1 castle card.$war',
      Paired(:final rank) => '$who played a pair of ${rankWord(rank)}s and drew two.$war',
      Blitzed(:final target, :final knocked) =>
        '$who BLITZED ${_whose(target)} castle: $knocked card${knocked == 1 ? '' : 's'} down!$war',
      Passed() => '$who had nothing to do.',
      Discarded(:final card) => '$who had nothing to hit and threw away ${_value(card)}.',
      _ => null,
    };
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
