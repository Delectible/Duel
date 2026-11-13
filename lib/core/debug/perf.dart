import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../account/account.dart';
import '../theme/toon.dart';

/// The hidden debug menu's switches (long-press About in Settings). Kept
/// for this run of the app only.
class Perf extends ChangeNotifier {
  Perf._();
  static final instance = Perf._();

  bool _fps = false, _graphs = false, _layers = false;

  /// A frame-rate counter in the corner.
  bool get fps => _fps;
  set fps(bool v) => _set(() => _fps = v);

  /// Flutter's own graphs of each frame's UI and GPU time.
  bool get graphs => _graphs;
  set graphs(bool v) => _set(() => _graphs = v);

  /// Checkerboards everything drawn in a layer of its own (costly on
  /// older phones: fades and see-through boxes).
  bool get layers => _layers;
  set layers(bool v) => _set(() => _layers = v);

  void _set(VoidCallback f) {
    f();
    notifyListeners();
  }
}

/// What the phone's screen is doing, from Android: the refresh rate it's
/// running at, the ones it offers, and the one the app asked for. Null
/// where the phone doesn't say (iOS, tests).
Future<Map<String, Object?>?> displayInfo() async {
  try {
    final info = await const MethodChannel('duel/display').invokeMapMethod<String, Object?>('info');
    return info;
  } on Object {
    return null;
  }
}

/// Frames drawn over the last second, measured from the engine's own
/// frame timings (so the counter costs nothing when off).
class FrameStats {
  FrameStats._();
  static final instance = FrameStats._();

  final _frames = <FrameTiming>[];
  var _listeners = 0;

  void _start() {
    if (_listeners++ == 0) SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _stop() {
    if (--_listeners == 0) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      _frames.clear();
    }
  }

  void _onTimings(List<FrameTiming> timings) {
    _lastHeard = DateTime.now();
    _frames.addAll(timings);
    // Keep about two seconds' worth.
    if (_frames.length > 300) _frames.removeRange(0, _frames.length - 300);
  }

  DateTime? _lastHeard;

  /// The last second: frames, worst UI (build) and GPU (raster) time,
  /// and how many frames missed [budget].
  ({int frames, double ui, double gpu, int slow}) lastSecond(Duration budget) {
    // A still screen draws nothing (timings come in batches about once a
    // second while frames are drawn).
    final heard = _lastHeard;
    if (_frames.isEmpty ||
        heard == null ||
        DateTime.now().difference(heard) > const Duration(milliseconds: 1500)) {
      return (frames: 0, ui: 0, gpu: 0, slow: 0);
    }
    final end = _frames.last.timestampInMicroseconds(FramePhase.rasterFinish);
    var ui = 0.0, gpu = 0.0, slow = 0, n = 0;
    for (final f in _frames) {
      if (end - f.timestampInMicroseconds(FramePhase.rasterFinish) >= 1000000) continue;
      n++;
      ui = max(ui, f.buildDuration.inMicroseconds / 1000);
      gpu = max(gpu, f.rasterDuration.inMicroseconds / 1000);
      if (f.buildDuration > budget || f.rasterDuration > budget) slow++;
    }
    return (frames: n, ui: ui, gpu: gpu, slow: slow);
  }
}

/// The frame-rate counter over the whole app while [Perf.fps] is on.
class PerfOverlay extends StatelessWidget {
  const PerfOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Perf.instance,
    builder: (context, child) => Stack(
      textDirection: TextDirection.ltr,
      children: [
        child!,
        if (Perf.instance.fps)
          const Positioned(
            top: 0,
            right: 0,
            child: SafeArea(child: IgnorePointer(child: _FpsBadge())),
          ),
      ],
    ),
    child: child,
  );
}

class _FpsBadge extends StatefulWidget {
  const _FpsBadge();

  @override
  State<_FpsBadge> createState() => _FpsBadgeState();
}

class _FpsBadgeState extends State<_FpsBadge> {
  Timer? _tick;
  var _text = 'fps…';
  var _hz = 60.0;

