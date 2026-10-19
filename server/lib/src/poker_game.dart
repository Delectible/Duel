import 'dart:math';

import 'package:duel_engine/cards.dart';
import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/poker/bot.dart';
import 'package:duel_engine/poker/poker_hand.dart';
import 'package:duel_engine/poker/sit_and_go.dart';

import 'games.dart';
import 'store.dart';

/// Texas Hold'em, a Sit & Go: everyone starts with 1,500, blinds rise, last
/// one with chips wins.
///
/// The full state is a secret seed (the shuffles) and every move so far,
/// hand by hand; the table is rebuilt by replaying them through the shared
/// engine. Players see each hand's moves, the board as it's turned and the
/// hands shown down ([public]); each sees their own two cards ([private]).
/// Phones replay the same moves through the same engine.
class PokerGame extends OnlineGame {
  const PokerGame();

  @override
  String get id => 'holdem';
  @override
  int get minPlayers => 2;
  @override
  int get maxPlayers => 6;

  /// Bot looks play their own way (as against bots in the app).
  static const _styles = {
    'cap': BotStyle.rookie,
    'shades': BotStyle.rock,
    'fin': BotStyle.shark,
    'spiky': BotStyle.maniac,
  };

  @override
  Doc start(int players, Random rng, {required int first, required Set<int> humans}) => {
    'seed': rng.nextInt(1 << 31),
    'n': players,
    'button': first,
    'humans': (humans.toList()..sort()),
    'gone': <int>[],
    'hands': [<List<int>>[]],
  };

  /// The tournament rebuilt from [state]; the last hand is the one being
  /// played (or the final one).
  static PokerTable replay(Doc state) {
    final n = state['n']! as int;
    final rng = Random(state['seed']! as int);
    final g = SitAndGo(
      names: List.filled(n, ''),
      config: SitAndGoConfig.forPlayers(n),
      rng: rng,
      button: state['button']! as int,
    );
    final hands = (state['hands']! as List).cast<List<Object?>>();
    final history = <Doc>[];
    final holes = <Map<int, List<PlayingCard>>>[];
    late PokerHand h;
    for (final moves in hands) {
      h = g.startHand();
      holes.add({
        for (final (k, p) in h.players.indexed) g.handSeats[k]: [...p.hole],
      });
      for (final m in moves.cast<List<Object?>>()) {
        advance(h);
        h.apply(toMove(MoveKind.values[m[0]! as int], m[1]! as int));
      }
      advance(h);
      history.add({
        'board': [for (final c in h.board) '$c'],
        // Turned up at a showdown (or an all-in runout).
        'shown': {
          for (final k in h.result?.shown.keys ?? const <int>[])
            '${g.handSeats[k]}': [for (final c in h.players[k].hole) '$c'],
        },
      });
      if (h.result != null) g.finishHand();
    }
    return PokerTable(g, h, state, history, holes);
  }

  static Move toMove(MoveKind kind, int amount) => switch (kind) {
    MoveKind.fold => const Move.fold(),
    MoveKind.check => const Move.check(),
    MoveKind.call => const Move.call(),
    MoveKind.raise => Move.raiseTo(amount),
  };

  /// Deals streets until someone has to act or the hand is over.
  static void advance(PokerHand h) {
    while (h.result == null && h.toAct == null) {
      h.nextStreet();
    }
  }

  @override
  int? turn(Doc state) {
    final t = replay(state);
    if (t.over) return null;
    final h = t.hand;
    return h.toAct == null ? null : t.seats[h.toAct!];
  }

  @override
  Doc play(Doc state, int seat, Doc move) {
    final t = replay(state);
    if (t.over) throw const MoveError('The game is over');
    final h = t.hand;
    final i = h.toAct;
    if (i == null || t.seats[i] != seat) throw const MoveError('Not your turn');
    final legal = h.legalMoves();
    final kind = MoveKind.values.asNameMap()[move['kind']];
    // More than you have is all in.
    final amount = min(move['amount'] is int ? move['amount']! as int : 0, legal.maxRaiseTo);
    final ok = switch (kind) {
      MoveKind.fold => true,
      MoveKind.check => legal.canCheck,
      MoveKind.call => !legal.canCheck,
      MoveKind.raise => legal.canRaise && amount >= legal.minRaiseTo && amount <= legal.maxRaiseTo,
      null => false,
    };
    if (!ok) throw const MoveError("That move isn't allowed now");
    final hands = [
      for (final hand in (state['hands']! as List).cast<List<Object?>>()) [...hand.cast<List<Object?>>()],
    ];
    hands.last.add([kind!.index, kind == MoveKind.raise ? amount : 0]);
    final next = {...state, 'hands': hands};
    // Hand over and the tournament isn't: deal the next one.
    final after = replay(next);
    if (after.hand.result != null && !after.over) hands.add([]);
    return next;
  }

  @override
  Result? result(Doc state) {
    final t = replay(state);
    if (!t.over) return null;
    return Result(winner: t.winner);
  }

