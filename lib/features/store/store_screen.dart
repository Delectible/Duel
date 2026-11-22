import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/account/account.dart';
import '../../core/avatars/faces.dart';
import '../../core/sound/sound.dart';
import '../../core/store/cosmetics.dart';
import '../../core/store/shop.dart';
import '../../core/theme/split_page.dart';
import '../../core/theme/toon.dart';

/// The store's shelves.
enum StoreTab {
  daily('Daily', Icons.today_rounded),
  face('Face', Icons.face_rounded),
  backs('Card backs', Icons.style_rounded),
  felts('Felts', Icons.table_restaurant_rounded),
  sets('Sets', Icons.collections_bookmark_rounded);

  const StoreTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Spend your pips: face parts, card backs and table felts (try anything
/// on before you buy), sets that pay a prize and a badge when finished,
/// and three small daily challenges that pay pips. Your face is still put
/// together in the profile; this is where the fancy parts come from.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key, this.tab = StoreTab.daily, this.item});

  final StoreTab tab;

  /// Opened on this item (a locked part tapped in the profile).
  final ShopItem? item;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  late var _tab = widget.tab;
  late var _part = widget.item?.part ?? FacePart.hat;
  late ShopItem? _picked = widget.item;

  void _pick(ShopItem item) {
    Sound.play(Sfx.tap);
    setState(() => _picked = item);
  }

  void _buy(Account account, ShopItem item) {
    final sets = account.buy(item);
    if (sets == null) return;
    Sound.play(Sfx.chips);
    for (final s in sets) {
      Sound.later(Sfx.winMedium, 300);
      _toast('${s.name} set complete! +${account.money(s.prize)}', s.color);
    }
  }

  void _toast(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        content: Text(
          text,
          style: Toon.text(16, weight: FontWeight.w700, color: Toon.on(color)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    final header = Row(
      children: [
        ToonButton(
          color: Toon.card,
          padding: const EdgeInsets.all(8),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text('Store', style: Toon.text(26, weight: FontWeight.w700)),
        ),
        _Balance(account: account),
      ],
    );
    final shelves = [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in StoreTab.values)
            _Chip(
              key: Key('store ${t.name}'),
              label: t.label,
              icon: t.icon,
              on: t == _tab,
              badge: t == StoreTab.daily ? account.dailyReady : 0,
              onTap: () => setState(() => _tab = t),
            ),
        ],
      ),
      const SizedBox(height: 12),
      switch (_tab) {
        StoreTab.daily => _Daily(account: account),
        StoreTab.face => _FaceShelf(
          account: account,
          part: _part,
          picked: _picked,
          onPart: (p) => setState(() => _part = p),
          onPick: _pick,
        ),
        StoreTab.backs => _Grid(
          account: account,
          items: Shop.all.where((i) => i.kind == ItemKind.back).toList(),
          picked: _picked,
          onPick: _pick,
        ),
        StoreTab.felts => _Grid(
          account: account,
          items: Shop.all.where((i) => i.kind == ItemKind.felt).toList(),
          picked: _picked,
          onPick: _pick,
        ),
        StoreTab.sets => _Sets(account: account, onPick: _pick),
      },
      const SizedBox(height: 16),
    ];
    // The preview stays put while the shelves scroll, so you always see
    // what you're trying on.
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            if (isLandscape(box.biggest)) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 10, 16),
                      children: [
                        header,
                        const SizedBox(height: 14),
                        _Preview(account: account, item: _picked, onBuy: _buy, art: 150),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(padding: const EdgeInsets.fromLTRB(10, 16, 16, 16), children: shelves),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: Column(
                    children: [
                      header,
                      const SizedBox(height: 12),
                      _Preview(
                        account: account,
                        item: _picked,
                        onBuy: _buy,
                        art: box.maxHeight < 780 ? 96 : 120,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 16), children: shelves),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Balance extends StatelessWidget {
  const _Balance({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('store balance'),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: Toon.box(Toon.yellow, radius: 14, shadow: 3),
    child: Text(
      account.money(account.balance),
      style: Toon.text(16, weight: FontWeight.w700, color: Toon.inkLight),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.icon,
    required this.on,
    required this.onTap,
    this.badge = 0,
  });

  final String label;
  final IconData icon;
  final bool on;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = on ? Toon.yellow : Toon.card;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ToonButton(
          color: color,
          radius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          onPressed: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Toon.on(color)),
              const SizedBox(width: 5),
              Text(label, style: Toon.text(14, color: Toon.on(color))),
            ],
          ),
        ),
        if (badge > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: Toon.box(Toon.red, radius: 11, shadow: 0),
              child: Text(
                '$badge',
                style: Toon.text(12, weight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

/// The item you're looking at, tried on: your face wearing it, a card in
/// that back, a table in that felt. Buy / Wear underneath.
class _Preview extends StatelessWidget {
  const _Preview({required this.account, required this.item, required this.onBuy, required this.art});

  /// The tried-on scene's height.
  final double art;

  final Account account;
  final ShopItem? item;
  final void Function(Account, ShopItem) onBuy;

  @override
  Widget build(BuildContext context) {
    final i = item;
    final avatar = i != null && i.kind == ItemKind.face
        ? account.avatar.withPart(i.part!, i.value!)
        : account.avatar;
    final back = i?.back ?? account.cardBack;
    final felt = i?.felt ?? account.felt;
    return ToonBox(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          SizedBox(
            height: art,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // A table in the felt, a card in the back, your face.
                Positioned.fill(child: _FeltSwatch(felt: felt, radius: 22)),
                Positioned(
                  left: 22,
                  child: Transform.rotate(
                    angle: -0.18,
                    child: _BackSwatch(back: back, width: art * 0.39),
                  ),
                ),
                Positioned(
                  left: 22 + art * 0.2,
                  child: Transform.rotate(
                    angle: 0.08,
                    child: _BackSwatch(back: back, width: art * 0.39),
                  ),
                ),
                Positioned(
                  right: 20,
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(avatar),
                    tween: Tween(begin: 0.85, end: 1),
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.elasticOut,
                    builder: (context, t, child) => Transform.scale(scale: t, child: child),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Toon.cardFace,
                        shape: BoxShape.circle,
                        border: Border.all(color: Toon.inkLight, width: 3),
                      ),
                      child: Face.of(avatar, size: art * 0.64),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (i == null)
            Text(
              'Tap anything to try it on.',
              style: Toon.text(16, weight: FontWeight.w600, color: Toon.muted),
            )
          else
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i.name, style: Toon.text(20, weight: FontWeight.w700)),
                      Text(
                        account.owns(i) ? 'Yours' : account.money(i.price),
                        style: Toon.text(15, weight: FontWeight.w700, color: Toon.muted),
                      ),
                    ],
                  ),
                ),
                _BuyButton(account: account, item: i, onBuy: onBuy),
              ],
            ),
        ],
      ),
    );
  }
}

