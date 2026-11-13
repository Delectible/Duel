import 'dart:math';

import '../cards.dart';
import '../difficulty.dart';
import '../names.dart';
import 'bot.dart';
import 'poker_hand.dart';
import 'sit_and_go.dart';

/// The cash tables, one per stake. Sit down with 50 to 100 big blinds of
/// your own pips, cash out whenever; bots get tougher as the stakes rise.
/// A table unlocks once your balance covers its full buy-in.
enum CashStake {
  kitchen('Kitchen Table', 5, 10, Difficulty.easy),
  backRoom('Back Room', 25, 50, Difficulty.normal),
  highRollers('High Rollers', 100, 200, Difficulty.hard),
  penthouse('The Penthouse', 500, 1000, Difficulty.hard);

  const CashStake(this.label, this.smallBlind, this.bigBlind, this.difficulty);

  final String label;
  final int smallBlind, bigBlind;
  final Difficulty difficulty;

  int get minBuyIn => bigBlind * 50;
  int get maxBuyIn => bigBlind * 100;

  /// Balance needed to sit here (the Kitchen Table is open to everyone).
  int get unlockAt => this == kitchen ? 0 : maxBuyIn;
}

/// Seats at a cash table.
const cashSeats = 6;

/// About how long a hand takes at a real table: how fast the bots' tables
/// move on while nobody's watching.
const cashHandMs = 30000;

/// Someone in a seat: a person (their uid) or a bot (`bot:…`).
class CashSeat {
  CashSeat({
    required this.id,
    required this.name,
    required this.stack,
    this.look,
    this.style,
    this.avatar,
    this.waiting = false,
    this.leaving = false,
    this.timeouts = 0,
    this.topUp = 0,
  });

  final String id;
  final String name;
  int stack;

  /// Bots: how they look ('cap', 'shades', 'fin', 'spiky') and play.
  final String? look;
  final String? style;

  /// People: their face (the app's avatar JSON).
  final Map<String, Object?>? avatar;

  /// Sat down mid-hand: dealt in from the next one.
  bool waiting;

  /// Standing up once the hand is over.
  bool leaving;

  /// Turns in a row that ran out (two and you're stood up).
  int timeouts;

  /// Chips added mid-hand, joining the stack after it.
  int topUp;

  bool get bot => id.startsWith('bot:');

  BotStyle get botStyle => BotStyle.values.asNameMap()[style] ?? BotStyle.shark;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'stack': stack,
    'look': ?look,
    'style': ?style,
    'avatar': ?avatar,
    if (waiting) 'waiting': true,
    if (leaving) 'leaving': true,
    if (timeouts > 0) 'timeouts': timeouts,
    if (topUp > 0) 'topUp': topUp,
  };

  static CashSeat fromJson(Map<Object?, Object?> j) => CashSeat(
    id: '${j['id']}',
    name: '${j['name'] ?? 'Player'}',
    stack: j['stack'] as int? ?? 0,
    look: j['look'] as String?,
    style: j['style'] as String?,
    avatar: (j['avatar'] as Map?)?.cast<String, Object?>(),
    waiting: j['waiting'] == true,
    leaving: j['leaving'] == true,
    timeouts: j['timeouts'] as int? ?? 0,
    topUp: j['topUp'] as int? ?? 0,
  );
}

/// One cash table between hands: who sits where with how much, where the
/// button is, and when the bots last played (they keep playing while
/// nobody's there: [simulate] catches them up).
class CashTableState {
  CashTableState({
    required this.stake,
    required this.seats,
    required this.button,
    required this.at,
    this.hands = 0,
  }) : assert(seats.length == cashSeats);

  final CashStake stake;
  final List<CashSeat?> seats;
  int button;

  /// When (ms since epoch) the table was last played up to.
  int at;
  int hands;

  /// People seated (not bots).
  Iterable<CashSeat> get people => seats.nonNulls.where((s) => !s.bot);

  int get filled => seats.nonNulls.length;

  /// A table that has been running a while: three to five bots.
  factory CashTableState.fresh(CashStake stake, Random rng, int now) {
    final t = CashTableState(stake: stake, seats: List.filled(cashSeats, null), button: 0, at: now);
    final want = 3 + rng.nextInt(3);
    final order = [for (var i = 0; i < cashSeats; i++) i]..shuffle(rng);
    for (final i in order.take(want)) {
      t.seats[i] = t.newBot(rng);
    }
    t.button = order.first;
    return t;
  }

  /// A bot sitting down with 60 to 100 big blinds.
  CashSeat newBot(Random rng) {
    final taken = {for (final s in seats.nonNulls) s.name};
    final pool = [
      for (final n in botNames)
        if (!taken.contains(n)) n,
    ];
    final name = pool[rng.nextInt(pool.length)];
    return CashSeat(
      id: 'bot:$name',
      name: name,
      stack: stake.bigBlind * (60 + rng.nextInt(41)),
      look: const ['cap', 'shades', 'fin', 'spiky'][rng.nextInt(4)],
      style: BotStyle.values[rng.nextInt(BotStyle.values.length)].name,
    );
  }

