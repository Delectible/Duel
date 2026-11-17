part of 'poker_controller.dart';

/// Your table in a tournament ([Tournament]): 18 players at three tables.
/// You play your table here; between hands the other tables each play a
/// hand straight through, those out are placed, and players move: a table
/// breaks up, the tables are evened out, until the final table. You never
/// move (everyone comes to you); seats are turned round so you're at the
/// bottom.
class TournamentController extends PokerController {
  TournamentController._({
    required this.tournament,
    required this.tier,
    required this.memoryOf,
    required super.you,
    required super.seats,
    required TournamentTable super.table,
    required super.styles,
    required super.rng,
    super.pace,
  }) : _home = tournament.you.table,
       _homeSeat = tournament.you.seat,
       super._cash(difficulty: tier.difficulty);

  /// Sits you at your table in [t] (a new tournament, or one picked up
  /// again). [memoryOf] gives what a rival remembers of you.
  factory TournamentController.seat({
    required Tournament t,
    required TournamentTier tier,
    required Persona you,
    ReadMemory? Function(String name)? memoryOf,
    double pace = 1,
    Random? rng,
  }) {
    final r = rng ?? Random();
    final home = t.you.table, hs = t.you.seat;
    final table = TournamentTable(tournament: t, rng: r, button: (t.buttons[home] - hs) % tournamentSeats);
    final c = TournamentController._(
      tournament: t,
      tier: tier,
      memoryOf: memoryOf ?? (_) => null,
      you: you,
      seats: List.filled(tournamentSeats, CashController._open),
      table: table,
      styles: List.filled(tournamentSeats, null),
      rng: r,
      pace: pace,
    );
    table.sit(0, you.name, t.you.stack);
    c.personas[0] = you;
    c._reseat();
    return c;
  }

  final Tournament tournament;
  final TournamentTier tier;
  final ReadMemory? Function(String name) memoryOf;
  final int _home, _homeSeat;

  /// Who sits in each of your table's seats (local, you at 0).
  final List<Entrant?> _at = List.filled(tournamentSeats, null);

  TournamentTable get table => game as TournamentTable;

  int _tournamentSeat(int local) => (local + _homeSeat) % tournamentSeats;

  @override
  String get title => tier.label;

  @override
  int get fieldSize => tournamentPlayers;

  @override
  int? get yourPlace => tournament.you.place ?? (tournament.over ? 1 : null);

  /// Your table as the tournament has it: newcomers sit down (a fresh read,
  /// a rival's memory), the empty seats clear.
  void _reseat() {
    _at[0] = tournament.you;
    for (var l = 1; l < tournamentSeats; l++) {
      final e = tournament.at(_home, _tournamentSeat(l));
      if (identical(e, _at[l])) continue;
      _at[l] = e;
      reads.players[l] = PlayerReads();
      if (e == null) {
        table.clear(l);
        personas[l] = CashController._open;
        _styles[l] = null;
        _bots[l] = null;
        continue;
      }
      final rival = Rival.all.where((r) => r.name == e.name).firstOrNull;
      table.sit(l, e.name, e.stack);
      personas[l] = rival?.persona ?? Persona.bot(e.name, Look.values.asNameMap()[e.look] ?? Look.cap);
      _styles[l] = e.botStyle;
      final memory = rival == null ? null : memoryOf(e.name);
      _bots[l] = PokerBot(
        style: e.botStyle,
        // A rival plays a level up and remembers you.
        difficulty: rival == null
            ? difficulty
            : Difficulty.values[min(difficulty.index + 1, Difficulty.values.length - 1)],
        rng: _rng,
        memory: memory,
        memoryWeight: rivalMemoryWeight(difficulty),
      );
    }
  }

  /// Rivals who sat at your table this tournament (they remember you).
  Iterable<({String name, PlayerReads reads})> get rivalsMet => [
    for (var l = 1; l < tournamentSeats; l++)
      if (_at[l] case final e? when Rival.all.any((r) => r.name == e.name))
        (name: e.name, reads: reads.players[0]),
  ];

  @override
  void _betweenHands() {
    // Your table's hand into the tournament, then the other tables' hands.
    for (var l = 0; l < tournamentSeats; l++) {
      _at[l]?.stack = game.players[l].stack;
    }
    tournament.buttons[_home] = (game.buttonSeat + _homeSeat) % tournamentSeats;
    for (final t in tournament.tables) {
      if (t == _home) continue;
      tournament.playHand(t, (e) => PokerBot(style: e.botStyle, difficulty: difficulty, rng: _rng), _rng);
    }
    final before = tournament.tables.length;
    tournament.endRound();
    final moves = tournament.balance(_rng);
    if (!tournament.you.live) return;
    _reseat();
    final joined = [
      for (final m in moves)
        if (m.to == _home) m.who.name,
    ];
    final tables = tournament.tables.length;
    if (tables == 1 && before > 1) {
      _nextBanner = 'Final table!';
    } else if (joined.isNotEmpty) {
      _nextBanner = joined.length == 1
          ? '${joined.single} joins your table'
          : '${joined.length} players join your table';
    } else if (tables < before) {
      _nextBanner = 'A table breaks up: $tables left';
    }
  }

  @override
  List<({int place, Persona who, bool you})> get lineup {
    // Your table, in tournament order.
    final order = tournament.standings;
    final here = [
      for (var l = 0; l < tournamentSeats; l++)
        if (_at[l] case final e? when l == 0 || !game.players[l].empty) (e: e, who: personas[l], you: l == 0),
    ];
    return [for (final x in here) (place: x.e.place ?? order.indexOf(x.e) + 1, who: x.who, you: x.you)]
      ..sort((a, b) => a.place.compareTo(b.place));
  }

  /// To pick it up again (between hands).
  @override
  Map<String, Object?> snapshot() => tournament.toJson();
}
