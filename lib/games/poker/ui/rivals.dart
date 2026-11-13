import 'dart:math';

import 'package:duel_engine/poker/bot.dart';

import '../../../core/avatars/characters.dart';
import '../../../core/avatars/faces.dart';

/// A bot who keeps coming back: same name, face and way of playing every
/// game, remembers how it's gone against you and says so. A rival plays a
/// level harder than the table.
class Rival {
  const Rival(
    this.name,
    this.look,
    this.style, {
    required this.hello,
    required this.beatYou,
    required this.lostToYou,
  });

  final String name;
  final Look look;
  final BotStyle style;

  /// At the start, given your record: (their wins, your wins).
  final String Function(int theirs, int yours) hello;

  /// When it knocks you out.
  final List<String> beatYou;

  /// When you knock it out.
  final List<String> lostToYou;

  Persona get persona =>
      Persona(name: name, look: look, avatar: CharacterFaces.byName[name] ?? Avatar.forName(name));

  static String _score(int theirs, int yours) => theirs == yours
      ? "we're all square at $theirs–$yours"
      : (theirs > yours ? "I'm up $theirs–$yours" : "you're up $yours–$theirs");

  static final all = [
    Rival(
      'Vinnie',
      Look.fin,
      BotStyle.shark,
      hello: (t, y) => t + y == 0
          ? "New face. I'm Vinnie. Remember it."
          : 'You again. ${_score(t, y)}. ${t >= y ? 'Let\'s keep it that way.' : 'Not for long.'}',
      beatYou: ['Same as last time.', 'Write that one down.', 'Better luck next game, pal.'],
      lostToYou: ['Fine. Next game.', 'This isn\'t over.', 'You got lucky. Again.'],
    ),
    Rival(
      'Roxy',
      Look.spiky,
      BotStyle.maniac,
      hello: (t, y) => t + y == 0
          ? 'Ooh, fresh chips! Hi, I\'m Roxy.'
          : 'My favourite opponent! ${_score(t, y)}. Shall we?',
      beatYou: ['Wheee! Bye bye!', 'Roxy wins again!', 'Told you I\'d get you.'],
      lostToYou: ['Rematch! Rematch!', 'Okay, okay, you\'re good.', 'Nooo, my chips!'],
    ),
    Rival(
      'The Professor',
      Look.shades,
      BotStyle.rock,
      hello: (t, y) =>
          t + y == 0 ? 'Good evening. I shall be studying you.' : 'Ah, my student returns. ${_score(t, y)}.',
      beatYou: ['Patience, as ever, prevails.', 'Class dismissed.', 'Study harder.'],
      lostToYou: ['Well played. I shall review my notes.', 'Impressive. Most impressive.', 'Hm. An anomaly.'],
    ),
  ];

  /// Who sits in this game: the rival you've played least lately.
  static Rival pick(Random rng, int Function(String name) played) {
    final least = all.map((r) => played(r.name)).reduce(min);
    final pool = all.where((r) => played(r.name) == least).toList();
    return pool[rng.nextInt(pool.length)];
  }
}
