import 'package:flutter/material.dart';

/// When the phone turns (upright <-> on its side), the screen dips and the
/// new layout fades in instead of jumping.
class RotationFade extends StatefulWidget {
  const RotationFade({super.key, required this.child});

  final Widget child;

  @override
  State<RotationFade> createState() => _RotationFadeState();
}

class _RotationFadeState extends State<RotationFade> with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 420), value: 1);
  Orientation? _last;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final now = MediaQuery.orientationOf(context);
    if (_last != null && now != _last) _fade.forward(from: 0);
    _last = now;
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    // Out fast, back in gently.
    opacity: CurvedAnimation(
      parent: _fade,
      curve: const Interval(0.15, 1, curve: Curves.easeOut),
    ),
    child: widget.child,
  );
}