class _BuyButton extends StatelessWidget {
  const _BuyButton({required this.account, required this.item, required this.onBuy});

  final Account account;
  final ShopItem item;
  final void Function(Account, ShopItem) onBuy;

  @override
  Widget build(BuildContext context) {
    if (account.owns(item)) {
      final on = account.wearing(item);
      return ToonButton(
        key: const Key('wear'),
        color: on ? Toon.card : Toon.blue,
        onPressed: on ? null : () => account.wear(item),
        child: Text(on ? 'Wearing' : 'Wear', style: Toon.text(18, weight: FontWeight.w700)),
      );
    }
    final short = item.price - account.balance;
    return ToonButton(
      key: const Key('buy'),
      color: Toon.green,
      onPressed: short > 0 ? null : () => onBuy(account, item),
      child: Text(
        short > 0 ? 'Need ${account.money(short)} more' : 'Buy',
        style: Toon.text(short > 0 ? 14 : 18, weight: FontWeight.w700),
      ),
    );
  }
}

/// Face parts for sale, one part at a time, each drawn on your own face.
class _FaceShelf extends StatelessWidget {
  const _FaceShelf({
    required this.account,
    required this.part,
    required this.picked,
    required this.onPart,
    required this.onPick,
  });

  final Account account;
  final FacePart part;
  final ShopItem? picked;
  final ValueChanged<FacePart> onPart;
  final ValueChanged<ShopItem> onPick;

