part of 'poker_controller.dart';

/// A shared cash table, online: the referee deals and plays the bots;
/// this table replays each hand through the same engine (turned round so
/// you sit at the bottom), as the online Sit & Go does. Between hands it
/// takes the table as the server has it: who sat down, who left, stacks.
class OnlineCashController extends PokerController {
  OnlineCashController._({
    required this.service,
    required this.stake,
    required this.mySeat,
    required Doc doc,
    required super.you,
    required super.seats,
    required CashGame super.table,
    super.pace,
    DateTime Function()? clock,
  }) : _doc = doc, // ignore: prefer_initializing_formals
       _clock = clock ?? DateTime.now,
       super._cash(
         difficulty: stake.difficulty,
         styles: List.filled(cashSeats, null),
         rng: Random(),
         resultTimeout: const Duration(seconds: 5),
       );

  /// The table [doc] (from the referee) with you sitting at it.
  factory OnlineCashController.forTable(
    CashService service,
    Doc doc, {
    required Persona you,
    double pace = 1,
    DateTime Function()? clock,
  }) {
    final t = CashTableState.fromJson(doc);
    final me = t.seats.indexWhere((s) => s?.id == service.uid);
    final mySeat = me < 0 ? 0 : me;
    final game = CashGame(stake: t.stake, rng: Random(), button: (t.button - mySeat) % cashSeats);
    final c = OnlineCashController._(
      service: service,
      stake: t.stake,
      mySeat: mySeat,
      doc: doc,
      you: you,
      seats: List.filled(cashSeats, CashController._open),
      table: game,
      pace: pace,
      clock: clock,
    );
    c._seatFrom(t, null);
    c._subs = [
      service.watch(t.stake).listen((d) {
        if (d != null) c._onDoc(d);
      }, onError: (Object _) {}),
      service.mine(t.stake).listen((d) {
        c._mine = d;
        c._onDoc(c._doc);
      }, onError: (Object _) {}),
    ];
    return c;
  }

  final CashService service;
  final CashStake stake;
  final int mySeat;
  final DateTime Function() _clock;
  Doc _doc;
  Doc? _mine;
  List<StreamSubscription<Doc?>> _subs = const [];
  Timer? _tick;

  @override
  bool get isCash => true;

  String get tableName => stake.label;

  CashGame get table => game as CashGame;

  /// The table as the server last had it.
  CashTableState get state => CashTableState.fromJson(_doc);

  /// Still seated on the server.
  bool get seated => state.seats.any((s) => s?.id == service.uid);

  /// A call to the server failed: the HUD says it's reconnecting.
  bool trouble = false;

  int _local(int server) => (server - mySeat) % cashSeats;
  int _server(int local) => (local + mySeat) % cashSeats;

  Map<Object?, Object?>? get _hand => _doc['hand'] as Map?;
  int? get _handNo => _hand?['no'] as int?;
  bool get _handOver => _hand?['won'] != null;
  List<List<Object?>> get _moves => ((_hand?['moves'] as List?) ?? const []).cast<List<Object?>>();

  /// The hand dealt on this table.
  int? _dealtNo;
  int _cursor = 0;

  /// Chips you'd leave with now (mid-hand: what's not in the pot).
  int get yourChips => handPlayer(0)?.stack ?? game.players[0].stack;

  /// Top-up waiting for the next hand, as the server has it.
  int get pendingTopUp => state.seats[mySeat]?.topUp ?? 0;

  int get maxTopUp => max(0, stake.maxBuyIn - (state.seats[mySeat]?.stack ?? 0) - pendingTopUp);

