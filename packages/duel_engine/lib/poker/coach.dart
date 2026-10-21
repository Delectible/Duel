import 'reads.dart';

/// One way to play better, from how you played this game.
class Tip {
  const Tip(this.title, this.text, {this.good = false, this.weight = 1});

  final String title;
  final String text;

  /// Something you did well (shown after the tips).
  final bool good;

  /// How much it matters (biggest first).
  final double weight;
}

/// Tips from your numbers ([r]) at a table of [players]: the biggest leaks
/// first, then what went well. Empty if there's too little to go on.
List<Tip> coachTips(PlayerReads r, {required int players}) {
  if (r.hands < 8) return const [];
  final tips = <Tip>[];
  final good = <Tip>[];
  // How many hands a good player plays grows as the table shrinks.
  final (loose, tight) = switch (players) {
    <= 2 => (0.8, 0.4),
    <= 4 => (0.5, 0.2),
    <= 6 => (0.38, 0.15),
    _ => (0.3, 0.12),
  };
  final vpip = r.vpipRate;
  String pct(double x) => '${(x * 100).round()}%';

  if (vpip > loose) {
    tips.add(
      Tip(
        'Play fewer hands',
        'You put chips in ${pct(vpip)} of the time. Most starting hands lose money: fold weak ones '
            '(small unpaired cards, a low card with a king or queen) and save your chips for strong ones.',
        weight: 2 + (vpip - loose) * 5,
      ),
    );
  } else if (vpip < tight) {
    tips.add(
      Tip(
        'Play a few more hands',
        'You only played ${pct(vpip)} of your hands, so the blinds ate your stack and everyone knew '
            'you had it when you bet. Open up a little, mostly when you act last or the blinds go up.',
        weight: 1.5 + (tight - vpip) * 5,
      ),
    );
  } else {
    good.add(
      Tip(
        'Good hand choice',
        'You played ${pct(vpip)} of your hands: about right for this table.',
        good: true,
      ),
    );
  }

  if (r.limps >= 3 && r.limps > r.opens) {
    tips.add(
      const Tip(
        'Raise instead of just calling',
        'Before the flop you often just called the big blind. That lets everyone in cheaply and tells '
            'them you\'re not strong. If a hand is worth playing, raise (about 3 big blinds); if not, fold.',
        weight: 1.8,
      ),
    );
  }

  if (r.opens >= 3) {
    final open = r.openBlinds / r.opens;
    if (open < 2.1) {
      tips.add(
        Tip(
          'Raise a bit more before the flop',
          'Your raises averaged ${open.toStringAsFixed(1)} big blinds. That\'s cheap for others to call; '
              'about 2.5 to 3 big blinds (plus one for each player who called already) thins the field.',
          weight: 1.2,
        ),
      );
    } else if (open > 5) {
      tips.add(
        Tip(
          'Smaller raises before the flop',
          'Your raises averaged ${open.toStringAsFixed(1)} big blinds. Big raises only get called by '
              'hands that beat you; 2.5 to 3 big blinds wins the same blinds and risks less.',
          weight: 1.2,
        ),
      );
    }
  }

  if (r.sizedBets >= 3) {
    final share = r.betShare / r.sizedBets;
    if (share < 0.35) {
      tips.add(
        Tip(
          'Bet bigger after the flop',
          'Your bets averaged ${pct(share)} of the pot. Small bets give others a cheap look at the next '
              'card. Bet about half to three quarters of the pot with good hands and good bluffs alike.',
          weight: 1.6,
        ),
      );
    } else if (share > 1.2) {
      tips.add(
        Tip(
          'Easy on the huge bets',
          'Your bets averaged ${pct(share)} of the pot. Bets that big fold out the hands you beat and only '
              'get called by better ones. Half to three quarters of the pot does the same job.',
          weight: 1.3,
        ),
      );
    } else {
      good.add(
        Tip(
          'Nice bet sizes',
          'Your bets averaged ${pct(share)} of the pot: right where they should be.',
          good: true,
        ),
      );
    }
  }

  if (r.calls >= 6 && r.aggression < 0.6) {
    tips.add(
      const Tip(
        'Bet more, call less',
        'You called far more often than you bet or raised. Betting wins pots when everyone folds; '
            'calling only wins at a showdown. When you like your hand, bet it.',
        weight: 1.7,
      ),
    );
  } else if (r.bets + r.raises >= 8 && r.aggression > 4 && r.bluffRate > 0.5) {
    tips.add(
      const Tip(
        'Pick your bluffs',
        'You bet a lot, and more than half your bets that got called were with very little. '
            'Bluff less often, and mostly when the cards on the table could have helped you.',
        weight: 1.5,
      ),
    );
  } else if (r.bets + r.raises >= 5 && r.aggression >= 1.2) {
    good.add(
      const Tip(
        'Good pressure',
        'You bet and raised more than you called: that\'s how pots are won.',
        good: true,
      ),
    );
  }

  if (r.facedBets >= 6) {
    final fold = r.foldToBetRate;
    if (fold > 0.65) {
      tips.add(
        Tip(
          'Don\'t fold to every bet',
          'You folded ${pct(fold)} of the time someone bet after the flop. The bots notice and bet at '
              'you with anything. Call (or raise) with a pair or a good draw more often.',
          weight: 1.6,
        ),
      );
    } else if (fold < 0.25 && r.showdowns >= 3 && r.showdownWinRate < 0.5) {
      tips.add(
        Tip(
          'Let weak hands go',
          'You called most bets after the flop but won only ${pct(r.showdownWinRate)} of your showdowns. '
              'When someone bets big and you have little, folding saves chips.',
          weight: 1.7,
        ),
      );
    }
  }

  if (r.cbetChances >= 3) {
    if (r.cbetRate < 0.35) {
      tips.add(
        const Tip(
          'Follow up your raise',
          'You raised before the flop, then usually checked the flop. Bet again (a third to a half of '
              'the pot): the others missed the flop most of the time and will fold.',
          weight: 1.1,
        ),
      );
    } else if (r.cbetRate >= 0.5) {
      good.add(const Tip('Good follow-up', 'You kept betting the flop after raising before it.', good: true));
    }
  }

  if (r.allIns >= 3 && r.allIns / r.hands > 0.15) {
    tips.add(
      const Tip(
        'Fewer all-ins',
        'You went all in a lot. It works when stacks are short (under about 10 big blinds); with more '
            'chips, a normal bet risks less and the bots call an all-in only when they\'re ahead.',
        weight: 1.4,
      ),
    );
  }

  if (r.showdowns >= 4 && r.showdownWinRate >= 0.6) {
    good.add(Tip('Strong at showdowns', 'You won ${pct(r.showdownWinRate)} of your showdowns.', good: true));
  }

  tips.sort((a, b) => b.weight.compareTo(a.weight));
  return [...tips.take(4), ...good.take(2)];
}