  /// Plays the bots' table forward to [now] while no person is there: a
  /// hand every [cashHandMs], each moving chips from losers to a winner,
  /// with bots coming and going, so a table looks different when you come
  /// back. (Quick sums, not real hands: nobody's watching.)
  void simulate(int now, Random rng, {int most = 150}) {
    if (people.isNotEmpty) {
      at = max(at, now);
      return;
    }
    final n = min((now - at) ~/ cashHandMs, most);
    if (n <= 0) return;
    for (var k = 0; k < n; k++) {
      _simHand(rng);
    }
    at = now;
  }

  void _simHand(Random rng) {
    final bb = stake.bigBlind;
    // Comings and goings.
    for (var i = 0; i < cashSeats; i++) {
      final s = seats[i];
      if (s != null && s.bot && rng.nextDouble() < 0.02) seats[i] = null;
    }
    for (var i = 0; i < cashSeats; i++) {
      if (seats[i] == null && filled < 5 && rng.nextDouble() < (filled < 3 ? 0.3 : 0.06)) {
        seats[i] = newBot(rng);
      }
    }
    while (filled < 2) {
      final i = seats.indexOf(null);
      seats[i] = newBot(rng);
    }
    // A hand: two to four players put chips in, one takes the pot.
    final playing = [
      for (var i = 0; i < cashSeats; i++)
        if (seats[i] != null && seats[i]!.stack > 0) i,
    ]..shuffle(rng);
    final inPot = playing.take(min(playing.length, 2 + rng.nextInt(3))).toList();
    if (inPot.length >= 2) {
      final size = bb * (1 + (pow(rng.nextDouble(), 2.5) * 40).round());
      var pot = 0;
      for (final i in inPot) {
        final put = min(seats[i]!.stack, size);
        seats[i]!.stack -= put;
        pot += put;
      }
      seats[inPot[rng.nextInt(inPot.length)]]!.stack += pot;
    }
    // Short or broke: buy back in, or leave.
    for (var i = 0; i < cashSeats; i++) {
      final s = seats[i];
      if (s == null || !s.bot || s.stack >= bb * 25) continue;
      if (rng.nextBool()) {
        s.stack = bb * (60 + rng.nextInt(41));
      } else {
        seats[i] = null;
      }
    }
    while (filled < 2) {
      seats[seats.indexOf(null)] = newBot(rng);
    }
    button = _nextFilled(button);
    hands++;
  }

  int _nextFilled(int from) {
    for (var k = 1; k <= cashSeats; k++) {
      final i = (from + k) % cashSeats;
      if (seats[i] != null) return i;
    }
    return from;
  }

  Map<String, Object?> toJson() => {
    'stake': stake.name,
    'seats': [for (final s in seats) s?.toJson()],
    'button': button,
    'at': at,
    'hands': hands,
  };

  static CashTableState fromJson(Map<Object?, Object?> j) => CashTableState(
    stake: CashStake.values.asNameMap()[j['stake']] ?? CashStake.kitchen,
    seats: [
      for (final s in (j['seats'] as List?) ?? List.filled(cashSeats, null))
        s is Map ? CashSeat.fromJson(s) : null,
    ],
    button: j['button'] as int? ?? 0,
    at: j['at'] as int? ?? 0,
    hands: j['hands'] as int? ?? 0,
  );
}

/// A cash table as the hand engine sees it: six seats (empty ones have no
/// chips and sit out), fixed blinds, and nobody ever "finishes": broke
/// players are dealt out until they buy back in or leave.
class CashGame extends SitAndGo {
  CashGame({required this.stake, required super.rng, required int button})
    : super(
        names: List.filled(cashSeats, ''),
        config: const SitAndGoConfig(startingStack: 0, handsPerLevel: 1 << 30),
        button: button,
      ) {
    for (final p in players) {
      p.empty = true;
    }
  }

  final CashStake stake;

  @override
  (int, int) get blinds => (stake.smallBlind, stake.bigBlind);

  @override
  int get level => 0;

  @override
  int? get handsToNextLevel => null;

  @override
  (int, int)? get nextBlinds => null;

  @override
  bool get isOver => false;

  /// Enough players with chips to deal a hand.
  bool get canDeal => active.length >= 2;

  /// [name] sits at [seat] with [stack].
  void sit(int seat, String name, int stack) =>
      players[seat] = TablePlayer(seat: seat, name: name, stack: stack);

  void clear(int seat) => players[seat] = TablePlayer(seat: seat, name: '', stack: 0)..empty = true;

  @override
  List<int> finishHand() {
    final h = hand;
    if (h == null || h.result == null) throw StateError('Hand not finished');
    for (final hp in h.players) {
      players[hp.seat].stack = hp.stack;
    }
    handsPlayed++;
    hand = null;
    return [
      for (final hp in h.players)
        if (hp.stack == 0) hp.seat,
    ];
  }

  @override
  PokerHand startHand({Deck? deck}) {
    if (!canDeal) throw StateError('Not enough players');
    return super.startHand(deck: deck);
  }
}
