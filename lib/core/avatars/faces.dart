import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/toon.dart';

part 'face_art.dart';

/// A bot's personality look (poker maps it to a play style). Your own face
/// is an [Avatar] you build in the profile.
enum Look { headband, cap, shades, fin, spiky }

/// Skin colours: real tones and cartoon ones.
enum AvatarColor {
  sun(Toon.yellow),
  mint(Color(0xFF8DE4B5)),
  lilac(Color(0xFFC9B6FF)),
  tan(Color(0xFFC68B59)),
  peach(Color(0xFFFFB38A)),
  stone(Color(0xFFB8B3A8)),
  sky(Color(0xFF7FB8E8)),
  pink(Color(0xFFFF9EC4)),
  porcelain(Color(0xFFFFE3CF)),
  honey(Color(0xFFE9B47E)),
  umber(Color(0xFFA16A45)),
  espresso(Color(0xFF7A4E35)),
  coral(Color(0xFFFF8F7A)),
  lime(Color(0xFFC6E86F)),
  aqua(Color(0xFF6FDCCF)),
  grape(Color(0xFFA98FE6));

  const AvatarColor(this.color);

  final Color color;
}

enum HeadShape { round, square, egg, wide, pear, tall }

enum Eyes { round, dots, happy, sleepy, wide, wink, shiny, angry, worried, side, big, closed, hearts, dizzy }

enum Nose { none, button, dots, round, clown, pointy, piggy }

enum Mouth { smile, grin, flat, open, small, smirk, tongue, frown, oh, fangs, buck, wavy, laugh, whistle }

/// Hair, hats and the like (on top of the head).
enum Hat {
  headband,
  cap,
  crown,
  none,
  fin,
  spiky,
  tuft,
  bob,
  afro,
  mohawk,
  bun,
  beanie,
  cowboy,
  topHat,
  wizard,
  party,
  chef,
  bow,
  viking,
  flower,
  propeller,
  headphones,
  halo,
  horns,
  bunny,
  cat,
  pirate,
  bandana,
}

/// One extra on the face.
enum Extra {
  none,
  freckles,
  blush,
  shades,
  glasses,
  monocle,
  eyepatch,
  mustache,
  beard,
  goatee,
  scar,
  bandage,
  earrings,
  tear,
  star,
}

/// A face put together from parts. Everything is open to everyone for now
/// (unlocks may come later).
@immutable
class Avatar {
  const Avatar({
    this.color = AvatarColor.sun,
    this.shape = HeadShape.round,
    this.eyes = Eyes.round,
    this.nose = Nose.none,
    this.mouth = Mouth.smile,
    this.hat = Hat.headband,
    this.extra = Extra.none,
  });

  final AvatarColor color;
  final HeadShape shape;
  final Eyes eyes;
  final Nose nose;
  final Mouth mouth;
  final Hat hat;
  final Extra extra;

  Avatar copyWith({
    AvatarColor? color,
    HeadShape? shape,
    Eyes? eyes,
    Nose? nose,
    Mouth? mouth,
    Hat? hat,
    Extra? extra,
  }) => Avatar(
    color: color ?? this.color,
    shape: shape ?? this.shape,
    eyes: eyes ?? this.eyes,
    nose: nose ?? this.nose,
    mouth: mouth ?? this.mouth,
    hat: hat ?? this.hat,
    extra: extra ?? this.extra,
  );

  /// [part] set to [value] (one of that part's enum values).
  Avatar withPart(FacePart part, Enum value) => switch (part) {
    FacePart.color => copyWith(color: value as AvatarColor),
    FacePart.shape => copyWith(shape: value as HeadShape),
    FacePart.eyes => copyWith(eyes: value as Eyes),
    FacePart.nose => copyWith(nose: value as Nose),
    FacePart.mouth => copyWith(mouth: value as Mouth),
    FacePart.hat => copyWith(hat: value as Hat),
    FacePart.extra => copyWith(extra: value as Extra),
  };

