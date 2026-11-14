part of 'referee.dart';

/// The shared cash tables: one per stake, the same for everyone with the
/// app. With nobody sitting, the bots "play on" in quick sums
/// ([CashTableState.simulate], caught up whenever someone looks); once a
/// person sits down, real hands are dealt and played here, bots and all.
///
/// Documents (never expire):
/// - `cash/{stake}`: the table ([CashTableState] JSON) plus `version`,
///   `hand` (the hand being played, or the last: `no`, `seats` and
///   `stacks` at the start, `button`, `moves` ([kind, amount, tempo%]),
///   the `board` so far, `shown` cards, and `won` once over), `turn` (a
///   seat), `deadline`, `turnAt`, `endedAt` (when the hand finished).
/// - `cashSecrets/{stake}`: the hand's shuffle (`seed`).
/// - `cash/{stake}/hands/{uid}`: a person's own two cards (`no`, `cards`).
extension CashTables on Referee {
  /// How long a person has for a move.
  static const cashTurn = Duration(seconds: 30);

  /// How long a finished hand stays up before the next is dealt.
  static const cashPause = Duration(seconds: 5);

  /// Every table, caught up to now, and the table you're sitting at.
  Future<Doc> cashLobby(Player p) => store.transaction((tx) async {
    final tables = <Doc>[];
    String? mine;
    for (final stake in CashStake.values) {
      final doc = await _cashTable(tx, stake);
      final t = CashTableState.fromJson(doc);
      // Everyone at it closed the app: their turns run out, they're stood
      // up (chips back), and the bots carry on alone.
      if (t.people.isNotEmpty && await _cashCatchUp(tx, stake, doc, t, grace: const Duration(seconds: 60))) {
        _bump(doc);
        _putCash(tx, stake, doc);
      }
      if (t.people.isEmpty && doc['hand'] == null) {
        t.simulate(_now, _rng);
        doc.addAll(t.toJson());
        _putCash(tx, stake, doc);
      }
      if (t.people.any((s) => s.id == p.uid)) mine = stake.name;
      tables.add(doc);
    }
    return {'tables': tables, 'mine': mine};
  });

  /// Sits [p] at [stake] with [buyIn] from their pips: in an open seat, or
  /// a bot's. Mid-hand they're dealt in from the next one.
  Future<Doc> cashSit(Player p, String stakeName, int buyIn, {int? seat}) => store.transaction((tx) async {
    final stake = _stake(stakeName);
    for (final other in CashStake.values) {
      if (other == stake) continue;
      final o = await tx.get('cash/${other.name}');
      if (o != null && CashTableState.fromJson(o).people.any((s) => s.id == p.uid)) {
        throw RefereeError(409, "You're already at the ${other.label}: cash out there first");
      }
    }
    final doc = await _cashTable(tx, stake);
    final t = CashTableState.fromJson(doc);
    if (t.people.any((s) => s.id == p.uid)) return doc;
    final w = await tx.get('wallets/${p.uid}');
    if (w == null) throw const RefereeError(409, 'Your balance is still being set up: try again in a moment');
    final balance = w['balance']! as int;
    if (balance < stake.unlockAt) {
      throw RefereeError(409, '${stake.label} unlocks once your balance reaches ${stake.unlockAt}');
    }
    if (buyIn < stake.minBuyIn || buyIn > stake.maxBuyIn) {
      throw RefereeError(400, 'Buy in with ${stake.minBuyIn} to ${stake.maxBuyIn}');
    }
    if (balance < buyIn) throw const RefereeError(409, "Your balance doesn't cover that");
    // The bots have been playing: catch up before anyone sits.
    if (t.people.isEmpty && doc['hand'] == null) t.simulate(_now, _rng);
    // The open seat they picked (if it's still open), else any open one,
    // else a bot gets up (never one they pick).
    final want = seat;
    var at = want != null && want >= 0 && want < cashSeats && t.seats[want] == null
        ? want
        : t.seats.indexOf(null);
    if (at < 0) {
      final bots = [
        for (var i = 0; i < cashSeats; i++)
          if (t.seats[i]!.bot && !_inHand(doc, i)) i,
      ];
      if (bots.isEmpty) throw const RefereeError(409, 'The table is full');
      at = bots[_rng.nextInt(bots.length)];
    }
    t.seats[at] = CashSeat(
      id: p.uid,
      name: Referee.cleanName(p.name),
      stack: buyIn,
      avatar: p.avatar,
      waiting: _handLive(doc),
    );
    _setWallet(tx, p.uid, {...w, 'balance': balance - buyIn});
    doc.addAll(t.toJson());
    if (!_handLive(doc)) await _cashNextHand(tx, stake, doc, t);
    _bump(doc);
    _putCash(tx, stake, doc);
    return doc;
  });

