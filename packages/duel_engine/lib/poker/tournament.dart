import 'dart:math';

import 'bot.dart';
import 'poker_hand.dart';
import 'reads.dart';
import 'sit_and_go.dart';

/// Three tables of six: you and 17 bots.
const tournamentTables = 3, tournamentSeats = 6, tournamentPlayers = tournamentTables * tournamentSeats;

/// One player in a tournament: where they sit and their chips. [style]
/// null is you.
class Entrant {
  Entrant({
    required this.name,
    required this.look,
    required this.style,
    required this.stack,
    required this.table,
    required this.seat,
    this.place,
  }) : startStack = stack;

  final String name;

  /// Their face's look (a [Look] name in the app).
  final String look;

  /// How they play (a [BotStyle] name); null for you.
  final String? style;

  int stack;
  int table;
  int seat;

  /// Their chips when this round began (who busts first finishes lower).
  int startStack;

  /// Finishing place once out (1 for the winner).
  int? place;

  bool get you => style == null;

  /// Still has chips.
  bool get live => stack > 0;

  BotStyle get botStyle => BotStyle.values.asNameMap()[style] ?? BotStyle.shark;

  Map<String, Object?> toJson() => {
    'n': name,
    'l': look,
    'st': style,
    's': stack,
    't': table,
    'seat': seat,
    'ss': startStack,
    'p': place,
  };

  static Entrant fromJson(Map<String, Object?> j) => Entrant(
    name: j['n']! as String,
    look: j['l']! as String,
    style: j['st'] as String?,
    stack: j['s']! as int,
    table: j['t']! as int,
    seat: j['seat']! as int,
    place: j['p'] as int?,
  )..startStack = j['ss'] as int? ?? j['s']! as int;
}

/// Someone moved table between hands (a table broke up, or the tables
/// were evened out).
typedef TableMove = ({Entrant who, int from, int to});

/// A multi-table tournament: everyone starts with the same stack, the
/// blinds go up together at every table, and as players go out tables
/// break up and the rest are moved to keep them even, until the last six
/// meet at one table. You never move: everyone comes to you.
///
/// Each round every table deals one hand: yours is played at the table
/// (the app), the others straight through here ([playHand]). Then
/// [endRound] places who went out and [balance] moves players.
class Tournament {
  Tournament._(this.entrants, this.buttons, this.round);

  /// You and [bots] (17: name, look, style) seated at random.
  factory Tournament.fresh({
    required String you,
    required String yourLook,
    required List<({String name, String look, String style})> bots,
    required Random rng,
  }) {
    assert(bots.length == tournamentPlayers - 1);
    final spots = [
      for (var t = 0; t < tournamentTables; t++)
        for (var s = 0; s < tournamentSeats; s++) (t, s),
    ]..shuffle(rng);
    final people = [(name: you, look: yourLook, style: null as String?), ...bots];
    return Tournament._(
      [
        for (final (k, p) in people.indexed)
          Entrant(
            name: p.name,
            look: p.look,
            style: p.style,
            stack: startingStack,
            table: spots[k].$1,
            seat: spots[k].$2,
          ),
      ],
      [for (var t = 0; t < tournamentTables; t++) rng.nextInt(tournamentSeats)],
      0,
    );
  }

  static const startingStack = 1500;

  /// The blinds go up every six rounds (about 20–30 minutes in all).
  static const handsPerLevel = 6;

  /// Shares of the prize pool for 1st, 2nd and 3rd.
  static const paid = [0.5, 0.3, 0.2];

  /// What [place] wins from a [pool].
  static int prize(int pool, int place) =>
      place >= 1 && place <= paid.length ? (pool * paid[place - 1]).round() : 0;

  final List<Entrant> entrants;

  /// Each table's button seat.
  final List<int> buttons;

  /// Rounds played (each table one hand).
  int round;

  int get level => min(round ~/ handsPerLevel, blindLevels.length - 1);
  (int, int) get blinds => blindLevels[level];
  int? get handsToNextLevel => level >= blindLevels.length - 1 ? null : handsPerLevel - round % handsPerLevel;
  (int, int)? get nextBlinds => level >= blindLevels.length - 1 ? null : blindLevels[level + 1];

  Entrant get you => entrants.firstWhere((e) => e.you);

  /// Players still in.
  int get left => entrants.where((e) => e.live).length;

  bool get over => left <= 1;

  /// Who's sitting at [table], seat [seat] (null: empty).
  Entrant? at(int table, int seat) =>
      entrants.where((e) => e.live && e.table == table && e.seat == seat).firstOrNull;

  List<Entrant> playersAt(int table) => entrants.where((e) => e.live && e.table == table).toList();

  /// Tables with anyone at them.
  List<int> get tables => [
    for (var t = 0; t < tournamentTables; t++)
      if (entrants.any((e) => e.live && e.table == t)) t,
  ];

  /// Everyone, best first: those still in by chips, then by place.
  List<Entrant> get standings => [
    ...entrants.where((e) => e.live).toList()..sort((a, b) => b.stack.compareTo(a.stack)),
    ...entrants.where((e) => !e.live).toList()..sort((a, b) => (a.place ?? 99).compareTo(b.place ?? 99)),
  ];