  /// This face's choice for [part].
  Enum partValue(FacePart part) => switch (part) {
    FacePart.color => color,
    FacePart.shape => shape,
    FacePart.eyes => eyes,
    FacePart.nose => nose,
    FacePart.mouth => mouth,
    FacePart.hat => hat,
    FacePart.extra => extra,
  };

  /// A random face (bots, "Surprise me"): mostly no extra, some bare heads.
  factory Avatar.random(Random rng) {
    T pick<T>(List<T> all) => all[rng.nextInt(all.length)];
    return Avatar(
      color: pick(AvatarColor.values),
      shape: pick(HeadShape.values),
      eyes: pick(Eyes.values),
      nose: rng.nextDouble() < 0.35 ? Nose.none : pick(Nose.values),
      mouth: pick(Mouth.values),
      hat: rng.nextDouble() < 0.12 ? Hat.none : pick(Hat.values),
      extra: rng.nextDouble() < 0.45 ? Extra.none : pick(Extra.values),
    );
  }

  /// The same face for the same [name] on every phone (online bots).
  factory Avatar.forName(String name) {
    var h = 0x811c9dc5;
    for (final u in name.codeUnits) {
      h = ((h ^ u) * 0x01000193) & 0xffffffff;
    }
    return Avatar.random(Random(h));
  }

  Map<String, String> toJson() => {
    'color': color.name,
    'shape': shape.name,
    'eyes': eyes.name,
    'nose': nose.name,
    'mouth': mouth.name,
    'hat': hat.name,
    'extra': extra.name,
    // For older versions of the app (one "face" part).
    'face': _legacyFace,
  };

  String get _legacyFace => extra == Extra.shades
      ? 'cool'
      : mouth == Mouth.grin
      ? 'grin'
      : eyes == Eyes.wide
      ? 'wild'
      : extra == Extra.freckles
      ? 'freckles'
      : 'smile';

