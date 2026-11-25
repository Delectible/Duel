part of 'referee.dart';

/// The shared blackjack tables: one per [BjTable], the same for everyone
/// with the app, each with its own house rules. Bots sit there all the
/// time; once a person sits down, rounds are dealt and played here, bots
/// and all. Bets come straight off the wallet (no buy-in): the bet when the
/// cards are dealt, the rest (doubles, splits, insurance, the win) when the
/// round is settled.
///
/// Documents (never expire):
/// - `bj/{table}`: `seats` (five: null, or {name, bot, look, style, chips}
///   for a bot, {id, name, avatar} for a person, with `skips`, `timeouts`,
///   `leaving`), `phase` (idle / betting / insurance / playing / done),
///   `no` (the round), `bets` (by seat), `wants` (people's bets while
///   betting), `answers` (people's insurance), `insured` (once settled:
///   seats that took it), `moves` ([seat, move]), `cards` (dealt so far,
///   in order; the dealer's hole card null until it turns: `hole` is its
///   index), `turn`, `deadline`, `turnAt`, `endedAt`, `payouts` (seat ->
///   net, once done), `left` / `decks` (the shoe), `shuffles`, `version`.
/// - `bjSecrets/{table}`: the shoe's `seed` and `pos` (cards dealt from it
///   before this round).
extension BjTables on Referee {
  static const bjTurn = Duration(seconds: 25);
  static const bjBetting = Duration(seconds: 15);
  static const bjInsurance = Duration(seconds: 12);

  /// A table nobody's phone has moved on for this long: everyone at it has
  /// gone (closed the app), and they're stood up.
  static const bjStale = Duration(minutes: 2);

  /// How long a finished round stays up before betting opens again.
  static const bjPause = Duration(seconds: 4);

  /// Rounds sat out (no bet) before you're stood up.
  static const bjMaxSkips = 3;

  static const _looks = ['cap', 'shades', 'fin', 'spiky'];

  /// Every table, caught up to now, and the one you're sitting at.
  Future<Doc> bjLobby(Player p) => store.transaction((tx) async {
    final tables = <Doc>[];
    String? mine;
    for (final table in bjTables) {
      final doc = await _bjTable(tx, table);
      final secret = await _bjSecret(tx, table);
      // Everyone at it closed the app: their turns run out and they're
      // stood up; then the table goes quiet.
      if (_bjPeople(doc).isNotEmpty &&
          (await _bjClearStale(tx, table, doc, secret) ||
              await _bjCatchUp(tx, table, doc, secret, grace: const Duration(seconds: 60)))) {
        _bump(doc);
        _bjPut(tx, table, doc, secret);
      }
      if (_bjPeople(doc).isEmpty && _bjShuffleBots(table, doc)) {
        _bump(doc);
        _bjPut(tx, table, doc, secret);
      }
      if (_bjPeople(doc).any((s) => s['id'] == p.uid)) mine = table.id;
      tables.add(doc);
    }
    return {'tables': tables, 'mine': mine};
  });

