import 'package:flutter/material.dart';

import '../theme/toon.dart';

/// Online or Local, for the tables that come both ways (Cash Games,
/// Blackjack): two halves of one pill, in the screen's own colours.
class WhereSwitch extends StatelessWidget {
  const WhereSwitch({
    super.key,
    required this.online,
    required this.onChanged,
    required this.on,
    required this.off,
    required this.text,
    required this.textOn,
  });

  final bool online;
  final ValueChanged<bool> onChanged;

  /// The picked half, the other half, and their text.
  final Color on, off, text, textOn;

  @override
  Widget build(BuildContext context) {
    Widget half(bool value, IconData icon, String label) {
      final picked = online == value;
      return Expanded(
        child: GestureDetector(
          key: Key('where ${value ? 'online' : 'local'}'),
          behavior: HitTestBehavior.opaque,
          onTap: picked ? null : () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: picked ? on : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: picked ? textOn : text),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Toon.text(15, weight: FontWeight.w700, color: picked ? textOn : text),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: online ? 'Online tables' : 'Local tables',
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: off, borderRadius: BorderRadius.circular(13)),
        child: Row(
          children: [
            half(true, Icons.public_rounded, 'Online'),
            half(false, Icons.phone_iphone_rounded, 'Local'),
          ],
        ),
      ),
    );
  }
}
