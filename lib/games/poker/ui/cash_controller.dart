part of 'poker_controller.dart';

/// A cash table on this phone (offline, or when the shared tables can't be
/// reached): you sit down with your own pips, the bots play on around you,
/// come and go between hands, and buy back in when they go broke. Leave
/// whenever you like: your chips go back to your balance (mid-hand, what
/// you've put in this hand stays in the pot).
class CashController extends PokerController {
  CashController._({
    required this.stake,
    required this.tableName,
    required super.you,
    required super.seats,
    required CashGame super.table,
    required super.styles,
    required super.rng,
    super.pace,
    this.onChips,
  }) : super._cash(difficulty: stake.difficulty);

  /// Sits you down at [table] with [buyIn]: in an empty seat, or a bot's
  /// (it gets up for you). Seats are turned round so you're at the bottom.
  factory CashController.sit({
    required CashTableState table,
    required int buyIn,
    required Persona you,
    double pace = 1,
    Random? rng,
    void Function(int chips)? onChips,
    int? seat,
  }) {
    final r = rng ?? Random();
    final bots = [
      for (var i = 0; i < cashSeats; i++)
        if (table.seats[i]?.bot ?? false) i,
    ];
    // The open seat you picked, else any open one, else a bot gets up.
    var mine = seat != null && seat >= 0 && seat < cashSeats && table.seats[seat] == null
        ? seat
        : table.seats.indexOf(null);
    if (mine < 0) mine = bots[r.nextInt(bots.length)];
    final stake = table.stake;
    final game = CashGame(stake: stake, rng: r, button: (table.button - mine) % cashSeats);
    final personas = <Persona>[];
    final styles = <BotStyle?>[];
    for (var l = 0; l < cashSeats; l++) {
      final s = l == 0 ? null : table.seats[(mine + l) % cashSeats];
      if (l == 0) {
        game.sit(0, you.name, buyIn);
        personas.add(you);
        styles.add(null);
      } else if (s == null || !s.bot) {
        game.clear(l);
        personas.add(_open);
        styles.add(null);
      } else {
        game.sit(l, s.name, s.stack);
        personas.add(Persona.bot(s.name, Look.values.asNameMap()[s.look] ?? Look.cap));
        styles.add(s.botStyle);
      }
    }
    final c = CashController._(
      stake: stake,
      tableName: stake.label,
      you: you,
      seats: personas,
      table: game,
      styles: styles,
      rng: r,
      pace: pace,
      onChips: onChips,
    );
    // Someone always has a word for a new face.
    if (personas.skip(1).any((p) => p != _open)) {
      final hello = [
        for (var l = 1; l < cashSeats; l++)
          if (personas[l] != _open) l,
      ];
      c._welcome = hello[r.nextInt(hello.length)];
    }
    return c;
  }

  static const _open = Persona(name: '', look: Look.cap, avatar: Avatar());

  final CashStake stake;
  final String tableName;

  /// Your chips after each hand (kept, so a closed app still cashes you out).
  final void Function(int chips)? onChips;

  int? _welcome;

  @override
  bool get isCash => true;

  CashGame get table => game as CashGame;

  /// Is [seat] (local) empty?
  bool isOpen(int seat) => game.players[seat].empty;

  /// Chips you'd leave with now (mid-hand: what's not in the pot).
  int get yourChips => handPlayer(0)?.stack ?? game.players[0].stack;

  /// Top-up waiting for the hand to finish.
  int pendingTopUp = 0;

  /// Most you may add (up to the table's full buy-in).
  int get maxTopUp =>
      max(0, stake.maxBuyIn - (handPlayer(0)?.startStack ?? game.players[0].stack) - pendingTopUp);

  /// Adds [pips] to your stack: now between hands, else when this hand's
  /// over.
  void topUp(int pips) {
    if (pips <= 0) return;
    if (hand == null || handPlayer(0) == null || phase == TablePhase.finished) {
      game.players[0].stack += pips;
    } else {
      pendingTopUp += pips;
    }
    _notify();
  }

  /// Broke: buy back in and carry on.
  void rebuy(int pips) {
    if (phase != TablePhase.finished || pips <= 0) return;
    game.players[0].stack = pips;
    _betweenHands();
    _newHand();
  }

  @override
  void start() {
    if (_welcome case final w?) {
      _sayLine(
        w,
        const ['Pull up a chair!', 'Fresh chips!', 'Evening.', 'Good luck. You\'ll need it.'][_rng.nextInt(
          4,
        )],
      );
    }
    _fill();
    _newHand();
  }

  /// At least one bot to play against.
  void _fill() {
    if (game.active.where((p) => p.seat != 0).isEmpty) _seatBot();
  }

  @override
  void _betweenHands() {
    if (pendingTopUp > 0) {
      game.players[0].stack += pendingTopUp;
      pendingTopUp = 0;
    }
    final bb = stake.bigBlind;
    for (var l = 1; l < cashSeats; l++) {
      final p = game.players[l];
      if (p.empty) continue;
      // Broke or short: buy back in, or go home.
      if (p.stack < bb * 20) {
        if (_rng.nextBool()) {
          p.stack = bb * (60 + _rng.nextInt(41));
        } else {
          _standUp(l);
        }
        continue;
      }
      if (_rng.nextDouble() < 0.04) _standUp(l);
    }
    final seated = game.players.where((p) => !p.empty).length;
    if (seated < 5 && _rng.nextDouble() < 0.3) _seatBot();
    _fill();
    onChips?.call(game.players[0].stack);
  }

  void _standUp(int seat) {
    table.clear(seat);
    personas[seat] = _open;
    _bots[seat] = null;
    _styles[seat] = null;
    talk.remove(seat);
  }

  void _seatBot() {
    final open = [
      for (var l = 1; l < cashSeats; l++)
        if (game.players[l].empty) l,
    ];
    if (open.isEmpty) return;
    final seat = open[_rng.nextInt(open.length)];
    final taken = {for (final p in personas) p.name};
    final names = [
      for (final n in Persona.botNames)
        if (!taken.contains(n)) n,
    ];
    final name = names[_rng.nextInt(names.length)];
    final look = Persona.botLooks[_rng.nextInt(Persona.botLooks.length)];
    final style = BotStyle.values[_rng.nextInt(BotStyle.values.length)];
    table.sit(seat, name, stake.bigBlind * (60 + _rng.nextInt(41)));
    personas[seat] = Persona.bot(name, look);
    _styles[seat] = style;
    _bots[seat] = PokerBot(style: style, difficulty: difficulty, rng: _rng);
    reads.players[seat] = PlayerReads();
    _sayLine(seat, const ['Deal me in.', 'Room for one more?', 'Hi all!', 'Let\'s go.'][_rng.nextInt(4)]);
  }
}