  /// Sits [p] at [tableId], in [seat] if it's open (else any open seat, or
  /// a bot's when the table's full).
  Future<Doc> bjSit(Player p, String tableId, {int? seat}) => store.transaction((tx) async {
    final table = _bjTableOf(tableId);
    for (final other in bjTables) {
      if (other == table) continue;
      final o = await tx.get('bj/${other.id}');
      // Still seated at another table (the app closed there): you get up
      // from it first, paid for any round in play.
      final at = o == null ? -1 : _bjSeats(o).indexWhere((s) => s?['id'] == p.uid);
      if (o != null && at >= 0) {
        final os = await _bjSecret(tx, other);
        await _bjStandUp(tx, other, o, os, at);
        _bump(o);
        _bjPut(tx, other, o, os);
      }
    }
    final doc = await _bjTable(tx, table);
    final secret = await _bjSecret(tx, table);
    final seats = _bjSeats(doc);
    if (seats.any((s) => s?['id'] == p.uid)) return doc;
    final w = await tx.get('wallets/${p.uid}');
    if (w == null) throw const RefereeError(409, 'Your balance is still being set up: try again in a moment');
    final balance = w['balance']! as int;
    if (balance < table.unlock) {
      throw RefereeError(409, '${table.name} opens once your balance reaches ${table.unlock}');
    }
    if (balance < table.min) throw RefereeError(409, 'You need ${table.min} to play at the ${table.name}');
    var at = seat != null && seat >= 0 && seat < bjSeatCount && seats[seat] == null
        ? seat
        : seats.indexOf(null);
    if (at < 0) {
      final bots = [
        for (var i = 0; i < bjSeatCount; i++)
          if (seats[i]!['bot'] == true && !_bjInRound(doc, i)) i,
      ];
      if (bots.isEmpty) throw const RefereeError(409, 'The table is full');
      at = bots[_rng.nextInt(bots.length)];
    }
    seats[at] = {
      'id': p.uid,
      'name': Referee.cleanName(p.name),
      'avatar': p.avatar,
      'skips': 0,
      'timeouts': 0,
    };
    doc['seats'] = [
      for (final x in seats) x == null ? null : {...x},
    ];
    if (doc['phase'] == 'idle' || doc['phase'] == null) _bjOpenBetting(table, doc);
    _bump(doc);
    _bjPut(tx, table, doc, secret);
    return doc;
  });

  /// [p]'s bet for the coming round (0 = sitting this one out). Once every
  /// person has answered, the cards go out.
  Future<Doc> bjBet(Player p, String tableId, int amount) => store.transaction((tx) async {
    final table = _bjTableOf(tableId);
    final doc = await _bjTable(tx, table);
    final secret = await _bjSecret(tx, table);
    final seat = _bjSeatOf(doc, p.uid);
    if (doc['phase'] != 'betting') {
      throw const RefereeError(409, 'Betting is closed: wait for the next round');
    }
    if (amount != 0) {
      if (amount < table.min || amount > table.max) {
        throw RefereeError(400, 'Bet ${table.min} to ${table.max}');
      }
      final balance = (await tx.get('wallets/${p.uid}'))?['balance'] as int? ?? 0;
      if (balance < amount) throw const RefereeError(409, "Your balance doesn't cover that");
    }
    final wants = _bjMap(doc['wants']);
    wants['$seat'] = amount;
    doc['wants'] = wants;
    if (_bjPeople(doc).every((s) => wants.containsKey('${_bjSeatOf(doc, s['id']! as String)}'))) {
      await _bjDeal(tx, table, doc, secret);
    }
    _bump(doc);
    _bjPut(tx, table, doc, secret);
    return doc;
  });

  /// [p]'s answer to insurance.
  Future<Doc> bjInsure(Player p, String tableId, bool yes) => store.transaction((tx) async {
    final table = _bjTableOf(tableId);
    final doc = await _bjTable(tx, table);
    final secret = await _bjSecret(tx, table);
    final seat = _bjSeatOf(doc, p.uid);
    if (doc['phase'] != 'insurance') throw const RefereeError(409, 'No insurance on offer');
    final answers = _bjMap(doc['answers']);
    answers['$seat'] = yes;
    doc['answers'] = answers;
    final waiting = [
      for (var s = 0; s < bjSeatCount; s++)
        if (_bjSeats(doc)[s]?['id'] != null && _bjBet(doc, s) != null && !answers.containsKey('$s')) s,
    ];
    if (waiting.isEmpty) await _bjResolveInsurance(tx, table, doc, secret);
    _bump(doc);
    _bjPut(tx, table, doc, secret);
    return doc;
  });

