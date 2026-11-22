import 'package:flutter/material.dart';

import '../avatars/faces.dart';
import 'cosmetics.dart';

/// What a store item is.
enum ItemKind { face, back, felt }

/// One thing in the store: a face part, a card back or a table felt.
/// [id]s are saved in the account: `hat.crown`, `back.ghost`, `felt.ocean`.
class ShopItem {
  const ShopItem._(this.id, this.name, this.price, this.kind, {this.part, this.value, this.back, this.felt});

  final String id;
  final String name;
  final int price;
  final ItemKind kind;

  /// A face item: which part, and its value.
  final FacePart? part;
  final Enum? value;
  final CardBack? back;
  final TableFelt? felt;

  bool get free => price == 0;

  static ShopItem face(FacePart part, Enum value) => ShopItem._(
    faceId(part, value),
    _title(value.name),
    Shop.facePrices[part]?[value.name] ?? 0,
    ItemKind.face,
    part: part,
    value: value,
  );

  static ShopItem ofBack(CardBack b) =>
      ShopItem._('back.${b.name}', b.label, Shop.backPrices[b] ?? 0, ItemKind.back, back: b);

  static ShopItem ofFelt(TableFelt f) =>
      ShopItem._('felt.${f.name}', f.label, Shop.feltPrices[f] ?? 0, ItemKind.felt, felt: f);

  static String faceId(FacePart part, Enum value) => '${part.name}.${value.name}';

  /// "topHat" -> "Top hat".
  static String _title(String name) {
    final words = name.replaceAllMapped(RegExp('[A-Z]'), (m) => ' ${m[0]!.toLowerCase()}');
    return words[0].toUpperCase() + words.substring(1);
  }

  @override
  bool operator ==(Object other) => other is ShopItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A set of items: own them all and it pays [prize] once and puts a badge
/// on your profile.
class Collection {
  const Collection(this.id, this.name, this.icon, this.color, this.items, this.prize);

  final String id;
  final String name;

  /// The badge.
  final IconData icon;
  final Color color;
  final List<String> items;
  final int prize;
}

/// Prices, sets and lookups. Everyday parts are free; the fun ones cost
/// pips. Prices are a first guess.
abstract final class Shop {
  static const facePrices = <FacePart, Map<String, int>>{
    FacePart.color: {
      'mint': 100, 'lilac': 100, 'sky': 100, 'pink': 100, 'coral': 100, //
      'lime': 150, 'aqua': 150, 'grape': 150,
    },
    FacePart.eyes: {
      'wink': 100, 'worried': 100, 'angry': 100, 'big': 100, //
      'shiny': 150, 'hearts': 250, 'dizzy': 250,
    },
    FacePart.nose: {'piggy': 150, 'clown': 200},
    FacePart.mouth: {
      'tongue': 100, 'wavy': 100, 'laugh': 100, 'whistle': 100, //
      'buck': 150, 'fangs': 250,
    },
    FacePart.hat: {
      'headphones': 150, 'bow': 150, 'flower': 150, 'party': 200, 'chef': 250, //
      'cowboy': 300, 'bunny': 300, 'cat': 300, 'propeller': 400, 'pirate': 400,
      'viking': 500, 'topHat': 500, 'wizard': 600, 'horns': 600, 'halo': 800, 'crown': 1000,
    },
    FacePart.extra: {
      'bandage': 80, 'tear': 80, 'earrings': 120, 'mustache': 150, 'beard': 150, //
      'goatee': 150, 'scar': 150, 'shades': 200, 'star': 200, 'eyepatch': 300, 'monocle': 400,
    },
  };

  static const backPrices = {
    CardBack.navy: 100,
    CardBack.stripes: 200,
    CardBack.polka: 200,
    CardBack.stars: 300,
    CardBack.ghost: 400,
    CardBack.royal: 600,
  };

  static const feltPrices = {
    TableFelt.ocean: 200,
    TableFelt.berry: 200,
    TableFelt.teal: 300,
    TableFelt.desert: 300,
    TableFelt.plum: 300,
    TableFelt.midnight: 500,
  };

  static const collections = [
    Collection('pirate', 'Pirate', Icons.sailing_rounded, Color(0xFF2E9BFF), [
      'hat.pirate',
      'extra.eyepatch',
      'extra.scar',
      'felt.ocean',
    ], 200),
    Collection('party', 'Party animal', Icons.celebration_rounded, Color(0xFFFF8A3D), [
      'hat.party',
      'eyes.hearts',
      'mouth.laugh',
      'back.polka',
    ], 200),
    Collection('west', 'Wild West', Icons.landscape_rounded, Color(0xFFC07A3C), [
      'hat.cowboy',
      'extra.mustache',
      'mouth.whistle',
      'felt.desert',
    ], 250),
    Collection('spooky', 'Spooky', Icons.blur_on_rounded, Color(0xFF9B6BFF), [
      'hat.horns',
      'mouth.fangs',
      'eyes.dizzy',
      'back.ghost',
    ], 300),
    Collection('night', 'Night sky', Icons.nights_stay_rounded, Color(0xFF262A44), [
      'hat.wizard',
      'extra.star',
      'back.stars',
      'felt.midnight',
    ], 350),
    Collection('royal', 'Royalty', Icons.workspace_premium_rounded, Color(0xFFD9A93A), [
      'hat.crown',
      'extra.monocle',
      'back.royal',
      'felt.berry',
    ], 400),
  ];

  /// Face parts the store shows (the profile's tabs, Head aside: all free).
  static const faceParts = [
    FacePart.color,
    FacePart.eyes,
    FacePart.nose,
    FacePart.mouth,
    FacePart.hat,
    FacePart.extra,
  ];

  static List<Enum> valuesOf(FacePart part) => switch (part) {
    FacePart.color => AvatarColor.values,
    FacePart.shape => HeadShape.values,
    FacePart.eyes => Eyes.values,
    FacePart.nose => Nose.values,
    FacePart.mouth => Mouth.values,
    FacePart.hat => Hat.values,
    FacePart.extra => Extra.values,
  };

  /// Every item, free ones too.
  static final List<ShopItem> all = [
    for (final part in FacePart.values)
      for (final v in valuesOf(part)) ShopItem.face(part, v),
    for (final b in CardBack.values) ShopItem.ofBack(b),
    for (final f in TableFelt.values) ShopItem.ofFelt(f),
  ];

  static final Map<String, ShopItem> byId = {for (final i in all) i.id: i};

  /// Items worth buying (the store's shelves).
  static List<ShopItem> forSale(ItemKind kind, {FacePart? part}) => [
    for (final i in all)
      if (i.kind == kind && !i.free && (part == null || i.part == part)) i,
  ];

  /// The ids of [avatar]'s parts (owned by whoever wears them).
  static Iterable<String> idsOf(Avatar avatar) => [
    for (final part in FacePart.values) ShopItem.faceId(part, avatar.partValue(part)),
  ];
}
