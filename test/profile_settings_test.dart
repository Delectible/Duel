import 'package:duel/core/account/account.dart';
import 'package:duel/core/avatars/faces.dart';
import 'package:duel/core/session/play_setup.dart';
import 'package:duel/core/theme/toon.dart';
import 'package:duel/core/sound/sound.dart';
import 'package:duel/features/profile/profile_screen.dart';
import 'package:duel/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screens.dart';

Widget _wrap(Widget home, Account a) => AccountScope(
  account: a,
  child: PlaySetupScope(
    setup: PlaySetup(),
    child: MaterialApp(debugShowCheckedModeBanner: false, theme: Toon.theme(), home: home),
  ),
);

void main() {
  for (final MapEntry(key: phone, value: size) in phones.entries) {
    testWidgets('profile on $phone: build your face from parts', (tester) async {
      usePhone(tester, size);
      final a = Account();
      await tester.pumpWidget(_wrap(const ProfileScreen(), a));
      await tester.pumpAndSettle();
      expect(a.avatar, const Avatar());
      await tester.enterText(find.byKey(const Key('name')), 'Luca');
      expect(a.name, 'Luca');

      Future<void> tap(String key) async {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
      }

      // Every part has a tab with every option.
      for (final part in FacePart.values) {
        await tap('tab ${part.name}');
        expect(find.byKey(Key('grid ${part.name}')), findsOneWidget);
      }
      for (final (part, value) in [
        ('color', 'lilac'),
        ('shape', 'square'),
        ('eyes', 'shiny'),
        ('nose', 'round'),
        ('mouth', 'grin'),
        ('hat', 'wizard'),
        ('extra', 'glasses'),
      ]) {
        await tap('tab $part');
        await tap('pick $part $value');
      }
      expect(
        a.avatar,
        const Avatar(
          color: AvatarColor.lilac,
          shape: HeadShape.square,
          eyes: Eyes.shiny,
          nose: Nose.round,
          mouth: Mouth.grin,
          hat: Hat.wizard,
          extra: Extra.glasses,
        ),
      );
      await shot(tester, 'profile_picker_$phone');
      expect(a.persona.avatar, a.avatar);
      await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
      await tester.pumpAndSettle();
      await shot(tester, 'profile_top_$phone');

      await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      await shot(tester, 'profile_$phone');
    });
  }

  testWidgets('Surprise me changes the face', (tester) async {
    usePhone(tester, phones.values.first);
    final a = Account();
    await tester.pumpWidget(_wrap(const ProfileScreen(), a));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('surprise me')));
    await tester.pumpAndSettle();
    final before = a.avatar;
    for (var i = 0; i < 3 && a.avatar == before; i++) {
      await tester.tap(find.byKey(const Key('surprise me')));
      await tester.pumpAndSettle();
    }
    expect(a.avatar, isNot(before));
  });

  for (final dark in [false, true]) {
    testWidgets('every option of every part paints${dark ? ' (dark)' : ''}', (tester) async {
      usePhone(tester, phones['pixel9pro']!);
      Toon.dark = dark;
      addTearDown(() => Toon.dark = false);
      const base = Avatar();
      List<Enum> options(FacePart part) => switch (part) {
        FacePart.color => AvatarColor.values,
        FacePart.shape => HeadShape.values,
        FacePart.eyes => Eyes.values,
        FacePart.nose => Nose.values,
        FacePart.mouth => Mouth.values,
        FacePart.hat => Hat.values,
        FacePart.extra => Extra.values,
      };
      final faces = [
        for (final part in FacePart.values)
          for (final v in options(part)) base.withPart(part, v),
        // Hats and extras on every head shape.
        for (final s in HeadShape.values)
          for (final h in Hat.values)
            Avatar(shape: s, hat: h, extra: Extra.values[h.index % Extra.values.length]),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Toon.paper,
            body: SingleChildScrollView(
              child: Wrap(
                children: [
                  for (final f in faces) ...[
                    Face.of(f, size: 44),
                    for (final part in FacePart.values) Face.part(f, part, size: 22),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await shot(tester, 'faces_all${dark ? '_dark' : ''}');
    });
  }

  testWidgets('settings: theme and currency', (tester) async {
    usePhone(tester, phones['small']!);
    final a = Account();
    await tester.pumpWidget(_wrap(const SettingsScreen(), a));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('theme dark')));
    await tester.pumpAndSettle();
    expect(a.theme, ThemeChoice.dark);
    await tester.scrollUntilVisible(
      find.byKey(const Key('currency eur')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('currency eur')));
    await tester.pumpAndSettle();
    expect(a.currency, CurrencyChoice.eur);
    expect(a.money(100), '€100');
  });

  testWidgets('settings: music picks a track, Off hides its volume', (tester) async {
    usePhone(tester, phones['pixel9pro']!);
    final a = Account();
    await tester.pumpWidget(_wrap(const SettingsScreen(), a));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('music tiki')));
    await tester.pumpAndSettle();
    await shot(tester, 'settings_music');
    await tester.tap(find.byKey(const Key('music tiki')));
    await tester.pumpAndSettle();
    expect(a.music, Track.tiki);
    expect(find.byKey(const Key('music volume')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('music off')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('music off')));
    await tester.pumpAndSettle();
    expect(a.music, isNull);
    expect(find.byKey(const Key('music volume')), findsNothing);
  });
}