  @override
  void initState() {
    super.initState();
    FrameStats.instance._start();
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) => _update());
  }

  void _update() {
    if (!mounted) return;
    final views = PlatformDispatcher.instance.views;
    if (views.isNotEmpty) _hz = views.first.display.refreshRate;
    final budget = Duration(microseconds: (1000000 / _hz).round());
    final s = FrameStats.instance.lastSecond(budget);
    final text = s.frames == 0
        ? 'still · ${_hz.round()} Hz'
        : '${s.frames} fps · ${_hz.round()} Hz\n'
              'UI ${s.ui.toStringAsFixed(1)} · GPU ${s.gpu.toStringAsFixed(1)} ms'
              '${s.slow > 0 ? '\n${s.slow} slow' : ''}';
    if (text != _text) setState(() => _text = text);
  }

  @override
  void dispose() {
    _tick?.cancel();
    FrameStats.instance._stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Container(
      key: const Key('fps badge'),
      margin: const EdgeInsets.all(6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xCC000000), borderRadius: BorderRadius.circular(8)),
      child: Text(
        _text,
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: Color(0xFF7CFF9B),
          fontSize: 11,
          height: 1.25,
          fontFeatures: [FontFeature.tabularFigures()],
          decoration: TextDecoration.none,
        ),
      ),
    ),
  );
}

/// The debug menu: performance switches, what the screen is doing, and a
/// smoothness test.
Future<void> showDebugSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  backgroundColor: Toon.paper,
  builder: (context) => const SafeArea(child: _DebugSheet()),
);

class _DebugSheet extends StatefulWidget {
  const _DebugSheet();

  @override
  State<_DebugSheet> createState() => _DebugSheetState();
}

class _DebugSheetState extends State<_DebugSheet> {
  Map<String, Object?>? _display;
  var _asked = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      displayInfo().then((d) {
        if (mounted) setState(() => (_display = d, _asked = true));
      }),
    );
  }

  String get _screen {
    final views = PlatformDispatcher.instance.views;
    final flutter = views.isEmpty ? null : views.first.display.refreshRate.round();
    final d = _display;
    if (d == null) return _asked ? 'Flutter sees ${flutter ?? '?'} Hz.' : 'Asking the phone…';
    String hz(Object? v) => v is num ? '${v.round()} Hz' : '?';
    final modes = ((d['modes'] as List?) ?? const []).map(hz).toSet().join(', ');
    return 'Running at ${hz(d['current'])} (offers $modes). '
        'Duel asked for ${hz(d['asked'])}. Flutter sees ${flutter ?? '?'} Hz.'
        '${d['powerSaver'] == true ? ' Battery saver is on: phones cap the screen at 60 Hz.' : ''}';
  }

  Widget _switch(String key, String title, String text, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(
        key: Key(key),
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: Toon.text(17, weight: FontWeight.w600)),
        subtitle: Text(text, style: Toon.text(13, color: Toon.muted)),
        value: value,
        onChanged: (v) => setState(() => onChanged(v)),
      );

  @override
  Widget build(BuildContext context) {
    final perf = Perf.instance;
    return SingleChildScrollView(
      key: const Key('debug sheet'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Debug', style: Toon.text(24, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Performance', style: Toon.text(18, weight: FontWeight.w700)),
          _switch(
            'debug fps',
            'Frame rate',
            'Frames drawn each second, and the slowest frame. A still screen draws none.',
            perf.fps,
            (v) => perf.fps = v,
          ),
          _switch(
            'debug graphs',
            'Frame graphs',
            "Flutter's graphs: top is the GPU, bottom is the app. Red bars are slow frames.",
            perf.graphs,
            (v) => perf.graphs = v,
          ),
          _switch(
            'debug layers',
            'Show extra layers',
            'Checkerboards what is drawn in a layer of its own (fades, see-through boxes): '
                'each one costs time on older phones.',
            perf.layers,
            (v) => perf.layers = v,
          ),
          const SizedBox(height: 12),
          Text('Screen', style: Toon.text(18, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(_screen, key: const Key('debug screen'), style: Toon.text(15)),
          const SizedBox(height: 16),
          const _SmoothnessTest(),
          const SizedBox(height: 18),
          Text('Money', style: Toon.text(18, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          const _SetMoney(),
        ],
      ),
    );
  }
}

/// Spins a card for five seconds and counts the frames: the best this
/// phone does with Duel's drawing, against the screen's rate.
class _SmoothnessTest extends StatefulWidget {
  const _SmoothnessTest();

  @override
  State<_SmoothnessTest> createState() => _SmoothnessTestState();
}

class _SmoothnessTestState extends State<_SmoothnessTest> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(seconds: 1));
  String? _result;
  var _running = false;

  Future<void> _run() async {
    setState(() => (_running = true, _result = null));
    final frames = <FrameTiming>[];
    void collect(List<FrameTiming> t) => frames.addAll(t);
    SchedulerBinding.instance.addTimingsCallback(collect);
    final watch = Stopwatch()..start();
    unawaited(_spin.repeat());
    await Future<void>.delayed(const Duration(seconds: 5));
    _spin.stop();
    // Timings arrive in batches: give the last one a moment.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    SchedulerBinding.instance.removeTimingsCallback(collect);
    if (!mounted) return;
    final seconds = watch.elapsedMilliseconds / 1000;
    final views = PlatformDispatcher.instance.views;
    final hz = views.isEmpty ? 60.0 : views.first.display.refreshRate;
    final budget = 1000000 / hz;
    final slow = frames
        .where((f) => f.buildDuration.inMicroseconds > budget || f.rasterDuration.inMicroseconds > budget)
        .length;
    final fps = frames.length / seconds;
    setState(() {
      _running = false;
      _result =
          '${fps.round()} fps on a ${hz.round()} Hz screen, $slow slow frames.'
          '${fps < hz * 0.8 && slow < frames.length / 10 ? ' Frames are quick but fewer than the screen allows: '
                    'the phone is holding the app to a lower rate.' : ''}';
    });
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      RepaintBoundary(
        child: RotationTransition(
          turns: _spin,
          child: Container(
            width: 36,
            height: 50,
            decoration: Toon.box(Toon.cardFace, radius: 6, shadow: 2),
            alignment: Alignment.center,
            child: Text(
              'A',
              style: Toon.text(20, weight: FontWeight.w700, color: Toon.red),
            ),
          ),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ToonButton(
              key: const Key('debug test'),
              color: Toon.yellow,
              onPressed: _running ? null : () => unawaited(_run()),
              child: Text(_running ? 'Testing…' : 'Smoothness test (5 s)'),
            ),
            if (_result != null) ...[
              const SizedBox(height: 6),
              Text(_result!, key: const Key('debug result'), style: Toon.text(14)),
            ],
          ],
        ),
      ),
    ],
  );
}