  /// [p]'s move in the hand ([version]: the table as they saw it).
  Future<Doc> cashMove(Player p, String stakeName, int version, Doc move) => store.transaction((tx) async {
    final stake = _stake(stakeName);
    final doc = await _cashTable(tx, stake);
    if (doc['version'] != version) throw const RefereeError(409, 'Out of date: the table moved on');
    final t = CashTableState.fromJson(doc);
    final seat = t.seats.indexWhere((s) => s?.id == p.uid);
    if (seat < 0) throw const RefereeError(403, "You're not at this table");
    if (doc['turn'] != seat) throw const RefereeError(409, 'Not your turn');
    final secret = await tx.get('cashSecrets/${stake.name}');
    final (_, h) = _replay(stake, doc, secret!['seed']! as int);
    final m = _checkMove(h, move);
    _append(doc, m);
    t.seats[seat]!.timeouts = 0;
    doc.addAll(t.toJson());
    await _cashPlayOn(tx, stake, doc, t, secret['seed']! as int);
    _bump(doc);
    _putCash(tx, stake, doc);
    return doc;
  });

  /// Deals the next hand once the last one has been up a few seconds (any
  /// phone at the table asks), or claims a person's turn that ran out
  /// (folded for them; two in a row and they're stood up).
  Future<Doc> cashTick(Player p, String stakeName) => store.transaction((tx) async {
    final stake = _stake(stakeName);
    final doc = await _cashTable(tx, stake);
    final t = CashTableState.fromJson(doc);
    if (!t.people.any((s) => s.id == p.uid)) return doc;
    if (!await _cashStep(tx, stake, doc, t)) return doc;
    _bump(doc);
    _putCash(tx, stake, doc);
    return doc;
  });

  /// One step on, if one is due: the next hand (the last has been up
  /// [cashPause] + [grace]), or a turn that ran out ([grace] past the
  /// deadline). Returns whether anything changed.
  Future<bool> _cashStep(
    Tx tx,
    CashStake stake,
    Doc doc,
    CashTableState t, {
    Duration grace = Duration.zero,
  }) async {
    if (!_handLive(doc)) {
      final ended = doc['endedAt'] as int?;
      if (ended != null && _now < ended + (cashPause + grace).inMilliseconds) return false;
      await _cashNextHand(tx, stake, doc, t);
      return true;
    }
    final deadline = doc['deadline'] as int?;
    final turn = doc['turn'] as int?;
    if (deadline == null || turn == null || _now < deadline + grace.inMilliseconds) return false;
    final secret = await tx.get('cashSecrets/${stake.name}');
    final (_, h) = _replay(stake, doc, secret!['seed']! as int);
    final s = t.seats[turn]!;
    if (++s.timeouts >= 2) s.leaving = true;
    _append(doc, h.legalMoves().canCheck ? const Move.check() : const Move.fold());
    doc.addAll(t.toJson());
    await _cashPlayOn(tx, stake, doc, t, secret['seed']! as int);
    return true;
  }

  /// Steps an abandoned table along (at most a few hands' worth).
  Future<bool> _cashCatchUp(
    Tx tx,
    CashStake stake,
    Doc doc,
    CashTableState t, {
    required Duration grace,
  }) async {
    var changed = false;
    for (var i = 0; i < 12 && t.people.isNotEmpty; i++) {
      if (!await _cashStep(tx, stake, doc, t, grace: grace)) break;
      changed = true;
    }
    return changed;
  }

