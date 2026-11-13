import 'faces.dart';

/// Faces made for Duel's named characters, so each looks like who they
/// are (everyone else's face comes from their name).
abstract final class CharacterFaces {
  /// The rivals.
  static const vinnie = Avatar(
    color: AvatarColor.stone,
    shape: HeadShape.square,
    eyes: Eyes.side,
    nose: Nose.pointy,
    mouth: Mouth.smirk,
    hat: Hat.topHat,
    extra: Extra.mustache,
  );
  static const roxy = Avatar(
    color: AvatarColor.pink,
    eyes: Eyes.wide,
    nose: Nose.button,
    mouth: Mouth.laugh,
    hat: Hat.mohawk,
    extra: Extra.star,
  );
  static const professor = Avatar(
    color: AvatarColor.porcelain,
    shape: HeadShape.tall,
    eyes: Eyes.sleepy,
    nose: Nose.round,
    mouth: Mouth.flat,
    hat: Hat.tuft,
    extra: Extra.monocle,
  );

  /// The bosses.
  static const luckyLou = Avatar(
    color: AvatarColor.lime,
    eyes: Eyes.wink,
    nose: Nose.button,
    mouth: Mouth.grin,
    hat: Hat.cowboy,
    extra: Extra.freckles,
  );
  static const grannyGold = Avatar(
    color: AvatarColor.porcelain,
    shape: HeadShape.egg,
    eyes: Eyes.happy,
    nose: Nose.round,
    mouth: Mouth.small,
    hat: Hat.bun,
    extra: Extra.glasses,
  );
  static const captainChaos = Avatar(
    color: AvatarColor.coral,
    shape: HeadShape.wide,
    eyes: Eyes.angry,
    nose: Nose.clown,
    mouth: Mouth.open,
    hat: Hat.pirate,
    extra: Extra.eyepatch,
  );
  static const mime = Avatar(
    color: AvatarColor.porcelain,
    shape: HeadShape.egg,
    eyes: Eyes.closed,
    mouth: Mouth.flat,
    hat: Hat.beanie,
    extra: Extra.tear,
  );
  static const madameNine = Avatar(
    color: AvatarColor.grape,
    shape: HeadShape.tall,
    eyes: Eyes.shiny,
    nose: Nose.pointy,
    mouth: Mouth.smirk,
    hat: Hat.wizard,
    extra: Extra.earrings,
  );

  /// By name (bosses are listed by name on the Boss Tables screen).
  static const byName = {
    'Vinnie': vinnie,
    'Roxy': roxy,
    'The Professor': professor,
    'Lucky Lou': luckyLou,
    'Granny Gold': grannyGold,
    'Captain Chaos': captainChaos,
    'The Mime': mime,
    'Madame Nine': madameNine,
  };
}