/// Sets your balance to any amount (testing stakes and cash tables).
class _SetMoney extends StatefulWidget {
  const _SetMoney();

  @override
  State<_SetMoney> createState() => _SetMoneyState();
}

class _SetMoneyState extends State<_SetMoney> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _set(int amount) {
    final account = AccountScope.maybeRead(context);
    if (account == null) return;
    setState(() => account.setBalance(amount));
  }

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.maybeRead(context);
    if (account == null) return const SizedBox.shrink();
    Widget quick(String label, int amount) => ToonButton(
      key: Key('debug money $amount'),
      color: Toon.card,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      onPressed: () => _set(amount),
      child: Text(label, style: Toon.text(14)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Now: ${account.money(account.balance)}', key: const Key('debug balance'), style: Toon.text(15)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('debug money field'),
                controller: _field,
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                decoration: const InputDecoration(hintText: 'Any amount', isDense: true),
                onSubmitted: (v) {
                  final n = int.tryParse(v.replaceAll(',', '').trim());
                  if (n != null) _set(n);
                },
              ),
            ),
            const SizedBox(width: 8),
            ToonButton(
              key: const Key('debug money set'),
              color: Toon.yellow,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              onPressed: () {
                final n = int.tryParse(_field.text.replaceAll(',', '').trim());
                if (n != null) _set(n);
              },
              child: const Text('Set'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            quick('0', 0),
            quick('1,000', 1000),
            quick('10,000', 10000),
            quick('100,000', 100000),
            quick('1,000,000', 1000000),
          ],
        ),
      ],
    );
  }
}
