import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

  /// Each recording has its own few players, loaded once: a sound plays at
  /// once (nothing to load) and the same one can overlap itself (a deal).
  static final _pools = <String, _Pool>{};
  static final _last = <Sfx, DateTime>{};

  static List<String> _files(Sfx s) => [
    if (s.variants == 0) s.file else for (var v = 1; v <= s.variants; v++) '${s.file}$v',
  ];

  /// Called once from main().
  static Future<void> start() async {
    try {
      // Media volume (not the ringer) and no audio focus on Android, so
      // Spotify and the like keep playing underneath; on iOS "ambient":
      // mixes with other audio and follows the silent switch.
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.game,
            contentType: AndroidContentType.sonification,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ),
      );
      _started = true;
      unawaited(Music._sync());
      // Load every sound now, quietly, rather than on its first play
      // (slow storage). Ones that come in quick runs get more players.
      for (final s in Sfx.values) {
        final busy = s == Sfx.deal || s == Sfx.place || s == Sfx.chips || s == Sfx.tap;
        for (final f in _files(s)) {
          _pools[f] = _Pool(f, busy ? 3 : 2);
        }
      }
      for (final pool in _pools.values) {
        await pool.load();
      }
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
    final files = _files(s);
    _pools[files[_rng.nextInt(files.length)]]?.play((volume * gain).clamp(0.0, 1.0));
  }

  /// [cards] dealt one after another, [gapMs] apart (as the deal animates).
  static void deal(int cards, {int gapMs = 100}) {
    for (var i = 0; i < cards; i++) {
      later(Sfx.deal, i * gapMs, gain: 0.7);
    }
  }

  /// [s] after [ms] (a deal: one card after another).
  static void later(Sfx s, int ms, {double gain = 1}) {
    if (!_started || !on) return;
    Timer(Duration(milliseconds: ms), () => play(s, gain: gain));
  }
}

/// A few players for one recording, taking turns.
class _Pool {
  _Pool(this.file, this.size);

  final String file;
  final int size;
  final _players = <AudioPlayer>[];
  final _volumes = <AudioPlayer, double>{};
  var _next = 0;

  Future<void> load() async {
    for (var i = 0; i < size; i++) {
      final p = AudioPlayer();
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.setSource(AssetSource('sounds/$file.mp3'));
      _players.add(p);
    }
  }

  void play(double volume) {
    if (_players.isEmpty) return;
    final p = _players[_next++ % _players.length];
    unawaited(
      () async {
        // Stop first: in low-latency mode a player never hears that its sound
        // ended, and would otherwise ignore being asked to play it again.
        await p.stop();
        if (_volumes[p] != volume) {
          _volumes[p] = volume;
          await p.setVolume(volume);
        }
        await p.resume();
      }().catchError((Object _) {}),
    );
  }
}

/// Background music (CC0, from OpenGameArt; `assets/music`).
enum Track {
  lounge('Lounge', '8-bit bossa nova'),
  lofi('Lo-fi', 'Chill beats'),
  tavern('Tavern', 'Medieval inn'),
  tiki('Tiki', 'Island exotica'),
  arcade('Arcade', 'Chiptune');

  const Track(this.label, this.blurb);

  final String label;
  final String blurb;
}

/// One track on a loop under everything, at its own volume. Quiet while
/// the app is in the background, and (like [Sound]) until [Sound.start].
abstract final class Music {
  static Track? _track;
  static double _volume = 0.5;
  static var _away = false;

  static AudioPlayer? _player;
  static Track? _playing;
  static var _paused = false;

  /// The chosen track (null: no music) and its volume.
  static void set(Track? track, double volume) {
    if (track == _track && volume == _volume) return;
    _track = track;
    _volume = volume;
    unawaited(_sync());
  }

  /// The app went to the background (or came back).
  static void away(bool away) {
    if (away == _away) return;
    _away = away;
    unawaited(_sync());
  }

  /// Android plays the track straight from memory: as an asset it would
  /// first be copied to a file (seconds on slow storage). iOS can't play
  /// bytes, but reads its assets straight from the app.
  static Future<Source> _source(Track t) async {
    final asset = 'music/music_${t.name}.mp3';
    if (defaultTargetPlatform != TargetPlatform.android) return AssetSource(asset);
    try {
      final data = await rootBundle.load('assets/$asset');
      return BytesSource(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        mimeType: 'audio/mpeg',
      );
    } on Object {
      return AssetSource(asset);
    }
  }

  static Track? get _want => _away || _volume <= 0 ? null : _track;

  static Future<void> _sync() async {
    if (!Sound._started) return;
    try {
      final p = _player ??= AudioPlayer();
      final want = _want;
      // Music sits under the effects.
      final volume = _volume * 0.6;
      if (want == null) {
        if (_playing != null && !_paused) {
          _paused = true;
          await p.pause();
        }
        return;
      }
      if (want != _playing) {
        _playing = want;
        _paused = false;
        // The old track stops at once, whatever the new one takes to load.
        await p.stop();
        final source = await _source(want);
        // Picked another one (or none) meanwhile: that call sorts it out.
        if (_playing != want) return;
        if (_want != want) {
          _playing = null;
          return;
        }
        await p.setReleaseMode(ReleaseMode.loop);
        try {
          await p.play(source, volume: volume);
        } on Object {
          // Older Androids can't play from memory: the file it is.
          await p.play(AssetSource('music/music_${want.name}.mp3'), volume: volume);
        }
        return;
      }
      await p.setVolume(volume);
      if (_paused) {
        _paused = false;
        await p.resume();
      }
    } on Object {
      // No music then.
    }
  }
}
