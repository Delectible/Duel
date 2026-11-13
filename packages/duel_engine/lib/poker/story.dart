import 'dart:math';

import '../cards.dart';
import 'poker_hand.dart';

/// One of your decisions in a game against bots, kept for "Hand of the
/// game": what you did, how good your cards were then, and (once the hand
/// is over) how it turned out.
class YourDecision {
  YourDecision({
    required this.hand,
    required this.street,
    required this.action,
    required this.hole,
    required this.board,
    required this.equity,
    required this.toCall,
    required this.pot,
    required this.bigBlind,
    this.against,
  });

  /// Hand number in the game.
  final int hand;
  final Street street;
  final ActionLabel action;
  final List<PlayingCard> hole;
  final List<PlayingCard> board;

  /// Chance to win against the players still in, if their cards were random.
  final double equity;

  /// Chips you had to put in to stay (0: nothing to call).
  final int toCall;

  /// The pot before you acted.
  final int pot;
  final int bigBlind;

  /// Who made the bet you faced.
  final String? against;

  /// Filled in when the hand ends: chips won minus chips put in.
  int net = 0;

  /// Folds: whether your cards would have won had you stayed to the end
  /// (null: the hand ended before all five cards were out).
  bool? wouldHaveWon;

  /// The hand went to a showdown with you in it.
  bool showdown = false;

  /// The price of calling: the share of the final pot your call is.
  double get potOdds => toCall == 0 ? 0 : toCall / (pot + toCall * 2);
}

/// "Hand of the game": your best and worst decision, each in a line.
({String? best, String? worst}) handOfTheGame(List<YourDecision> decisions) {
  ({double score, String text})? best, worst;
  void consider(double score, String text) {
    if (score > 0 && (best == null || score > best!.score)) best = (score: score, text: text);
    if (score < 0 && (worst == null || score < worst!.score)) worst = (score: score, text: text);
  }

  for (final d in decisions) {
    final bb = max(1, d.bigBlind);
    final cards = _holeName(d.hole);
    final pct = '${(d.equity * 100).round()}%';
    final who = d.against == null ? '' : " ${d.against}'s";
    switch (d.action) {
      case ActionLabel.fold when d.toCall > 0:
        if (d.wouldHaveWon == false && d.toCall >= bb * 3) {
          consider(
            d.toCall / bb * (d.equity < d.potOdds ? 1.2 : 0.8),
            'Hand ${d.hand}: you laid down $cards to$who ${_street(d.street)} bet. '
            'It would have lost: a good fold that kept ${_c(d.toCall)} chips.',
          );
        } else if (d.wouldHaveWon == true && d.equity > d.potOdds + 0.15) {
          consider(
            -(d.pot + d.toCall) / bb,
            'Hand ${d.hand}: you folded $cards ${_street(d.street, before: true)} with $pct to win. '
            'It would have taken the pot.',
          );
        }
      case ActionLabel.call || ActionLabel.allIn || ActionLabel.check
          when d.toCall > 0 || d.action == ActionLabel.allIn:
        if (d.net > 0 && d.equity >= d.potOdds) {
          consider(
            d.net / bb * 0.8,
            'Hand ${d.hand}: you ${d.action == ActionLabel.allIn ? 'went all in' : 'called'} with $cards ($pct to win) '
            'and won ${_c(d.net)}.',
          );
        } else if (d.net < 0 && d.equity < d.potOdds - 0.1) {
          consider(
            d.net / bb,
            'Hand ${d.hand}: you ${d.action == ActionLabel.allIn ? 'went all in' : 'called'} with $cards, '
            'only $pct to win, and lost ${_c(-d.net)}.',
          );
        }
      case ActionLabel.bet || ActionLabel.raise || ActionLabel.allIn:
        if (d.net > 0 && !d.showdown && d.equity < 0.35) {
          consider(
            d.net / bb * 1.3,
            'Hand ${d.hand}: you ${d.action == ActionLabel.bet ? 'bet' : 'raised'} with just $cards '
            'and everyone folded: a ${_c(d.net)} bluff.',
          );
        } else if (d.net > 0 && d.showdown && d.equity > 0.6) {
          consider(d.net / bb, 'Hand ${d.hand}: you bet $cards for value and got paid ${_c(d.net)}.');
        } else if (d.net < 0 && d.equity < 0.3 && -d.net >= bb * 5) {
          consider(
            d.net / bb * 0.9,
            'Hand ${d.hand}: you put ${_c(-d.net)} in with $cards ($pct to win) and lost it.',
          );
        }
      default:
    }
  }
  return (best: best?.text, worst: worst?.text);
}

/// Something worth telling after the game.
sealed class StoryEvent {
  const StoryEvent();
}

