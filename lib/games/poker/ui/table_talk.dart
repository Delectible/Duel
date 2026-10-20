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
/// as little as possible, the shark is smug, the maniac is loud, and so
/// on: what they say hints at how they play.
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
  BotStyle.grinder: {
    Talk.allIn: ['Standard.', 'Easy shove, by the chart.'],
    Talk.bigRaise: ['Three-bet.', 'Raise, for value.'],
    Talk.fold: ['Easy fold.', 'Not with that price.'],
    Talk.winBig: ['Good spot.', 'Plus EV.'],
    Talk.winSmall: ['Small ball.', 'Every chip counts.'],
    Talk.lucky: ['Had the odds. Barely.', 'That evens it out.'],
    Talk.lose: ['Cooler.', 'Played it right. Long run.'],
    Talk.niceHand: ['Good call.', 'Well played, sir or madam.'],
    Talk.bust: ['GG. Variance.', 'Next session.'],
  },
  BotStyle.fish: {
    Talk.allIn: ['Something tells me…', 'All in! I feel it!'],
    Talk.bigRaise: ['Raise? Sure, why not!', 'Ooh, I like this one.'],
    Talk.fold: ['Fine, fine.', "I'd have hit it, you know."],
    Talk.winBig: ['Rivered you! Ha!', 'Knew it was coming!', 'Gutshot, baby!'],
    Talk.winSmall: ['Had to see it!', 'Worth the call!'],
    Talk.lucky: ['Never fold a draw!', 'One outer! Did you see that?'],
    Talk.lose: ['So close!', 'It was one card off!'],
    Talk.niceHand: ['I had to see it!', 'Ah, what did you have?'],
    Talk.bust: ['Who needs chips anyway?', 'Fun while it lasted!'],
  },
  BotStyle.trapper: {
    Talk.allIn: ['Oh dear. All in, I suppose.', 'I think I have to…'],
    Talk.bigRaise: ['Hm, maybe a raise.', 'Just a little bump.'],
    Talk.fold: ['Too rich.', "You've got me."],
    Talk.winBig: ['Oh, did I not mention?', 'Snap.', 'Gotcha.'],
    Talk.winSmall: ['Little by little.', 'Mm, thank you.'],
    Talk.lucky: ['Oh my.', 'Sometimes the deck is kind.'],
    Talk.lose: ['Didn’t see that coming.', 'Well. Well, well.'],
    Talk.niceHand: ['Sneaky! I like it.', 'You got me there.'],
    Talk.bust: ['Caught in my own trap.', 'Good game, all.'],
  },
  BotStyle.bully: {
    Talk.allIn: ['You gonna call that?', 'Put it all in. Go on.', 'Pay up or fold.'],
    Talk.bigRaise: ['Bigger.', 'Pay to see it.', 'Too much for you?'],
    Talk.fold: ['Take it. Crumbs.', 'Fine. Next one’s mine.'],
    Talk.winBig: ['Who’s next?', 'Stack ’em up!', 'Don’t mind me.'],
    Talk.winSmall: ['Mine.', 'Keep folding.'],
    Talk.lucky: ['Told you, my table.', 'Never in doubt.'],
    Talk.lose: ['You won’t do that twice.', 'Huh. Lucky.'],
    Talk.niceHand: ['Enjoy it.', 'Okay, okay.'],
    Talk.bust: ['This table’s rigged.', 'Whatever.'],
  },
  BotStyle.sheriff: {
    Talk.allIn: ['Nobody pushes me around.', "All in. I'm not buying it."],
    Talk.bigRaise: ["Raise. Let's see who's lying.", 'I smell a bluff.'],
    Talk.fold: ["Fine. But I'm watching you.", 'This once.'],
    Talk.winBig: ['Knew you had nothing!', 'Caught ya!', 'Justice!'],
    Talk.winSmall: ['Called it.', 'Nice try.'],
    Talk.lucky: ['Still a good call.', 'Had to keep you honest.'],
    Talk.lose: ['You actually had it?', 'Huh. Didn’t see that.'],
    Talk.niceHand: ['Fair enough, you had it.', 'Okay, you had it.'],
    Talk.bust: ['Someone had to keep you honest.', 'I regret nothing.'],
  },
};

String talkLine(BotStyle style, Talk talk, Random rng) {
  final options = _lines[style]![talk]!;
  return options[rng.nextInt(options.length)];
}
