import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../features/party/lobby.dart';
import '../account/account.dart';
import '../account/stake.dart';
import '../avatars/faces.dart';
import '../table/table_bits.dart';
import 'party.dart';

/// A card game played with the party (Crazy Eights, Go Fish, Spades): the
/// server keeps the seed, the seating and the log of moves; every phone
/// rebuilds the same table from them (turned round so you sit at 0) and
/// plays the others' moves through it as they arrive. The game's
/// controller asks [next] where it would ask a bot, and [send]s your moves.
class OnlineLink {
  OnlineLink(this.party) : _matchId = party.match!['id']! as String {
    party.addListener(_changed);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _second());
  }

  final PartyService party;
  final String _matchId;
  late final Timer _tick;
  var _disposed = false;

  /// This link's match: the party's while it's still this one, else as it
  /// last was (the party moved on and this screen is on its way out).
  Doc? get _match {
    final m = party.match;
    if (m?['id'] == _matchId) _last = m;
    return _last;
  }

  Doc? _last;
  Doc get state => ((_match?['state'] as Map?) ?? const {}).cast<String, Object?>();

  bool get live => _match?['status'] == 'live';
  int get n => state['n']! as int;
  int get seed => state['seed']! as int;
  Doc get options => ((state['options'] as Map?) ?? const {}).cast<String, Object?>();

  /// Engine position -> match seat (null while Spades partners are picked).
  List<int>? get order => (state['order'] as List?)?.cast<int>();
  bool get seated => order != null;

  int get _myPos => order!.indexOf(party.seat);

  /// Your seat on this phone (0) from an engine position, and back.
  int local(int pos) => (pos - _myPos) % n;
  int pos(int local) => (local + _myPos) % n;

  int get localDealer => local(state['dealer']! as int);
  Random get rng => Random(seed);

  /// Who sits at each local seat (you at 0).
  List<Persona> personas(Persona you) {
    final m = _match!;
    final seats = (m['seats']! as List).cast<String>();
    final names = (m['names']! as List).cast<Object?>();
    final bots = (m['bots'] as List?) ?? const [];
    return [
      for (var l = 0; l < n; l++)
        () {
          final seat = order![pos(l)];
          if (seat == party.seat) return you;
          final bot = bots[seat];
          if (bot is Map) return PartyBot.fromJson(bot).persona;
          final member = party.members.where((x) => x.uid == seats[seat]).firstOrNull;
          return Persona(
            name: '${names[seat] ?? 'Player'}',
            look: Look.headband,
            avatar: member?.persona.avatar ?? Avatar.forName('${names[seat]}'),
          );
        }(),
    ];
  }

  List<Map<Object?, Object?>> get moves =>
      ((state['moves'] as List?) ?? const []).cast<Map<Object?, Object?>>();

  /// Moves already played on this table.
  int cursor = 0;

  /// The next move to show (the local player in 'p'), or null while
  /// waiting for it (or while the game is paused).
  Map<String, Object?>? next() {
    if (party.paused != null) return null;
    final list = moves;
    if (cursor >= list.length) return null;
    final m = list[cursor].cast<String, Object?>();
    return {...m, 'p': local(m['p']! as int)};
  }

  /// Called once when a new move arrives (or the pause lifts).
  VoidCallback? waiting;

  /// Plays your move: counted as shown, sent to the referee. If it's
  /// refused the screen is rebuilt from the server's state ([onReset]).
  void send(Doc move) {
    cursor++;
    unawaited(
      party.move(move).then((e) {
        if (e != null && !_disposed) onReset?.call();
      }),
    );
  }

  VoidCallback? onReset;

  /// Seconds left on whoever's turn it is (the server's clock).
  int get secondsLeft {
    final m = _match;
    final d = m?['deadline'] as int?, at = m?['turnAt'] as int?;
    if (d == null || at == null || !live) return 0;
    return (((d - at) - DateTime.now().difference(_heard).inMilliseconds) / 1000).ceil().clamp(0, 999);
  }

  DateTime _heard = DateTime.now();
  Object? _turnAt;
  int? _claimed;

  void _changed() {
    if (_disposed) return;
    final m = _match;
    if (m?['turnAt'] != _turnAt) {
      _turnAt = m?['turnAt'];
      _heard = DateTime.now();
    }
    final w = waiting;
    if (w != null && next() != null) {
      waiting = null;
      w();
    }
  }

  /// A person ran out of time: claim it (the referee moves for them).
  void _second() {
    final m = _match;
    if (_disposed || m == null || !live || m['paused'] != null) return;
    final d = m['deadline'] as int?, at = m['turnAt'] as int?;
    if (d == null || at == null) return;
    final left = (d - at) - DateTime.now().difference(_heard).inMilliseconds;
    if (left < -1500 && _claimed != m['version']) {
      _claimed = m['version'] as int?;
      unawaited(party.claimTimeout());
    }
  }

  /// Leaving mid-game: say what happens, forfeit, back to the party.
  Future<void> leave(BuildContext context, StakeTicket ticket, {required bool over}) async {
    if (party.inGame && !over) {
      if (!await confirmLeave(context, ticket, online: leaveNote(party))) return;
      await party.forfeit(stake: ticket.stake);
    }
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// Rematch (null once you've asked, or while it's still going).
  VoidCallback? get rematch {
    final m = _match;
    if (m == null || m['status'] != 'over') return null;
    if (((m['rematch'] as List?) ?? const []).contains(party.uid)) return null;
    return () => unawaited(party.rematch());
  }

  String get rematchLabel {
    final m = _match;
    if (m == null || m['status'] != 'over') return 'Still playing…';
    return ((m['rematch'] as List?) ?? const []).contains(party.uid) ? 'Waiting…' : 'Rematch';
  }

  void dispose() {
    _disposed = true;
    _tick.cancel();
    party.removeListener(_changed);
  }
}