  /// Stands [p] up: their chips go back to their pips now, or (in the
  /// middle of a hand they're still in) once they've folded and it's
  /// over.
  Future<Doc> cashLeave(Player p, String stakeName) => store.transaction((tx) async {
    final stake = _stake(stakeName);
    final doc = await _cashTable(tx, stake);
    final t = CashTableState.fromJson(doc);
    final seat = t.seats.indexWhere((s) => s?.id == p.uid);
    if (seat < 0) return doc;
    if (_inHand(doc, seat) && _handLive(doc)) {
      t.seats[seat]!.leaving = true;
      doc.addAll(t.toJson());
      // Their turn: fold now.
      if (doc['turn'] == seat) {
        final secret = await tx.get('cashSecrets/${stake.name}');
        _append(doc, const Move.fold());
        await _cashPlayOn(tx, stake, doc, t, secret!['seed']! as int);
      }
      // Nobody else here to move it along: settle up now.
      if (!_handLive(doc) && t.people.every((s) => s.leaving)) await _cashNextHand(tx, stake, doc, t);
    } else {
      await _cashOut(tx, t.seats[seat]!);
      t.seats[seat] = null;
      doc.addAll(t.toJson());
      if (t.people.isEmpty) _cashRest(doc, t);
    }
    _bump(doc);
    _putCash(tx, stake, doc);
    return doc;
  });

  /// More chips from [p]'s pips (up to the table's full buy-in): now if
  /// they're not in a hand, else from the next one.
  Future<Doc> cashTopUp(Player p, String stakeName, int pips) => store.transaction((tx) async {
    final stake = _stake(stakeName);
    final doc = await _cashTable(tx, stake);
    final t = CashTableState.fromJson(doc);
    final s = t.seats.where((s) => s?.id == p.uid).firstOrNull;
    if (s == null) throw const RefereeError(403, "You're not at this table");
    final w = (await tx.get('wallets/${p.uid}'))!;
    final balance = w['balance']! as int;
    final room = stake.maxBuyIn - s.stack - (s.topUp);
    final add = min(pips, room);
    if (add <= 0) throw RefereeError(409, 'You already have the most you can bring (${stake.maxBuyIn})');
    if (balance < add) throw const RefereeError(409, "Your balance doesn't cover that");
    _setWallet(tx, p.uid, {...w, 'balance': balance - add});
    final seat = t.seats.indexOf(s);
    if (_inHand(doc, seat) && _handLive(doc)) {
      s.topUp += add;
    } else {
      s.stack += add;
    }
    doc.addAll(t.toJson());
    _bump(doc);
    _putCash(tx, stake, doc);
    return doc;
  });

  // --- Hands -----------------------------------------------------------------

  CashStake _stake(String name) =>
      CashStake.values.asNameMap()[name] ?? (throw const RefereeError(404, 'No such table'));

  Future<Doc> _cashTable(Tx tx, CashStake stake) async {
    final doc = await tx.get('cash/${stake.name}');
    if (doc != null) return doc;
    return {...CashTableState.fresh(stake, _rng, _now).toJson(), 'version': 0};
  }

  void _putCash(Tx tx, CashStake stake, Doc doc) => tx.set('cash/${stake.name}', doc);

  void _bump(Doc doc) => doc['version'] = (doc['version'] as int? ?? 0) + 1;

  static Map<Object?, Object?>? _hand(Doc doc) => doc['hand'] as Map?;

  /// A hand is being played (not finished).
  static bool _handLive(Doc doc) => _hand(doc) != null && _hand(doc)!['won'] == null;

  /// [seat] was dealt into the current (or last) hand.
  static bool _inHand(Doc doc, int seat) => ((_hand(doc)?['seats'] as List?) ?? const []).contains(seat);

