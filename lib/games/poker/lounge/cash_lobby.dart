import 'dart:async';
import 'dart:math';

import 'package:duel_engine/poker/cash.dart';
import 'package:flutter/material.dart';

import '../../../core/account/account.dart';
import '../../../core/avatars/faces.dart';
import '../../../core/online/cash_service.dart';
import '../../../core/online/party.dart';
import '../../../core/session/play_setup.dart';
import '../../../core/sound/sound.dart';
import '../../../core/theme/toon.dart';
import '../ui/cash_screen.dart';
import 'lounge_modes.dart';

/// The cash tables as this phone sees them when it can't reach the shared
/// ones: the same four tables, their bots playing on in their own time
/// (worked out from the clock, so they've moved on when you come back).
abstract final class LocalCashTables {
  /// A fresh table every half hour, played forward to now.
  static const _window = 30 * 60 * 1000;

  static List<CashTableState> at(int now) => [
    for (final stake in CashStake.values)
      () {
        final w = now ~/ _window;
        final seed = stake.index * 100003 + w;
        final t = CashTableState.fresh(stake, Random(seed), w * _window);
        t.simulate(now, Random(seed ^ 0x5eed));
        return t;
      }(),
  ];
}

/// Cash Games: one table per stake, always running. Pick one, choose how
/// much to sit down with, and play. Your pips are the chips.
class CashLobbyScreen extends StatefulWidget {
  const CashLobbyScreen({super.key, this.now, this.pace = 1});

  /// The clock (tests).
  final int Function()? now;
  final double pace;

  @override
  State<CashLobbyScreen> createState() => _CashLobbyScreenState();
}

class _CashLobbyScreenState extends State<CashLobbyScreen> {
  /// The tables shown: the shared ones when the server answers, else this
  /// phone's (marked Local). Never waits on the network to show something.
  late List<CashTableState> _tables = LocalCashTables.at(_now());

  /// Opening: waiting a moment for the shared tables before showing any
  /// (so this phone's don't flash up first).
  var _finding = false;
  var _online = false;

  /// You're seated at this shared table (the app was closed at it).
  String? _mine;
  Map<String, Doc> _docs = const {};
  Timer? _refresh;
  CashService? _service;

