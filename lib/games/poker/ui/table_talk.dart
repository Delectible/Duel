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

  /// You showed the bluff it folded to.
  bluffed,

  /// You showed the strong hand it folded to.
  shownStrong,

  /// You lost a showdown with a strong hand and showed it anyway.
  badBeat,

  /// You showed the bluff it just caught.
  caughtBluff,
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
    Talk.bluffed: ['You were bluffing?!', 'That is so mean! …Teach me?'],
    Talk.shownStrong: ['Phew, glad I folded!', 'Oh wow, good fold by me.'],
    Talk.badBeat: ["Oh no, that's so unlucky!", 'Ouch, sorry!'],
    Talk.caughtBluff: ['I caught you? Really?', 'I called and it worked!'],
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
    Talk.bluffed: ['Noted.', 'Hm. Noted.'],
    Talk.shownStrong: ['Good fold.', 'As I thought.'],
    Talk.badBeat: ['Unlucky.', 'Cooler.'],
    Talk.caughtBluff: ['Thought so.', 'Expected.'],
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
    Talk.bluffed: ['Cute. Do it again.', 'I let you have that one.'],
    Talk.shownStrong: ['Obviously. I folded.', 'Saw it coming.'],
    Talk.badBeat: ['Cry me a river.', 'Should have folded.'],
    Talk.caughtBluff: ['Nice try, rookie.', 'I own you.'],
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
    Talk.bluffed: ['NO WAY! Respect!', 'Ha! You bluffed me! Love it!'],
    Talk.shownStrong: ['Boring! Bluff next time!', 'Yeah yeah, you had it.'],
    Talk.badBeat: ['OOF! Brutal!', 'That hurts to look at!'],
    Talk.caughtBluff: ['GOTCHA!', 'Hahaha, caught ya!'],
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
    Talk.bluffed: ['Interesting. Adjusting.', 'Logged.'],
    Talk.shownStrong: ['Standard fold.', 'Correct fold, then.'],
    Talk.badBeat: ['Cooler. Nothing to do.', 'Variance. Standard.'],
    Talk.caughtBluff: ['Bluff-catcher works.', 'Priced in.'],
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
    Talk.bluffed: ['I knew it! I should have called!', 'Next time I call!'],
    Talk.shownStrong: ['See, I can fold!', 'Good thing I folded!'],
    Talk.badBeat: ['Ha, the river loves me!', 'Gotta play the odds, friend.'],
    Talk.caughtBluff: ['Told you I had to see it!', 'See? Always call!'],
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
    Talk.bluffed: ["Oh, you'll pay for that.", "I'll remember that."],
    Talk.shownStrong: ['Mm, I believe it.', 'Nice. Patience.'],
    Talk.badBeat: ['Oh dear, poor thing.', 'That was cruel of the deck.'],
    Talk.caughtBluff: ['Mm, I wondered.', 'Patience, dear.'],
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
    Talk.bluffed: ['Try that again. I dare you.', 'Lucky I let it go.'],
    Talk.shownStrong: ['Whatever.', 'Big deal.'],
    Talk.badBeat: ['Shoulda folded.', 'Too bad, so sad.'],
    Talk.caughtBluff: ['Nice try. Not on me.', 'Bluff me? Ha.'],
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
    Talk.bluffed: ['I KNEW it! Never again.', "Next time I'm calling you down."],
    Talk.shownStrong: ['Fine, you had it this time.', 'Hm. Honest, for once.'],
    Talk.badBeat: ['Rough one. You had it.', 'Honest hand, bad luck.'],
    Talk.caughtBluff: ['CAUGHT YOU!', 'Knew you were lying!'],
  },
  BotStyle.nit: {
    Talk.allIn: ["I've waited all night for this.", 'All in. Finally.'],
    Talk.bigRaise: ['Raise. I mean it.', 'This one I like.'],
    Talk.fold: ['Fold.', 'Fold. Again.', 'Not good enough.'],
    Talk.winBig: ['Told you I had it.', 'Worth the wait.'],
    Talk.winSmall: ['Mm.', 'Small but safe.'],
    Talk.lucky: ['Unusual for me.', 'Hm. Fortunate.'],
    Talk.lose: ['I had the best hand!', 'That never happens to me.'],
    Talk.niceHand: ['Well. Fine.', 'Good hand.'],
    Talk.bust: ['I played it right.', 'Too careful, maybe.'],
    Talk.bluffed: ['I folded the best hand?!', 'Ugh. Never again.'],
    Talk.shownStrong: ['Correct fold.', 'Knew it.'],
    Talk.badBeat: ['Unlucky. I know the feeling.', 'Cold.'],
    Talk.caughtBluff: ['Bluffing me never works.', 'I only call with the goods.'],
  },
  BotStyle.gambler: {
    Talk.allIn: ["Let's gamble!", "Big pot? I'm in."],
    Talk.bigRaise: ['Make it worth it.', 'Bigger pots, better stories.'],
    Talk.fold: ['Too small to bother.', 'Wake me when it gets big.'],
    Talk.winBig: ['THAT is why I play!', 'Jackpot!'],
    Talk.winSmall: ['Peanuts.', 'Small change.'],
    Talk.lucky: ['Fortune favours the bold!', 'Never in doubt!'],
    Talk.lose: ['Easy come, easy go.', 'Next one I double up.'],
    Talk.niceHand: ['Big hand, respect.', 'Now that was a pot.'],
    Talk.bust: ['Went down swinging!', 'All or nothing, baby.'],
    Talk.bluffed: ['You bluffed me in a big one? Respect.', 'Gutsy!'],
    Talk.shownStrong: ['Should have gambled.', 'Bah, you had it.'],
    Talk.badBeat: ["That's gambling!", 'The deck giveth…'],
    Talk.caughtBluff: ['Bold. Wrong, but bold.', 'Ha! Not this time.'],
  },
  BotStyle.copycat: {
    Talk.allIn: ['Your move, my move.', 'Monkey see, monkey shove.'],
    Talk.bigRaise: ['Just like you.', 'Learned that from you.'],
    Talk.fold: ['You fold, I fold.', 'Copying you: fold.'],
    Talk.winBig: ['Your style, my chips.', 'Thanks for the lesson.'],
    Talk.winSmall: ['Like you would.', 'Copied and pasted.'],
    Talk.lucky: ['You do that too!', 'Learned from the best.'],
    Talk.lose: ['Hm, should have copied better.', 'Not quite like you.'],
    Talk.niceHand: ['Teach me that one.', 'Noted. Copying it.'],
    Talk.bust: ['Copied the wrong move.', 'Back to studying you.'],
    Talk.bluffed: ['Ooh, adding that to my list.', 'So THAT is how you do it.'],
    Talk.shownStrong: ['Copying that fold.', 'Good one. Mine now.'],
    Talk.badBeat: ['Even you lose those.', 'Ouch, that looked familiar.'],
    Talk.caughtBluff: ['I saw that coming. Saw it from you.', 'My move, really.'],
  },
  BotStyle.wildcard: {
    Talk.allIn: ['Feeling it! Or not!', 'Why not?'],
    Talk.bigRaise: ['Surprise!', 'Guess what I have.'],
    Talk.fold: ['Not in the mood.', 'Meh.'],
    Talk.winBig: ['Did not see that coming, did you?', 'Chaos pays!'],
    Talk.winSmall: ['Whatever works.', 'Tiny win, big smile.'],
    Talk.lucky: ['The universe agrees!', 'Random is my friend.'],
    Talk.lose: ['New plan!', 'Changing everything.'],
    Talk.niceHand: ['Huh, nice.', 'Unexpected!'],
    Talk.bust: ['Plot twist!', 'That was a ride.'],
    Talk.bluffed: ['Ha! Wild! I like it.', 'Nice, totally random?'],
    Talk.shownStrong: ['Boring! But fine.', 'Sure, sure.'],
    Talk.badBeat: ['Weird game, eh?', 'Chaos strikes!'],
    Talk.caughtBluff: ['Gotcha, maybe.', 'Wild guess paid off!'],
  },
};

String talkLine(BotStyle style, Talk talk, Random rng) {
  final options = _lines[style]![talk]!;
  return options[rng.nextInt(options.length)];
}