  static Avatar fromJson(Map<String, dynamic> j) {
    T? named<T extends Enum>(List<T> values, String key) => values.asNameMap()[j[key]];
    // Saved by an older version: one "face" for eyes, mouth and extras.
    final legacy = j['eyes'] == null ? j['face'] : null;
    final old = switch (legacy) {
      'grin' => const Avatar(mouth: Mouth.grin),
      'cool' => const Avatar(mouth: Mouth.flat, extra: Extra.shades),
      'wild' => const Avatar(eyes: Eyes.wide, mouth: Mouth.open),
      'freckles' => const Avatar(mouth: Mouth.small, extra: Extra.freckles),
      _ => const Avatar(),
    };
    return Avatar(
      color: named(AvatarColor.values, 'color') ?? AvatarColor.sun,
      shape: named(HeadShape.values, 'shape') ?? HeadShape.round,
      eyes: named(Eyes.values, 'eyes') ?? old.eyes,
      nose: named(Nose.values, 'nose') ?? Nose.none,
      mouth: named(Mouth.values, 'mouth') ?? old.mouth,
      hat: named(Hat.values, 'hat') ?? Hat.headband,
      extra: named(Extra.values, 'extra') ?? old.extra,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Avatar &&
      other.color == color &&
      other.shape == shape &&
      other.eyes == eyes &&
      other.nose == nose &&
      other.mouth == mouth &&
      other.hat == hat &&
      other.extra == extra;

  @override
  int get hashCode => Object.hash(color, shape, eyes, nose, mouth, hat, extra);

  @override
  String toString() =>
      'Avatar(${color.name}, ${shape.name}, ${eyes.name}, ${nose.name}, ${mouth.name}, ${hat.name}, ${extra.name})';
}

/// Who sits in a seat: a name and a face.
class Persona {
  const Persona({required this.name, required this.look, required this.avatar});

  const Persona.you({this.name = 'You', this.avatar = const Avatar()}) : look = Look.headband;

  final String name;
  final Look look;
  final Avatar avatar;

  Color get skin => avatar.color.color;

  /// A bot by name (online: the server keeps the name and look). Its face
  /// comes from its name, so every phone draws the same one.
  factory Persona.bot(String name, Look look) =>
      Persona(name: name, look: look, avatar: Avatar.forName(name));

  /// The bot looks, in the order games map them to personalities (poker:
  /// cap = Rookie, shades = Rock, fin = Shark, spiky = Maniac).
  static const botLooks = [Look.cap, Look.shades, Look.fin, Look.spiky];

  /// Names bots are given at random.
  static const botNames = [
    'Pip', 'Bean', 'Tad', 'Dot', 'Boulder', 'Slate', 'Rocky', 'Flint', //
    'Finn', 'Reef', 'Marlin', 'Gill', 'Blaze', 'Zap', 'Turbo', 'Bonkers', //
    'Ace', 'Biscuit', 'Bingo', 'Blossom', 'Bramble', 'Buster', 'Button', 'Cactus', //
    'Clover', 'Cocoa', 'Comet', 'Cosmo', 'Crumpet', 'Dash', 'Dizzy', 'Domino', //
    'Dusty', 'Echo', 'Ember', 'Fizz', 'Flapjack', 'Fudge', 'Gizmo', 'Goose', //
    'Gumbo', 'Hazel', 'Honey', 'Iggy', 'Indigo', 'Jazz', 'Jellybean', 'Jinx', //
    'Juniper', 'Kiwi', 'Koko', 'Lark', 'Lemon', 'Lolly', 'Lucky', 'Mango', //
    'Maple', 'Marbles', 'Mochi', 'Moxie', 'Muffin', 'Nacho', 'Nugget', 'Noodle', //
    'Olive', 'Onyx', 'Otto', 'Pebble', 'Pepper', 'Pickle', 'Pixel', 'Plum', //
    'Pogo', 'Popcorn', 'Pretzel', 'Puddle', 'Quill', 'Rascal', 'Razzle', 'Ripley', //
    'Rosie', 'Rusty', 'Saffron', 'Sage', 'Scout', 'Shadow', 'Skipper', 'Smudge', //
    'Sprout', 'Sparky', 'Squid', 'Sunny', 'Taffy', 'Tango', 'Tinsel', 'Toffee', //
    'Trixie', 'Truffle', 'Tumble', 'Twiggy', 'Velvet', 'Waffles', 'Whisper', 'Widget', //
    'Willow', 'Wobble', 'Yeti', 'Yoyo', 'Ziggy', 'Zinnia', 'Zest', 'Bubbles', //
    'Chip', 'Duke', 'Lady Luck', 'Mittens', 'Sly', 'Snapper', 'Doc', 'Lulu', //
  ];

  /// [count] bots with random names and faces, no name twice. Each also
  /// gets a look (a hidden personality some games use), mixed round.
  static List<Persona> bots(int count, Random rng) {
    final looks = [...botLooks]..shuffle(rng);
    final names = [...botNames]..shuffle(rng);
    return [
      for (var i = 0; i < count; i++)
        Persona(name: names[i], look: looks[i % looks.length], avatar: Avatar.random(rng)),
    ];
  }
}

/// One part of a face, for the face builder.
enum FacePart { color, shape, eyes, nose, mouth, hat, extra }

/// A cartoon face, drawn from its [Avatar] parts.
class Face extends StatelessWidget {
  Face(Persona persona, {super.key, required this.size}) : avatar = persona.avatar, only = null;

  const Face.of(this.avatar, {super.key, required this.size}) : only = null;

  /// Just one part of [avatar]: a colour swatch, the bare head, a close-up
  /// of the eyes / nose / mouth, the hat on its own, or the face with its
  /// extra.
  const Face.part(this.avatar, FacePart part, {super.key, required this.size}) : only = part;

  final Avatar avatar;
  final double size;
  final FacePart? only;

  @override
  Widget build(BuildContext context) =>
      // Many paths: on its own layer so it isn't redrawn when things
      // around it move.
      RepaintBoundary(
        child: CustomPaint(size: Size.square(size), painter: FacePainter(avatar, only)),
      );
}

abstract final class RRectPath {
  static Path of(Rect r, double radius) =>
      Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));
}
