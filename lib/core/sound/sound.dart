import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';

/// Every sound in the app (Kenney's CC0 packs, `assets/sounds`).
enum Sfx {
  tap('tap'),
  shuffle('shuffle'),
  deal('deal', 3),
  place('place', 3),
  chips('chips', 3),
  collect('collect'),
  pot('pot'),
  yourTurn('your_turn'),
  tension('tension'),
  clash('clash'),
  fall('fall'),
  drop('drop'),
  book('book'),
  winSmall('win_small'),
  winMedium('win_medium'),
  winBig('win_big'),
  loseSmall('lose_small'),
  loseMedium('lose_medium'),
  loseBig('lose_big');

  const Sfx(this.file, [this.variants = 0]);

  final String file;

  /// Recordings to pick from at random (file1, file2…), or 0 for one.
  final int variants;
}

/// Plays sound effects: quietly does nothing until [start] (so tests and
/// screenshots stay silent), and when turned off in Settings. Mixes with
/// other apps' audio and follows the iPhone's silent switch.
abstract final class Sound {
  static bool _started = false;
  static bool on = true;
  static double volume = 0.8;

  static final _rng = Random();
  static final List<AudioPlayer> _players = [];
  static var _next = 0;
  static final _last = <Sfx, DateTime>{};

  /// Called once from main().
  static Future<void> start() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers, respectSilence: true).build(),
      );
      for (var i = 0; i < 6; i++) {
        final p = AudioPlayer();
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setPlayerMode(PlayerMode.lowLatency);
        _players.add(p);
      }
      _started = true;
    } on Object {
      // No audio on this device: stay silent.
    }
  }

  /// Plays [s] at [gain] (of the volume). The same sound twice within
  /// 40 ms plays once.
  static void play(Sfx s, {double gain = 1}) {
    if (!_started || !on || volume <= 0) return;
    final now = DateTime.now();
    final last = _last[s];
    if (last != null && now.difference(last).inMilliseconds < 40) return;
    _last[s] = now;
    final file = s.variants == 0 ? s.file : '${s.file}${1 + _rng.nextInt(s.variants)}';
    final p = _players[_next++ % _players.length];
    unawaited(
      p
          .play(AssetSource('sounds/$file.mp3'), volume: (volume * gain).clamp(0.0, 1.0))
          .catchError((Object _) {}),
    );
  }

  /// A shuffle, then [cards] cards dealt one after another.
  static void deal(int cards, {int gapMs = 90}) {
    play(Sfx.shuffle);
    for (var i = 0; i < cards; i++) {
      later(Sfx.deal, 700 + i * gapMs, gain: 0.7);
    }
  }

  /// [s] after [ms] (a deal: one card after another).
  static void later(Sfx s, int ms, {double gain = 1}) {
    if (!_started || !on) return;
    Timer(Duration(milliseconds: ms), () => play(s, gain: gain));
  }
}
