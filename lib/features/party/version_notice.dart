import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_info.dart';
import '../../core/online/party.dart';
import '../../core/theme/toon.dart';

/// Someone in your party has a newer Duel (a newer x.Y): say so once per
/// version, and offer the store. Nothing is blocked.
Future<void> showVersionNotice(BuildContext context, PartyService party, String newer) async {
  party.versionNoticeSeen = newer;
  final update = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: ToonBox(
        key: const Key('version notice'),
        color: Toon.paper,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Update Duel?', style: Toon.text(22, weight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Someone in your party has Duel $newer and you have ${AppInfo.version}. '
              'Playing together on an older version may cause problems.',
              textAlign: TextAlign.center,
              style: Toon.text(16, weight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ToonButton(
                    key: const Key('ignore version'),
                    color: Toon.card,
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Ignore'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ToonButton(
                    key: const Key('update'),
                    color: Toon.green,
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Update'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (update == true) await openStore();
}

/// Duel in the store: Google Play, or TestFlight on an iPhone (where the
/// builds come from for now).
Future<void> openStore() async {
  final url = defaultTargetPlatform == TargetPlatform.iOS
      ? Uri.parse('itms-beta://')
      : Uri.parse('https://play.google.com/store/apps/details?id=com.dingo.duel');
  try {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  } on Object {
    // No store app: nothing to do.
  }
}
