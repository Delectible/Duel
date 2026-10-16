import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/account/account.dart';
import 'core/account/prefs_store.dart';
import 'core/app_info.dart';
import 'core/online/firebase_backend.dart';
import 'core/online/firebase_config.dart';
import 'core/online/online.dart';
import 'core/online/party.dart';
import 'core/session/play_setup.dart';
import 'core/theme/rotation_fade.dart';
import 'core/theme/toon.dart';
import 'features/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Online is off until the Firebase project is set up (docs/ONLINE.md).
  await Online.start();
  final prefs = await SharedPreferences.getInstance();
  final account = Account(store: PrefsStore(prefs));
  final party = Online.ready ? PartyService(FirebaseBackend(FirebaseConfig.referee), account: account) : null;
  runApp(DuelApp(account: account, party: party));
}

class DuelApp extends StatefulWidget {
  DuelApp({super.key, PlaySetup? setup, Account? account, this.party})
    : setup = setup ?? PlaySetup(party: party),
      account = account ?? Account();

  /// Online: your party (null when this build can't go online).
  final PartyService? party;

  /// The connection bar's state, shared by every screen.
  final PlaySetup setup;

  /// You: profile, wallet, stats, settings.
  final Account account;

  @override
  State<DuelApp> createState() => _DuelAppState();
}

class _DuelAppState extends State<DuelApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.account.addListener(_applyTheme);
    Toon.dark = _wantDark();
  }

  @override
  void dispose() {
    widget.account.removeListener(_applyTheme);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _wantDark() => switch (widget.account.theme) {
    ThemeChoice.light => false,
    ThemeChoice.dark => true,
    ThemeChoice.system => WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark,
  };

  /// Light / dark changed (setting or phone): repaint every screen.
  void _applyTheme() {
    final dark = _wantDark();
    if (dark == Toon.dark) return;
    Toon.dark = dark;
    setState(() {});
    rebuildAll();
  }

  @override
  void didChangePlatformBrightness() => _applyTheme();

  @override
  Widget build(BuildContext context) {
    return AccountScope(
      account: widget.account,
      child: PartyScope(
        party: widget.party,
        child: PlaySetupScope(
          setup: widget.setup,
          child: MaterialApp(
            title: AppInfo.name,
            debugShowCheckedModeBanner: false,
            theme: Toon.theme(),
            builder: (context, child) => RotationFade(child: child!),
            home: const HomeScreen(),
          ),
        ),
      ),
    );
  }
}
