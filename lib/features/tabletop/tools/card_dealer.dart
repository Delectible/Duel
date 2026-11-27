import 'dart:async';
import 'dart:math';

import 'package:duel_engine/cards.dart';
import 'package:duel_engine/deck_table/deck_table.dart';
import 'package:flutter/material.dart';

import '../../../core/account/account.dart';
import '../../../core/cards/card_view.dart';
import '../../../core/online/party.dart';
import '../../../core/session/play_setup.dart';
import '../../../core/sound/sound.dart';
import '../../../core/table/table_bits.dart';
import '../../../core/theme/toon.dart';
import '../scorer/presets.dart';
import '../scorer/scorer_tools.dart';
import 'tool_page.dart';

/// The card dealer's table, here or the party's: what's public (the deck's
/// size, the face-up pile, how many each holds, the log) and your hand.
class DealerController extends ChangeNotifier {
  /// One phone passed round the table.
  DealerController.local(List<String> names, {Random? rng})
    : party = null,
      _table = DeckTable.fresh(
        [for (var i = 0; i < names.length; i++) 'p$i'],
        {for (var i = 0; i < names.length; i++) 'p$i': names[i]},
        rng ?? Random(),
      );

  /// The party's table on the referee: seats are the members.
  DealerController.shared(PartyService this.party) : _table = null {
    final pid = party!.party?['id'] as String?;
    if (pid != null) {
      _subs.add(party!.backend.watch('deck/$pid').listen(_heard));
      _subs.add(party!.backend.watch('deck/$pid/hands/${party!.uid}').listen(_heardHand));
      unawaited(_send(const {}));
    }
  }

  final PartyService? party;
  final DeckTable? _table;
  final List<StreamSubscription<Object?>> _subs = [];
  Map<String, Object?> _public = const {};
  List<PlayingCard> _mine = [];
  var _disposed = false;
  String? error;

  bool get shared => party != null;
  bool get host => !shared || (party?.isHost ?? false);

  Map<String, Object?> get public => _table?.public() ?? _public;
  List<String> get players => [for (final p in (public['players'] as List?) ?? const []) '$p'];
  String name(String id) => '${((public['names'] as Map?) ?? const {})[id] ?? 'Player'}';
  int count(String id) => (((public['counts'] as Map?) ?? const {})[id] as int?) ?? 0;
  int get deckLeft => public['deckLeft'] as int? ?? 0;
  List<PlayingCard> get pile => [
    for (final c in (public['pile'] as List?) ?? const []) PlayingCard.parse('$c'),
  ];
  List<String> get log => [for (final s in (public['log'] as List?) ?? const []) '$s'];

  /// Here: whose turn at the phone it is.
  String? seat;

  /// Your hand (here: the seat's).
  List<PlayingCard> get hand {
    if (_table != null) return sortBySuit(_table.hands[seat] ?? const []);
    return sortBySuit(_mine);
  }

  String? get me => shared ? party?.uid : seat;

  void _heard(Doc? d) {
    if (d == null || _disposed) return;
    _public = d;
    _notify();
  }

