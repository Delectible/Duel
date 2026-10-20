import 'package:flutter/material.dart';

import 'toon.dart';

/// A sheet that slides up over the screen at a fixed [height] (a share of
/// the screen) and slides away whole: drag or flick the handle, the top,
/// or the list once it's scrolled to the top, and it closes in one go. Its
/// contents never get squashed while it moves.
Future<T?> showToonSheet<T>(BuildContext context, {double height = 0.85, required WidgetBuilder builder}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Toon.paper,
      builder: (context) => _PullToClose(
        child: SizedBox(height: MediaQuery.sizeOf(context).height * height, child: builder(context)),
      ),
    );

/// Pulling a list down past its top (or flicking it down there) closes
/// the sheet, like dragging the sheet itself.
class _PullToClose extends StatefulWidget {
  const _PullToClose({required this.child});

  final Widget child;

  @override
  State<_PullToClose> createState() => _PullToCloseState();
}

class _PullToCloseState extends State<_PullToClose> {
  var _pulled = 0.0;
  var _closing = false;

  void _close() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical || _closing) return false;
    switch (n) {
      // Clamping lists (Android): the pull shows up as overscroll.
      case OverscrollNotification(:final overscroll, dragDetails: _?) when overscroll < 0:
        _pulled -= overscroll;
        if (_pulled > 70) _close();
      // Bouncing lists (iOS): the list itself goes past the top.
      case ScrollUpdateNotification(dragDetails: _?) when n.metrics.pixels < -70:
        _close();
      case ScrollEndNotification(:final dragDetails?)
          when n.metrics.pixels <= n.metrics.minScrollExtent && (dragDetails.primaryVelocity ?? 0) > 700:
        _close();
      case ScrollStartNotification():
        _pulled = 0;
      default:
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(onNotification: _onScroll, child: widget.child);
}
