part of 'bj_controller.dart';

/// A shared blackjack table, played through the referee. The table doc has
/// every card dealt so far (the dealer's hole card hidden until it turns),
/// the bets, insurance and moves: the round is rebuilt from them through
/// the same engine and played back event by event, as at a table here.
/// Your bets, insurance and moves go to the referee; it plays the bots and
/// moves the pips (your balance follows the wallet).
class OnlineBjController extends BjController {
  OnlineBjController({required this.service, required Doc doc, required super.account, super.pace})
    : _doc = doc,
      super(table: BjTable.byId(doc['table']! as String) ?? bjTables.first, bots: 0, rules: _rulesOf(doc)) {
    _applySeats(doc);
    _apply(doc, first: true);
    _sub = service.watch(table.id).listen((d) {
      if (d != null) _apply(d);
    });
    // Any phone at the table moves it on when something's due.
    _ticker = Timer.periodic(const Duration(seconds: 3), (_) => _tick());
  }

  final BjService service;
  Doc _doc;
  StreamSubscription<Doc?>? _sub;
  Timer? _ticker;

  /// The round on show (its number), and a newer table waiting for the
  /// playback to finish.
  int _roundNo = -1;
  Doc? _pending;

  /// Caught up and waiting for the table to move.
  bool _idle = false;

  /// Showing the last round's result for a moment.
  bool _resting = false;

  /// Your bet for this round is in.
  bool betIn = false;
  bool _sending = false;

  static BjRules _rulesOf(Doc doc) => (BjTable.byId(doc['table']! as String) ?? bjTables.first).onlineRules;

  int get _version => _doc['version'] as int? ?? 0;

  List<Map<Object?, Object?>?> get _seatDocs => [for (final s in (_doc['seats']! as List)) s as Map?];

  @override
  int get youSeat {
    final i = [for (final s in (_doc['seats']! as List)) (s as Map?)?['id']].indexOf(service.uid);
    return i < 0 ? 2 : i;
  }

  @override
  bool get _local => false;

  @override
  bool get credit => false;

  @override
  int get shoeLeft => _doc['left'] as int? ?? table.onlineRules.decks * 52;

  @override
  int get shoeDecks => table.onlineRules.decks;

  @override
  double get decksLeft => max(0.5, shoeLeft / 52);

  @override
  bool get canDeal => super.canDeal && !betIn && !_sending && _doc['phase'] == 'betting';

  // --- The table doc -----------------------------------------------------------

  void _apply(Doc d, {bool first = false}) {
    // Still playing back the last round (or showing how it went): a newer
    // round waits for it.
    final later = (d['no'] as int? ?? 0) > _roundNo && round != null;
    if (!first && later && (_resting || !_idle)) {
      _pending = d;
      return;
    }
    final shuffled = (d['shuffles'] as int? ?? 0) > (_doc['shuffles'] as int? ?? 0);
    _doc = d;
    if (shuffled && !first) {
      shuffles++;
      Sound.play(Sfx.shuffle);
      _say(-1, dealerLine(BjTalk.shuffle, _rng));
    }
    final no = d['no'] as int? ?? 0;
    switch (d['phase']) {
      case 'idle':
      case 'betting':
        _applySeats(d);
        _betting(d);
      default:
        if (no != _roundNo) {
          _applySeats(d);
          _newRound(d, first: first);
        } else {
          _rebuild(d);
          if (phase == BjPhase.insurance && !round!.insuring) phase = BjPhase.dealing;
          if (_idle) {
            _idle = false;
            _playBack();
          }
        }
    }
    _notify();
  }

  /// The seats from the doc: you, bots and other people (each a bot-shaped
  /// seat here: the referee plays the bots).
  void _applySeats(Doc d) {
    final docs = [for (final s in (d['seats']! as List)) s as Map?];
    seats
      ..clear()
      ..addAll([
        for (final s in docs)
          if (s == null)
            BjSeat.empty()
          else if (s['id'] == service.uid)
            BjSeat(account.persona, null, 0)
          else if (s['bot'] == true)
            BjSeat(
              Persona.bot(s['name']! as String, Look.values.asNameMap()[s['look']] ?? Look.cap),
              BjBot(style: BjStyle.bookie, difficulty: table.difficulty, rng: _rng),
              s['chips'] as int? ?? 0,
            )
          else
            BjSeat(
              Persona(
                name: s['name'] as String? ?? 'Player',
                look: Look.headband,
                avatar: s['avatar'] is Map
                    ? Avatar.fromJson((s['avatar']! as Map).cast<String, dynamic>())
                    : Avatar.forName(s['name'] as String? ?? 'Player'),
              ),
              BjBot(style: BjStyle.bookie, difficulty: table.difficulty, rng: _rng),
              0,
            ),
      ]);
  }

  void _betting(Doc d) {
    final wants = (d['wants'] as Map?) ?? const {};
    betIn = wants.containsKey('$youSeat');
    if (phase != BjPhase.betting) {
      phase = BjPhase.betting;
      speech.clear();
      for (final s in seats) {
        s.bet = null;
      }
      bet = min(max(bet, table.min), maxBet);
    }
    news = d['phase'] == 'idle' ? 'Waiting for the table to open…' : null;
  }

