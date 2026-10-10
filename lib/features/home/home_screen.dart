import 'package:flutter/material.dart';

import '../../core/app_info.dart';

/// The first screen: pick how to play. Both modes are still to come.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'About',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showAboutSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppInfo.name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Card games, head to head.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 48),
                const _ModeButton(icon: Icons.public, label: 'Play online'),
                const SizedBox(height: 16),
                const _ModeButton(icon: Icons.smart_toy_outlined, label: 'Play vs bot'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
      icon: Icon(icon),
      label: Text(label),
      onPressed: () => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$label is coming soon.'))),
    );
  }
}

/// Version and what's new in each version.
void showAboutSheet(BuildContext context) {
  final theme = Theme.of(context);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          Text('${AppInfo.name} ${AppInfo.version}', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final (version, notes) in AppInfo.revisions) ...[
            Text(version, style: theme.textTheme.titleSmall),
            for (final note in notes) Text('• $note'),
            const SizedBox(height: 8),
          ],
        ],
      ),
    ),
  );
}