  static const _names = {
    FacePart.color: 'Skin',
    FacePart.eyes: 'Eyes',
    FacePart.nose: 'Nose',
    FacePart.mouth: 'Mouth',
    FacePart.hat: 'Hats',
    FacePart.extra: 'Extras',
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final p in Shop.faceParts)
            ToonButton(
              key: Key('shelf ${p.name}'),
              color: p == part ? Toon.blue : Toon.card,
              radius: 10,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              onPressed: () => onPart(p),
              child: Text(
                _names[p]!,
                style: Toon.text(13, color: Toon.on(p == part ? Toon.blue : Toon.card)),
              ),
            ),
        ],
      ),
      const SizedBox(height: 10),
      _Grid(
        account: account,
        items: Shop.forSale(ItemKind.face, part: part),
        picked: picked,
        onPick: onPick,
      ),
    ],
  );
}

/// Items in tiles: what it looks like, then its price or a tick if yours.
class _Grid extends StatelessWidget {
  const _Grid({required this.account, required this.items, required this.picked, required this.onPick});

  final Account account;
  final List<ShopItem> items;
  final ShopItem? picked;
  final ValueChanged<ShopItem> onPick;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final cols = max(3, (box.maxWidth / 96).floor());
      final size = (box.maxWidth - 8 * (cols - 1)) / cols;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final i in items)
            _Tile(account: account, item: i, size: size, on: i == picked, onPick: onPick),
        ],
      );
    },
  );
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.account,
    required this.item,
    required this.size,
    required this.on,
    required this.onPick,
  });

  final Account account;
  final ShopItem item;
  final double size;
  final bool on;
  final ValueChanged<ShopItem> onPick;

  @override
  Widget build(BuildContext context) {
    final owned = account.owns(item);
    final art = size - 12;
    return GestureDetector(
      key: Key('item ${item.id}'),
      onTap: () => onPick(item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
        decoration: Toon.box(on ? Toon.yellow : Toon.card, radius: 14, shadow: on ? 0 : 3),
        child: Column(
          children: [
            SizedBox(
              width: art,
              height: art * 0.86,
              child: Center(
                child: switch (item.kind) {
                  ItemKind.face => _faceArt(art * 0.86),
                  ItemKind.back => _BackSwatch(back: item.back!, width: art * 0.55),
                  ItemKind.felt => _FeltSwatch(felt: item.felt!, radius: 12),
                },
              ),
            ),
            const SizedBox(height: 4),
            owned
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 16, color: on ? Toon.inkLight : Toon.green),
                      const SizedBox(width: 3),
                      Text('Yours', style: Toon.text(12, color: on ? Toon.inkLight : null)),
                    ],
                  )
                : FittedBox(
                    child: Text(
                      account.money(item.price),
                      style: Toon.text(13, weight: FontWeight.w700, color: on ? Toon.inkLight : null),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _faceArt(double s) {
    final option = account.avatar.withPart(item.part!, item.value!);
    final closeUp = const {FacePart.eyes, FacePart.nose, FacePart.mouth}.contains(item.part);
    return closeUp
        ? ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Face.part(option, item.part!, size: s),
          )
        : Face.of(option, size: s);
  }
}

/// A face-down card in [back].
class _BackSwatch extends StatelessWidget {
  const _BackSwatch({required this.back, required this.width});

  final CardBack back;
  final double width;

  @override
  Widget build(BuildContext context) {
    final r = width * 0.14;
    return Container(
      width: width,
      height: width * 1.4,
      padding: EdgeInsets.all(width * 0.08),
      decoration: BoxDecoration(
        color: back.color,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: Toon.inkLight, width: 2),
        boxShadow: [BoxShadow(color: Toon.inkLight.withValues(alpha: 0.35), offset: const Offset(0, 2))],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r * 0.6),
          border: Border.all(color: back.ink.withValues(alpha: 0.9), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r * 0.6),
          child: CustomPaint(painter: BackPatternPainter(back), child: const SizedBox.expand()),
        ),
      ),
    );
  }
}

/// A patch of table in [felt], with its rail.
class _FeltSwatch extends StatelessWidget {
  const _FeltSwatch({required this.felt, required this.radius});

  final TableFelt felt;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: felt.felt,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: felt.rail, width: 7),
    ),
    foregroundDecoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Toon.inkLight, width: 2),
    ),
  );
}

/// Sets: own every piece for a prize and a badge on your profile.
class _Sets extends StatelessWidget {
  const _Sets({required this.account, required this.onPick});

