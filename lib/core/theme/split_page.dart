import 'package:flutter/material.dart';

/// Whether [size] is a phone on its side (wide enough for two columns).
bool isLandscape(Size size) => size.width > size.height * 1.15 && size.width >= 600;

/// A scrolling page: one column upright ([left], [right], then [after]),
/// two side by side in landscape ([left] + [after] | [right]), each
/// scrolling on its own.
class SplitPage extends StatelessWidget {
  const SplitPage({super.key, required this.left, required this.right, this.after = const []});

  final List<Widget> left;
  final List<Widget> right;
  final List<Widget> after;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, box) {
        if (!isLandscape(box.biggest)) {
          return ListView(padding: const EdgeInsets.all(16), children: [...left, ...right, ...after]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 10, 16),
                children: [...left, ...after],
              ),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(10, 16, 16, 16), children: right),
            ),
          ],
        );
      },
    ),
  );
}
