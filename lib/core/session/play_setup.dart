import 'package:flutter/widgets.dart';

import 'difficulty.dart';

/// Who you're playing with: bots, or a friend in a party.
enum PlayMode { bots, friends }

/// How a party chooses the next game.
enum PickRule {
  host('Host decides'),
  vote('Vote'),
  firstCome('First come');

  const PickRule(this.label);

  final String label;
}

/// The connection bar's state: shared by every screen.
class PlaySetup extends ChangeNotifier {
  static const maxBots = 5;

  PlayMode _mode = PlayMode.bots;
  Difficulty _difficulty = Difficulty.normal;
  int _botCount = 3;
  PickRule _pickRule = PickRule.host;

  PlayMode get mode => _mode;
  Difficulty get difficulty => _difficulty;
  int get botCount => _botCount;
  PickRule get pickRule => _pickRule;

  /// People in the party (online play isn't there yet: just you).
  int get partySize => 1;

  /// Players at the table, you included.
  int get players => _mode == PlayMode.bots ? 1 + _botCount : partySize;

  set mode(PlayMode v) => _set(() => _mode = v);
  set difficulty(Difficulty v) => _set(() => _difficulty = v);
  set botCount(int v) => _set(() => _botCount = v.clamp(1, maxBots));
  set pickRule(PickRule v) => _set(() => _pickRule = v);

  void _set(VoidCallback change) {
    change();
    notifyListeners();
  }
}

class PlaySetupScope extends InheritedNotifier<PlaySetup> {
  const PlaySetupScope({super.key, required PlaySetup setup, required super.child}) : super(notifier: setup);

  static PlaySetup of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlaySetupScope>()!.notifier!;
}