  /// [p]'s move ([version]: the table as they saw it).
  Future<Doc> bjMove(Player p, String tableId, int version, String move) => store.transaction((tx) async {
    final table = _bjTableOf(tableId);
    final doc = await _bjTable(tx, table);
    final secret = await _bjSecret(tx, table);
    if (doc['version'] != version) throw const RefereeError(409, 'Out of date: the table moved on');
    final seat = _bjSeatOf(doc, p.uid);
    if (doc['phase'] != 'playing' || doc['turn'] != seat) throw const RefereeError(409, 'Not your turn');
    final m = BjMove.values.where((v) => v.name == move).firstOrNull;
    if (m == null) throw const RefereeError(400, 'Not a move');
    final r = _bjReplay(table, doc, secret);
    final balance = (await tx.get('wallets/${p.uid}'))?['balance'] as int? ?? 0;
    // What they can still cover: the wallet, less what doubles and splits
    // already put on the table this round.
    final free = balance - (r.round.staked(seat) - _bjBet(doc, seat)!);
    if (!r.round.moves(balance: free).contains(m)) throw const RefereeError(409, "You can't do that now");
    _bjMoves(doc).add([seat, m.name]);
    (_bjSeats(doc)[seat]!)['timeouts'] = 0;
    await _bjPlayOn(tx, table, doc, secret);
    _bump(doc);
    _bjPut(tx, table, doc, secret);
    return doc;
  });

  /// Moves the table on when something's due: betting closes, insurance
  /// runs out, a turn runs out (stood for them; twice and they're stood
  /// up), or the next round opens. Any phone at the table asks.
  Future<Doc> bjTick(Player p, String tableId) => store.transaction((tx) async {
    final table = _bjTableOf(tableId);
    final doc = await _bjTable(tx, table);
    final secret = await _bjSecret(tx, table);
    if (!_bjPeople(doc).any((s) => s['id'] == p.uid)) return doc;
    if (!await _bjStep(tx, table, doc, secret)) return doc;
    _bump(doc);
    _bjPut(tx, table, doc, secret);
    return doc;
  });

  /// Stands [p] up: now, or (mid-round, with cards) once the round's over.
  Future<Doc> bjLeave(Player p, String tableId) => store.transaction((tx) async {
    final table = _bjTableOf(tableId);
    final doc = await _bjTable(tx, table);
    final secret = await _bjSecret(tx, table);
    final seat = _bjSeats(doc).indexWhere((s) => s?['id'] == p.uid);
    if (seat < 0) return doc;
    await _bjStandUp(tx, table, doc, secret, seat);
    if (_bjPeople(doc).isEmpty && doc['phase'] == 'betting') doc['phase'] = 'idle';
    _bump(doc);
    _bjPut(tx, table, doc, secret);
    return doc;
  });

  /// Stands up whoever's in [seat]: the seat's free at once (they can sit
  /// elsewhere straight away). Mid-round, the dealer stands for them and
  /// they're paid when it settles (`gone` remembers who to pay).
  Future<void> _bjStandUp(Tx tx, BjTable table, Doc doc, Doc secret, int seat) async {
    final seats = _bjSeats(doc);
    final uid = seats[seat]?['id'] as String?;
    if (uid == null) return;
    final midRound = _bjInRound(doc, seat) && doc['phase'] != 'done';
    if (midRound) doc['gone'] = {..._bjMap(doc['gone']), '$seat': uid};
    seats[seat] = null;
    doc['seats'] = [
      for (final x in seats) x == null ? null : {...x},
    ];
    final wants = _bjMap(doc['wants'])..remove('$seat');
    doc['wants'] = wants;
    if (midRound) {
      if (doc['phase'] == 'insurance') {
        final answers = _bjMap(doc['answers']);
        answers['$seat'] = false;
        doc['answers'] = answers;
        final waiting = [
          for (var s = 0; s < bjSeatCount; s++)
            if (_bjSeats(doc)[s]?['id'] != null && _bjBet(doc, s) != null && !answers.containsKey('$s')) s,
        ];
        if (waiting.isEmpty) await _bjResolveInsurance(tx, table, doc, secret);
      } else if (doc['turn'] == seat) {
        await _bjPlayOn(tx, table, doc, secret);
      }
    }
  }

  /// Nothing's happened at the table for a while (nobody's phone is moving
  /// it on): whoever's still seated has gone. Stands them all up.
  Future<bool> _bjClearStale(Tx tx, BjTable table, Doc doc, Doc secret) async {
    final last = doc['turnAt'] as int? ?? doc['endedAt'] as int? ?? 0;
    if (_now - last < bjStale.inMilliseconds) return false;
    var changed = false;
    for (var s = 0; s < bjSeatCount; s++) {
      if (_bjSeats(doc)[s]?['id'] != null) {
        await _bjStandUp(tx, table, doc, secret, s);
        changed = true;
      }
    }
    if (_bjPeople(doc).isEmpty && doc['phase'] == 'betting') doc['phase'] = 'idle';
    return changed;
  }

