import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/account/account.dart';
import '../../../core/session/play_setup.dart';
import '../../../core/sound/sound.dart';
import '../../../core/theme/toon.dart';
import '../scorer/presets.dart';
import '../scorer/scorer_tools.dart';
import 'tool_page.dart';

/// Who owes whom after a home game: [nets] (name → won, negative lost) as
/// the fewest payments, biggest first.
List<(String from, String to, int amount)> settleUp(Map<String, int> nets) {
  final owe = [
    for (final e in nets.entries)
      if (e.value < 0) (e.key, -e.value),
  ]..sort((a, b) => b.$2.compareTo(a.$2));
  final get = [
    for (final e in nets.entries)
      if (e.value > 0) (e.key, e.value),
  ]..sort((a, b) => b.$2.compareTo(a.$2));
  final out = <(String, String, int)>[];
  var i = 0, j = 0;
  var o = owe.isEmpty ? 0 : owe[0].$2, g = get.isEmpty ? 0 : get[0].$2;
  while (i < owe.length && j < get.length) {
    final pay = min(o, g);
    if (pay > 0) out.add((owe[i].$1, get[j].$1, pay));
    o -= pay;
    g -= pay;
    if (o == 0 && ++i < owe.length) o = owe[i].$2;
    if (g == 0 && ++j < get.length) g = get[j].$2;
  }
  return out;
}

class _Player {
  _Player(this.name, {List<int>? buyIns, this.cashOut}) : buyIns = buyIns ?? [];
  String name;
  final List<int> buyIns;
  int? cashOut;

  int get paidIn => buyIns.fold(0, (a, b) => a + b);
  int? get net => cashOut == null ? null : cashOut! - paidIn;

  Map<String, Object?> toJson() => {'name': name, 'buyIns': buyIns, 'cashOut': cashOut};
  static _Player fromJson(Map<Object?, Object?> j) => _Player(
    '${j['name']}',
    buyIns: [for (final b in (j['buyIns'] as List?) ?? const []) b as int],
    cashOut: j['cashOut'] as int?,
  );
}

/// The bank for a home poker game played with real chips and real money:
/// everyone's buy-ins and rebuys, what they cash out with at the end, a
/// check that the chips add up, and who pays whom (the fewest payments).
/// Kept on the phone until you start a new game.
class ChipBank extends StatefulWidget {
  const ChipBank({super.key});

  @override
  State<ChipBank> createState() => _ChipBankState();
}

class _ChipBankState extends State<ChipBank> {
  late final Account _account = AccountScope.read(context);
  late final List<_Player> _players;
  late int _buyIn;
  late String _symbol;

  static const _symbols = ['\$', '£', '€', ''];

  @override
  void initState() {
    super.initState();
    final s = _account.toolState('chips');
    if (s != null && s['players'] is List) {
      _players = [for (final p in s['players']! as List) _Player.fromJson(p as Map)];
      _buyIn = s['buyIn'] as int? ?? 20;
      _symbol = s['symbol'] as String? ?? '\$';
    } else {
      _players = [];
      _buyIn = 20;
      _symbol = '\$';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_players.isEmpty) {
      final party = context.dependOnInheritedWidgetOfExactType<PlaySetupScope>()?.notifier?.party;
      final names = startingNames(
        context,
        party: party?.members.map((m) => m.persona.name).toList(),
        me: _account.name,
      );
      _players.addAll([for (final n in names) _Player(n)]);
    }
  }

  void _save() => _account.saveToolState('chips', {
    'players': [for (final p in _players) p.toJson()],
    'buyIn': _buyIn,
    'symbol': _symbol,
  });

  void _change(VoidCallback f) {
    setState(f);
    _save();
  }

  String money(int v) => '${v < 0 ? '−' : ''}$_symbol${_group(v.abs())}';