  @override
  Doc autoMove(Doc state, int seat, Random rng) {
    final h = replay(state).hand;
    return {'kind': h.legalMoves().canCheck ? 'check' : 'fold'};
  }

  @override
  Doc botMove(Doc state, int seat, Doc bot, Random rng) {
    final h = replay(state).hand;
    final difficulty = Difficulty.values.asNameMap()[bot['difficulty']] ?? Difficulty.normal;
    final style = _styles[bot['look']] ?? BotStyle.shark;
    final m = PokerBot(style: style, difficulty: difficulty, rng: rng).decide(h);
    return {'kind': m.kind.name, 'amount': m.amount};
  }

  @override
  Doc? leave(Doc state, int seat) => {
    ...state,
    'gone': {...(state['gone']! as List).cast<int>(), seat}.toList()..sort(),
  };

  @override
  Doc rejoin(Doc state, int seat) => {
    ...state,
    'gone': [...(state['gone']! as List).cast<int>()]..remove(seat),
  };

  @override
  Doc public(Doc state) {
    final t = replay(state);
    final hands = (state['hands']! as List).cast<List<Object?>>();
    return {
      'n': state['n'],
      'button': state['button'],
      'gone': state['gone'],
      'places': {for (final e in t.places.entries) '${e.key}': e.value},
      'simulated': t.simulated,
      'hands': [
        for (final (i, moves) in hands.indexed) {'moves': moves, ...t.history[i]},
      ],
    };
  }

  @override
  Doc? private(Doc state, int seat) {
    final t = replay(state);
    final hands = (state['hands']! as List).length;
    // This hand's cards and the last one's (a phone may still be showing it).
    return {
      'hands': {
        for (final i in [hands - 2, hands - 1])
          if (i >= 0 && t.holes[i][seat] != null) '$i': [for (final c in t.holes[i][seat]!) '$c'],
      },
    };
  }

  @override
  Duration show(Doc before, Doc after) {
    final a = (before['hands']! as List).cast<List<Object?>>();
    final b = (after['hands']! as List).cast<List<Object?>>();
    var moves = 0;
    for (var i = 0; i < b.length; i++) {
      moves += b[i].length - (i < a.length ? a[i].length : 0);
    }
    // About a second a move, a few for each new deal and showdown.
    final ms = moves * 1100 + (b.length - a.length) * 9000;
    return Duration(milliseconds: min(ms, 40000));
  }
}

/// A replayed tournament, with what was dealt (for [PokerGame.public] /
/// [PokerGame.private]).
class PokerTable {
  PokerTable(this.game, this.hand, Doc state, this.history, this.holes)
    : humans = (state['humans']! as List).cast<int>().toSet(),
      seats = [for (final p in hand.players) p.seat] {
    final gone = (state['gone']! as List).cast<int>().toSet();
    // Over when one player has every chip, or no one left at the table is
    // a person (bots don't play on alone).
    final people = game.players.where(
      (p) => humans.contains(p.seat) && !gone.contains(p.seat) && p.stack > 0,
    );
    over = game.isOver || (hand.result != null && people.isEmpty);
    places = {
      for (final p in game.players)
        if (p.place != null) p.seat: p.place!,
    };
    simulated = over && !game.isOver;
    if (simulated) {
      // Nobody left to play for: the bots don't play it out. Rank who's
      // left by their chances: the bigger the stack, the likelier to
      // finish higher (a fair draw, the same on every replay).
      final order = rankByChances({
        for (final p in game.players.where((p) => p.stack > 0)) p.seat: p.stack,
      }, Random((state['seed']! as int) ^ game.handsPlayed));
      for (final (i, seat) in order.indexed) {
        places[seat] = i + 1;
      }
    }
  }

  /// Seats best first, drawn one place at a time with odds by stack.
  static List<int> rankByChances(Map<int, int> stacks, Random rng) {
    final left = {...stacks};
    final order = <int>[];
    while (left.isNotEmpty) {
      var pick = rng.nextInt(left.values.fold(0, (a, b) => a + b));
      final seat = left.keys.firstWhere((s) => (pick -= left[s]!) < 0);
      order.add(seat);
      left.remove(seat);
    }
    return order;
  }

  /// Finishing places so far, by table seat (everyone's once it's over).
  late final Map<int, int> places;

  /// It ended with only bots left, so they were ranked rather than played.
  late final bool simulated;

  final SitAndGo game;

  /// The last hand dealt (being played, or the final one).
  final PokerHand hand;

  /// PokerTable seat of each player in [hand].
  final List<int> seats;
  final Set<int> humans;
  late final bool over;

  /// Each hand's board and shown cards.
  final List<Doc> history;

  /// Hole cards per hand, by table seat.
  final List<Map<int, List<PlayingCard>>> holes;

  /// Who won (first place).
  int get winner => places.entries.firstWhere((e) => e.value == 1).key;
}