  /// Seats everyone as [t] has them; for a hand, only those dealt in have
  /// chips (the rest sit out until the next).
  void _seatFrom(CashTableState t, Map<Object?, Object?>? hand) {
    final inHand = (hand?['seats'] as List?)?.cast<int>();
    final stacks = (hand?['stacks'] as List?)?.cast<int>();
    for (var l = 0; l < cashSeats; l++) {
      final s = _server(l);
      final seat = t.seats[s];
      if (seat == null) {
        table.clear(l);
        personas[l] = CashController._open;
        continue;
      }
      final k = inHand?.indexOf(s) ?? -1;
      final stack = inHand == null ? seat.stack : (k >= 0 ? stacks![k] : 0);
      final was = personas[l];
      final persona = l == 0
          ? you
          : seat.bot
          ? Persona.bot(seat.name, Look.values.asNameMap()[seat.look] ?? Look.cap)
          : Persona(
              name: seat.name,
              look: Look.headband,
              avatar: seat.avatar == null ? Avatar.forName(seat.name) : Avatar.fromJson(seat.avatar!),
            );
      if (was.name != persona.name) reads.players[l] = PlayerReads();
      personas[l] = persona;
      table.sit(l, persona.name, stack);
    }
  }

  static const _blank = PlayingCard(2, Suit.clubs);

  List<PlayingCard>? get _myCards {
    final m = _mine;
    if (m == null || m['no'] != _handNo) return null;
    return [for (final c in (m['cards'] as List?) ?? const []) PlayingCard.parse('$c')];
  }

  bool get _imIn => ((_hand?['seats'] as List?) ?? const []).contains(mySeat);

  // --- Replaying the server's hands ------------------------------------------

  @override
  bool get _youDeal => false;

  @override
  bool _canDeal() {
    final no = _handNo;
    if (no == null || no == _dealtNo) return false;
    if (_imIn && _myCards == null) return false;
    _seatFrom(state, _hand);
    table.nextButton = _local(_hand!['button']! as int);
    return table.canDeal;
  }

  @override
  Deck? _nextDeck() {
    final dealt = game.active.length * 2;
    const boardAt = {1: 0, 2: 1, 3: 2, 5: 3, 7: 4};
    final no = _handNo;
    return Deck.lazy((i) {
      if (i < dealt) return _blank;
      final k = boardAt[i - dealt];
      final board = _handNo == no ? (_hand?['board'] as List?) ?? const [] : const [];
      return k != null && k < board.length ? PlayingCard.parse('${board[k]}') : _blank;
    });
  }

  @override
  void _dealt(PokerHand h) {
    _cursor = 0;
    _dealtNo = _handNo;
    final mine = _myCards;
    final me = handIndex(0);
    if (mine != null && me != null) {
      h.players[me].hole
        ..clear()
        ..addAll(mine);
    }
  }

  void _showCards(PokerHand h) {
    if (_handNo != _dealtNo) return;
    final shown = (_hand?['shown'] as Map?) ?? const {};
    for (final e in shown.entries) {
      final i = handIndex(_local(int.parse('${e.key}')));
      if (i == null) continue;
      h.players[i].hole
        ..clear()
        ..addAll([for (final c in e.value as List) PlayingCard.parse('$c')]);
    }
  }

  @override
  bool _canAdvance(PokerHand h) {
    if (_handNo != _dealtNo) return true;
    if (h.isAllInRunout || h.street == Street.river) return _handOver;
    final needed = switch (h.street) {
      Street.preflop => 3,
      Street.flop => 4,
      _ => 5,
    };
    return ((_hand?['board'] as List?) ?? const []).length >= needed;
  }

  @override
  void _beforeAdvance(PokerHand h) => _showCards(h);

  Move? _logged() {
    if (_handNo != _dealtNo) return null;
    final moves = _moves;
    if (_cursor >= moves.length) return null;
    final m = moves[_cursor];
    return OnlinePokerController._toMove(MoveKind.values[m[0]! as int], m[1]! as int);
  }

  @override
  void _actFor(int seat, PokerHand h) {
    final m = _logged();
    if (m == null) {
      if (seat != 0 || _doc['turn'] != mySeat) _park(_step);
      return;
    }
    final raw = _moves[_cursor];
    final tempo = raw.length > 2 ? (raw[2]! as int) / 100 : null;
    final think = seat == 0
        ? 0
        : !youAreIn
        ? 250 + _rng.nextInt(200)
        : tempo != null
        ? onlineThinkMs(tempo)
        : 400;
    _after(think, () {
      _cursor++;
      _play(h, m);
      _afterMove();
    });
  }