  static String _group(int v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  Future<void> _cashOut(_Player p) async {
    final v = await showKeypad(context, title: '${p.name} cashes out with', signed: false);
    if (v != null) _change(() => p.cashOut = v);
  }

  Future<void> _customBuyIn(_Player p) async {
    final v = await showKeypad(context, title: '${p.name} buys in for', signed: false);
    if (v != null && v > 0) {
      _change(() => p.buyIns.add(v));
      Sound.play(Sfx.chips);
    }
  }

  Future<void> _addPlayer() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Toon.paper,
        title: const Text('Who joined?'),
        content: TextField(
          key: const Key('chip name'),
          controller: c,
          autofocus: true,
          maxLength: 20,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(c.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) _change(() => _players.add(_Player(name)));
  }

  Future<void> _newGame() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Toon.paper,
        title: const Text('Start a new game?'),
        content: const Text('Everyone stays; the buy-ins and cash-outs are cleared.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('New game')),
        ],
      ),
    );
    if (ok == true) {
      _change(() {
        for (final p in _players) {
          p.buyIns.clear();
          p.cashOut = null;
        }
      });
    }
  }

  Future<void> _settle() async {
    final nets = {
      for (final p in _players)
        if (p.net != null) p.name: p.net!,
    };
    final pays = settleUp(nets);
    await showToonSheet<void>(
      context,
      title: 'Settle up',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pays.isEmpty) Text('Nobody owes anyone.', style: Toon.text(16)),
          for (final (from, to, amount) in pays)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: Toon.box(Toon.card, radius: 14, shadow: 1),
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: from,
                            style: Toon.text(16, weight: FontWeight.w700),
                          ),
                          TextSpan(text: ' pays ', style: Toon.text(16)),
                          TextSpan(
                            text: to,
                            style: Toon.text(16, weight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    money(amount),
                    style: Toon.text(20, weight: FontWeight.w700, color: Toon.green),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paidIn = _players.fold(0, (a, p) => a + p.paidIn);
    final done = _players.every((p) => p.cashOut != null || p.paidIn == 0);
    final out = _players.fold(0, (a, p) => a + (p.cashOut ?? 0));
    final gap = out - paidIn;
    return ToolPage(
      title: 'Chip bank',
      subtitle: 'Buy-ins, cash-outs, who owes whom',
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          color: Toon.paper,
          onSelected: (v) {
            if (v == 'new') _newGame();
            if (v == 'add') _addPlayer();
            if (v.startsWith('sym')) _change(() => _symbol = v.substring(3));
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'add', child: Text('Add a player')),
            const PopupMenuItem(value: 'new', child: Text('New game')),
            for (final s in _symbols)
              PopupMenuItem(value: 'sym$s', child: Text(s.isEmpty ? 'No currency sign' : 'Use $s')),
          ],
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text('Buy-in', style: Toon.text(15, weight: FontWeight.w600)),
                const SizedBox(width: 8),
                GestureDetector(
                  key: const Key('buy-in amount'),
                  onTap: () async {
                    final v = await showKeypad(context, title: 'Buy-in', signed: false);
                    if (v != null && v > 0) _change(() => _buyIn = v);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: Toon.box(Toon.yellow, radius: 10, shadow: 2),
                    child: Text(
                      money(_buyIn),
                      style: Toon.text(16, weight: FontWeight.w700, color: Toon.inkLight),
                    ),
                  ),
                ),
                const Spacer(),
                Text('In the pot ', style: Toon.text(14, color: Toon.muted)),
                Text(money(paidIn), style: Toon.text(17, weight: FontWeight.w700)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              children: [
                for (final (i, p) in _players.indexed)
                  Dismissible(
                    key: ValueKey('chip player $i ${p.name}'),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => _change(() => _players.remove(p)),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: Toon.box(Toon.red, radius: 16, shadow: 0),
                      child: const Icon(Icons.delete_rounded, color: Colors.white),
                    ),
                    child: _PlayerRow(
                      player: p,
                      color: scoreColor(i),
                      money: money,
                      buyIn: _buyIn,
                      onBuyIn: () {
                        _change(() => p.buyIns.add(_buyIn));
                        Sound.play(Sfx.chips);
                      },
                      onCustom: () => _customBuyIn(p),
                      onUndo: p.buyIns.isEmpty ? null : () => _change(() => p.buyIns.removeLast()),
                      onCashOut: () => _cashOut(p),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(12),
            decoration: Toon.box(Toon.card, radius: 16, shadow: 2),
            child: Column(
              children: [
                if (done && paidIn > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      gap == 0
                          ? 'The chips add up.'
                          : gap < 0
                          ? '${money(-gap)} short: someone\'s chips are missing.'
                          : '${money(gap)} too many: check the cash-outs.',
                      key: const Key('chip check'),
                      style: Toon.text(14, weight: FontWeight.w600, color: gap == 0 ? Toon.green : Toon.red),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ToonButton(
                    key: const Key('settle up'),
                    color: Toon.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    onPressed: done && paidIn > 0 && gap == 0 ? _settle : null,
                    child: Text(done ? 'Settle up' : 'Enter everyone\'s cash-out to settle'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.player,
    required this.color,
    required this.money,
    required this.buyIn,
    required this.onBuyIn,
    required this.onCustom,
    required this.onUndo,
    required this.onCashOut,
  });

  final _Player player;
  final Color color;
  final String Function(int) money;
  final int buyIn;
  final VoidCallback onBuyIn, onCustom, onCashOut;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final net = player.net;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: Toon.box(Toon.card, radius: 16, shadow: 1),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(player.name, style: Toon.text(17, weight: FontWeight.w700)),
              ),
              if (net != null)
                Text(
                  net == 0 ? 'even' : (net > 0 ? '+${money(net)}' : money(net)),
                  style: Toon.text(
                    18,
                    weight: FontWeight.w700,
                    color: net > 0 ? Toon.green : (net < 0 ? Toon.red : Toon.muted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  player.buyIns.isEmpty
                      ? 'Not in yet'
                      : 'In ${money(player.paidIn)}${player.buyIns.length > 1 ? ' (${player.buyIns.length} buy-ins)' : ''}',
                  style: Toon.text(14, color: Toon.muted),
                ),
              ),
              if (onUndo != null)
                IconButton(
                  tooltip: 'Take back the last buy-in',
                  onPressed: onUndo,
                  icon: const Icon(Icons.undo_rounded, size: 20),
                ),
              ToonButton(
                key: Key('buy in ${player.name}'),
                color: Toon.yellow,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                onPressed: onBuyIn,
                onLongPress: onCustom,
                child: Text(
                  player.buyIns.isEmpty ? '+${money(buyIn)}' : 'Rebuy',
                  style: Toon.text(14, weight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 6),
              ToonButton(
                key: Key('cash out ${player.name}'),
                color: player.cashOut == null ? Toon.card : Toon.green,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                onPressed: player.buyIns.isEmpty ? null : onCashOut,
                child: Text(
                  player.cashOut == null ? 'Cash out' : money(player.cashOut!),
                  style: Toon.text(14, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
