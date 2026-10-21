import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// On its side (tablets especially), the phone's navigation buttons and
/// status bar get in the way of the table: they hide, and a swipe in from
/// the edge brings them back for a moment before they slide away again.
/// Upright, they show as usual.
class SystemBars extends StatefulWidget {
  const SystemBars({super.key, required this.child});

  final Widget child;

  @override
  State<SystemBars> createState() => _SystemBarsState();
}

class _SystemBarsState extends State<SystemBars> {
  bool? _hidden;

  void _apply(bool hide) {
    if (hide == _hidden) return;
    _hidden = hide;
    SystemChrome.setEnabledSystemUIMode(hide ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _apply(landscape);
    });
    return widget.child;
  }
}