/// The online frame round a card game's screen: a fresh table (and stake)
/// per match, the pause while the host decides about someone who left,
/// and the card when the game stops early.
class OnlineGameFrame extends StatefulWidget {
  const OnlineGameFrame({super.key, required this.party, required this.gameId, required this.builder});

  final PartyService party;
  final String gameId;
  final Widget Function(OnlineLink link, StakeTicket ticket) builder;

  @override
  State<OnlineGameFrame> createState() => _OnlineGameFrameState();
}

class _OnlineGameFrameState extends State<OnlineGameFrame> {
  OnlineLink? _link;
  StakeTicket? _ticket;
  String? _matchId;
  var _resets = 0;

  PartyService get party => widget.party;

  @override
  void initState() {
    super.initState();
    party.showing(this, widget.gameId);
    party.addListener(_follow);
    _follow();
  }

  void _follow() {
    final m = party.match;
    if (!mounted || m == null || m['game'] != widget.gameId) return;
    if (m['id'] != _matchId) {
      _matchId = m['id'] as String?;
      _link?.dispose();
      _link = OnlineLink(party)..onReset = _reset;
      _ticket = party.ticket(AccountScope.maybeRead(context) ?? Account(), m);
    }
    // Stopped early (someone left, the host ended it): settle the stake.
    final r = (m['result'] as Map?) ?? const {};
    final t = _ticket;
    if (m['status'] == 'over' && t != null && !t.settled && r['reason'] != 'won' && r['reason'] != 'draw') {
      t.settle(
        r['reason'] == 'ended' ? Outcome.tie : (r['winner'] == party.seat ? Outcome.win : Outcome.loss),
      );
    }
    setState(() {});
  }

  /// Out of step with the server: a fresh table from its state.
  void _reset() {
    if (!mounted) return;
    setState(() {
      _link?.dispose();
      _link = OnlineLink(party)..onReset = _reset;
      _resets++;
    });
  }

  @override
  void dispose() {
    party.removeListener(_follow);
    party.hidden(this);
    _link?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final link = _link, ticket = _ticket;
    if (link == null || ticket == null) return const Scaffold(body: SizedBox.shrink());
    final m = party.match;
    final r = (m?['result'] as Map?) ?? const {};
    final early =
        m?['id'] == _matchId && m?['status'] == 'over' && r['reason'] != 'won' && r['reason'] != 'draw';
    return Stack(
      children: [
        KeyedSubtree(key: ValueKey('$_matchId-$_resets'), child: widget.builder(link, ticket)),
        if (party.paused != null && !early) Positioned.fill(child: PausedCard(party: party)),
        if (early)
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: GameOverCard(
                face: (AccountScope.maybeRead(context) ?? Account()).persona,
                title: r['reason'] == 'ended' ? 'Game ended' : 'Game over',
                subtitle: r['reason'] == 'ended'
                    ? 'The game was ended.${ticket.stake > 0 ? ' Your stake is back.' : ''}'
                    : (r['winner'] == party.seat ? 'Everyone else left: you win.' : 'You ran out of time.'),
                ticket: ticket,
                won: r['winner'] == party.seat,
                onAgain: link.rematch,
                againLabel: link.rematchLabel,
                leaveLabel: 'Back to party',
                onLeave: () => Navigator.of(context).popUntil((route) => route.isFirst),
              ),
            ),
          ),
      ],
    );
  }
}
