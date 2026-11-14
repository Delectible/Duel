import 'dart:async';
import 'dart:math';

import 'package:duel_engine/poker/cash.dart';
import 'package:flutter/material.dart';

import '../../../core/account/account.dart';
import '../../../core/help/game_guide.dart';
import '../../../core/online/cash_service.dart';
import '../../../core/online/party.dart';
import '../../../core/table/table_bits.dart';
import '../../../core/theme/toon.dart';
import 'action_bar.dart';
import 'poker_controller.dart';
import 'poker_guide.dart';
import 'table_stats.dart';
import 'table_view.dart';

/// How many pips to sit down (or buy back in, or top up) with: from the
/// table's minimum (or [least]) up to its full buy-in, never more than
/// you have. Null if you change your mind.
Future<int?> chooseBuyIn(
  BuildContext context, {
  required CashStake stake,
  required int balance,
  String title = 'Buy in',
  String action = 'Sit down',
  int? most,
  int? least,
}) {
  final bb = stake.bigBlind;
  final top = min(most ?? stake.maxBuyIn, balance);
  final bottom = min(least ?? stake.minBuyIn, top);
  if (top <= 0) return Future.value(null);
  var pick = top;
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Toon.paper,
    builder: (context) => StatefulBuilder(
      builder: (context, set) => SafeArea(
        child: SingleChildScrollView(
          key: const Key('buy in'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$title · ${stake.label}', style: Toon.text(22, weight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Blinds ${chips(stake.smallBlind)} / ${chips(bb)} · ${chips(bottom)} to ${chips(top)}',
                style: Toon.text(14, weight: FontWeight.w500, color: Toon.muted),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  chips(pick),
                  key: const Key('buy in amount'),
                  style: Toon.text(34, weight: FontWeight.w800),
                ),
              ),
              Center(
                child: Text(
                  '${(pick / bb).round()} big blinds',
                  style: Toon.text(13, weight: FontWeight.w500, color: Toon.muted),
                ),
              ),
              if (top > bottom)
                Slider(
                  key: const Key('buy in slider'),
                  value: pick.toDouble(),
                  min: bottom.toDouble(),
                  max: top.toDouble(),
                  divisions: max(1, (top - bottom) ~/ bb),
                  onChanged: (v) => set(() => pick = (v / bb).round() * bb),
                ),
              const SizedBox(height: 8),
              ToonButton(
                key: const Key('buy in go'),
                color: Toon.green,
                onPressed: () => Navigator.pop(context, pick.clamp(bottom, top)),
                child: Text(action),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A cash table on this phone. Your chips come from your balance and go
/// back to it when you leave.
class CashScreen extends StatefulWidget {
  const CashScreen({super.key, required this.table, required this.buyIn, this.seat, this.pace = 1, this.seed})
    : service = null,
      doc = null;

  /// At a shared table online (already seated: [doc] is the table).
  CashScreen.online({super.key, required CashService this.service, required Doc this.doc, this.pace = 1})
    : table = CashTableState.fromJson(doc),
      buyIn = 0,
      seat = null,
      seed = null;

  final CashTableState table;
  final int buyIn;

  /// The open seat you picked (local tables).
  final int? seat;
  final CashService? service;
  final Doc? doc;
  final double pace;
  final int? seed;

  @override
  State<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends State<CashScreen> {
  late final Account _account = AccountScope.maybeRead(context) ?? Account();
  late final PokerController _c =
      (widget.service == null
            ? CashController.sit(
                table: widget.table,
                buyIn: widget.buyIn,
                seat: widget.seat,
                you: _account.persona,
                pace: widget.pace,
                rng: widget.seed == null ? null : Random(widget.seed),
                onChips: _account.cashChips,
              )
            : OnlineCashController.forTable(
                widget.service!,
                widget.doc!,
                you: _account.persona,
                pace: widget.pace,
              ))
        ..start();

  CashStake get stake => widget.table.stake;

  bool get _onlineTable => widget.service != null;
  CashController? get _local => _c is CashController ? _c : null;
  OnlineCashController? get _online => _c is OnlineCashController ? _c : null;
  int get _chips => _local?.yourChips ?? _online!.yourChips;
  int get _maxTopUp => _local?.maxTopUp ?? _online!.maxTopUp;
  int get _pendingTopUp => _local?.pendingTopUp ?? _online!.pendingTopUp;

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    final chipsNow = _chips;
    final midHand = _c.youAreIn && _c.hand?.result == null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ToonBox(
          color: Toon.paper,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Cash out?', style: Toon.text(22, weight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                '${chips(chipsNow)} chips go back to your balance.'
                '${midHand ? ' You\'re in a hand: what you\'ve bet stays in the pot.' : ''}',
                textAlign: TextAlign.center,
                style: Toon.text(16, weight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ToonButton(
                      key: const Key('stay'),
                      color: Toon.card,
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Stay'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ToonButton(
                      key: const Key('cash out'),
                      color: Toon.green,
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Cash out'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    if (_online case final online?) {
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      await online.leave();
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(midHand ? 'Cashing out after this hand.' : 'Cashed out.')));
      return;
    }
    final net = _account.cashOut(_chips);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            net == 0
                ? 'Cashed out: broke even.'
                : net > 0
                ? 'Cashed out: up ${_account.money(net)}.'
                : 'Cashed out: down ${_account.money(-net)}.',
          ),
        ),
      );
  }

  Future<void> _topUp() async {
    final pips = await chooseBuyIn(
      context,
      stake: stake,
      balance: _account.balance,
      title: 'Top up',
      action: 'Add chips',
      most: _maxTopUp,
      least: stake.bigBlind,
    );
    if (pips == null || !mounted) return;
    if (_online case final online?) {
      final e = await online.topUp(pips);
      if (e != null && mounted) _say(e);
      return;
    }
    _account.cashIn(pips);
    _local!.topUp(pips);
  }

  Future<void> _rebuy() async {
    final pips = await chooseBuyIn(context, stake: stake, balance: _account.balance, title: 'Buy back in');
    if (pips == null || !mounted) return;
    if (_online case final online?) {
      final e = await online.rebuy(pips);
      if (e != null && mounted) _say(e);
      return;
    }
    _account.cashIn(pips);
    _local!.rebuy(pips);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _c,
          builder: (context, _) => Stack(
            children: [
              GameLayout(
                top: _CashHud(
                  c: _c,
                  name: stake.label,
                  online: _onlineTable,
                  trouble: _online?.trouble ?? false,
                  pending: _pendingTopUp,
                  onLeave: _leave,
                  onTopUp: _account.balance > 0 && _maxTopUp > 0 ? _topUp : null,
                ),
                commentary: TableInfo(c: _c),
                table: TableView(c: _c),
                controls: ActionBar(c: _c),
              ),
              if (_c.phase == TablePhase.finished)
                Positioned.fill(
                  child: Material(
                    type: MaterialType.transparency,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: ToonBox(
                          key: const Key('busted'),
                          color: Toon.paper,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Out of chips', style: Toon.text(24, weight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Text(
                                _account.balance >= stake.bigBlind
                                    ? 'Buy back in, or call it a night.'
                                    : 'Not enough ${_account.currency.noun} to buy back in here.',
                                textAlign: TextAlign.center,
                                style: Toon.text(15, weight: FontWeight.w500),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: ToonButton(
                                      key: const Key('busted leave'),
                                      color: Toon.card,
                                      onPressed: () {
                                        if (_online case final online?) {
                                          unawaited(online.leave());
                                        } else {
                                          _account.cashOut(0);
                                        }
                                        Navigator.of(context).pop();
                                      },
                                      child: const Text('Leave'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ToonButton(
                                      key: const Key('rebuy'),
                                      color: Toon.green,
                                      onPressed: _account.balance >= stake.bigBlind ? _rebuy : null,
                                      child: const Text('Buy in'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CashHud extends StatelessWidget {
  const _CashHud({
    required this.c,
    required this.name,
    required this.online,
    required this.trouble,
    required this.pending,
    required this.onLeave,
    this.onTopUp,
  });

  final PokerController c;
  final String name;
  final bool online;
  final bool trouble;
  final int pending;
  final VoidCallback onLeave;
  final VoidCallback? onTopUp;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: Row(
      children: [
        ToonButton(
          key: const Key('leave'),
          color: Toon.card,
          padding: const EdgeInsets.all(8),
          tooltip: 'Cash out',
          onPressed: onLeave,
          child: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Toon.text(20, weight: FontWeight.w700),
              ),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      trouble
                          ? 'Reconnecting…'
                          : 'Blinds ${chips(c.game.blinds.$1)} / ${chips(c.game.blinds.$2)}'
                                '${pending > 0 ? ' · +${chips(pending)} next hand' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Toon.text(13, weight: FontWeight.w500, color: Toon.muted),
                    ),
                  ),
                  const SizedBox(width: 6),
                  CashWhere(online: online),
                ],
              ),
            ],
          ),
        ),
        ToonButton(
          key: const Key('top up'),
          color: Toon.yellow,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          onPressed: onTopUp,
          child: Text('Top up', style: Toon.text(14)),
        ),
        const SizedBox(width: 6),
        GuideButton(title: "Texas Hold'em", stages: pokerGuide, current: () => pokerStage(c)),
      ],
    ),
  );
}

/// The small marker for which tables you're at: the shared online ones, or
/// this phone's own (no connection, or the server can't be reached).
class CashWhere extends StatelessWidget {
  const CashWhere({super.key, required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: online
        ? 'Shared tables: anyone can join you.'
        : 'Local tables: playing on this phone (no connection). Friends can\'t join you here.',
    child: Container(
      key: Key(online ? 'online tables' : 'local tables'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: (online ? Toon.green : Toon.grey).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(online ? Icons.public_rounded : Icons.phone_android_rounded, size: 11, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            online ? 'Online' : 'Local',
            style: Toon.text(11, weight: FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    ),
  );
}