  /// Plays one hand at [table] straight through (bots only), moving its
  /// button first.
  void playHand(int table, PokerBot Function(Entrant e) botFor, Random rng) {
    final seated = [
      for (var s = 0; s < tournamentSeats; s++)
        if (at(table, s) != null) s,
    ];
    if (seated.length < 2) return;
    final who = {for (final s in seated) s: at(table, s)!};
    var b = buttons[table];
    for (var k = 1; k <= tournamentSeats; k++) {
      final s = (b + k) % tournamentSeats;
      if (who.containsKey(s)) {
        b = s;
        break;
      }
    }
    buttons[table] = b;
    final (sb, bb) = blinds;
    final h = PokerHand(
      players: [for (final s in seated) HandPlayer(seat: s, stack: who[s]!.stack)],
      button: seated.indexOf(b),
      smallBlind: sb,
      bigBlind: bb,
      rng: rng,
    );
    final bots = {for (final s in seated) s: botFor(who[s]!)};
    final reads = TableReads(tournamentSeats)..startHand(h, seated);
    while (h.result == null) {
      final i = h.toAct;
      if (i == null) {
        h.nextStreet();
        continue;
      }
      final m = bots[seated[i]]!.decide(h, reads: reads, seats: seated);
      reads.observe(h, seated, m);
      h.apply(m);
    }
    for (final p in h.players) {
      who[p.seat]!.stack = p.stack;
    }
  }

  /// The round's over: who went out is placed (whoever began it with
  /// fewer chips finishes lower), the last one standing wins. Returns who
  /// went out.
  List<Entrant> endRound() {
    final out = entrants.where((e) => !e.live && e.place == null).toList()
      ..sort((a, b) => a.startStack.compareTo(b.startStack));
    var place = entrants.where((e) => e.place == null).length;
    for (final e in out) {
      e.place = place--;
    }
    round++;
    if (left == 1) entrants.firstWhere((e) => e.live).place = 1;
    for (final e in entrants) {
      if (e.live) e.startStack = e.stack;
    }
    return out;
  }

  /// Moves players between tables: a table breaks up once the rest fit at
  /// one fewer (or it's down to one player), and tables are kept within
  /// one player of each other. Yours never breaks and you never move.
  List<TableMove> balance(Random rng) {
    final moves = <TableMove>[];
    final home = you.live ? you.table : null;
    int count(int t) => playersAt(t).length;
    List<int> open(int t) => [
      for (var s = 0; s < tournamentSeats; s++)
        if (at(t, s) == null) s,
    ];
    void move(Entrant e, int to) {
      final seats = open(to);
      final from = e.table;
      e
        ..table = to
        ..seat = seats[rng.nextInt(seats.length)];
      moves.add((who: e, from: from, to: to));
    }

    for (var guard = 0; guard < 40; guard++) {
      final live = tables;
      if (live.length <= 1) break;
      // Break a table: the smallest that isn't yours.
      final others = live.where((t) => t != home).toList()..sort((a, b) => count(a).compareTo(count(b)));
      final smallest = others.firstOrNull;
      if (smallest != null && (left <= tournamentSeats * (live.length - 1) || count(smallest) < 2)) {
        for (final e in playersAt(smallest)) {
          final rest = live.where((t) => t != smallest).toList()
            ..sort((a, b) => count(a).compareTo(count(b)));
          move(e, rest.first);
        }
        continue;
      }
      // Even them out.
      final bySize = [...live]..sort((a, b) => count(a).compareTo(count(b)));
      final low = bySize.first, high = bySize.last;
      if (count(high) - count(low) < 2) break;
      final pool = playersAt(high).where((e) => !e.you).toList();
      move(pool[rng.nextInt(pool.length)], low);
    }
    return moves;
  }

  Map<String, Object?> toJson() => {
    'e': [for (final e in entrants) e.toJson()],
    'b': buttons,
    'r': round,
  };

  static Tournament fromJson(Map<String, Object?> j) => Tournament._(
    [for (final e in (j['e']! as List)) Entrant.fromJson((e as Map).cast<String, Object?>())],
    [...(j['b']! as List).cast<int>()],
    j['r']! as int,
  );
}

/// Your table in a [Tournament], as the hand engine sees it: six seats
/// (empty ones sit out), the tournament's blinds, nobody placed here (the
/// tournament does that).
class TournamentTable extends SitAndGo {
  TournamentTable({required this.tournament, required super.rng, required int button})
    : super(
        names: List.filled(tournamentSeats, ''),
        config: const SitAndGoConfig(startingStack: 0, handsPerLevel: Tournament.handsPerLevel),
        button: button,
      ) {
    for (final p in players) {
      p.empty = true;
    }
  }

  final Tournament tournament;

  @override
  (int, int) get blinds => tournament.blinds;

  @override
  int get level => tournament.level;

  @override
  int? get handsToNextLevel => tournament.handsToNextLevel;

  @override
  (int, int)? get nextBlinds => tournament.nextBlinds;

  @override
  bool get isOver => tournament.over;

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
}
