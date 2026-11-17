import 'package:duel_engine/difficulty.dart';
import 'package:duel_engine/poker/bot.dart';
import 'package:duel_engine/poker/reads.dart';

import '../../../core/account/achievements.dart';
import '../../../core/avatars/faces.dart';
import 'rivals.dart';

/// One rung of the Boss Tables ladder: a named shark with a habit you can
/// learn to beat. Each boss table is a Sit & Go: the boss and three bots.
/// Finish ahead of the boss to beat them (and unlock the next).
///
/// Up the ladder the bosses get harder: tougher play, their habit showing
/// less often, and more of what they remember of you put to use.
class Boss {
  const Boss({
    required this.rung,
    required this.rival,
    required this.quirk,
    required this.habit,
    required this.difficulty,
    required this.stake,
    required this.multiple,
    required this.quirkStrength,
    required this.memoryWeight,
    required this.achievement,
  });

  /// 0 = the first boss.
  final int rung;

  /// Name, face, style and lines.
  final Rival rival;
  final Quirk quirk;

  /// The habit in a few words.
  final String habit;
  final Difficulty difficulty;

  /// To sit down; beating them pays [multiple] times it (all of it back).
  final int stake;
  final int multiple;

  /// How often the habit shows (1 every time).
  final double quirkStrength;

  /// How much of what they remember of you they use (0..1).
  final double memoryWeight;
  final Achievement achievement;

  String get name => rival.name;

  /// What beating them pays back (the stake included).
  int get prize => stake * multiple;

  /// Winning the whole table too: another stake on top.
  int get tableBonus => stake;

  /// The three bots alongside: a level below the boss (Hard at the top).
  Difficulty get tableDifficulty => rung >= 4
      ? Difficulty.hard
      : Difficulty.values[(difficulty.index - 1).clamp(0, Difficulty.values.length - 1)];

  bool get last => rung == ladder.length - 1;

  static Boss? byName(String name) => ladder.where((b) => b.name == name).firstOrNull;

