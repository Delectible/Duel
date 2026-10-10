import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/cards/cards.dart';
import '../../../core/session/difficulty.dart';
import '../../../core/theme/toon.dart';
import '../engine/bot.dart';
import '../engine/hand_eval.dart';
import '../engine/poker_hand.dart';
import '../engine/sit_and_go.dart';
import 'faces.dart';

enum TablePhase {
  /// Your deal: shuffle the deck, then tap Deal.
  shuffle,

  /// Cards going out (new hand or new street).
  dealing,

  /// Someone is deciding.
  acting,

  /// Bets sliding into the pot.
  collecting,

  /// Pots flying to the winners.
  payout,

  /// Your tournament is over (won or busted).
  finished,
}

/// Runs a Sit & Go against bots for the table screen: deals, paces the
/// bots, waits for you, settles hands. Seat 0 is you.
class PokerController extends ChangeNotifier {
  PokerController({required int bots, required this.difficulty, Random? rng, this.pace = 1})
    : _rng = rng ?? Random(),
      assert(bots >= 1 && bots <= 5) {
    personas = [const Persona.you(), ...Persona.bots(bots, _rng)];
    game = SitAndGo(
      names: [for (final p in personas) p.name],
      config: SitAndGoConfig.forPlayers(bots + 1),
      rng: _rng,
    );
    _bots = [
      for (final p in personas)
        p.style == null ? null : PokerBot(style: p.style!, difficulty: difficulty, rng: _rng),
    ];
  }

  final Difficulty difficulty;

  /// Multiplies every delay (0 in tests).
  final double pace;
  final Random _rng;

  late final List<Persona> personas;
  late final SitAndGo game;
  late final List<PokerBot?> _bots;

  TablePhase phase = TablePhase.dealing;

  /// Hands dealt this tournament, for keys that restart deal animations.
  int handNumber = 0;

  /// Table seats whose cards are face up (showdown, all-in runout).
  final Set<int> revealed = {};

  /// A one-hand notice: "Blinds up!".
  String? banner;

  /// Seats that busted in the last hand.
  List<int> justBusted = const [];

  /// Times you've shuffled the deck this deal.
  int shuffles = 0;

  /// Blind level the last "Blinds up!" was shown for.
  var _shownLevel = 0;

  Timer? _timer;
  var _disposed = false;

  PokerHand? get hand => game.hand;

  /// Index of [seat] in the current hand, or null if not in it.
  int? handIndex(int seat) {
    final i = game.handSeats.indexOf(seat);
    return hand == null || i < 0 ? null : i;
  }

  HandPlayer? handPlayer(int seat) {
    final i = handIndex(seat);
    return i == null ? null : hand!.players[i];
  }

  int? get actingSeat {
    final i = hand?.toAct;
    return i == null || phase != TablePhase.acting ? null : game.handSeats[i];
  }

  bool get yourTurn => actingSeat == 0;

  bool get youAreIn {
    final me = handPlayer(0);
    return me != null && !me.folded;
  }

  /// Your place when your tournament is over.
  int? get yourPlace => game.players[0].place;

  void start() => _newHand();