  /// The current hand rebuilt from its start and its moves.
  static (CashGame, PokerHand) _replay(CashStake stake, Doc doc, int seed) {
    final hand = _hand(doc)!;
    final seats = (hand['seats']! as List).cast<int>();
    final stacks = (hand['stacks']! as List).cast<int>();
    final g = CashGame(stake: stake, rng: Random(seed), button: hand['button']! as int);
    for (final (k, s) in seats.indexed) {
      g.sit(s, '', stacks[k]);
    }
    final h = g.startHand();
    for (final m in (hand['moves']! as List).cast<List<Object?>>()) {
      PokerGame.advance(h);
      h.apply(PokerGame.toMove(MoveKind.values[m[0]! as int], m[1]! as int));
    }
    PokerGame.advance(h);
    return (g, h);
  }

  static Move _checkMove(PokerHand h, Doc move) {
    final legal = h.legalMoves();
    var kind = MoveKind.values.asNameMap()[move['kind']];
    // A call with nothing to call is a check.
    if (kind == MoveKind.call && legal.canCheck) kind = MoveKind.check;
    final amount = min(move['amount'] is int ? move['amount']! as int : 0, legal.maxRaiseTo);
    final ok = switch (kind) {
      MoveKind.fold => true,
      MoveKind.check => legal.canCheck,
      MoveKind.call => !legal.canCheck,
      MoveKind.raise => legal.canRaise && amount >= legal.minRaiseTo && amount <= legal.maxRaiseTo,
      null => false,
    };
    if (!ok) throw const RefereeError(400, "That move isn't allowed now");
    return PokerGame.toMove(kind!, amount);
  }

  static void _append(Doc doc, Move m, {int? tempo}) {
    final hand = {...(_hand(doc)!).cast<String, Object?>()};
    hand['moves'] = [
      ...(hand['moves']! as List),
      [m.kind.index, m.kind == MoveKind.raise ? m.amount : 0, ?tempo],
    ];
    doc['hand'] = hand;
  }

  /// Plays bots (and people standing up) until a person is to act or the
  /// hand is over; then sets the clock, or settles the hand.
  Future<void> _cashPlayOn(Tx tx, CashStake stake, Doc doc, CashTableState t, int seed) async {
    for (var guard = 0; guard < 500; guard++) {
      final (g, h) = _replay(stake, doc, seed);
      _publishBoard(doc, h, g);
      if (h.result != null) {
        _settle(doc, t, g, h);
        return;
      }
      final i = h.toAct!;
      final seat = g.handSeats[i];
      final s = t.seats[seat]!;
      if (s.bot) {
        final d = PokerBot(
          style: s.botStyle,
          difficulty: stake.difficulty,
          rng: Random(seed ^ (h.board.length * 131 + _movesOf(doc) * 7919)),
        ).think(h, reads: TableReads(cashSeats), seats: g.handSeats);
        _append(doc, d.move, tempo: (d.tempo * 100).round());
      } else if (s.leaving) {
        _append(doc, const Move.fold());
      } else {
        doc['turn'] = seat;
        doc['turnAt'] = _now;
        // The phones show the bots thinking first: their time on top.
        doc['deadline'] = _now + cashTurn.inMilliseconds + _pendingShow(doc);
        return;
      }
    }
  }

  static int _movesOf(Doc doc) => ((_hand(doc)?['moves'] as List?) ?? const []).length;

  /// Rough time phones take to show the moves since the last person's.
  int _pendingShow(Doc doc) {
    final moves = ((_hand(doc)?['moves'] as List?) ?? const []).cast<List<Object?>>();
    var ms = 0;
    for (final m in moves.reversed) {
      if (m.length < 3) break;
      ms += onlineThinkMs((m[2]! as int) / 100) + 300;
    }
    return min(ms, 30000);
  }

  static void _publishBoard(Doc doc, PokerHand h, CashGame g) {
    final hand = {...(_hand(doc)!).cast<String, Object?>()};
    hand['board'] = [for (final c in h.board) '$c'];
    final r = h.result;
    if (r != null) {
      hand['shown'] = {
        for (final k in r.shown.keys) '${g.handSeats[k]}': [for (final c in h.players[k].hole) '$c'],
      };
    }
    doc['hand'] = hand;
  }