  // --- Steps ------------------------------------------------------------------

  Future<bool> _bjStep(Tx tx, BjTable table, Doc doc, Doc secret, {Duration grace = Duration.zero}) async {
    final deadline = doc['deadline'] as int?;
    final due = deadline != null && _now >= deadline + grace.inMilliseconds;
    switch (doc['phase']) {
      case 'betting':
        if (!due) return false;
        await _bjDeal(tx, table, doc, secret);
        return true;
      case 'insurance':
        if (!due) return false;
        await _bjResolveInsurance(tx, table, doc, secret);
        return true;
      case 'playing':
        if (!due) return false;
        final turn = doc['turn']! as int;
        final s = _bjSeats(doc)[turn];
        if (s != null) {
          s['timeouts'] = (s['timeouts'] as int? ?? 0) + 1;
          if ((s['timeouts']! as int) >= 2) s['leaving'] = true;
        }
        _bjMoves(doc).add([turn, BjMove.stand.name]);
        await _bjPlayOn(tx, table, doc, secret);
        return true;
      case 'done':
        final ended = doc['endedAt'] as int? ?? 0;
        if (_now < ended + (bjPause + grace).inMilliseconds) return false;
        _bjOpenBetting(table, doc);
        return true;
      default:
        if (_bjPeople(doc).isEmpty) return false;
        _bjOpenBetting(table, doc);
        return true;
    }
  }

  /// Steps an abandoned table along (a few steps per look).
  Future<bool> _bjCatchUp(Tx tx, BjTable table, Doc doc, Doc secret, {required Duration grace}) async {
    var changed = false;
    for (var i = 0; i < 20 && _bjPeople(doc).isNotEmpty; i++) {
      if (!await _bjStep(tx, table, doc, secret, grace: grace)) break;
      changed = true;
    }
    return changed;
  }

  void _bjOpenBetting(BjTable table, Doc doc) {
    if (_bjPeople(doc).isEmpty) {
      doc['phase'] = 'idle';
      doc['deadline'] = null;
      return;
    }
    doc
      ..['phase'] = 'betting'
      ..['no'] = (doc['no'] as int? ?? 0) + 1
      ..['bets'] = List<int?>.filled(bjSeatCount, null)
      ..['wants'] = <String, Object?>{}
      ..['answers'] = <String, Object?>{}
      ..['insured'] = null
      ..['moves'] = <Object?>[]
      ..['cards'] = <Object?>[]
      ..['hole'] = null
      ..['turn'] = null
      ..['payouts'] = null
      ..['gone'] = null
      ..['deadline'] = _now + bjBetting.inMilliseconds
      ..['turnAt'] = _now;
  }

  /// Bets down (people's from the wallet, bots' from their chips) and the
  /// cards out. Nobody betting: people who sat it out too often are stood
  /// up, and betting opens again.
  Future<void> _bjDeal(Tx tx, BjTable table, Doc doc, Doc secret) async {
    final seats = _bjSeats(doc);
    final wants = _bjMap(doc['wants']);
    final shoe = _bjShoe(table, secret);
    final bets = List<int?>.filled(bjSeatCount, null);
    for (var s = 0; s < bjSeatCount; s++) {
      final seat = seats[s];
      if (seat == null) continue;
      if (seat['bot'] == true) {
        final bot = _bjBot(table, seat);
        final b = bot.bet(
          min: table.min,
          max: table.max,
          chips: seat['chips']! as int,
          trueCount: shoe.trueCount,
        );
        if (b >= table.min) bets[s] = b;
        continue;
      }
      final want = wants['$s'] as int? ?? 0;
      final uid = seat['id']! as String;
      final w = await tx.get('wallets/$uid');
      final balance = w?['balance'] as int? ?? 0;
      if (want >= table.min && want <= balance && seat['leaving'] != true) {
        bets[s] = want;
        _setWallet(tx, uid, {...w!, 'balance': balance - want});
        seat['skips'] = 0;
      } else {
        seat['skips'] = (seat['skips'] as int? ?? 0) + 1;
        if ((seat['skips']! as int) >= bjMaxSkips || seat['leaving'] == true) seats[s] = null;
      }
    }
    doc['seats'] = [
      for (final x in seats) x == null ? null : {...x},
    ];
    final anyPerson = [
      for (var s = 0; s < bjSeatCount; s++)
        if (bets[s] != null && seats[s]?['id'] != null) s,
    ];
    if (anyPerson.isEmpty) {
      _bjOpenBetting(table, doc);
      return;
    }
    doc['bets'] = bets;
    doc['phase'] = 'playing';
    await _bjPlayOn(tx, table, doc, secret);
  }

