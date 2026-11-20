import 'dart:math';

/// Things said at the blackjack table.
enum BjTalk {
  hello,
  bust,
  blackjack,
  youBlackjack,
  dealerBust,
  dealerBlackjack,
  youDouble,
  youSplit,
  bigWin,
  bigLoss,
  push,
  win,
  dealerTwentyOne,
  shuffle,
  leaving,
}

const _bot = <BjTalk, List<String>>{
  BjTalk.hello: ['Evening.', 'Deal me in.', 'Feeling lucky tonight.', 'Room for one more?'],
  BjTalk.bust: ['Too many!', 'Ugh, 22.', 'Should\'ve stood.', 'Greedy, greedy.', 'Over. Again.'],
  BjTalk.blackjack: ['Blackjack, baby!', 'Twenty-one, pay me!', 'Ace and a face!', 'Now we\'re talking.'],
  BjTalk.youBlackjack: ['Nice one!', 'Look at you!', 'Show-off.', 'Lucky!'],
  BjTalk.dealerBust: ['Dealer busts! Pay the table!', 'Woo! Everybody wins!', 'There it is!', 'Ha! Over!'],
  BjTalk.dealerBlackjack: ['Of course.', 'Brutal.', 'Every time.', 'Who stacked this shoe?'],
  BjTalk.youDouble: ['Bold!', 'Double down? Brave.', 'Go on then!', 'Here we go…'],
  BjTalk.youSplit: ['Two for the price of two.', 'Splitting? Respect.', 'Double trouble.'],
  BjTalk.bigWin: ['Big money!', 'Now that\'s a payout.', 'Save some for us!'],
  BjTalk.bigLoss: ['Oof.', 'That one hurt.', 'Rough hand.', 'The house giveth…'],
  BjTalk.push: ['A push. Fine.', 'Nobody wins.', 'Again!'],
  BjTalk.win: ['Thank you!', 'I\'ll take it.', 'Up we go.'],
  BjTalk.dealerTwentyOne: ['Twenty-one? Come on!', 'Unreal.'],
  BjTalk.shuffle: ['Fresh shoe!', 'New shuffle, new luck.'],
  BjTalk.leaving: ['I\'m out. Night all.', 'Busted. See you.', 'That\'s me done.'],
};

const _dealer = <BjTalk, List<String>>{
  BjTalk.hello: ['Welcome. Bets, please.', 'Place your bets.'],
  BjTalk.dealerBust: ['Dealer busts.', 'Too many for me.', 'Over. Paying the table.'],
  BjTalk.dealerBlackjack: ['Dealer has blackjack.', 'Sorry, folks: blackjack.'],
  BjTalk.youBlackjack: ['Blackjack! Pays three to two.', 'Blackjack, very nice.'],
  BjTalk.dealerTwentyOne: ['Twenty-one.'],
  BjTalk.shuffle: ['Shuffling up a fresh shoe.', 'Cut card\'s out: new shoe.'],
  BjTalk.push: ['Push.'],
};

String? botLine(BjTalk t, Random rng) {
  final lines = _bot[t];
  return lines == null ? null : lines[rng.nextInt(lines.length)];
}

String? dealerLine(BjTalk t, Random rng) {
  final lines = _dealer[t];
  return lines == null ? null : lines[rng.nextInt(lines.length)];
}
