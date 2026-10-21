import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../sound/sound.dart';

/// Duel's cartoon look: flat colours, thick dark outlines, chunky drop
/// shadows, rounded everything, Fredoka type.
///
/// Light and dark: the bright colours and the table stay the same; the
/// page, panels, text and outlines switch with [dark]. Those are getters,
/// so they can't go in `const` expressions; after changing [dark] the app
/// rebuilds every widget (`rebuildAll`).
abstract final class Toon {
  /// Dark mode on (set from Settings / the phone).
  static var dark = false;

  /// Outlines and drop shadows.
  static Color get ink => dark ? const Color(0xFF0D0E16) : inkLight;

  /// Text and icons on the page and panels.
  static Color get fg => dark ? const Color(0xFFF2EDE1) : inkLight;

  /// The page behind everything.
  static Color get paper => dark ? const Color(0xFF1B1E2B) : const Color(0xFFFFF6E5);

  /// Panels and plain buttons.
  static Color get card => dark ? const Color(0xFF2B2F42) : const Color(0xFFFFFDF7);

  /// Secondary text.
  static Color get muted => dark ? const Color(0xFFA19EB2) : const Color(0xFF8A8778);

  /// Turned-off buttons.
  static Color get grey => dark ? const Color(0xFF4A4D5E) : const Color(0xFFCFCAC0);

  /// Dark text on the bright colours (yellow, green, ...), in both modes.
  static const inkLight = Color(0xFF2B2D42);

  /// Playing card faces stay white in both modes.
  static const cardFace = Color(0xFFFFFDF7);
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

  static const outline = 2.5;
  static const radius = 16.0;
  static const font = 'Fredoka';

  /// Text that reads on [background]: dark ink on bright colours, [fg] on
  /// the page and panels.
  static Color on(Color background) => background.computeLuminance() > 0.35 ? inkLight : fg;

  /// Without [color] the text takes the colour of what it sits on: [fg] on
  /// the page, dark ink on bright buttons and panels (ToonButton / ToonBox
  /// set it).
  static TextStyle text(double size, {FontWeight weight = FontWeight.w600, Color? color}) =>
      TextStyle(fontFamily: font, fontSize: size, fontWeight: weight, color: color, height: 1.1);

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: font,
      colorScheme: ColorScheme.fromSeed(
        seedColor: felt,
        surface: paper,
        brightness: dark ? Brightness.dark : Brightness.light,
      ),
      scaffoldBackgroundColor: paper,
    );
    return base.copyWith(
      // Plain text on the page (Toon.text without a colour) is [fg].
      textTheme: base.textTheme.apply(bodyColor: fg, displayColor: fg, fontFamily: font),
      iconTheme: IconThemeData(color: fg),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? card : inkLight,
        contentTextStyle: text(15, color: dark ? fg : paper),
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
    this.color,
    this.radius = Toon.radius,
    this.shadow = 4,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;

  /// Defaults to the panel colour.
  final Color? color;
  final double radius;
  final double shadow;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Toon.card;
    return Container(
      margin: EdgeInsets.only(bottom: shadow),
      padding: padding,
      decoration: Toon.box(c, radius: radius, shadow: shadow),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: Toon.on(c)),
        child: IconTheme.merge(
          data: IconThemeData(color: Toon.on(c)),
          child: child,
        ),
      ),
    );
  }
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
    // Letting go always counts, even if holding it just switched the
    // button off (- down to Free); otherwise it would stay stuck down.
    if (down == _down || (down && !_enabled)) return;
    setState(() => _down = down);
    if (down && widget.repeat) {
      HapticFeedback.selectionClick();
      Sound.play(Sfx.tap, gain: 0.6);
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
  void didUpdateWidget(ToonButton old) {
    super.didUpdateWidget(old);
    // Switched off while held (e.g. a repeat reached its limit): pop up.
    if (!_enabled && _down) {
      _repeat?.cancel();
      _down = false;
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
          Sound.play(Sfx.tap, gain: 0.6);
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
            style: Toon.text(17, color: _enabled ? Toon.on(color) : Toon.muted),
            textAlign: TextAlign.center,
            child: IconTheme.merge(
              data: IconThemeData(color: _enabled ? Toon.on(color) : Toon.muted),
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

/// Rebuilds every widget in the app, after [Toon.dark] changes (const
/// widgets would otherwise keep their old colours).
void rebuildAll() {
  void mark(Element e) {
    e.markNeedsBuild();
    e.visitChildren(mark);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(mark);
}