  /// Insurance answered (or run out): bots decide, and play goes on.
  Future<void> _bjResolveInsurance(Tx tx, BjTable table, Doc doc, Doc secret) async {
    final seats = _bjSeats(doc);
    final answers = _bjMap(doc['answers']);
    final shoe = _bjShoe(table, secret);
    final insured = <int>[];
    for (var s = 0; s < bjSeatCount; s++) {
      final bet = _bjBet(doc, s);
      final seat = seats[s];
      if (bet == null || seat == null || bet ~/ 2 == 0) continue;
      if (seat['bot'] == true) {
        if ((seat['chips']! as int) >= bet ~/ 2 && _bjBot(table, seat).insure(shoe.trueCount)) insured.add(s);
      } else if (answers['$s'] == true) {
        final balance = (await tx.get('wallets/${seat['id']}'))?['balance'] as int? ?? 0;
        if (balance >= bet ~/ 2) insured.add(s);
      }
    }
    doc['insured'] = insured;
    doc['phase'] = 'playing';
    await _bjPlayOn(tx, table, doc, secret);
  }

  /// Plays the bots' turns, then stops at a person's turn (or insurance),
  /// or settles the round.
  Future<void> _bjPlayOn(Tx tx, BjTable table, Doc doc, Doc secret) async {
    for (var guard = 0; guard < 200; guard++) {
      final r = _bjReplay(table, doc, secret);
      final round = r.round;
      if (round.insuring) {
        doc
          ..['phase'] = 'insurance'
          ..['turn'] = null
          ..['deadline'] = _now + bjInsurance.inMilliseconds
          ..['turnAt'] = _now;
        _bjPublish(table, doc, secret, r);
        return;
      }
      if (round.settled) {
        await _bjSettle(tx, table, doc, secret, r);
        return;
      }
      final (s, _) = round.turn!;
      final seat = _bjSeats(doc)[s];
      // Someone who got up mid-round: the dealer stands for them.
      if (seat == null) {
        _bjMoves(doc).add([s, BjMove.stand.name]);
        continue;
      }
      if (seat['bot'] == true) {
        final bot = _bjBot(table, seat);
        final m = bot.decide(round.current, round.upCard, round.moves(balance: seat['chips']! as int));
        _bjMoves(doc).add([s, m.name]);
        continue;
      }
      doc
        ..['turn'] = s
        ..['deadline'] = _now + bjTurn.inMilliseconds
        ..['turnAt'] = _now;
      _bjPublish(table, doc, secret, r);
      return;
    }
  }