  final Account account;
  final ValueChanged<ShopItem> onPick;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Collect every piece of a set for a prize and its badge on your profile.',
        style: Toon.text(14, weight: FontWeight.w500, color: Toon.muted),
      ),
      const SizedBox(height: 10),
      for (final c in Shop.collections)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _SetCard(account: account, set: c, onPick: onPick),
        ),
    ],
  );
}

class _SetCard extends StatelessWidget {
  const _SetCard({required this.account, required this.set, required this.onPick});

  final Account account;
  final Collection set;
  final ValueChanged<ShopItem> onPick;

  @override
  Widget build(BuildContext context) {
    final have = account.ownedIn(set);
    final done = account.collectionsDone.contains(set);
    return ToonBox(
      key: Key('set ${set.id}'),
      padding: const EdgeInsets.all(10),
      shadow: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SetBadge(set: set, size: 34, earned: done),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(set.name, style: Toon.text(17, weight: FontWeight.w700)),
                    Text(
                      done
                          ? 'Complete! Badge earned'
                          : '$have of ${set.items.length} · prize ${account.money(set.prize)}',
                      style: Toon.text(13, weight: FontWeight.w600, color: done ? Toon.green : Toon.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final id in set.items)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _SetPiece(account: account, item: Shop.byId[id]!, onPick: onPick),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SetPiece extends StatelessWidget {
  const _SetPiece({required this.account, required this.item, required this.onPick});

  final Account account;
  final ShopItem item;
  final ValueChanged<ShopItem> onPick;

  @override
  Widget build(BuildContext context) {
    final owned = account.owns(item);
    return GestureDetector(
      key: Key('piece ${item.id}'),
      onTap: () => onPick(item),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: Toon.box(
            owned ? Toon.green.withValues(alpha: 0.35) : Toon.paper,
            radius: 10,
            shadow: 0,
          ),
          padding: const EdgeInsets.all(4),
          child: Stack(
            children: [
              Center(
                child: LayoutBuilder(
                  builder: (context, box) => switch (item.kind) {
                    ItemKind.face => Face.of(
                      account.avatar.withPart(item.part!, item.value!),
                      size: box.maxWidth,
                    ),
                    ItemKind.back => _BackSwatch(back: item.back!, width: box.maxHeight / 1.45),
                    ItemKind.felt => _FeltSwatch(felt: item.felt!, radius: 8),
                  },
                ),
              ),
              if (owned)
                const Positioned(
                  right: 0,
                  top: 0,
                  child: Icon(Icons.check_circle_rounded, size: 18, color: Toon.green),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A set's badge: its icon in a coin, greyed until earned.
class SetBadge extends StatelessWidget {
  const SetBadge({super.key, required this.set, this.size = 32, this.earned = true});

  final Collection set;
  final double size;
  final bool earned;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: earned ? set.color : Toon.grey,
      shape: BoxShape.circle,
      border: Border.all(color: Toon.inkLight, width: 2),
    ),
    child: Icon(set.icon, size: size * 0.58, color: earned ? Toon.on(set.color) : Toon.muted),
  );
}

/// Today's three challenges: play, collect the pips. New ones tomorrow.
class _Daily extends StatelessWidget {
  const _Daily({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final today = account.daily;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Three small goals a day. Finish one and collect its pips. New ones every morning; '
          'nothing carries over and nothing is lost.',
          style: Toon.text(14, weight: FontWeight.w500, color: Toon.muted),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < today.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ToonBox(
              key: Key('daily $i'),
              padding: const EdgeInsets.all(12),
              shadow: 3,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(today[i].title, style: Toon.text(16, weight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: account.dailyProgress(i) / today[i].goal,
                            minHeight: 10,
                            backgroundColor: Toon.grey,
                            color: Toon.green,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${account.dailyProgress(i)} / ${today[i].goal} · ${account.money(today[i].reward)}',
                          style: Toon.text(13, weight: FontWeight.w600, color: Toon.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (account.dailyClaimed(i))
                    const Icon(Icons.check_circle_rounded, color: Toon.green, size: 32)
                  else
                    ToonButton(
                      key: Key('collect $i'),
                      color: Toon.yellow,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      onPressed: account.dailyDone(i)
                          ? () {
                              if (account.claimDaily(i)) Sound.play(Sfx.collect);
                            }
                          : null,
                      child: Text('Collect', style: Toon.text(15, weight: FontWeight.w700)),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
