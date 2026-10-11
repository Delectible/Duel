import 'package:duel/core/account/account.dart';
import 'package:duel/core/avatars/faces.dart';
import 'package:duel/core/session/play_setup.dart';
import 'package:duel/core/theme/toon.dart';
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

      for (final part in ['color', 'shape', 'face', 'hat']) {
        for (var i = 0; i < Avatar.choices; i++) {
          expect(find.byKey(Key('$part $i')), findsOneWidget);
        }
      }
      await tester.tap(find.byKey(const Key('color 2')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('hat 2')));
      for (final k in ['shape 1', 'face 3', 'hat 2']) {
        await tester.tap(find.byKey(Key(k)));
        await tester.pumpAndSettle();
      }
      expect(
        a.avatar,
        const Avatar(
          color: AvatarColor.lilac,
          shape: HeadShape.square,
          face: Expression.wild,
          hat: Hat.crown,
        ),
      );
      expect(a.persona.avatar, a.avatar);
      await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
      await tester.pumpAndSettle();
      await shot(tester, 'profile_top_$phone');

      await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      await shot(tester, 'profile_$phone');
    });
  }

  testWidgets('every part combination paints', (tester) async {
    usePhone(tester, phones['pixel9pro']!);
    final all = [
      for (final c in AvatarColor.values)
        for (final s in HeadShape.values)
          for (final f in Expression.values)
            for (final h in Hat.values) Avatar(color: c, shape: s, face: f, hat: h),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Wrap(children: [for (final a in all.take(400)) Face.of(a, size: 20)])),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings: theme and currency', (tester) async {
    usePhone(tester, phones['small']!);
    final a = Account();
    await tester.pumpWidget(_wrap(const SettingsScreen(), a));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('theme dark')));
    await tester.pumpAndSettle();
    expect(a.theme, ThemeChoice.dark);
    await tester.ensureVisible(find.byKey(const Key('currency eur')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('currency eur')));
    await tester.pumpAndSettle();
    expect(a.currency, CurrencyChoice.eur);
    expect(a.money(100), '€100');
  });
}
