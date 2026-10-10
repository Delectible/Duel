import 'package:flutter/material.dart';

import 'core/app_info.dart';
import 'core/session/play_setup.dart';
import 'core/theme/toon.dart';
import 'features/home/home_screen.dart';

void main() => runApp(DuelApp());

class DuelApp extends StatelessWidget {
  DuelApp({super.key, PlaySetup? setup}) : setup = setup ?? PlaySetup();

  /// The connection bar's state, shared by every screen.
  final PlaySetup setup;

  @override
  Widget build(BuildContext context) {
    return PlaySetupScope(
      setup: setup,
      child: MaterialApp(
        title: AppInfo.name,
        debugShowCheckedModeBanner: false,
        theme: Toon.theme(),
        home: const HomeScreen(),
      ),
    );
  }
}