  @override
  bool get yourTurn => super.yourTurn && _doc['turn'] == mySeat && _logged() == null;

  @override
  void act(Move move) {
    if (!yourTurn) return;
    final version = _doc['version']! as int;
    _cursor++;
    _play(hand!, move);
    _afterMove();
    unawaited(
      service
          .move(stake, version, {'kind': move.kind.name, 'amount': move.amount})
          .then((d) => _onDoc(d), onError: (Object _) => _troubled()),
    );
  }

  @override
  void _handEnded() => _cursor = 0;

  /// Out of chips as the server has it (sitting out a hand isn't broke).
  @override
  bool get _youBusted {
    final me = state.seats[mySeat];
    return me == null || me.id != service.uid || me.stack + me.topUp == 0;
  }

  // --- Following the server --------------------------------------------------

  DateTime _heard = DateTime.now();
  Object? _turnAt;
  Object? _endedAt;
  DateTime _endedHeard = DateTime.now();
  int? _asked;

  void _onDoc(Doc d) {
    if (_disposed) return;
    if ((d['version'] as int? ?? 0) < (_doc['version'] as int? ?? 0)) return;
    _doc = d;
    trouble = false;
    if (d['turnAt'] != _turnAt) {
      _turnAt = d['turnAt'];
      _heard = _clock();
    }
    if (d['endedAt'] != _endedAt) {
      _endedAt = d['endedAt'];
      _endedHeard = _clock();
    }
    // Not dealt into a hand yet (sat down mid-hand, or between hands):
    // show the table as it is.
    if (hand == null && phase != TablePhase.finished) _seatFrom(state, null);
    final parked = _parked;
    if (parked != null) {
      _parked = null;
      parked();
    } else {
      _notify();
    }
  }

  void _troubled() {
    if (_disposed) return;
    trouble = true;
    _notify();
  }

  @override
  void start() {
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _second());
    _newHand();
  }

  /// Asks the server to move on: deal the next hand once the last has been
  /// up a while, or claim a turn that ran out.
  void _second() {
    if (_disposed) return;
    final v = _doc['version'] as int?;
    final now = _clock();
    var due = false;
    if (_hand == null || _handOver) {
      due = now.difference(_endedHeard).inMilliseconds > 5500 || _hand == null;
    } else {
      final d = _doc['deadline'] as int?, at = _doc['turnAt'] as int?;
      if (d != null && at != null) due = (d - at) - now.difference(_heard).inMilliseconds < -1500;
    }
    _notify();
    if (due && _asked != v) {
      _asked = v;
      unawaited(service.tick(stake).then((d) => _onDoc(d), onError: (Object _) => _troubled()));
    }
  }

  /// Seconds left for whoever is to act (people only).
  @override
  int? get turnSecondsLeft {
    final d = _doc['deadline'] as int?, at = _doc['turnAt'] as int?;
    if (d == null || at == null || _handOver) return null;
    final ms = (d - at) - _clock().difference(_heard).inMilliseconds;
    return (ms / 1000).ceil().clamp(0, 30);
  }

  /// Stands you up (now, or once you've folded and the hand is over).
  Future<void> leave() async {
    try {
      await service.leave(stake);
    } on Object {
      // The server stands you up after your turns run out, chips and all.
    }
  }

  Future<String?> topUp(int pips) async {
    try {
      _onDoc(await service.topUp(stake, pips));
      return null;
    } on OnlineError catch (e) {
      return e.message;
    } on Object {
      return "Couldn't reach the table. Try again.";
    }
  }

  /// Broke: more chips (still seated), or sit back down.
  Future<String?> rebuy(int pips) async {
    try {
      final d = seated ? await service.topUp(stake, pips) : await service.sit(stake, pips);
      _onDoc(d);
      if (phase == TablePhase.finished) {
        _seatFrom(state, null);
        phase = TablePhase.dealing;
        _newHand();
      }
      return null;
    } on OnlineError catch (e) {
      return e.message;
    } on Object {
      return "Couldn't reach the table. Try again.";
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    super.dispose();
  }
}