  int _now() => widget.now?.call() ?? DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    final party = PlaySetupScope.read(context)?.party;
    if (party != null) {
      _service = CashService(party);
      _finding = true;
    }
    unawaited(_load(first: true));
    // The tables move on while you watch; offline, it keeps trying.
    _refresh = Timer.periodic(const Duration(seconds: 15), (_) => unawaited(_load()));
  }

  Future<void> _load({bool first = false}) async {
    final service = _service;
    if (service != null) {
      try {
        // The first look waits a little longer (it may be signing in); after
        // that the local tables show and it keeps trying in the background.
        final r = await service.lobby(limit: Duration(seconds: first ? 4 : 5));
        if (!mounted) return;
        setState(() {
          _finding = false;
          _online = true;
          _mine = r.mine;
          _docs = {for (final d in r.tables) '${d['stake']}': d};
          _tables = [for (final d in r.tables) CashTableState.fromJson(d)];
        });
        return;
      } on Object {
        // No connection, or the server's down: this phone's tables.
      }
    }
    if (!mounted) return;
    setState(() {
      _finding = false;
      _online = false;
      _mine = null;
      _tables = LocalCashTables.at(_now());
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _open(Doc doc) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CashScreen.online(service: _service!, doc: doc, pace: widget.pace),
      ),
    );
    if (mounted) unawaited(_load());
  }

  Future<void> _sit(CashTableState table) async {
    final account = AccountScope.read(context);
    // Back at your seat (the app was closed at this table).
    if (_online && _mine == table.stake.name) return _open(_docs[_mine]!);
    // Pick an open seat (a full table: a bot gets up for you).
    int? seat;
    if (table.seats.contains(null)) {
      seat = await chooseSeat(context, table);
      if (seat == null || !mounted) return;
    }
    final pips = await chooseBuyIn(context, stake: table.stake, balance: account.balance);
    if (pips == null || !mounted) return;
    if (_online) {
      try {
        final doc = await _service!.sit(table.stake, pips, seat: seat);
        if (mounted) await _open(doc);
        return;
      } on OnlineError catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(e.message)));
        }
        return;
      } on Object {
        // Lost the connection just now: play here instead.
        if (!mounted) return;
        setState(() => _online = false);
      }
    }
    if (!mounted) return;
    account.cashIn(pips);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CashScreen(table: table, buyIn: pips, seat: seat, pace: widget.pace),
      ),
    );
    if (mounted) unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    return Scaffold(
      backgroundColor: Lounge.navy,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              key: const Key('cash lobby'),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                Row(
                  children: [
                    ToonButton(
                      key: const Key('lobby back'),
                      color: Lounge.panel,
                      padding: const EdgeInsets.all(8),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.arrow_back_rounded, size: 24, color: Lounge.cream),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cash Games',
                            style: Toon.text(28, weight: FontWeight.w700, color: Lounge.gold),
                          ),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Tables that never close',
                                  style: Toon.text(14, weight: FontWeight.w500, color: Lounge.dim),
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (!_finding) CashWhere(online: _online),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('cash info'),
                      tooltip: 'How cash games work',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LoungeModeScreen(mode: LoungeMode.cash),
                        ),
                      ),
                      icon: const Icon(Icons.info_outline_rounded, color: Lounge.cream),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Lounge.night,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Lounge.gold, width: 2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded, color: Lounge.gold, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        account.currency == CurrencyChoice.pips ? 'Your pips' : 'Your money',
                        style: Toon.text(14, weight: FontWeight.w600, color: Lounge.dim),
                      ),
                      const Spacer(),
                      Text(
                        account.money(account.balance),
                        key: const Key('lobby balance'),
                        style: Toon.text(17, weight: FontWeight.w700, color: Lounge.lamp),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_finding)
                  const Padding(
                    key: Key('finding tables'),
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 3, color: Lounge.gold),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Finding the tables…',
                          style: TextStyle(fontFamily: 'Fredoka', color: Lounge.dim, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                for (final t in _finding ? const <CashTableState>[] : _tables)
                  _TableCard(
                    table: t,
                    balance: account.balance,
                    yours: _online && _mine == t.stake.name,
                    friends: {
                      for (final m in PlaySetupScope.of(context).party?.members ?? const <PartyMember>[])
                        if (!m.you) m.uid,
                    },
                    onSit: () => _sit(t),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.table,
    required this.balance,
    required this.onSit,
    this.yours = false,
    this.friends = const {},
  });

  final CashTableState table;
  final int balance;
  final VoidCallback onSit;

  /// You're seated here (shared tables).
  final bool yours;

  /// Your party's people: marked at the table.
  final Set<String> friends;

  @override
  Widget build(BuildContext context) {
    final money = (AccountScope.maybeRead(context) ?? Account()).money;
    final s = table.stake;
    final locked = balance < s.unlockAt;
    final broke = !locked && balance < s.minBuyIn;
    final people = table.people.toList();
    final full = table.filled >= cashSeats && table.seats.nonNulls.every((x) => !x.bot);
    final why = yours
        ? null
        : locked
        ? 'Unlocks at ${money(s.unlockAt)}'
        : broke
        ? 'Needs ${money(s.minBuyIn)} to sit'
        : full
        ? 'Full'
        : null;
    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: GestureDetector(
        key: Key('table ${s.name}'),
        onTap: why == null
            ? () {
                Sound.play(Sfx.tap, gain: 0.6);
                onSit();
              }
            : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Lounge.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: locked ? Lounge.dim.withValues(alpha: 0.4) : Lounge.gold, width: 2),
            boxShadow: const [BoxShadow(color: Lounge.night, offset: Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.label,
                          style: Toon.text(19, weight: FontWeight.w700, color: Lounge.cream),
                        ),
                        Text(
                          'Blinds ${chips(s.smallBlind)} / ${chips(s.bigBlind)} · '
                          'buy in ${chips(s.minBuyIn)}–${chips(s.maxBuyIn)}',
                          style: Toon.text(13, weight: FontWeight.w500, color: Lounge.dim),
                        ),
                      ],
                    ),
                  ),
                  if (locked)
                    const Icon(Icons.lock_rounded, color: Lounge.dim)
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: why == null ? Lounge.gold : Lounge.night,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        yours ? 'Back to your seat' : (why ?? 'Sit down'),
                        style: Toon.text(
                          13,
                          weight: FontWeight.w700,
                          color: why == null ? Lounge.night : Lounge.dim,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // Who's there: faces round the table, open seats outlined.
              Row(
                children: [
                  for (final seat in table.seats)
                    Expanded(
                      child: Center(
                        child: seat == null
                            ? Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Lounge.dim.withValues(alpha: 0.4), width: 2),
                                ),
                              )
                            : Container(
                                decoration: seat.bot
                                    ? null
                                    : BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Lounge.gold, width: 2.5),
                                      ),
                                child: Face(
                                  seat.bot
                                      ? Persona.bot(seat.name, Look.values.asNameMap()[seat.look] ?? Look.cap)
                                      : Persona(
                                          name: seat.name,
                                          look: Look.headband,
                                          avatar: seat.avatar == null
                                              ? Avatar.forName(seat.name)
                                              : Avatar.fromJson(seat.avatar!),
                                        ),
                                  size: 34,
                                ),
                              ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                people.isEmpty
                    ? '${table.filled} at the table · all bots'
                    : '${people.length} ${people.length == 1 ? 'person' : 'people'} here: '
                          '${people.map((p) => friends.contains(p.id) ? '★ ${p.name}' : p.name).join(', ')}',
                key: Key('table ${s.name} people'),
                style: Toon.text(
                  13,
                  weight: FontWeight.w600,
                  color: people.isEmpty ? Lounge.dim : Lounge.lamp,
                ),
              ),
              if (locked) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.lock_rounded, size: 14, color: Lounge.gold),
                    const SizedBox(width: 4),
                    Text(
                      why!,
                      style: Toon.text(13, weight: FontWeight.w700, color: Lounge.gold),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Where to sit: the table from above, the open seats to tap. Null if you
/// change your mind.
Future<int?> chooseSeat(BuildContext context, CashTableState table) => showModalBottomSheet<int>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  backgroundColor: Lounge.navy,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      key: const Key('pick seat'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Pick a seat · ${table.stake.label}',
            style: Toon.text(22, weight: FontWeight.w700, color: Lounge.gold),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap an open seat.',
            style: Toon.text(14, weight: FontWeight.w500, color: Lounge.dim),
          ),
          const SizedBox(height: 14),
          // The table fits the screen either way up.
          SizedBox(
            height: min(MediaQuery.sizeOf(context).width / 1.5, MediaQuery.sizeOf(context).height * 0.5),
            child: LayoutBuilder(
              builder: (context, box) {
                final h = box.maxHeight, w = min(box.maxWidth, h * 1.6);
                // Round the felt, clockwise from the bottom.
                Offset spot(int i) {
                  final a = pi / 2 + i * 2 * pi / cashSeats;
                  return Offset(w / 2 + cos(a) * w * 0.40, h / 2 + sin(a) * h * 0.36);
                }

                return Center(
                  child: SizedBox(
                    width: w,
                    child: Stack(
                      children: [
                        Positioned(
                          left: w * 0.14,
                          right: w * 0.14,
                          top: h * 0.18,
                          bottom: h * 0.18,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Lounge.felt,
                              borderRadius: BorderRadius.circular(h),
                              border: Border.all(color: const Color(0xFF8A5A2B), width: 8),
                            ),
                          ),
                        ),
                        for (var i = 0; i < cashSeats; i++)
                          Positioned(
                            left: spot(i).dx - 34,
                            top: spot(i).dy - 30,
                            width: 68,
                            height: 60,
                            child: table.seats[i] == null
                                ? GestureDetector(
                                    key: Key('pick seat $i'),
                                    onTap: () => Navigator.pop(context, i),
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: Lounge.gold,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Lounge.night, width: 2.5),
                                          ),
                                          child: const Icon(Icons.add_rounded, color: Lounge.night),
                                        ),
                                        Text(
                                          'Sit here',
                                          style: Toon.text(11, weight: FontWeight.w700, color: Lounge.lamp),
                                        ),
                                      ],
                                    ),
                                  )
                                : Column(
                                    children: [
                                      Face(
                                        table.seats[i]!.bot
                                            ? Persona.bot(
                                                table.seats[i]!.name,
                                                Look.values.asNameMap()[table.seats[i]!.look] ?? Look.cap,
                                              )
                                            : Persona(
                                                name: table.seats[i]!.name,
                                                look: Look.headband,
                                                avatar: table.seats[i]!.avatar == null
                                                    ? Avatar.forName(table.seats[i]!.name)
                                                    : Avatar.fromJson(table.seats[i]!.avatar!),
                                              ),
                                        size: 40,
                                      ),
                                      Text(
                                        table.seats[i]!.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Toon.text(11, weight: FontWeight.w600, color: Lounge.cream),
                                      ),
                                    ],
                                  ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  ),
);
