import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:duel_engine/cards.dart';
import 'package:duel_engine/difficulty.dart';
import '../../../core/theme/toon.dart';
import 'package:duel_engine/poker/bot.dart';
import 'package:duel_engine/poker/hand_eval.dart';
import 'package:duel_engine/poker/odds.dart';
import 'package:duel_engine/poker/poker_hand.dart';
import 'package:duel_engine/poker/reads.dart';
import 'package:duel_engine/poker/sit_and_go.dart';
import '../../../core/avatars/faces.dart';
import '../../../core/online/party.dart';
import 'table_talk.dart';
import '../../../core/sound/sound.dart';

part 'online_poker.dart';

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
  PokerController({
    required int bots,
    required this.difficulty,
    Random? rng,
    this.pace = 1,
    this.you = const Persona.you(),
    this.resultTimeout,
  }) : _rng = rng ?? Random(),
       assert(bots >= 1 && bots <= 5) {
    personas = [you, ...Persona.bots(bots, _rng)];
    game = SitAndGo(
      names: [for (final p in personas) p.name],
      config: SitAndGoConfig.forPlayers(bots + 1),
      rng: _rng,
    );
    reads = TableReads(personas.length);
    // Each bot plays its own hidden way (no two alike): you work it out.
    final deck = [...BotStyle.values]..shuffle(_rng);
    _styles = [for (var i = 0; i <= bots; i++) i == 0 ? null : deck[(i - 1) % deck.length]];
    _bots = [
      for (final s in _styles) s == null ? null : PokerBot(style: s, difficulty: difficulty, rng: _rng),
    ];
  }

  /// A table set up elsewhere (online: the server's seats, you at 0).
  PokerController._seated({
    required this.difficulty,
    required this.you,
    required List<Persona> seats,
    required int button,
    this.pace = 1,
    this.resultTimeout,
  }) : _rng = Random() {
    personas = seats;
    game = SitAndGo(
      names: [for (final p in personas) p.name],
      config: SitAndGoConfig.forPlayers(seats.length),
      rng: _rng,
      button: button,
    );
    _bots = List.filled(seats.length, null);
    _styles = List.filled(seats.length, null);
    reads = TableReads(seats.length);
  }

  final Difficulty difficulty;

  /// Your face and name at the table.
  final Persona you;

  /// How long a showdown result waits for Next hand before moving on by
  /// itself: null (bot games) waits for you; online games use 10 seconds so
  /// one player can't hold up the table.
  final Duration? resultTimeout;

  /// Time between cards going out in the deal (milliseconds).
  static const dealGap = 90;

  /// Multiplies every delay (0 in tests).
  final double pace;
  final Random _rng;

  late final List<Persona> personas;
  late final SitAndGo game;
  late final List<PokerBot?> _bots;

  /// How each bot plays, by seat (null: a person). Hidden until the game's
  /// over (online: the server tells once it is).
  List<BotStyle?> get styles => _styles;
  late final List<BotStyle?> _styles;

  /// What the table has seen everyone do (read cards, the hand history,
  /// the summary; the bots study it too).
  late final TableReads reads;

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

  /// The showdown result is up and waits for [nextHand].
  bool waitingForYou = false;

  /// The hand's over and you may turn your cards up (you lost a showdown,
  /// or everyone folded to you); until you do, they're mucked.
  bool canShowCards = false;

  /// You turned them up this hand.
  bool showedCards = false;

  /// You lost a showdown and kept your cards down.
  bool get youMucked => canShowCards && !showedCards && (hand?.result?.showdown ?? false);

  /// Seconds left before the result moves on by itself (timeout only).
  int? secondsLeft;
  Timer? _countdown;

  /// Blind level the last "Blinds up!" was shown for.
  var _shownLevel = 0;

  Timer? _timer;
  var _disposed = false;

  /// What bots are saying right now: seat -> (words, an id per line so
  /// each pops in once).
  final Map<int, ({String text, int id})> talk = {};
  var _talkId = 0;
  final _talkTimers = <int, Timer>{};

  /// All in with cards face up: each contender's chance to win, by seat.
  Map<int, double> odds = const {};

  /// A pot big enough to celebrate: the headline ("BIG WIN!") and who won.
  String? bigWin;
  int? bigWinSeat;

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

  /// Everyone, best first: places for those out, the rest (still
  /// playing) by their chips.
  List<({int place, Persona who, bool you})> get lineup {
    final out = [
      for (final p in game.players)
        if (p.place != null) (place: p.place!, who: personas[p.seat], you: p.seat == 0),
    ];
    final inPlay = [...game.players.where((p) => p.place == null)]
      ..sort((a, b) => b.stack.compareTo(a.stack));
    return [
      for (final (k, p) in inPlay.indexed) (place: k + 1, who: personas[p.seat], you: p.seat == 0),
      ...out..sort((a, b) => a.place.compareTo(b.place)),
    ];
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

  // --- Hooks (the online table answers these from the server) -------------

  /// The button's come round to you: you shuffle and deal.
  bool get _youDeal => game.nextButtonSeat == 0;

  /// The deck for the next hand (null: shuffled here).
  Deck? _nextDeck() => null;

  /// The cards for the next hand are known.
  bool _canDeal() => true;

  /// Just dealt [h] (online: put your real cards in).
  void _dealt(PokerHand h) {}

  /// The next street's cards (or the showdown) are known.
  bool _canAdvance(PokerHand h) => true;

  /// About to deal a street or show down (online: turn up shown cards).
  void _beforeAdvance(PokerHand h) {}

  /// [seat] is to act: a bot thinks and moves; you get the buttons.
  void _actFor(int seat, PokerHand h) {
    final bot = _bots[seat];
    if (bot == null) {
      hurrying = false; // your move: the bots wait for you again
      Sound.play(Sfx.yourTurn, gain: 0.7);
      return;
    }
    final decision = bot.think(h, reads: reads, seats: game.handSeats);
    _botMove = () {
      _botMove = null;
      final youBet = _youAreAggressor(h);
      _play(h, decision.move);
      _talkAbout(seat, h, youBet: youBet);
      _afterMove();
    };
    _after(hurrying ? 250 + _rng.nextInt(200) : thinkTime(decision.tempo), _botMove!);
  }

  /// A bot's thinking time from its tempo (0 snap .. 1 tank): 2 to 10
  /// seconds. Some bots' timing gives their hand away; others' doesn't.
  static int thinkTime(double tempo) => 2000 + (8000 * pow(tempo.clamp(0.0, 1.0), 1.8)).round();

  /// Plays [m] in [h], the table noting it down first.
  void _play(PokerHand h, Move m) {
    reads.observe(h, game.handSeats, m);
    final before = h.pot;
    h.apply(m);
    // Chips going in (a bet, call or raise).
    if (h.pot > before) Sound.play(Sfx.chips, gain: m.kind == MoveKind.raise ? 1 : 0.7);
  }

  /// You made the last bet or raise this street.
  bool _youAreAggressor(PokerHand h) {
    final me = handPlayer(0);
    final label = me?.lastAction?.label;
    return me != null &&
        h.currentBet > 0 &&
        me.bet == h.currentBet &&
        (label == ActionLabel.bet || label == ActionLabel.raise || label == ActionLabel.allIn);
  }

  /// A bot's move might get a word in.
  void _talkAbout(int seat, PokerHand h, {required bool youBet}) {
    final p = handPlayer(seat);
    final label = p?.lastAction?.label;
    if (p == null || label == null) return;
    switch (label) {
      case ActionLabel.allIn:
        _say(seat, Talk.allIn, chance: 0.6);
      case ActionLabel.bet || ActionLabel.raise when p.bet >= h.bigBlind * 6:
        _say(seat, Talk.bigRaise, chance: 0.3);
      case ActionLabel.fold when youBet:
        _say(seat, Talk.fold, chance: 0.35);
      default:
    }
  }

  /// [seat] (a bot) says something in its own voice, now and then, and
  /// never more than two at once.
  void _say(int seat, Talk what, {double chance = 1}) {
    final bot = _bots[seat];
    if (bot == null || _rng.nextDouble() > chance) return;
    if (talk.length >= 2 && !talk.containsKey(seat)) return;
    talk[seat] = (text: talkLine(bot.style, what, _rng), id: ++_talkId);
    _talkTimers[seat]?.cancel();
    _talkTimers[seat] = Timer(Duration(milliseconds: (3200 * pace).round()), () {
      if (_disposed) return;
      talk.remove(seat);
      _notify();
    });
    _notify();
  }

  /// Everyone still in shows their cards: their chances to win.
  void _updateOdds(PokerHand h) {
    final inHand = [
      for (var i = 0; i < h.players.length; i++)
        if (!h.players[i].folded) i,
    ];
    if (inHand.length < 2 || inHand.any((i) => !revealed.contains(game.handSeats[i]))) return;
    final chances = winChances(
      [for (final i in inHand) h.players[i].hole],
      h.board,
      rng: _rng,
      simulations: 600,
    );
    odds = {for (final (k, i) in inHand.indexed) game.handSeats[i]: chances[k]};
  }

  /// The skip button: bots play quickly until it's your move again (or the
  /// next hand).
  bool hurrying = false;
  VoidCallback? _botMove;

  /// A bot is thinking and can be hurried along.
  bool get canHurry => phase == TablePhase.acting && _botMove != null && !hurrying;

  void hurry() {
    if (!canHurry) return;
    hurrying = true;
    _after(150, _botMove!);
    _notify();
  }

  /// Seconds left for whoever is acting (online), or null.
  int? get turnSecondsLeft => null;

  /// Waiting for something to arrive before [_parked] can go on.
  VoidCallback? _parked;

  void _park(VoidCallback f) {
    _parked = f;
    _notify();
  }

  void _newHand() {
    revealed.clear();
    canShowCards = showedCards = false;
    if (_youDeal) {
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
    Sound.play(Sfx.shuffle);
    _notify();
  }

  /// Deals after you've shuffled at least once.
  void deal() {
    if (phase != TablePhase.shuffle || shuffles == 0) return;
    _deal();
  }

  void _deal() {
    if (!_canDeal()) return _park(_deal);
    _parked = null;
    hurrying = false;
    odds = const {};
    bigWin = null;
    bigWinSeat = null;
    final h = game.startHand(deck: _nextDeck());
    _dealt(h);
    reads.startHand(h, game.handSeats);
    handNumber++;
    justBusted = const [];
    final (sb, bb) = game.blinds;
    banner = game.level > _shownLevel ? 'Blinds up! ${chips(sb)} / ${chips(bb)}' : null;
    _shownLevel = game.level;
    phase = TablePhase.dealing;
    _notify();
    // A card sound for each card as it goes round.
    for (var k = 0; k < hand!.players.length * 2; k++) {
      Sound.later(Sfx.deal, ((500 + k * dealGap) * pace).round(), gain: 0.8);
    }
    // Wait for the cards to go round (two each) before anyone acts.
    _after(500 + hand!.players.length * 2 * dealGap + 350, _step);
  }

  void _step() {
    final h = hand!;
    if (h.result != null) {
      _payout();
      return;
    }
    if (h.toAct == null) {
      // Betting round over: collect, then the next street.
      if (!_canAdvance(h)) return _park(_step);
      _parked = null;
      _beforeAdvance(h);
      if (h.isAllInRunout) {
        // Everyone's cards come up: the tension sting, once.
        if (odds.isEmpty) Sound.play(Sfx.tension);
        for (var i = 0; i < h.players.length; i++) {
          if (!h.players[i].folded) revealed.add(game.handSeats[i]);
        }
        _updateOdds(h);
      }
      phase = TablePhase.collecting;
      Sound.play(Sfx.collect, gain: 0.8);
      _notify();
      _after(450, () {
        h.nextStreet();
        if (h.result == null) Sound.play(Sfx.place);
        if (h.result != null) {
          _payout();
          return;
        }
        phase = TablePhase.dealing;
        // All in: each card turned slowly, the chances updating.
        if (h.isAllInRunout) _updateOdds(h);
        _notify();
        _after(h.isAllInRunout ? 2300 : 550, _step);
      });
      return;
    }
    phase = TablePhase.acting;
    _parked = null;
    _notify();
    _actFor(game.handSeats[h.toAct!], h);
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
    _play(hand!, move);
    _afterMove();
  }

  void _payout() {
    final h = hand!;
    final r = h.result!;
    final mucked = _mucked(h);
    for (final i in r.shown.keys) {
      if (!mucked.contains(i)) revealed.add(game.handSeats[i]);
    }
    phase = TablePhase.payout;
    reads.endHand(h, game.handSeats, number: handNumber, mucked: mucked);
    final me = handIndex(0);
    canShowCards = me != null && (h.muckable.contains(me) || h.showable == me);
    _celebrate(h, r);
    _payoutSound(h, r);
    odds = const {};
    if (!r.showdown) {
      // Everyone else folded: nothing to read, move on (a moment longer
      // if it's yours, to show your cards if you like).
      _notify();
      _after(canShowCards ? 3500 : 1500, _endHand);
      return;
    }
    // Who won and with what: wait until you've read it (Next hand).
    waitingForYou = true;
    final timeout = resultTimeout;
    if (timeout != null) {
      secondsLeft = timeout.inSeconds;
      _countdown = Timer.periodic(Duration(milliseconds: (1000 * pace).round().clamp(1, 1000)), (t) {
        if (_disposed) return;
        secondsLeft = secondsLeft! - 1;
        if (secondsLeft! <= 0) {
          nextHand();
        } else {
          _notify();
        }
      });
    }
    _notify();
  }

  /// Chips to the winner, and how it went for you: a small or medium win
  /// (a big pot), a small or medium loss at a showdown.
  void _payoutSound(PokerHand h, HandResult r) {
    Sound.play(Sfx.pot);
    final i = handIndex(0);
    if (i == null) return;
    final big = bigWin != null;
    if ((r.winnings[i] ?? 0) > 0) {
      Sound.later(big ? Sfx.winMedium : Sfx.winSmall, 250);
    } else if (r.showdown && r.shown.containsKey(i)) {
      Sound.later(big ? Sfx.loseMedium : Sfx.loseSmall, 250);
    }
  }

  /// A big pot gets a splash, and the bots have their say.
  void _celebrate(PokerHand h, HandResult r) {
    final total = r.pots.fold(0, (s, p) => s + p.amount);
    final inPlay = game.players.fold(0, (s, p) => s + p.stack) + h.pot;
    final big = total >= max(h.bigBlind * 20, inPlay * 0.3);
    final main = r.pots.first;
    final winners = [for (final w in main.winners) game.handSeats[w]];
    if (big && winners.length == 1) {
      bigWinSeat = winners.single;
      bigWin = bigWinSeat == 0 ? 'BIG WIN!' : 'HUGE POT!';
    }
    if (!r.showdown) {
      for (final w in winners) {
        _say(w, Talk.winSmall, chance: 0.15);
      }
      return;
    }
    for (final w in winners) {
      final chance = odds[w];
      if (chance != null && chance < 0.4) {
        _say(w, Talk.lucky, chance: 0.9);
      } else {
        _say(w, big ? Talk.winBig : Talk.winSmall, chance: big ? 0.7 : 0.3);
      }
    }
    final losers = [
      for (final i in r.shown.keys)
        if (!main.winners.contains(i) && game.handSeats[i] != 0) game.handSeats[i],
    ];
    if (big && losers.isNotEmpty) {
      if (winners.contains(0)) {
        _say(losers[_rng.nextInt(losers.length)], Talk.niceHand, chance: 0.75);
      } else {
        _say(losers.first, Talk.lose, chance: 0.5);
      }
    }
  }

  /// Hands that lost a showdown and stay face down (offline: yours, unless
  /// you show them; bots always show).
  Set<int> _mucked(PokerHand h) => {if (handIndex(0) case final i? when h.muckable.contains(i)) i};

  /// Turns your cards up for the table after the hand. The bots remember
  /// what you had (a shown bluff makes them call you lighter).
  void showCards() {
    final h = hand;
    final i = handIndex(0);
    if (!canShowCards || showedCards || h == null || i == null || phase != TablePhase.payout) return;
    showedCards = true;
    revealed.add(0);
    reads.reveal(h, game.handSeats, i);
    _shown(i);
    // A bluff shown off gets a reaction from someone it worked on.
    final r = h.result!;
    if (!r.showdown && i == h.showable && h.players[i].hole.length == 2) {
      final weak = h.board.length >= 3
          ? evaluateHand([...h.players[i].hole, ...h.board]).category == HandCategory.highCard
          : h.players[i].hole[0].rank != h.players[i].hole[1].rank &&
                max(h.players[i].hole[0].rank, h.players[i].hole[1].rank) < 12;
      final folders = [
        for (final (k, p) in h.players.indexed)
          if (k != i && p.folded && _bots[game.handSeats[k]] != null) game.handSeats[k],
      ];
      if (folders.isNotEmpty) {
        _say(folders[_rng.nextInt(folders.length)], weak ? Talk.bluffed : Talk.shownStrong, chance: 0.8);
      }
    }
    _notify();
  }

  /// Online: tells the server you showed.
  void _shown(int i) {}

  /// Keep them down: with everyone folded to you, straight on to the next
  /// hand.
  void muckCards() {
    final r = hand?.result;
    if (!canShowCards || showedCards || r == null || r.showdown || phase != TablePhase.payout) return;
    canShowCards = false;
    _timer?.cancel();
    _endHand();
  }

  /// You've read the result: on to the next hand.
  void nextHand() {
    if (!waitingForYou) return;
    waitingForYou = false;
    secondsLeft = null;
    _countdown?.cancel();
    _endHand();
  }

  /// A hand's chips are settled (online: on to the next hand's moves).
  void _handEnded() {}

  void _endHand() {
    justBusted = game.finishHand();
    for (final seat in justBusted) {
      _say(seat, Talk.bust, chance: 0.8);
    }
    _handEnded();
    if (game.isOver || game.players[0].stack == 0) {
      // The tournament: the big win, or the big loss.
      Sound.play(yourPlace == 1 ? Sfx.winBig : Sfx.loseBig);
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
      final names = pot.winners
          .map((i) => game.handSeats[i] == 0 ? 'You' : personas[game.handSeats[i]].name)
          .toList();
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
    _countdown?.cancel();
    for (final t in _talkTimers.values) {
      t.cancel();
    }
    super.dispose();
  }
}