  static final ladder = [
    Boss(
      rung: 0,
      rival: Rival(
        'Lucky Lou',
        Look.cap,
        BotStyle.fish,
        hello: (t, y) => t + y == 0
            ? "Howdy! Lady Luck's sittin' right here on my shoulder."
            : "Back for more? ${y > 0 ? 'You got me $y time${y == 1 ? '' : 's'}, but luck turns.' : 'Luck stays with Lou.'}",
        beatYou: ['Yee-haw! Luck never lies!', 'Told ya, Lady Luck loves Lou.', 'One more card, every time!'],
        lostToYou: [
          'Well, shoot. My luck ran dry.',
          'Dang. Should\'ve folded that one.',
          'Next time, partner.',
        ],
      ),
      quirk: Quirk.callsRivers,
      habit: 'Calls every river. Never folds a draw.',
      difficulty: Difficulty.easy,
      stake: 200,
      multiple: 3,
      quirkStrength: 1,
      memoryWeight: 0.3,
      achievement: Achievement.bossLou,
    ),
    Boss(
      rung: 1,
      rival: Rival(
        'Granny Gold',
        Look.headband,
        BotStyle.rock,
        hello: (t, y) => t + y == 0
            ? 'Hello, dear. Sit down, have a biscuit. I never bluff, you know.'
            : 'Hello again, dear. ${y > 0 ? 'You surprised me last time.' : 'Still hungry?'}',
        beatYou: ['Oh dear, was that too strong?', 'Patience, dear. Always patience.', 'Another biscuit?'],
        lostToYou: [
          'Well I never! Well played, dear.',
          'You remind me of my late husband.',
          'Oh my. Good for you.',
        ],
      ),
      quirk: Quirk.trapsNeverBluffs,
      habit: 'Never bluffs, but traps with monsters.',
      difficulty: Difficulty.normal,
      stake: 500,
      multiple: 3,
      quirkStrength: 0.9,
      memoryWeight: 0.5,
      achievement: Achievement.bossGranny,
    ),
    Boss(
      rung: 2,
      rival: Rival(
        'Captain Chaos',
        Look.spiky,
        BotStyle.maniac,
        hello: (t, y) => t + y == 0
            ? 'ARRR! Raise! Raise everything! Who are you? RAISE!'
            : 'YOU! ${y > 0 ? 'You sank me last time. Revenge!' : 'Back to walk the plank?'}',
        beatYou: ['Overboard with ye!', 'CHAOS REIGNS!', 'Raise, raise, and RAISE!'],
        lostToYou: ['Blast! Sunk by a landlubber!', 'Mutiny! Rematch!', 'Arr... fair winds.'],
      ),
      quirk: Quirk.raisesEverything,
      habit: 'Raises almost every hand.',
      difficulty: Difficulty.normal,
      stake: 1000,
      multiple: 3,
      quirkStrength: 0.8,
      memoryWeight: 0.6,
      achievement: Achievement.bossChaos,
    ),
    Boss(
      rung: 3,
      rival: Rival(
        'The Mime',
        Look.shades,
        BotStyle.shark,
        hello: (t, y) => t + y == 0 ? '…' : '… (tips an invisible hat)',
        beatYou: ['… (waves goodbye)', '… (bows deeply)', '… (mimes a tiny violin)'],
        lostToYou: ['… (wipes away a tear)', '… (claps silently)', '… (mimes a wall, then walks into it)'],
      ),
      quirk: Quirk.noTells,
      habit: 'No tells at all: always takes the same time.',
      difficulty: Difficulty.hard,
      stake: 2500,
      multiple: 3,
      quirkStrength: 0.75,
      memoryWeight: 0.8,
      achievement: Achievement.bossMime,
    ),
    Boss(
      rung: 4,
      rival: Rival(
        'Madame Nine',
        Look.fin,
        BotStyle.shark,
        hello: (t, y) => t + y == 0
            ? 'I have been expecting you. I see everything you do.'
            : 'Welcome back. ${y > 0 ? 'You won once. I have studied that game.' : 'I know you better every time.'}',
        beatYou: ['As I foresaw.', 'Your cards told me everything.', 'The cards never lie to me.'],
        lostToYou: ['This… I did not foresee.', 'Remarkable. You have changed.', 'The student surpasses me.'],
      ),
      quirk: Quirk.studiesYou,
      habit: 'Studies how you play and adapts mid-game.',
      difficulty: Difficulty.hard,
      stake: 5000,
      multiple: 5,
      quirkStrength: 0.65,
      memoryWeight: 1,
      achievement: Achievement.bossMadame,
    ),
  ];
}

/// The tournaments: 18 players, three tables, the top three paid 50 / 30
/// / 20% of the prize pool (the bots' buy-ins come from the bank).
enum TournamentTier {
  freeroll('Daily Freeroll', buyIn: 0, pool: 1000, difficulty: Difficulty.easy),
  regular('Regular', buyIn: 500, pool: 9000, difficulty: Difficulty.normal),
  main('Main Event', buyIn: 5000, pool: 90000, difficulty: Difficulty.hard);

  const TournamentTier(this.label, {required this.buyIn, required this.pool, required this.difficulty});

  final String label;
  final int buyIn;
  final int pool;
  final Difficulty difficulty;

  static TournamentTier? byName(String? name) => values.asNameMap()[name];
}

/// How much a rival uses what it remembers of you: more the harder it is.
double rivalMemoryWeight(Difficulty d) => switch (d) {
  Difficulty.easy => 0.3,
  Difficulty.normal => 0.6,
  Difficulty.hard => 1,
};

/// What a rival or boss says about how it remembers you playing (null:
/// it hasn't seen enough of you yet).
String? memoryLine(ReadMemory memory) {
  if (memory.hands < 12) return null;
  final r = memory.reads;
  if (r.facedBets >= 8 && r.foldToBetRate > 0.6) return 'Still folding when someone bets? I remember.';
  if (r.aggressiveShowdowns >= 3 && r.bluffRate > 0.35) return "I haven't forgotten your bluffs.";
  if (r.vpipRate > 0.45) return 'Still playing every hand, I see.';
  if (r.vpipRate < 0.18) return 'Waiting for aces again? I know your game.';
  if (r.aggression > 2.5) return 'You like to push people around. Not me.';
  return "I've been studying how you play.";
}
