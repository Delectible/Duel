import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Duel's cartoon look: flat colours, thick dark outlines, chunky drop
/// shadows, rounded everything, Fredoka type.
abstract final class Toon {
  static const ink = Color(0xFF2B2D42);
  static const paper = Color(0xFFFFF6E5);
  static const card = Color(0xFFFFFDF7);
  static const felt = Color(0xFF3DA35D);
  static const feltDark = Color(0xFF2C7A45);
  static const wood = Color(0xFFB0703A);
  static const woodDark = Color(0xFF7A4520);
  static const yellow = Color(0xFFFFC745);
  static const orange = Color(0xFFFF8A3D);
  static const red = Color(0xFFF2545B);
  static const blue = Color(0xFF4C9AFF);
  static const purple = Color(0xFF9B6BFF);
  static const teal = Color(0xFF2EC4B6);
  static const green = Color(0xFF57C27A);
  static const grey = Color(0xFFCFCAC0);
  static const muted = Color(0xFF8A8778);

  static const outline = 2.5;
  static const radius = 16.0;
  static const font = 'Fredoka';

  static TextStyle text(double size, {FontWeight weight = FontWeight.w600, Color color = ink}) =>
      TextStyle(fontFamily: font, fontSize: size, fontWeight: weight, color: color, height: 1.1);

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: font,
      colorScheme: ColorScheme.fromSeed(seedColor: felt, surface: paper),
      scaffoldBackgroundColor: paper,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink, fontFamily: font),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: text(15, color: paper),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
    );
  }

  static BoxDecoration box(Color color, {double radius = Toon.radius, double shadow = 4}) => BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: ink, width: outline),
    boxShadow: [if (shadow > 0) BoxShadow(color: ink, offset: Offset(0, shadow))],
  );
}

/// A flat panel with an outline and a solid drop shadow.
class ToonBox extends StatelessWidget {
  const ToonBox({
    super.key,
    required this.child,
    this.color = Toon.card,
    this.radius = Toon.radius,
    this.shadow = 4,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final Color color;
  final double radius;
  final double shadow;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.only(bottom: shadow),
    padding: padding,
    decoration: Toon.box(color, radius: radius, shadow: shadow),
    child: child,
  );
}

/// A chunky button that sinks into its shadow when pressed. Null [onPressed]
/// greys it out. With [repeat], holding it fires again and again, faster.
class ToonButton extends StatefulWidget {
  const ToonButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.color = Toon.yellow,
    this.radius = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.repeat = false,
    this.tooltip,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final Color color;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool repeat;
  final String? tooltip;

  @override
  State<ToonButton> createState() => _ToonButtonState();
}

class _ToonButtonState extends State<ToonButton> {
  static const _depth = 4.0;
  var _down = false;
  Timer? _repeat;

  bool get _enabled => widget.onPressed != null;

  void _press(bool down) {
    if (!_enabled || down == _down) return;
    setState(() => _down = down);
    if (down && widget.repeat) {
      HapticFeedback.selectionClick();
      widget.onPressed!();
      var delay = 380;
      void tick() {
        _repeat = Timer(Duration(milliseconds: delay), () {
          if (!mounted || !_down) return;
          widget.onPressed?.call();
          delay = (delay * 0.8).clamp(60, 380).round();
          tick();
        });
      }

      tick();
    } else if (!down) {
      _repeat?.cancel();
    }
  }

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _enabled ? widget.color : Toon.grey;
    final button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press(true),
      onTapUp: (_) {
        final wasDown = _down;
        _press(false);
        if (wasDown && !widget.repeat) {
          HapticFeedback.lightImpact();
          widget.onPressed?.call();
        }
      },
      onTapCancel: () => _press(false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: _depth),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          transform: Matrix4.translationValues(0, _down ? _depth : 0, 0),
          padding: widget.padding,
          decoration: Toon.box(color, radius: widget.radius, shadow: _down ? 0 : _depth),
          child: DefaultTextStyle.merge(
            style: Toon.text(17, color: _enabled ? Toon.ink : Toon.muted),
            textAlign: TextAlign.center,
            child: IconTheme.merge(
              data: IconThemeData(color: _enabled ? Toon.ink : Toon.muted),
              child: Center(widthFactor: 1, heightFactor: 1, child: widget.child),
            ),
          ),
        ),
      ),
    );
    final semantic = Semantics(button: true, enabled: _enabled, child: button);
    return widget.tooltip == null ? semantic : Tooltip(message: widget.tooltip, child: semantic);
  }
}

/// 1240 -> "1,240".
String chips(int n) {
  final s = n.abs().toString();
  final out = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}