  /// Pays the round: people's wallets get their bet back plus the round's
  /// net (doubles, splits and insurance settle here), bots' chips move;
  /// the shoe moves on (a fresh one past the cut card); leavers go; a bot
  /// may get up or sit down.
  Future<void> _bjSettle(Tx tx, BjTable table, Doc doc, Doc secret, _BjState r) async {
    final seats = _bjSeats(doc);
    final payouts = <String, Object?>{};
    for (final s in r.round.inPlay) {
      final net = r.round.net(s);
      payouts['$s'] = net;
      final seat = seats[s];
      final goneUid = _bjMap(doc['gone'])['$s'] as String?;
      if (seat == null || goneUid != null) {
        // They got up mid-round: still paid.
        if (goneUid != null) {
          final w = await tx.get('wallets/$goneUid');
          if (w != null) {
            _setWallet(tx, goneUid, {...w, 'balance': (w['balance']! as int) + _bjBet(doc, s)! + net});
          }
        }
        continue;
      }
      if (seat['bot'] == true) {
        seat['chips'] = (seat['chips']! as int) + net;
      } else {
        final uid = seat['id']! as String;
        final w = await tx.get('wallets/$uid');
        if (w != null) _setWallet(tx, uid, {...w, 'balance': (w['balance']! as int) + _bjBet(doc, s)! + net});
      }
    }
    doc
      ..['phase'] = 'done'
      ..['turn'] = null
      ..['deadline'] = null
      ..['payouts'] = payouts
      ..['endedAt'] = _now;
    _bjPublish(table, doc, secret, r, reveal: true);
    // The shoe moves on; past the cut card a fresh one.
    secret['pos'] = (secret['pos']! as int) + r.drawn;
    if (_bjShoe(table, secret).due) {
      secret
        ..['seed'] = _rng.nextInt(1 << 31)
        ..['pos'] = 0;
      doc['shuffles'] = (doc['shuffles'] as int? ?? 0) + 1;
    }
    final fresh = _bjShoe(table, secret);
    doc
      ..['left'] = fresh.left
      ..['decks'] = table.onlineRules.decks;
    // Leavers go; broke bots go, now and then one cashes out; someone new
    // may sit down.
    for (var s = 0; s < bjSeatCount; s++) {
      final seat = seats[s];
      if (seat == null) continue;
      if (seat['leaving'] == true) seats[s] = null;
      if (seat['bot'] == true && ((seat['chips']! as int) < table.min || _rng.nextDouble() < 0.05)) {
        seats[s] = null;
      }
    }
    final open = [
      for (var s = 0; s < bjSeatCount; s++)
        if (seats[s] == null) s,
    ];
    if (open.isNotEmpty && _rng.nextDouble() < 0.15) {
      seats[open[_rng.nextInt(open.length)]] = _bjNewBot(table, seats);
    }
    doc['seats'] = [
      for (final x in seats) x == null ? null : {...x},
    ];
  }

  /// The round so far for phones: the cards dealt (the hole card hidden
  /// until [reveal]), and the shoe's count.
  void _bjPublish(BjTable table, Doc doc, Doc secret, _BjState r, {bool reveal = false}) {
    final hole = 2 * r.round.inPlay.length + 1;
    doc['hole'] = hole;
    doc['cards'] = [
      for (var i = 0; i < r.cards.length; i++)
        i == hole && !reveal && !r.round.holeShown ? null : r.cards[i].toString(),
    ];
    doc['left'] = r.shoe.left;
    doc['decks'] = table.onlineRules.decks;
  }

  // --- Replay --------------------------------------------------------------------

  Shoe _bjShoe(BjTable table, Doc secret) {
    final shoe = Shoe(Random(secret['seed']! as int), decks: table.onlineRules.decks);
    for (var i = 0; i < (secret['pos']! as int); i++) {
      shoe.draw();
    }
    return shoe;
  }

  /// The round rebuilt from the bets, insurance and moves.
  _BjState _bjReplay(BjTable table, Doc doc, Doc secret) {
    final shoe = _bjShoe(table, secret);
    final before = shoe.left;
    final round = BjRound(
      shoe: shoe,
      bets: [for (var s = 0; s < bjSeatCount; s++) _bjBet(doc, s)],
      rules: table.onlineRules,
    );
    final insured = doc['insured'] as List?;
    if (round.insuring && insured != null) round.insure({for (final s in insured) s as int});
    for (final m in _bjMoves(doc)) {
      final mv = BjMove.values.byName((m as List)[1]! as String);
      if (round.playing) round.act(mv);
    }
    final drawn = before - shoe.left;
    final copy = _bjShoe(table, secret);
    return _BjState(shoe, round, drawn, [for (var i = 0; i < drawn; i++) copy.draw()]);
  }