  void _after(int ms, VoidCallback f) {
    _timer?.cancel();
    final d = Duration(milliseconds: (ms * pace).round());
    _timer = Timer(d, () {
      if (!_disposed) f();
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _newHand() {
    revealed.clear();
    if (game.nextButtonSeat == 0) {
      // The button's come round to you: you shuffle and deal.
      shuffles = 0;
      phase = TablePhase.shuffle;
      _notify();
      return;
    }
    _deal();
  }

  /// One riffle of the deck (your deal).
  void shuffleDeck() {
    if (phase != TablePhase.shuffle) return;
    shuffles++;
    _notify();
  }

  /// Deals after you've shuffled at least once.
  void deal() {
    if (phase != TablePhase.shuffle || shuffles == 0) return;
    _deal();
  }

  void _deal() {
    game.startHand();
    handNumber++;
    justBusted = const [];
    final (sb, bb) = game.blinds;
    banner = game.level > _shownLevel ? 'Blinds up! ${chips(sb)} / ${chips(bb)}' : null;
    _shownLevel = game.level;
    phase = TablePhase.dealing;
    _notify();
    _after(900, _step);
  }

  void _step() {
    final h = hand!;
    if (h.result != null) {
      _payout();
      return;
    }
    if (h.toAct == null) {
      // Betting round over: collect, then the next street.
      if (h.isAllInRunout) {
        for (var i = 0; i < h.players.length; i++) {
          if (!h.players[i].folded) revealed.add(game.handSeats[i]);
        }
      }
      phase = TablePhase.collecting;
      _notify();
      _after(450, () {
        h.nextStreet();
        if (h.result != null) {
          _payout();
          return;
        }
        phase = TablePhase.dealing;
        _notify();
        _after(h.isAllInRunout ? 1100 : 550, _step);
      });
      return;
    }
    phase = TablePhase.acting;
    _notify();
    final seat = game.handSeats[h.toAct!];
    final bot = _bots[seat];
    if (bot == null) return; // your move
    // Bots take their time while you're in the hand; once you've folded
    // they hurry up.
    final think = youAreIn ? 650 + _rng.nextInt(800) : 300 + _rng.nextInt(200);
    _after(think, () {
      h.apply(bot.decide(h));
      _afterMove();
    });
  }

  void _afterMove() {
    final h = hand!;
    if (h.result != null) {
      // Everyone else folded: sweep the bets in first.
      phase = TablePhase.collecting;
      _notify();
      _after(450, _payout);
    } else {
      _step();
    }
  }

  /// Your move. Only while [yourTurn].
  void act(Move move) {
    if (!yourTurn) return;
    hand!.apply(move);
    _afterMove();
  }

  void _payout() {
    final r = hand!.result!;
    for (final i in r.shown.keys) {
      revealed.add(game.handSeats[i]);
    }
    phase = TablePhase.payout;
    _notify();
    _after(r.showdown ? 3200 : 1500, _endHand);
  }

  void _endHand() {
    justBusted = game.finishHand();
    if (game.isOver || game.players[0].stack == 0) {
      phase = TablePhase.finished;
      _notify();
      return;
    }
    _newHand();
  }

  /// What the pot's winners get told: "Finn wins 1,240 with Two pair".
  List<String> resultLines() {
    final h = hand;
    final r = h?.result;
    if (h == null || r == null) return const [];
    final lines = <String>[];
    for (final (k, pot) in r.pots.indexed) {
      // A side pot only one player is in is an uncalled bet coming back.
      if (k > 0 && pot.eligible.length == 1) continue;
      final names = pot.winners.map((i) => personas[game.handSeats[i]].name).toList();
      final who = names.length == 1
          ? names.first
          : '${names.sublist(0, names.length - 1).join(', ')} & ${names.last}';
      final wins = names.length == 1 ? (names.first == 'You' ? 'win' : 'wins') : 'split';
      final what = k == 0 ? '' : ' (side pot)';
      final how = pot.hand == null ? '' : ' with ${pot.hand!.describe()}';
      lines.add('$who $wins ${chips(pot.amount)}$what$how');
    }
    return lines;
  }

  /// The winning five cards of the main pot at a showdown.
  Set<PlayingCard> winningCards() {
    final hand = this.hand?.result?.pots.first.hand;
    return hand == null ? const {} : hand.cards.toSet();
  }

  /// Your hand for the cheat sheet: its rank and the cards that make it
  /// (your best five, or just your two cards before the flop).
  ({HandCategory category, bool royal, List<PlayingCard> cards})? yourHand() {
    final me = handPlayer(0);
    final h = hand;
    if (me == null || h == null || me.hole.length < 2) return null;
    if (h.board.length >= 3) {
      final v = evaluateHand([...me.hole, ...h.board]);
      final royal = v.category == HandCategory.straightFlush && v.ranks.first == 14;
      return (category: v.category, royal: royal, cards: v.cards);
    }
    final pair = me.hole[0].rank == me.hole[1].rank;
    return (category: pair ? HandCategory.pair : HandCategory.highCard, royal: false, cards: me.hole);
  }

  /// Your hand in words: "Pocket Jacks", "Two pair, Kings and Sevens".
  String? yourHandName() {
    final me = handPlayer(0);
    final h = hand;
    if (me == null || h == null || me.hole.length < 2) return null;
    if (h.board.length >= 3) return evaluateHand([...me.hole, ...h.board]).describe();
    final a = me.hole[0], b = me.hole[1];
    if (a.rank == b.rank) return 'Pocket ${rankPlural(a.rank)}';
    final hi = max(a.rank, b.rank), lo = min(a.rank, b.rank);
    return '${rankName(hi)}-${rankName(lo)}${a.suit == b.suit ? ' suited' : ''}';
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
