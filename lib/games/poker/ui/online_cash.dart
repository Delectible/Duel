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
    c._listen();
    return c;
  }

  /// Follows the table and your cards; a stream that drops is picked up
  /// again (the watchdog in [_second] fetches the table meanwhile).
  void _listen() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    void again(Object? _) {
      if (_disposed || _relisten != null) return;
      _relisten = Timer(const Duration(seconds: 3), () {
        _relisten = null;
        if (!_disposed) _listen();
      });
    }

    _subs = [
      service
          .watch(stake)
          .listen(
            (d) {
              if (d != null) _onDoc(d);
            },
            onError: again,
            onDone: () => again(null),
          ),
      service
          .mine(stake)
          .listen(
            (d) {
              _mine = d;
              _onDoc(_doc);
            },
            onError: again,
            onDone: () => again(null),
          ),
    ];
  }

  final CashService service;
  final CashStake stake;
  final int mySeat;
  final DateTime Function() _clock;
  Doc _doc;
  Doc? _mine;
  List<StreamSubscription<Doc?>> _subs = const [];
  Timer? _tick;
  Timer? _relisten;

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

  /// The hand dealt on this table.
  int? _dealtNo;
  int _cursor = 0;

  /// The hand being shown, as the server last had it: kept when the
  /// server moves on to the next one, so this phone (still showing the
  /// bots think) can finish it.
  Map<Object?, Object?>? _played;

  /// The last hand this phone finished showing.
  int? _finishedNo;

  /// The server's hand [no], if this phone has it.
  Map<Object?, Object?>? _handNumbered(int? no) {
    if (no == null) return null;
    if (_played?['no'] == no) return _played;
    return _handNo == no ? _hand : null;
  }

  /// The server moved past the hand this phone is showing.
  bool get _movedOn => _dealtNo != null && _handNo != _dealtNo;

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
      final board = (_handNumbered(no)?['board'] as List?) ?? const [];
      return k != null && k < board.length ? PlayingCard.parse('${board[k]}') : _blank;
    });
  }

  @override
  void _dealt(PokerHand h) {
    _cursor = 0;
    _dealtNo = _handNo;
    _played = _hand;
    final mine = _myCards;
    final me = handIndex(0);
    if (mine != null && me != null) {
      h.players[me].hole
        ..clear()
        ..addAll(mine);
    }
  }

  void _showCards(PokerHand h) {
    final shown = (_played?['shown'] as Map?) ?? const {};
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
    final played = _played;
    if (played == null) return true;
    final needed = switch (h.street) {
      Street.preflop => 3,
      Street.flop => 4,
      _ => 5,
    };
    final ok = h.isAllInRunout || h.street == Street.river
        ? played['won'] != null
        : ((played['board'] as List?) ?? const []).length >= needed;
    // The rest of the hand never reached this phone: on to the server's.
    if (!ok && _movedOn) _after(0, _resync);
    return ok;
  }

  @override
  void _beforeAdvance(PokerHand h) => _showCards(h);

  List<List<Object?>> get _playedMoves => ((_played?['moves'] as List?) ?? const []).cast<List<Object?>>();

  Move? _logged() {
    final moves = _playedMoves;
    if (_cursor >= moves.length) return null;
    final m = moves[_cursor];
    return OnlinePokerController._toMove(MoveKind.values[m[0]! as int], m[1]! as int);
  }

  @override
  void _actFor(int seat, PokerHand h) {
    final m = _logged();
    if (m == null) {
      // The server moved on and this hand's moves never all came: catch up.
      if (_movedOn) return _resync();
      // Yours too: if your time runs out, the server's fold comes next.
      _park(_step);
      return;
    }
    final raw = _playedMoves[_cursor];
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
  bool get yourTurn => super.yourTurn && !_movedOn && _doc['turn'] == mySeat && _logged() == null;

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
  void _handEnded() {
    _cursor = 0;
    _finishedNo = _dealtNo;
  }

  /// Gives up on a hand this phone can't finish (its moves were missed)
  /// and deals the server's current one.
  void _resync() {
    if (_disposed || !_movedOn) return;
    _timer?.cancel();
    _countdown?.cancel();
    _parked = null;
    waitingForYou = false;
    secondsLeft = null;
    _cursor = 0;
    _finishedNo = _dealtNo;
    _played = null;
    _dealtNo = null;
    if (phase == TablePhase.finished) return _notify();
    phase = TablePhase.dealing;
    _newHand();
  }

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
  DateTime _askedAt = DateTime.now();

  /// Since when this table has been waiting on the server (null: it isn't).
  DateTime? _stuckSince;
  DateTime _fetchedAt = DateTime.now();

  void _onDoc(Doc d) {
    if (_disposed) return;
    if ((d['version'] as int? ?? 0) < (_doc['version'] as int? ?? 0)) return;
    if (d['version'] != _doc['version']) _stuckSince = null;
    _doc = d;
    trouble = false;
    if (_hand?['no'] == _dealtNo && _dealtNo != null) _played = _hand;
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
    if (_hand == null) {
      due = true;
    } else if (_handOver) {
      // The next hand once this phone has shown this one (the server
      // waits its two seconds), or after a while whatever this phone's up to.
      final since = now.difference(_endedHeard).inMilliseconds;
      due = (_finishedNo == _handNo && since > 2000) || since > 15000;
      // Asked a little early: again next second, not in five.
      if (due && _asked == v && now.difference(_askedAt).inMilliseconds >= 1000) _asked = null;
    } else {
      final d = _doc['deadline'] as int?, at = _doc['turnAt'] as int?;
      if (d != null && at != null) due = (d - at) - now.difference(_heard).inMilliseconds < -1500;
    }
    _watchdog(now);
    _notify();
    // Asked once per table version; again every few seconds if nothing came
    // of it (a lost call, or the server not ready yet).
    if (due && (_asked != v || now.difference(_askedAt).inSeconds >= 5)) {
      _asked = v;
      _askedAt = now;
      _fetchedAt = now;
      unawaited(service.tick(stake).then((d) => _onDoc(d), onError: (Object _) => _troubled()));
    }
  }

  /// A table waiting on a move that never comes (a dropped stream, a lost
  /// update): fetch the table afresh every few seconds until it moves.
  void _watchdog(DateTime now) {
    if (_parked == null || yourTurn) {
      _stuckSince = null;
      return;
    }
    final since = _stuckSince ??= now;
    if (now.difference(since).inSeconds < 10 || now.difference(_fetchedAt).inSeconds < 5) return;
    _fetchedAt = now;
    unawaited(service.tick(stake).then((d) => _onDoc(d), onError: (Object _) => _troubled()));
  }

  /// Seconds left for whoever is to act: people only, once this phone has
  /// reached their turn (never under a bot it's still showing).
  @override
  int? get turnSecondsLeft {
    final d = _doc['deadline'] as int?, at = _doc['turnAt'] as int?;
    if (d == null || at == null || _handOver || _movedOn) return null;
    final seat = actingSeat;
    if (seat == null || _server(seat) != _doc['turn'] || _logged() != null) return null;
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
    _relisten?.cancel();
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    super.dispose();
  }
}
