import 'package:flutter/material.dart';

import '../../../core/theme/toon.dart';

/// A Tabletop tool's page: back, a title and a line under it, then the tool.
class ToolPage extends StatelessWidget {
  const ToolPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions = const [],
    this.background,
  });

  final String title, subtitle;
  final Widget child;
  final List<Widget> actions;
  final Color? background;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                ToonButton(
                  color: Toon.card,
                  padding: const EdgeInsets.all(8),
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Toon.text(
                          22,
                          weight: FontWeight.w700,
                          color: background == null ? null : Colors.white,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Toon.text(
                          13,
                          weight: FontWeight.w500,
                          color: background == null ? Toon.muted : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                ...actions,
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    ),
  );
}

/// Names to start a tool with: the party's members, else your name and
/// a friend.
List<String> startingNames(BuildContext context, {List<String>? party, String? me}) {
  if (party != null && party.length >= 2) return party;
  return [if (me != null && me != 'You') me else 'Player 1', 'Player 2', 'Player 3', 'Player 4'];
}