  /// The hand's over: stacks back to the seats, what each won.
  void _settle(Doc doc, CashTableState t, CashGame g, PokerHand h) {
    final hand = {...(_hand(doc)!).cast<String, Object?>()};
    hand['won'] = {for (final e in h.result!.winnings.entries) '${g.handSeats[e.key]}': e.value};
    doc['hand'] = hand;
    for (final hp in h.players) {
      t.seats[hp.seat]?.stack = hp.stack;
    }
    doc.addAll(t.toJson());
    doc['turn'] = null;
    doc['deadline'] = null;
    doc['endedAt'] = _now;
  }

  /// Between hands: people standing up are cashed out (and broke ones),
  /// top-ups land, bots come and go, and the next hand is dealt if a
  /// person is still here.
  Future<void> _cashNextHand(Tx tx, CashStake stake, Doc doc, CashTableState t) async {
    final bb = stake.bigBlind;
    for (var i = 0; i < cashSeats; i++) {
      final s = t.seats[i];
      if (s == null) continue;
      if (!s.bot) {
        if (s.leaving || s.stack + s.topUp == 0) {
          await _cashOut(tx, s);
          t.seats[i] = null;
          continue;
        }
        s.stack += s.topUp;
        s.topUp = 0;
        s.waiting = false;
        continue;
      }
      if (s.stack < bb * 20) {
        if (_rng.nextBool()) {
          s.stack = bb * (60 + _rng.nextInt(41));
        } else {
          t.seats[i] = null;
        }
      } else if (_rng.nextDouble() < 0.04) {
        t.seats[i] = null;
      }
    }
    if (t.people.isEmpty) {
      _cashRest(doc, t);
      return;
    }
    if (t.filled < 5 && _rng.nextDouble() < 0.3) t.seats[t.seats.indexOf(null)] = t.newBot(_rng);
    while (t.seats.nonNulls.where((s) => s.stack > 0).length < 2 && t.seats.contains(null)) {
      t.seats[t.seats.indexOf(null)] = t.newBot(_rng);
    }
    // The button moves on to the next seat with chips.
    final playing = [
      for (var i = 0; i < cashSeats; i++)
        if (t.seats[i] != null && t.seats[i]!.stack > 0) i,
    ];
    if (playing.length < 2) {
      doc.addAll(t.toJson());
      return;
    }
    var button = t.button;
    for (var k = 1; k <= cashSeats; k++) {
      final i = (t.button + k) % cashSeats;
      if (playing.contains(i)) {
        button = i;
        break;
      }
    }
    t.button = button;
    t.hands++;
    final seed = _rng.nextInt(1 << 31);
    tx.set('cashSecrets/${stake.name}', {'seed': seed});
    doc.addAll(t.toJson());
    doc['hand'] = {
      'no': t.hands,
      'seats': playing,
      'stacks': [for (final i in playing) t.seats[i]!.stack],
      'button': button,
      'moves': <Object?>[],
      'board': <Object?>[],
    };
    doc['endedAt'] = null;
    final (g, h) = _replay(stake, doc, seed);
    for (final (k, seat) in g.handSeats.indexed) {
      final s = t.seats[seat]!;
      if (!s.bot) {
        tx.set('cash/${stake.name}/hands/${s.id}', {
          'no': t.hands,
          'cards': [for (final c in h.players[k].hole) '$c'],
        });
      }
    }
    await _cashPlayOn(tx, stake, doc, t, seed);
  }

  /// No people left: the table goes back to the bots, who play on from now.
  void _cashRest(Doc doc, CashTableState t) {
    t.at = _now;
    doc.addAll(t.toJson());
    doc['hand'] = null;
    doc['turn'] = null;
    doc['deadline'] = null;
    doc['endedAt'] = null;
  }

  Future<void> _cashOut(Tx tx, CashSeat s) async {
    final w = await tx.get('wallets/${s.id}');
    if (w == null) return;
    _setWallet(tx, s.id, {...w, 'balance': (w['balance']! as int) + s.stack + s.topUp});
  }
}
