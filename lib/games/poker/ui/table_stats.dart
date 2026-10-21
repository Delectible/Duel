import 'dart:math';

import 'package:flutter/material.dart';

import 'package:duel_engine/cards.dart';
import 'package:duel_engine/poker/bot.dart';
import 'package:duel_engine/poker/coach.dart';
import 'package:duel_engine/poker/poker_hand.dart';
import 'package:duel_engine/poker/reads.dart';
import '../../../core/avatars/faces.dart';
import '../../../core/cards/card_view.dart';
import '../../../core/theme/toon.dart';
import '../../../core/table/table_bits.dart';
import 'poker_controller.dart';
import '../../../core/theme/sheet.dart';

/// The numbers a poker player keeps an eye on: the strip over the table
/// (your place, your stack in big blinds, the average), read cards (tap a
/// seat), the hand history, pot odds and outs, and the end-of-game quotes.

String _pct(double v) => '${(v * 100).round()}%';

String _ordinal(int n) => switch (n) {
  1 => '1st',
  2 => '2nd',
  3 => '3rd',
  _ => '${n}th',
};

/// The seat with the most chips (null on a tie or before anyone's ahead).
int? chipLeader(PokerController c) {
  int? best;
  var most = 0, tied = false;
  for (final p in c.game.players) {
    final h = c.handPlayer(p.seat);
    final stack = h == null ? p.stack : h.stack + h.committed;
    if (stack > most) {
      best = p.seat;
      most = stack;
      tied = false;
    } else if (stack == most) {
      tied = true;
    }
  }
  return tied ? null : best;
}

/// Over the table: your place, your stack in big blinds, the average stack,
/// and the hand history.
class TableInfo extends StatelessWidget {
  const TableInfo({super.key, required this.c});

  final PokerController c;

  @override
  Widget build(BuildContext context) {
    final bb = c.game.blinds.$2;
    final alive = c.game.players.where((p) => p.stack > 0 || c.handPlayer(p.seat) != null).toList();
    final total =
        c.game.players.fold(0, (s, p) => s + p.stack) + (c.hand?.result == null ? (c.hand?.pot ?? 0) : 0);
    final avg = alive.isEmpty ? 0 : total ~/ alive.length;
    int chipsOf(int seat) {
      final h = c.handPlayer(seat);
      return h == null ? c.game.players[seat].stack : h.stack + h.committed;
    }

    final mine = chipsOf(0);
    // Your place by chips (ties share it).
    final rank = 1 + alive.where((p) => p.seat != 0 && chipsOf(p.seat) > mine).length;
    Widget pill(String text, {Key? key, IconData? icon, Color? color}) => Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: Toon.box(color ?? Toon.card, radius: 10, shadow: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: Toon.on(color ?? Toon.card)),
            const SizedBox(width: 3),
          ],
          Text(text, style: Toon.text(13, color: Toon.on(color ?? Toon.card))),
        ],
      ),
    );
    final pills = [
      if (mine > 0)
        pill(
          '${_ordinal(rank)} of ${alive.length}',
          key: const Key('your place'),
          icon: rank == 1 ? Icons.emoji_events_rounded : null,
          color: rank == 1 ? Toon.yellow : null,
        ),
      pill('You ${(mine / bb).toStringAsFixed(mine >= bb * 10 ? 0 : 1)} BB', key: const Key('your bb')),
      pill('Avg ${chips(avg)}', key: const Key('average')),
    ];
    final history = ToonButton(
      key: const Key('history'),
      color: Toon.card,
      radius: 10,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      tooltip: 'Hand history',
      onPressed: c.reads.history.isEmpty ? null : () => showHandHistory(context, c),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history_rounded, size: 18),
          const SizedBox(width: 3),
          Text('Hands', style: Toon.text(13)),
        ],
      ),
    );
    // In the landscape side panel there's room to wrap onto two lines.
    if (SidePanel.of(context)) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [...pills, history],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  for (final (k, p) in pills.indexed) ...[if (k > 0) const SizedBox(width: 6), p],
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          history,
        ],
      ),
    );
  }
}

// --- Read cards ----------------------------------------------------------------

