import 'dart:math';

import '../cards.dart';

/// Refused: not allowed, or makes no sense.
class DeckError implements Exception {
  const DeckError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A deck of cards on the table, standing in for a real one: a shuffled
/// pile to draw from, each player's hand, and a pile of cards played face
/// up. Only the hands are secret: online, the referee keeps the deck and
/// sends each player just their own cards.
///
/// Ops: `{op: deal, n}` (the host: gather every card, shuffle, deal [n] each)
/// · `{op: draw}` · `{op: play, card}` (from your hand onto the pile) ·
/// `{op: take}` (the pile's top card into your hand) · `{op: reset}` (the
/// host: everything back in the deck, shuffled).
class DeckTable {
  DeckTable({required this.players, Map<String, String>? names, int seed = 0})
    : names = names ?? {for (final p in players) p: p},
      _rng = Random(seed) {
    _gather();
  }

  /// Player ids, in seat order (online: uids).
  final List<String> players;
  final Map<String, String> names;
  final Random _rng;

  List<PlayingCard> deck = [];
  final Map<String, List<PlayingCard>> hands = {};
  final List<PlayingCard> pile = [];

  /// Who played each card on the pile (same order).
  final List<String> pileBy = [];

  /// What happened, newest last ("Sam drew a card").
  final List<String> log = [];

  /// Deals so far.
  int deals = 0;

  void _gather() {
    deck = [...PlayingCard.fullDeck]..shuffle(_rng);
    hands
      ..clear()
      ..addAll({for (final p in players) p: <PlayingCard>[]});
    pile.clear();
    pileBy.clear();
  }

  String _name(String p) => names[p] ?? 'Someone';

  void _say(String s) {
    log.add(s);
    if (log.length > 30) log.removeAt(0);
  }

  /// Applies [op] for player [by] (null: this phone, which may do anything
  /// for anyone named in `op['as']`). [host] may deal and reset.
  void apply(Map<Object?, Object?> op, {String? by, bool host = true}) {
    final who = by ?? (op['as'] as String?);
    void need(bool ok, String why) {
      if (!ok) throw DeckError(why);
    }

    switch (op['op']) {
      case 'deal':
        need(host, 'Only the host deals');
        final raw = op['n'];
        need(raw is int && raw >= 0, 'How many each?');
        final n = raw! as int;
        need(players.isNotEmpty, 'Nobody to deal to');
        need(n * players.length <= 52, 'Not enough cards for ${players.length} players');
        _gather();
        for (var i = 0; i < n; i++) {
          for (final p in players) {
            hands[p]!.add(deck.removeLast());
          }
        }
        deals++;
        _say('Shuffled and dealt $n each');
      case 'draw':
        need(who != null && hands.containsKey(who), 'You\'re not at the table');
        need(deck.isNotEmpty, 'The deck is empty');
        hands[who]!.add(deck.removeLast());
        _say('${_name(who!)} drew a card');
      case 'play':
        need(who != null && hands.containsKey(who), 'You\'re not at the table');
        final card = op['card'];
        final hand = hands[who]!;
        final i = hand.indexWhere((c) => '$c' == card);
        need(i >= 0, 'That card isn\'t in your hand');
        final c = hand.removeAt(i);
        pile.add(c);
        pileBy.add(who!);
        _say('${_name(who)} played $c');
      case 'take':
        need(who != null && hands.containsKey(who), 'You\'re not at the table');
        need(pile.isNotEmpty, 'The pile is empty');
        hands[who]!.add(pile.removeLast());
        pileBy.removeLast();
        _say('${_name(who!)} took from the pile');
      case 'reset':
        need(host, 'Only the host can gather the cards');
        _gather();
        _say('Everything back in the deck, shuffled');
      default:
        throw const DeckError('Unknown move');
    }
  }

  /// What everyone may see.
  Map<String, Object?> public() => {
    'players': players,
    'names': names,
    'deckLeft': deck.length,
    'counts': {for (final p in players) p: hands[p]?.length ?? 0},
    'pile': [for (final c in pile) '$c'],
    'pileBy': pileBy,
    'log': log,
    'deals': deals,
  };

  /// Everything (the referee's secret copy).
  Map<String, Object?> toJson() => {
    ...public(),
    'deck': [for (final c in deck) '$c'],
    'hands': {
      for (final e in hands.entries) e.key: [for (final c in e.value) '$c'],
    },
    'seed': _seed,
  };

  int _seed = 0;

  static DeckTable fromJson(Map<Object?, Object?> j) {
    final players = [for (final p in (j['players'] as List?) ?? const []) '$p'];
    final seed = j['seed'] as int? ?? 0;
    final t = DeckTable(
      players: players,
      names: {for (final e in ((j['names'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}'},
      seed: seed + (j['deals'] as int? ?? 0) * 7919 + ((j['log'] as List?)?.length ?? 0),
    );
    t._seed = seed;
    t.deck = [for (final c in (j['deck'] as List?) ?? const []) PlayingCard.parse('$c')];
    t.hands
      ..clear()
      ..addAll({
        for (final p in players)
          p: [
            for (final c in (((j['hands'] as Map?) ?? const {})[p] as List?) ?? const [])
              PlayingCard.parse('$c'),
          ],
      });
    t.pile
      ..clear()
      ..addAll([for (final c in (j['pile'] as List?) ?? const []) PlayingCard.parse('$c')]);
    t.pileBy
      ..clear()
      ..addAll([for (final p in (j['pileBy'] as List?) ?? const []) '$p']);
    t.log.addAll([for (final s in (j['log'] as List?) ?? const []) '$s']);
    t.deals = j['deals'] as int? ?? 0;
    return t;
  }

  /// A fresh table with a new random seed.
  static DeckTable fresh(List<String> players, Map<String, String> names, Random rng) {
    final seed = rng.nextInt(1 << 31);
    return DeckTable(players: players, names: names, seed: seed).._seed = seed;
  }
}