  void _heardHand(Doc? d) {
    if (d == null || _disposed) return;
    _mine = [for (final c in (d['cards'] as List?) ?? const []) PlayingCard.parse('$c')];
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> apply(Map<String, Object?> op) async {
    error = null;
    final t = _table;
    if (t != null) {
      try {
        t.apply({...op, 'as': seat});
      } on DeckError catch (e) {
        error = e.message;
      }
      _notify();
      return error == null;
    }
    return _send(op);
  }

  Future<bool> _send(Map<String, Object?> op) async {
    final pid = party?.party?['id'] as String?;
    if (pid == null) return false;
    try {
      await party!.signedIn();
      final d = await party!.backend.call('/v1/deck/$pid', op);
      _heard(d);
      _mine = [for (final c in (d['mine'] as List?) ?? const []) PlayingCard.parse('$c')];
      _notify();
      return true;
    } on OnlineError catch (e) {
      error = e.message;
    } on Object {
      error = 'Lost the connection: try again';
    }
    _notify();
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

/// A deck of cards when you haven't got one. With your party, every phone
/// holds its own hand (nobody else sees it); on one phone, pass it round:
/// pick who's holding it and press Peek to see your cards. The host deals;
/// anyone draws, plays a card face up, or takes the top of the pile.
class CardDealer extends StatefulWidget {
  const CardDealer({super.key, this.controller});

  final DealerController? controller;

  @override
  State<CardDealer> createState() => _CardDealerState();
}

class _CardDealerState extends State<CardDealer> {
  late final DealerController c = widget.controller ?? _make();
  PlayingCard? _picked;
  var _peek = false;
  var _lastDeal = 7;

  DealerController _make() {
    final party = context.dependOnInheritedWidgetOfExactType<PlaySetupScope>()?.notifier?.party;
    if (party != null && party.party != null && party.members.length >= 2) {
      return DealerController.shared(party);
    }
    final account = AccountScope.maybeRead(context);
    final names = startingNames(context, me: account?.name);
    return DealerController.local(names)..seat = 'p0';
  }

  var _listening = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_listening) {
      _listening = true;
      c.addListener(_changed);
    }
  }

  void _changed() {
    final e = c.error;
    if (e != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e), duration: const Duration(seconds: 2)));
      c.error = null;
    }
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Future<void> _deal() async {
    final n = await showToonSheet<int>(
      context,
      title: 'Deal how many each?',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final n in [1, 2, 3, 5, 7, 8, 10, 13])
            ToonButton(
              key: Key('deal $n'),
              color: n == _lastDeal ? Toon.yellow : Toon.card,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              onPressed: () => Navigator.of(context).pop(n),
              child: Text('$n'),
            ),
          ToonButton(
            color: Toon.card,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            onPressed: () async {
              final v = await showKeypad(context, title: 'Cards each', signed: false);
              if (!mounted) return;
              Navigator.of(context).pop(v);
            },
            child: const Text('Other'),
          ),
        ],
      ),
    );
    if (n == null) return;
    _lastDeal = n;
    if (await c.apply({'op': 'deal', 'n': n})) Sound.deal(min(16, n * c.players.length), gapMs: 50);
    setState(() => _picked = null);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final hand = c.hand;
      final pile = c.pile;
      final showHand = c.shared || _peek;
      return ToolPage(
        title: 'Card dealer',
        subtitle: c.shared
            ? 'Your party\'s deck: your hand is only on your phone'
            : 'One phone: pass it round',
        actions: [
          if (c.host)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              color: Toon.paper,
              onSelected: (v) {
                if (v == 'reset') c.apply({'op': 'reset'});
              },
              itemBuilder: (_) => [const PopupMenuItem(value: 'reset', child: Text('Gather and shuffle'))],
            ),
        ],
        child: LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth > box.maxHeight;
            final players = SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final (i, p) in c.players.indexed)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        key: Key('seat $i'),
                        onTap: c.shared
                            ? null
                            : () => setState(() {
                                c.seat = p;
                                _peek = false;
                                _picked = null;
                              }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: Toon.box(
                            (c.shared ? p == c.me : p == c.seat) ? scoreColor(i) : Toon.card,
                            radius: 12,
                            shadow: 1,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                c.name(p),
                                style: Toon.text(
                                  14,
                                  weight: FontWeight.w700,
                                  color: (c.shared ? p == c.me : p == c.seat) ? Toon.on(scoreColor(i)) : null,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.style_rounded, size: 16),
                              Text('${c.count(p)}', style: Toon.text(14, weight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
            final table = Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(
                  color: Toon.felt,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Toon.ink, width: Toon.outline),
                ),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final w = min(box.maxWidth * 0.26, box.maxHeight * 0.48).clamp(50.0, 110.0);
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _Stack(
                              key: const Key('deck'),
                              label: c.deckLeft == 0 ? 'Empty' : 'Draw · ${c.deckLeft}',
                              onTap: c.deckLeft > 0
                                  ? () async {
                                      if (await c.apply({'op': 'draw'})) Sound.play(Sfx.deal);
                                    }
                                  : null,
                              child: c.deckLeft == 0
                                  ? _Empty(width: w)
                                  : Stack(
                                      children: [
                                        for (var i = 0; i < min(4, (c.deckLeft / 8).ceil()); i++)
                                          Padding(
                                            padding: EdgeInsets.only(left: i * 2.0, top: i * 1.5),
                                            child: CardView(card: null, width: w, faceUp: false),
                                          ),
                                      ],
                                    ),
                            ),
                            _Stack(
                              key: const Key('pile'),
                              label: pile.isEmpty ? 'Played cards' : 'Take · ${pile.length}',
                              onTap: pile.isNotEmpty
                                  ? () async {
                                      if (await c.apply({'op': 'take'})) Sound.play(Sfx.place);
                                    }
                                  : null,
                              child: pile.isEmpty
                                  ? _Empty(width: w)
                                  : Stack(
                                      children: [
                                        if (pile.length > 1)
                                          Transform.rotate(
                                            angle: -0.12,
                                            child: CardView(card: pile[pile.length - 2], width: w),
                                          ),
                                        Pop(
                                          key: ValueKey('top ${pile.length} ${pile.last}'),
                                          child: Transform.rotate(
                                            angle: 0.05,
                                            child: CardView(card: pile.last, width: w),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (c.log.isNotEmpty)
                          Text(
                            c.log.last,
                            style: Toon.text(14, weight: FontWeight.w600, color: Colors.white70),
                          ),
                      ],
                    );
                  },
                ),
              ),
            );
            final handArea = SizedBox(
              height: 128,
              child: hand.isEmpty
                  ? Center(
                      child: Text(
                        c.host ? 'Deal to start' : 'Waiting for the host to deal',
                        style: Toon.text(16, color: Toon.muted),
                      ),
                    )
                  : !showHand
                  ? Center(
                      child: Text(
                        '${c.name(c.seat!)}: ${hand.length} cards. Hold Peek to look.',
                        style: Toon.text(15, color: Toon.muted),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, box) {
                        final w = 64.0;
                        final step = hand.length <= 1
                            ? 0.0
                            : min(w * 0.75, (box.maxWidth - 24 - w) / (hand.length - 1));
                        final total = w + step * (hand.length - 1);
                        return Center(
                          child: SizedBox(
                            width: total,
                            height: 120,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                for (final (i, card) in hand.indexed)
                                  AnimatedPositioned(
                                    duration: const Duration(milliseconds: 160),
                                    left: i * step,
                                    top: card == _picked ? 0 : 22,
                                    child: GestureDetector(
                                      key: Key('card $card'),
                                      onTap: () => setState(() => _picked = card == _picked ? null : card),
                                      child: CardView(card: card, width: w, glow: card == _picked),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            );
            final buttons = Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  if (c.host)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ToonButton(
                        key: const Key('deal'),
                        color: Toon.yellow,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        onPressed: _deal,
                        child: const Text('Deal'),
                      ),
                    ),
                  if (!c.shared)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTapDown: (_) => setState(() => _peek = true),
                        onTapUp: (_) => setState(() => _peek = false),
                        onTapCancel: () => setState(() => _peek = false),
                        child: ToonBox(
                          key: const Key('peek'),
                          color: _peek ? Toon.blue : Toon.card,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: const Text('Peek'),
                        ),
                      ),
                    ),
                  Expanded(
                    child: ToonButton(
                      key: const Key('play card'),
                      color: Toon.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      onPressed: _picked != null && showHand
                          ? () async {
                              final card = _picked!;
                              setState(() => _picked = null);
                              if (await c.apply({'op': 'play', 'card': '$card'})) Sound.play(Sfx.place);
                            }
                          : null,
                      child: Text(_picked == null ? 'Pick a card to play' : 'Play it face up'),
                    ),
                  ),
                ],
              ),
            );
            // On its side: the table on the left, your hand and buttons on the right.
            if (wide) {
              return Column(
                children: [
                  players,
                  Expanded(
                    child: Row(
                      children: [
                        table,
                        SizedBox(
                          width: box.maxWidth * 0.48,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(child: handArea),
                              buttons,
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return Column(children: [players, table, handArea, buttons]);
          },
        ),
      );
    },
  );
}

class _Stack extends StatelessWidget {
  const _Stack({super.key, required this.label, required this.child, this.onTap});

  final String label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        const SizedBox(height: 6),
        Text(
          label,
          style: Toon.text(14, weight: FontWeight.w700, color: Colors.white),
        ),
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: width * 1.4,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(width * 0.1),
      border: Border.all(color: Colors.white38, width: 2),
    ),
  );
}