/// What anyone at the table could have worked out about a player: plain
/// words from the numbers, once there's enough to go on.
List<String> readNotes(PlayerReads r) {
  if (r.hands < 6) return ['Too soon to tell: ${r.hands} hand${r.hands == 1 ? '' : 's'} seen.'];
  final notes = <String>[];
  if (r.tilt > 0.35) notes.add('Steaming after losing a big pot: expect wild plays.');
  if (r.vpipRate >= 0.5) {
    notes.add('Plays most hands.');
  } else if (r.vpipRate >= 0.33) {
    notes.add('Plays a lot of hands.');
  } else if (r.vpipRate <= 0.16) {
    notes.add('Very picky: when they play, they have something.');
  }
  if (r.vpipRate > 0.25 && r.pfrRate < r.vpipRate * 0.35) {
    notes.add('Limps and calls before the flop more than they raise.');
  } else if (r.pfrRate >= 0.25) {
    notes.add('Raises a lot before the flop.');
  }
  final moves = r.bets + r.raises + r.calls;
  if (moves >= 6) {
    if (r.aggression >= 2.5) {
      notes.add('Bets and raises far more than they call.');
    } else if (r.aggression <= 0.6) {
      notes.add('Calls a lot, rarely bets: a calling station?');
    }
  }
  if (r.facedBets >= 4) {
    if (r.foldToBetRate >= 0.6) {
      notes.add('Folds to bets often: a good one to bluff.');
    } else if (r.foldToBetRate <= 0.25) {
      notes.add("Hard to bluff: doesn't fold to bets.");
    }
  }
  if (r.cbetChances >= 3 && r.cbetRate >= 0.75) notes.add('Bets the flop after raising almost every time.');
  if (r.bluffsShown > 0) {
    notes.add('Caught bluffing ${r.bluffsShown}× at showdowns.');
  } else if (r.aggressiveShowdowns >= 3) {
    notes.add('Every river bet shown so far was the real thing.');
  }
  if (r.bigBetsShown >= 2) {
    final honest = r.bigBetsStrong / r.bigBetsShown;
    if (honest >= 0.75) notes.add('Big bets have meant a big hand.');
    if (honest <= 0.34) notes.add('Big bets have been bluffs more than not.');
  }
  if (r.smallBetsShown >= 2 && r.smallBetsStrong / r.smallBetsShown >= 0.75) {
    notes.add('Small bets have been strong hands: a trap?');
  }
  if (r.allIns >= 3) notes.add('Has gone all in ${r.allIns} times.');
  if (notes.isEmpty) notes.add('Nothing stands out yet: a solid, balanced player?');
  return notes;
}

Future<void> showReadCard(BuildContext context, PokerController c, int seat) => showToonSheet<void>(
  context,
  height: 0.7,
  builder: (context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => _ReadCard(c: c, seat: seat),
  ),
);

class _ReadCard extends StatelessWidget {
  const _ReadCard({required this.c, required this.seat});

  final PokerController c;
  final int seat;