  /// The round from the doc: the cards dealt so far (a stand-in for the
  /// hole card while it's down), the bets, insurance and moves.
  BjRound _build(Doc d) {
    final hole = d['hole'] as int?;
    final cards = <PlayingCard>[
      for (final (i, c) in ((d['cards'] as List?) ?? const []).indexed)
        c == null || i == hole && c == null ? PlayingCard.parse('2c') : PlayingCard.parse(c as String),
    ];
    final bets = [for (final b in (d['bets'] as List?) ?? List<Object?>.filled(bjSeatCount, null)) b as int?];
    final r = BjRound(
      shoe: Shoe(_rng, decks: shoeDecks, stacked: cards),
      bets: bets,
      rules: table.onlineRules,
    );
    final insured = d['insured'] as List?;
    if (r.insuring && insured != null) r.insure({for (final s in insured) s as int});
    for (final m in (d['moves'] as List?) ?? const []) {
      if (!r.playing) break;
      r.act(BjMove.values.byName((m as List)[1]! as String));
    }
    return r;
  }

  void _newRound(Doc d, {required bool first}) {
    _roundNo = d['no'] as int? ?? 0;
    round = _build(d);
    final bets = (d['bets'] as List?) ?? const [];
    for (final (i, s) in seats.indexed) {
      s.bet = i < bets.length ? bets[i] as int? : null;
    }
    shown = [for (final h in round!.hands) List.filled(h.length, 0, growable: true)];
    dealerShown = 0;
    holeUp = false;
    resultsUp = false;
    lastNet = null;
    lastBlackjack = false;
    _cursor = 0;
    _idle = false;
    betIn = false;
    rounds++;
    phase = BjPhase.dealing;
    speech.clear();
    Sound.play(Sfx.chips);
    _after(300, _playBack);
  }

  /// The same round, further on: rebuilt (the events so far are the same;
  /// the hole card may now be the real one).
  void _rebuild(Doc d) => round = _build(d);

  // --- Playback hooks ------------------------------------------------------------

  @override
  void _decide() {
    final r = round!;
    _idle = true;
    if (r.turn?.$1 == youSeat) hurrying = false;
    if (r.insuring) return;
    final t = r.turn;
    if (t == null) return;
    phase = BjPhase.playing;
    if (t.$1 == youSeat) Sound.play(Sfx.yourTurn, gain: 0.7);
    _notify();
  }

  @override
  void _insuranceOffered() {
    _idle = true;
    // The referee may have moved on already (insurance answered).
    if (!round!.insuring) {
      _idle = false;
      phase = BjPhase.dealing;
      _after(250, _playBack);
    }
  }

  @override
  void _paid(int staked, int net) => account.payoutStats('blackjack', staked: staked, back: staked + net);

  @override
  void _afterRound() {
    _idle = true;
    _resting = true;
    _after(2600, () {
      _resting = false;
      final next = _pending;
      _pending = null;
      if (next != null) _apply(next);
    });
  }

  // --- Your side --------------------------------------------------------------------

  @override
  void deal() {
    if (!canDeal) return;
    _send(() => service.bet(table.id, bet), then: () => betIn = true);
    Sound.play(Sfx.chips);
  }

  /// Sit this round out.
  void skip() {
    if (_doc['phase'] != 'betting' || betIn) return;
    _send(() => service.bet(table.id, 0), then: () => betIn = true);
  }

  @override
  void act(BjMove m) {
    if (!moves.contains(m) || _sending) return;
    _send(() => service.move(table.id, _version, m.name));
  }

  @override
  void insure(bool yes) {
    if (!canInsure || _sending) return;
    _send(() => service.insure(table.id, yes));
  }

  void _send(Future<Doc> Function() call, {VoidCallback? then}) {
    _sending = true;
    _notify();
    call().then(
      (d) {
        _sending = false;
        then?.call();
        _apply(d);
      },
      onError: (Object e) {
        _sending = false;
        news = e is OnlineError ? e.message : 'Lost the connection: trying again…';
        _notify();
      },
    );
  }

  void _tick() {
    if (_disposed) return;
    service.tick(table.id).then((d) {
      if (!_disposed && (d['version'] as int? ?? 0) > _version) _apply(d);
    }, onError: (Object _) {});
  }

  @override
  Future<void> leaveTable() async {
    try {
      await service.leave(table.id);
    } on Object {
      // Offline: the referee stands you up when your turns run out.
    }
  }

  @override
  String commentary() {
    if (phase == BjPhase.betting) {
      final n = news;
      if (n != null) return n;
      if (betIn) {
        final waiting = _seatDocs.nonNulls.where((s) => s['id'] != null).length > 1;
        return waiting ? 'Bet in. Waiting for the others…' : 'Bet in. Dealing…';
      }
      return 'Place a bet: ${account.money(table.min)} to ${account.money(table.max)}, then Deal.';
    }
    if (phase == BjPhase.insurance && !canInsure) return 'Insurance? Waiting for the others…';
    return super.commentary();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }
}