/// [winner] won the biggest pot with [hand] (null: everyone folded).
class BigPot extends StoryEvent {
  const BigPot(this.winner, this.amount, this.hand, this.handNumber);
  final int winner, amount, handNumber;
  final String? hand;
}

/// [winner] won an all-in with only [chance] to win against [loser].
class BadBeat extends StoryEvent {
  const BadBeat(this.winner, this.loser, this.chance);
  final int winner, loser;
  final double chance;
}

/// [by] knocked [out] out on hand [handNumber].
class KnockOut extends StoryEvent {
  const KnockOut(this.out, this.by, this.handNumber);
  final int out, handNumber;
  final int? by;
}

/// [seat] won [amount] with nothing.
class Bluff extends StoryEvent {
  const Bluff(this.seat, this.amount);
  final int seat, amount;
}

/// You dropped to [low] big blinds and came back.
class Comeback extends StoryEvent {
  const Comeback(this.low);
  final double low;
}

/// A few lines about how the game went (seat 0 is you): who won, the big
/// moments. [names] by seat ("You" at 0); [tilts] per seat.
List<String> tableStory({
  required List<String> names,
  required List<StoryEvent> events,
  required int winner,
  required int hands,
  List<int> tilts = const [],
}) {
  String n(int seat) => seat == 0 ? 'you' : names[seat];
  String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  final lines = <String>[
    winner == 0
        ? 'You outlasted the table in $hands hands.'
        : '${names[winner]} took the table after $hands hands.',
  ];
  final big = events.whereType<BigPot>().fold<BigPot?>(
    null,
    (a, b) => a == null || b.amount > a.amount ? b : a,
  );
  if (big != null) {
    lines.add(
      'The biggest pot, ${_c(big.amount)} on hand ${big.handNumber}, went to ${n(big.winner)}'
      '${big.hand == null ? ' without a showdown' : ' with ${big.hand!.toLowerCase()}'}.',
    );
  }
  final beat = events.whereType<BadBeat>().fold<BadBeat?>(
    null,
    (a, b) => a == null || b.chance < a.chance ? b : a,
  );
  if (beat != null) {
    lines.add(
      '${cap(n(beat.winner))} cracked ${n(beat.loser) == 'you' ? 'you' : n(beat.loser)} with only '
      '${(beat.chance * 100).round()}% to win.',
    );
  }
  final yourKos = events.whereType<KnockOut>().where((k) => k.by == 0).toList();
  if (yourKos.isNotEmpty) {
    final who = yourKos.map((k) => names[k.out]).toList();
    lines.add('You knocked out ${_list(who)}.');
  } else {
    final outYou = events.whereType<KnockOut>().where((k) => k.out == 0 && k.by != null).firstOrNull;
    if (outYou != null) lines.add('${names[outYou.by!]} sent you home on hand ${outYou.handNumber}.');
  }
  final comeback = events.whereType<Comeback>().firstOrNull;
  if (comeback != null) {
    lines.add(
      'Down to ${comeback.low.toStringAsFixed(comeback.low < 3 ? 1 : 0)} big blinds, you fought back.',
    );
  }
  final bluff = events
      .whereType<Bluff>()
      .where((b) => b.seat == 0)
      .fold<Bluff?>(null, (a, b) => a == null || b.amount > a.amount ? b : a);
  if (bluff != null) lines.add('Your best bluff stole ${_c(bluff.amount)}.');
  for (var s = 1; s < tilts.length; s++) {
    if (tilts[s] >= 2) {
      lines.add('${names[s]} tilted ${tilts[s]} times.');
      break;
    }
  }
  return lines.take(5).toList();
}

String _list(List<String> xs) =>
    xs.length == 1 ? xs.single : '${xs.sublist(0, xs.length - 1).join(', ')} and ${xs.last}';

String _street(Street s, {bool before = false}) => switch (s) {
  Street.preflop => before ? 'before the flop' : 'pre-flop',
  Street.flop => before ? 'on the flop' : 'flop',
  Street.turn => before ? 'on the turn' : 'turn',
  Street.river => before ? 'on the river' : 'river',
  _ => '',
};

String _holeName(List<PlayingCard> hole) {
  if (hole.length < 2) return 'your cards';
  final a = hole[0], b = hole[1];
  if (a.rank == b.rank) return 'a pair of ${rankPlural(a.rank).toLowerCase()}';
  final hi = max(a.rank, b.rank), lo = min(a.rank, b.rank);
  return '${rankShort(hi)}-${rankShort(lo)}${a.suit == b.suit ? ' suited' : ''}';
}

String rankShort(int r) => const {14: 'A', 13: 'K', 12: 'Q', 11: 'J', 10: '10'}[r] ?? '$r';

String _c(int n) {
  final s = n.abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}
