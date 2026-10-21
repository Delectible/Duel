import 'dart:async';

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
import 'core/theme/system_bars.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final account = Account(store: await _store());
  final setup = PlaySetup();
  // The app shows straight away; online joins in when Firebase has started
  // (never waited for: a slow or stuck start mustn't hold up the app).
  runApp(DuelApp(account: account, setup: setup));
  // Markers in the phone's log (adb logcat) for checking a launch.
  WidgetsBinding.instance.addPostFrameCallback((_) => debugPrint('Duel: first frame'));
  unawaited(_goOnline(account, setup));
}

/// The phone's saved account; if that can't be read the app still opens
/// (this session just isn't saved) rather than hanging on the splash.
Future<AccountStore> _store() async {
  try {
    return PrefsStore(await SharedPreferences.getInstance().timeout(const Duration(seconds: 5)));
  } catch (e) {
    debugPrint('Duel: saved account unavailable ($e)');
    return MemoryStore();
  }
}

Future<void> _goOnline(Account account, PlaySetup setup) async {
  await Online.start();
  debugPrint(Online.ready ? 'Duel: online ready' : 'Duel: online off');
  if (Online.ready) setup.party = PartyService(FirebaseBackend(FirebaseConfig.referee), account: account);
}

class DuelApp extends StatefulWidget {
  DuelApp({super.key, PlaySetup? setup, Account? account, PartyService? party})
    : setup = setup ?? PlaySetup(party: party),
      account = account ?? Account();

  /// Online: your party (null until Firebase has started, or offline).
  PartyService? get party => setup.party;

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
    widget.setup.addListener(_partyChanged);
    _party = widget.party;
    Toon.dark = _wantDark();
  }

  /// The party the app was last built with.
  PartyService? _party;

  /// Online came up after the app opened: offer it everywhere.
  void _partyChanged() {
    if (widget.party == _party) return;
    setState(() => _party = widget.party);
  }

  @override
  void dispose() {
    widget.setup.removeListener(_partyChanged);
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
        party: _party,
        child: PlaySetupScope(
          setup: widget.setup,
          child: MaterialApp(
            title: AppInfo.name,
            debugShowCheckedModeBanner: false,
            theme: Toon.theme(),
            builder: (context, child) => SystemBars(child: RotationFade(child: child!)),
            home: const HomeScreen(),
          ),
        ),
      ),
    );
  }
}