  // --- Docs and seats --------------------------------------------------------------

  BjTable _bjTableOf(String id) => BjTable.byId(id) ?? (throw const RefereeError(404, 'No such table'));

  Future<Doc> _bjTable(Tx tx, BjTable table) async {
    final doc = await tx.get('bj/${table.id}');
    if (doc != null) return doc;
    final seats = List<Doc?>.filled(bjSeatCount, null);
    final n = 1 + _rng.nextInt(4);
    final at = [for (var s = 0; s < bjSeatCount; s++) s]..shuffle(_rng);
    for (final s in at.take(n)) {
      seats[s] = _bjNewBot(table, seats);
    }
    return {
      'table': table.id,
      'seats': seats,
      'phase': 'idle',
      'no': 0,
      'version': 0,
      'shuffles': 0,
      'decks': table.onlineRules.decks,
      'rules': table.onlineRules.toJson(),
      'shuffledAt': _now,
    };
  }

  Future<Doc> _bjSecret(Tx tx, BjTable table) async =>
      await tx.get('bjSecrets/${table.id}') ?? {'seed': _rng.nextInt(1 << 31), 'pos': 0};

  void _bjPut(Tx tx, BjTable table, Doc doc, Doc secret) {
    tx.set('bj/${table.id}', doc);
    tx.set('bjSecrets/${table.id}', secret);
  }

  /// With nobody there, a fresh crowd every 20 minutes.
  bool _bjShuffleBots(BjTable table, Doc doc) {
    final at = doc['shuffledAt'] as int? ?? 0;
    if (_now - at < 20 * 60 * 1000) return false;
    final seats = List<Doc?>.filled(bjSeatCount, null);
    final n = 1 + _rng.nextInt(4);
    final order = [for (var s = 0; s < bjSeatCount; s++) s]..shuffle(_rng);
    for (final s in order.take(n)) {
      seats[s] = _bjNewBot(table, seats);
    }
    doc
      ..['seats'] = seats
      ..['shuffledAt'] = _now
      ..['phase'] = 'idle';
    return true;
  }

  Doc _bjNewBot(BjTable table, List<Doc?> seats) {
    final taken = {for (final s in seats) s?['name']};
    final names = [...botNames.where((n) => !taken.contains(n))]..shuffle(_rng);
    return {
      'name': names.first,
      'bot': true,
      'look': _looks[_rng.nextInt(_looks.length)],
      'style': _rng.nextInt(BjStyle.values.length),
      'chips': table.min * (20 + _rng.nextInt(40)),
    };
  }

  BjBot _bjBot(BjTable table, Doc seat) =>
      BjBot(style: BjStyle.values[seat['style'] as int? ?? 0], difficulty: table.difficulty, rng: _rng);

  static List<Doc?> _bjSeats(Doc doc) => [
    for (final s in (doc['seats']! as List)) (s as Map?)?.cast<String, Object?>(),
  ];

  static Iterable<Doc> _bjPeople(Doc doc) => _bjSeats(doc).nonNulls.where((s) => s['id'] != null);

  static List<Object?> _bjMoves(Doc doc) => (doc['moves'] ??= <Object?>[]) as List<Object?>;

  static Map<String, Object?> _bjMap(Object? m) => m is Map ? m.cast<String, Object?>() : <String, Object?>{};

  static int? _bjBet(Doc doc, int seat) {
    final bets = doc['bets'] as List?;
    return bets == null || seat >= bets.length ? null : bets[seat] as int?;
  }

  static bool _bjInRound(Doc doc, int seat) =>
      _bjBet(doc, seat) != null && doc['phase'] != 'betting' && doc['phase'] != 'idle';

  int _bjSeatOf(Doc doc, String uid) {
    final s = _bjSeats(doc).indexWhere((x) => x?['id'] == uid);
    if (s < 0) throw const RefereeError(403, "You're not at this table");
    return s;
  }
}

class _BjState {
  _BjState(this.shoe, this.round, this.drawn, this.cards);
  final Shoe shoe;
  final BjRound round;

  /// Cards drawn this round, in order.
  final int drawn;
  final List<PlayingCard> cards;
}