  @override
  Widget build(BuildContext context) {
    final r = c.reads.players[seat];
    final persona = c.personas[seat];
    final you = seat == 0;
    final bb = c.game.blinds.$2;
    final p = c.handPlayer(seat);
    final stack = p == null ? c.game.players[seat].stack : p.stack + p.committed;
    final width = (MediaQuery.sizeOf(context).width.clamp(0.0, 640.0) - 48) / 2;
    Widget stat(String label, String value, {String? hint}) => Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: Toon.box(Toon.card, radius: 12, shadow: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Toon.text(20, weight: FontWeight.w800)),
          Text(label, style: Toon.text(13, weight: FontWeight.w600)),
          if (hint != null)
            Text(
              hint,
              style: Toon.text(11, weight: FontWeight.w500, color: Toon.muted),
            ),
        ],
      ),
    );
    return ListView(
      key: Key('read card $seat'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Row(
          children: [
            Face(persona, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(you ? 'You' : persona.name, style: Toon.text(24, weight: FontWeight.w700)),
                  Text(
                    you
                        ? 'What the table has seen of you (the bots are reading it too)'
                        : 'Your read on them',
                    style: Toon.text(14, weight: FontWeight.w500, color: Toon.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            stat('Stack', chips(stack), hint: '${(stack / bb).toStringAsFixed(1)} big blinds'),
            stat('Hands seen', '${r.hands}', hint: 'won ${r.handsWon}'),
            stat('Plays', _pct(r.vpipRate), hint: 'hands they put chips in'),
            stat('Raises first', _pct(r.pfrRate), hint: 'raised before the flop'),
            stat('Aggression', r.aggression.toStringAsFixed(1), hint: 'bets + raises per call'),
            stat('Folds to bets', r.facedBets == 0 ? '–' : _pct(r.foldToBetRate), hint: 'after the flop'),
            stat('Showdowns won', '${r.showdownsWon} / ${r.showdowns}', hint: 'cards turned up'),
            stat('Biggest pot', r.biggestPot == 0 ? '–' : chips(r.biggestPot)),
          ],
        ),
        const SizedBox(height: 16),
        Text(you ? 'How you come across' : 'Notes', style: Toon.text(18, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        for (final n in readNotes(r))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(Icons.visibility_rounded, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(n, style: Toon.text(15, weight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        if (!you) ...[
          const SizedBox(height: 8),
          Text(
            'Watch how long they think, too: some take ages with a monster, some with a bluff.',
            style: Toon.text(13, weight: FontWeight.w500, color: Toon.muted),
          ),
        ],
      ],
    );
  }
}

// --- Hand history --------------------------------------------------------------

Future<void> showHandHistory(BuildContext context, PokerController c) => showToonSheet<void>(
  context,
  builder: (context) {
    final hands = c.reads.history.reversed.toList();
    return ListView(
      key: const Key('hand history'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text('Last hands', style: Toon.text(24, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final h in hands) _HandEntry(c: c, hand: h),
      ],
    );
  },
);

String _who(PokerController c, int seat) => seat == 0 ? 'You' : c.personas[seat].name;

/// "Finn raises to 60", "You call".
String describeAction(PokerController c, ActionRecord a) {
  final you = a.seat == 0;
  String verb(String s) => you ? s : '${s}s';
  final what = switch (a.label) {
    ActionLabel.fold => verb('fold'),
    ActionLabel.check => verb('check'),
    ActionLabel.call => verb('call'),
    ActionLabel.bet => '${verb('bet')} ${chips(a.to)}',
    ActionLabel.raise => '${verb('raise')} to ${chips(a.to)}',
    ActionLabel.allIn => you ? 'You go all in' : '${c.personas[a.seat].name} goes all in',
    _ => a.label.name,
  };
  return a.label == ActionLabel.allIn ? what : '${_who(c, a.seat)} $what';
}

class _HandEntry extends StatelessWidget {
  const _HandEntry({required this.c, required this.hand});

  final PokerController c;
  final HandRecord hand;

  @override
  Widget build(BuildContext context) {
    final winners = hand.won.keys.toList();
    final names = [for (final w in winners) _who(c, w)];
    final headline = winners.isEmpty
        ? 'Hand ${hand.number}'
        : '${names.join(' & ')} ${winners.length > 1 ? 'split' : (winners.single == 0 ? 'win' : 'wins')} '
              '${chips(hand.pot)}${hand.winningHand == null ? ' (everyone else folded)' : ' with ${hand.winningHand}'}';
    final streets = <Street, List<ActionRecord>>{};
    for (final a in hand.actions) {
      streets.putIfAbsent(a.street, () => []).add(a);
    }
    final shown = {...hand.shown, 0};
    Widget cards(List<PlayingCard> cs) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final card in cs)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: CardView(card: card, width: 26),
          ),
      ],
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: Toon.box(Toon.card, radius: 14, shadow: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hand ${hand.number}',
            style: Toon.text(13, weight: FontWeight.w600, color: Toon.muted),
          ),
          Text(headline, style: Toon.text(16, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (hand.board.isNotEmpty) cards(hand.board),
              for (final s in shown)
                if ((hand.holes[s]?.length ?? 0) == 2)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${_who(c, s)} ', style: Toon.text(13, weight: FontWeight.w600)),
                      cards(hand.holes[s]!),
                    ],
                  ),
            ],
          ),
          const SizedBox(height: 6),
          for (final e in streets.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text:
                          '${switch (e.key) {
                            Street.preflop => 'Pre-flop',
                            Street.flop => 'Flop',
                            Street.turn => 'Turn',
                            _ => 'River',
                          }}: ',
                      style: Toon.text(13, weight: FontWeight.w700),
                    ),
                    TextSpan(
                      text: e.value.map((a) => describeAction(c, a)).join(' · '),
                      style: Toon.text(13, weight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- Pot odds and outs ---------------------------------------------------------

/// Under your buttons: what the call costs against the pot, and your outs.
/// Null when there's nothing to say.
String? oddsLine(PokerController c) {
  final h = c.hand;
  final me = c.handPlayer(0);
  if (h == null || me == null || me.hole.length < 2) return null;
  final legal = h.legalMoves();
  final parts = <String>[];
  if (!legal.canCheck && legal.callAmount > 0) {
    final call = legal.callAmount;
    final pot = h.pot;
    final ratio = pot / call;
    parts.add(
      'Pot odds ${ratio >= 10 ? ratio.round() : ratio.toStringAsFixed(1)} : 1 · '
      'you need ${_pct(call / (pot + call))}',
    );
  }
  final o = h.board.length >= 3 && h.board.length < 5 ? outs(me.hole, h.board) : null;
  if (o != null && o.outs > 0) {
    parts.add('${o.outs} outs · ${_pct(o.chance)} to hit${h.board.length == 3 ? ' by the river' : ''}');
  }
  return parts.isEmpty ? null : parts.join('  ·  ');
}

// --- End of game: quotes -------------------------------------------------------

/// A line about each player's game, from their most outlying stat, no
/// line twice: "Never met a hand they didn't like."
Map<int, String> pickQuotes(List<PlayerReads> players, {required Iterable<int> seats}) {
  final biggest = players.fold(0, (m, r) => max(m, r.biggestPot));
  final options = <int, List<({String kind, double score, String text})>>{};
  for (final seat in seats) {
    final r = players[seat];
    final list = <({String kind, double score, String text})>[];
    void add(String kind, double score, List<String> lines) =>
        list.add((kind: kind, score: score, text: lines[seat % lines.length]));
    if (r.hands >= 8) {
      final s = (r.vpipRate - 0.3) / 0.12;
      if (s > 0) {
        add('loose', s, [
          "Never met a hand they didn't like.",
          'Played ${_pct(r.vpipRate)} of hands. Every one felt lucky.',
        ]);
      } else {
        add('tight', -s, [
          'Waited all night for aces.',
          'Patient as a rock: played just ${_pct(r.vpipRate)} of hands.',
        ]);
      }
    }
    if (r.bets + r.raises + r.calls >= 8) {
      final s = (r.aggression - 1.5) / 0.8;
      if (s > 0) {
        add('aggro', s, ['Bet first, asked questions never.', 'Raised like the chips were free.']);
      } else {
        add('passive', -s * 0.9, [
          'Called everything, raised nothing.',
          'A friendly caller: ${r.calls} calls, ${r.bets} bets.',
        ]);
      }
    }
    if (r.facedBets >= 5) {
      final s = (r.foldToBetRate - 0.4) / 0.15;
      if (s > 0) {
        add('folds', s, ['Folded at the first sign of a bet.', 'Bet at them and watch them fold.']);
      } else {
        add('sticky', -s, ['Could not be pushed off a hand.', "Wouldn't fold if you paid them."]);
      }
    }
    if (r.bluffsShown >= 2) {
      add('caught', r.bluffsShown * 0.9, ['Caught bluffing ${r.bluffsShown} times, never blushed.']);
    }
    if (r.bluffWins >= 2) add('thief', r.bluffWins * 0.7, ['Stole ${r.bluffWins} pots with nothing at all.']);
    if (r.showdowns >= 3) {
      final s = (r.showdownWinRate - 0.5) / 0.2;
      if (s > 0) {
        add('nuts', s, ['Always had it: won ${r.showdownsWon} of ${r.showdowns} showdowns.']);
      } else {
        add('hopeful', -s, ['Showed down ${r.showdowns} times, won ${r.showdownsWon}. An optimist.']);
      }
    }
    if (r.tilts >= 2) {
      add('tilt', r.tilts * 0.8, ['Steamed after every bad beat.', 'Took the bad beats personally.']);
    }
    if (r.allIns >= 3) add('shove', r.allIns * 0.6, ['Shoved ${r.allIns} times. Subtlety optional.']);
    if (r.cbetChances >= 4 && r.cbetRate >= 0.8) {
      add('cbet', (r.cbetRate - 0.6) / 0.15, ['Bet every flop like clockwork.']);
    }
    if (biggest > 0 && r.biggestPot == biggest) {
      add('pot', 1.2, ['Dragged the biggest pot of the game (${chips(biggest)}).']);
    }
    list.sort((a, b) => b.score.compareTo(a.score));
    options[seat] = list;
  }
  // Strongest stand-outs first; each kind of line only once.
  final order = [...options.keys]
    ..sort((a, b) => (options[b]!.firstOrNull?.score ?? 0).compareTo(options[a]!.firstOrNull?.score ?? 0));
  final used = <String>{};
  final out = <int, String>{};
  for (final seat in order) {
    final pick = options[seat]!.where((o) => !used.contains(o.kind)).firstOrNull;
    if (pick == null) {
      out[seat] = const [
        'Kept it quiet. Too quiet.',
        'Steady as she goes.',
        'Hard to read all game.',
      ][seat % 3];
      continue;
    }
    used.add(pick.kind);
    out[seat] = pick.text;
  }
  return out;
}

/// The end-of-game board: everyone in finishing order, a line about how
/// they played, what each bot really was (bot games), and your numbers.
class GameSummary extends StatelessWidget {
  const GameSummary({super.key, required this.c, this.footer});

  final PokerController c;

  /// Under the lineup (online: "The others are still playing…").
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final lineup = c.lineup;
    if (lineup.isEmpty) return const SizedBox.shrink();
    final seatOf = {for (final p in c.game.players) c.personas[p.seat]: p.seat};
    final quotes = pickQuotes(c.reads.players, seats: seatOf.values);
    final me = c.reads.players[0];
    Widget number(String value, String label) => Expanded(
      child: Column(
        children: [
          FittedBox(
            child: Text(value, style: Toon.text(18, weight: FontWeight.w800)),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Toon.text(11, weight: FontWeight.w600, color: Toon.muted),
          ),
        ],
      ),
    );
    return Column(
      key: const Key('summary'),
      children: [
        const SizedBox(height: 12),
        Container(
          key: const Key('your numbers'),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: Toon.box(Toon.card, radius: 12, shadow: 2),
          child: Row(
            children: [
              number('${me.handsWon}', 'hands won'),
              number(me.biggestPot == 0 ? '–' : chips(me.biggestPot), 'biggest pot'),
              number(me.bestBluff == 0 ? '–' : chips(me.bestBluff), 'best bluff'),
              number(_pct(me.vpipRate), 'hands played'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ToonButton(
          key: const Key('improve'),
          color: Toon.blue,
          radius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          onPressed: () => showCoach(context, me, players: lineup.length),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.school_rounded, size: 20),
              const SizedBox(width: 6),
              Text('Improve your game', style: Toon.text(15)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Column(
          key: const Key('lineup'),
          children: [
            for (final p in lineup)
              () {
                final seat = seatOf[p.who] ?? 0;
                final style = c.styles[seat];
                final bg = p.you ? Toon.yellow : (p.place == 1 ? Toon.green.withValues(alpha: 0.35) : null);
                final fg = p.you ? Toon.inkLight : null;
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text(
                          _ordinal(p.place),
                          style: Toon.text(15, weight: FontWeight.w700, color: fg),
                        ),
                      ),
                      Face(p.who, size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    p.you ? 'You' : p.who.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Toon.text(15, color: fg),
                                  ),
                                ),
                                if (style != null) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    decoration: Toon.box(Toon.paper, radius: 8, shadow: 0),
                                    child: Text(style.label, style: Toon.text(11, weight: FontWeight.w700)),
                                  ),
                                ],
                              ],
                            ),
                            if (quotes[seat] case final q?)
                              Text(
                                '“$q”',
                                style: Toon.text(
                                  12,
                                  weight: FontWeight.w500,
                                  color: fg ?? Toon.muted,
                                ).copyWith(fontStyle: FontStyle.italic),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }(),
          ],
        ),
        ?footer,
      ],
    );
  }
}

/// "Improve your game": tips from how you played this game.
Future<void> showCoach(BuildContext context, PlayerReads me, {required int players}) {
  final tips = coachTips(me, players: players);
  return showToonSheet<void>(
    context,
    height: 0.7,
    builder: (context) => ListView(
      key: const Key('coach'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text('Improve your game', style: Toon.text(22, weight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          tips.isEmpty
              ? 'Play a few more hands and there\'ll be tips here.'
              : 'From the ${me.hands} hands you played this game.',
          style: Toon.text(13, weight: FontWeight.w600, color: Toon.muted),
        ),
        const SizedBox(height: 12),
        for (final t in tips)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: Toon.box(Toon.card, radius: 14, shadow: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  t.good ? Icons.thumb_up_alt_rounded : Icons.lightbulb_rounded,
                  color: t.good ? Toon.green : Toon.orange,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.title, style: Toon.text(16, weight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(t.text, style: Toon.text(13.5, weight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
