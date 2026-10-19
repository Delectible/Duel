part of 'poker_controller.dart';

/// Texas Hold'em with your party, online: the referee deals and keeps the
/// deck; this table replays its moves through the same engine, so it looks
/// and paces like a bot game. You sit at seat 0 (the server's seats are
/// turned round so you're at the bottom); your two cards come privately,
/// the board as it's turned, other hands only when shown down.
class OnlinePokerController extends PokerController {
  OnlinePokerController._(
    this.party, {
    required this.mySeat,
    required this.serverSeats,
    required this.matchId,
    required super.you,
    required super.seats,
    required super.button,
    super.pace,
    this.onReset,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super._seated(difficulty: Difficulty.normal, resultTimeout: const Duration(seconds: 10));

  /// The table for the party's current match (null if you're not in it).
  static OnlinePokerController? forMatch(
    PartyService party, {
    required Persona you,
    double pace = 1,
    VoidCallback? onReset,
    DateTime Function()? clock,
  }) {
    final m = party.match;
    final me = party.seat;
    if (m == null || me < 0) return null;
    final seats = (m['seats']! as List).cast<String>();
    final n = seats.length;
    final names = (m['names']! as List).cast<Object?>();
    final bots = (m['bots'] as List?) ?? List.filled(n, null);
    final standIns = (m['standIns'] as Map?) ?? const {};
    Persona at(int server) {
      if (server == me) return you;
      final bot = bots[server];
      if (bot is Map) return PartyBot.fromJson(bot).persona;
      // Someone who left, played by a bot until they're back.
      final standIn = standIns['$server'];
      if (standIn is Map) {
        return Persona.bot('${names[server] ?? 'Player'} (bot)', PartyBot.fromJson(standIn).look);
      }
      final member = party.members.where((x) => x.uid == seats[server]).firstOrNull;
      return Persona(
        name: '${names[server] ?? 'Player'}',
        look: Look.headband,
        avatar: member?.persona.avatar ?? const Avatar(color: AvatarColor.lilac),
      );
    }

    final state = (m['state']! as Map).cast<String, Object?>();
    final c = OnlinePokerController._(
      party,
      mySeat: me,
      serverSeats: n,
      matchId: m['id']! as String,
      you: you,
      seats: [for (var l = 0; l < n; l++) at((l + me) % n)],
      button: ((state['button']! as int) - me) % n,
      pace: pace,
      onReset: onReset,
      clock: clock,
    );
    c._catchUp();
    party.addListener(c._onData);
    return c;
  }

  final PartyService party;
  final int mySeat;
  final int serverSeats;
  final String matchId;

  /// Something went wrong between this table and the server: the screen
  /// builds a fresh one from the server's state.
  final VoidCallback? onReset;
  final DateTime Function() _clock;

  /// The move we're on in the current hand (index into its log).
  int _cursor = 0;

  /// Log index of the hand being played.
  int get _handIdx => game.handsPlayed;

  Timer? _tick;
  DateTime _heard = DateTime.now();
  Object? _turnAt;
  int? _claimed;

  int _local(int server) => (server - mySeat) % serverSeats;
  int _server(int local) => (local + mySeat) % serverSeats;

  Doc? get _match => party.match?['id'] == matchId ? party.match : null;
  bool get matchOver => _match?['status'] == 'over';
  Doc get _state => ((_match?['state'] as Map?) ?? const {}).cast<String, Object?>();
  List<Map<Object?, Object?>> get _hands =>
      ((_state['hands'] as List?) ?? const []).cast<Map<Object?, Object?>>();
  Map<Object?, Object?>? get _thisHand => _handIdx < _hands.length ? _hands[_handIdx] : null;
  List<List<Object?>> get _moves => ((_thisHand?['moves'] as List?) ?? const []).cast<List<Object?>>();

  /// Is [seat] (local) a bot? (Bots think a moment; people's moves land at once.)
  bool _isBot(int seat) {
    final bots = (_match?['bots'] as List?) ?? const [];
    final s = _server(seat);
    return s < bots.length && bots[s] != null || party.standIn(s);
  }

  /// Nobody moves while the host decides about someone who left.
  @override
  bool get yourTurn => super.yourTurn && party.paused == null;

  /// The server has finished the current hand (dealt the next or ended).
  bool get _handClosed => _hands.length > _handIdx + 1 || matchOver;

  static const _blank = PlayingCard(2, Suit.clubs);

  // --- Replaying the server's moves ------------------------------------------

  @override
  bool get _youDeal => false;

  @override
  bool _canDeal() {
    if (_thisHand == null) return false;
    // Your two cards, unless you're out of chips.
    return game.players[0].stack == 0 || _myCards(_handIdx) != null;
  }

  List<PlayingCard>? _myCards(int idx) {
    final hands = (party.mine?['hands'] as Map?) ?? const {};
    final cards = hands['$idx'];
    return cards is List ? [for (final c in cards) PlayingCard.parse('$c')] : null;
  }

  @override
  Deck? _nextDeck() {
    final idx = _handIdx;
    final dealt = game.active.length * 2;
    // After the hole cards: burn, flop x3, burn, turn, burn, river.
    const boardAt = {1: 0, 2: 1, 3: 2, 5: 3, 7: 4};
    return Deck.lazy((i) {
      if (i < dealt) return _blank;
      final k = boardAt[i - dealt];
      final board = idx < _hands.length ? (_hands[idx]['board'] as List?) ?? const [] : const [];
      return k != null && k < board.length ? PlayingCard.parse('${board[k]}') : _blank;
    });
  }

  @override
  void _dealt(PokerHand h) {
    _cursor = 0;
    final mine = _myCards(_handIdx);
    final me = handIndex(0);
    if (mine != null && me != null) {
      h.players[me].hole
        ..clear()
        ..addAll(mine);
    }
    _showCards(h);
  }

  /// Turns up the hands the server has shown for this hand.
  void _showCards(PokerHand h) {
    final shown = (_thisHand?['shown'] as Map?) ?? const {};
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
    // A runout or the showdown needs the cards turned up; a street its card.
    if (h.isAllInRunout || h.street == Street.river) return _handClosed;
    final needed = switch (h.street) {
      Street.preflop => 3,
      Street.flop => 4,
      _ => 5,
    };
    return ((_thisHand?['board'] as List?) ?? const []).length >= needed;
  }

  @override
  void _beforeAdvance(PokerHand h) => _showCards(h);

  Move? _logged() {
    final moves = _moves;
    if (_cursor >= moves.length) return null;
    final m = moves[_cursor];
    return _toMove(MoveKind.values[m[0]! as int], m[1]! as int);
  }

  static Move _toMove(MoveKind kind, int amount) => switch (kind) {
    MoveKind.fold => const Move.fold(),
    MoveKind.check => const Move.check(),
    MoveKind.call => const Move.call(),
    MoveKind.raise => Move.raiseTo(amount),
  };

  @override
  void _actFor(int seat, PokerHand h) {
    final m = _logged();
    if (m == null) {
      // Yours: the buttons are up. Someone else's: wait for the server.
      if (seat != 0) _park(_step);
      return;
    }
    final think = seat == 0
        ? 0
        : _isBot(seat)
        ? (youAreIn ? 600 + _rng.nextInt(600) : 250 + _rng.nextInt(200))
        : 250;
    _after(think, () {
      _cursor++;
      h.apply(m);
      _afterMove();
    });
  }

  @override
  void act(Move move) {
    if (!yourTurn || _logged() != null) return;
    _cursor++;
    hand!.apply(move);
    _afterMove();
    final send = {'kind': move.kind.name, 'amount': move.amount};
    unawaited(
      party.move(send).then((e) {
        if (e != null && !_disposed) onReset?.call();
      }),
    );
  }

  @override
  void _handEnded() => _cursor = 0;

  /// New moves, cards or a new hand from the server: carry on.
  void _onData() {
    if (_disposed) return;
    final m = _match;
    if (m == null) return;
    if (m['turnAt'] != _turnAt) {
      _turnAt = m['turnAt'];
      _heard = _clock();
    }
    final parked = _parked;
    if (parked != null) {
      _parked = null;
      parked();
    } else {
      _notify();
    }
  }

  @override
  void start() {
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _second());
    if (game.isOver || game.players[0].stack == 0 || matchOver && _hands.length <= game.handsPlayed) {
      phase = TablePhase.finished;
      _notify();
      return;
    }
    _newHand();
  }

  /// Plays every finished hand straight through (opening the table, or
  /// coming back to it), so the animated hand is the one being played.
  void _catchUp() {
    while (_handIdx < _hands.length - 1 && !game.isOver) {
      final h = game.startHand(deck: _nextDeck());
      _dealt(h);
      for (final raw in _moves) {
        _advance(h);
        h.apply(_toMove(MoveKind.values[raw[0]! as int], raw[1]! as int));
      }
      _advance(h);
      game.finishHand();
      handNumber++;
    }
  }

  void _advance(PokerHand h) {
    while (h.result == null && h.toAct == null) {
      _showCards(h);
      h.nextStreet();
    }
  }

  // --- The final standings ---------------------------------------------------

  /// Everyone placed so far, best first (all of them once it's over).
  List<({int place, Persona who, bool you})> get lineup {
    final places = (_state['places'] as Map?) ?? const {};
    final list = [
      for (final e in places.entries)
        (
          place: e.value as int,
          who: personas[_local(int.parse('${e.key}'))],
          you: _local(int.parse('${e.key}')) == 0,
        ),
    ]..sort((a, b) => a.place.compareTo(b.place));
    return list;
  }

  /// It ended with only bots left: they were ranked by their chances.
  bool get simulated => _state['simulated'] == true;

  // --- The turn clock --------------------------------------------------------

  int get _msLeft {
    final m = _match;
    final d = m?['deadline'] as int?;
    final at = m?['turnAt'] as int?;
    if (d == null || at == null || m?['status'] != 'live') return 0;
    return (d - at) - _clock().difference(_heard).inMilliseconds;
  }

  /// Seconds left for the person whose turn it is on the server.
  @override
  int? get turnSecondsLeft {
    final m = _match;
    if (m == null || m['status'] != 'live' || m['turn'] == null || m['paused'] != null) return null;
    // The server allows extra while phones show the bots' moves; the
    // clock shows a person's 45 seconds.
    return (_msLeft / 1000).ceil().clamp(0, 45);
  }

  /// A person ran out of time: claim it (the referee moves for them).
  void _second() {
    if (_disposed) return;
    final m = _match;
    if (m == null || m['status'] != 'live') return;
    _notify();
    final v = m['version'] as int?;
    if (_msLeft < -1500 && _claimed != v) {
      _claimed = v;
      unawaited(party.claimTimeout());
    }
  }

  @override
  void dispose() {
    party.removeListener(_onData);
    _tick?.cancel();
    super.dispose();
  }
}
