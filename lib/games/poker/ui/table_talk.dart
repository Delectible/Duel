import 'dart:math';

import 'package:duel_engine/poker/bot.dart';

/// What a bot might pipe up about.
enum Talk {
  /// It just shoved.
  allIn,

  /// A big raise.
  bigRaise,

  /// It folded to your bet.
  fold,

  /// Won a big pot.
  winBig,

  /// Won a little one.
  winSmall,

  /// Won an all-in it was behind in.
  lucky,

  /// Lost a big pot at the showdown.
  lose,

  /// You just won a big one off it.
  niceHand,

  /// Knocked out.
  bust,
}

/// Each bot has a voice: the rookie is nervous and polite, the rock says
/// as little as possible, the shark is smug, the maniac is loud.
const _lines = <BotStyle, Map<Talk, List<String>>>{
  BotStyle.rookie: {
    Talk.allIn: ['Oh no. Okay. All in!', 'I think this is right?', 'Here goes nothing…'],
    Talk.bigRaise: ['Is this a lot?', 'I raise! I think.'],
    Talk.fold: ['Nope, too scary.', 'You can have it!', 'I fold. Was that right?'],
    Talk.winBig: ['Wait, I won?!', 'Mum is going to be so proud!', 'I did it!!'],
    Talk.winSmall: ['Ooh, chips!', 'Yay!'],
    Talk.lucky: ['Sorry! Sorry!', 'I closed my eyes and it worked!'],
    Talk.lose: ['Aw, shucks.', 'I really liked that hand…'],
    Talk.niceHand: ['Nice hand!', 'How did you know?!'],
    Talk.bust: ['Good game, everyone!', 'That was fun anyway!'],
  },
  BotStyle.rock: {
    Talk.allIn: ['All in.', 'I have it.'],
    Talk.bigRaise: ['Raise.', 'Mm.'],
    Talk.fold: ['Fold.', 'Not today.'],
    Talk.winBig: ['As expected.', 'Patience pays.'],
    Talk.winSmall: ['Mm.', 'Fine.'],
    Talk.lucky: ["…I'll take it.", 'Variance.'],
    Talk.lose: ['Hm.', 'Noted.'],
    Talk.niceHand: ['Well played.', 'Hm. Good hand.'],
    Talk.bust: ['GG.', 'Back to the library.'],
  },
  BotStyle.shark: {
    Talk.allIn: ['Your move.', 'All of it. Call me.', "Let's see your nerve."],
    Talk.bigRaise: ['Make it bigger.', 'Pay to play.', 'Too rich for you?'],
    Talk.fold: ["I'll get you next time.", 'Enjoy it while it lasts.'],
    Talk.winBig: ['Thanks for the donation.', 'Ship it!', 'Too easy.'],
    Talk.winSmall: ['Mine.', 'Thank you very much.'],
    Talk.lucky: ['Skill.', 'Calculated.'],
    Talk.lose: ['Lucky.', "Enjoy it. It won't last."],
    Talk.niceHand: ['Lucky river.', 'Hmph. Nice hand.'],
    Talk.bust: ['Rigged.', "I'll be back."],
  },
  BotStyle.maniac: {
    Talk.allIn: ['ALL IN BABY!', 'YOLO!', 'Who wants to gamble?!'],
    Talk.bigRaise: ['RAISE! Woo!', 'More chips! MORE!', "Let's make it spicy!"],
    Talk.fold: ['Boring! Fine.', 'Ugh, okay, fold.'],
    Talk.winBig: ['WOOOO!', 'MONSTER POT!', "Can't stop, won't stop!"],
    Talk.winSmall: ['Easy money!', 'Gimme gimme!'],
    Talk.lucky: ['Never in doubt!!', 'The poker gods love me!'],
    Talk.lose: ['NOOO!', 'I was SO close!', 'Again! Again!'],
    Talk.niceHand: ['Ooh, sneaky!', 'Okay okay, nice one!'],
    Talk.bust: ['Rebuy! Can I rebuy?', 'Worth it!'],
  },
};

String talkLine(BotStyle style, Talk talk, Random rng) {
  final options = _lines[style]![talk]!;
  return options[rng.nextInt(options.length)];
}
