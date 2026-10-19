import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/online/party.dart';
import '../../core/theme/toon.dart';
import '../../games/catalog.dart';

/// Leaving and coming back to a party's game, the same on every screen:
/// what leaving means, the pause while the host decides about someone who
/// left, Game In Progress, and the host ending a game. Everything here
/// reads the match the server keeps, so every phone shows the same.

String gameName(String? id) => games.where((g) => g.id == id).firstOrNull?.name ?? 'The game';

/// What happens if you leave now (for the leave dialog).
String leaveNote(PartyService party) {
  final m = party.match;
  if (m == null) return '';
  final seats = (m['seats']! as List).length;
  final bots = (m['bots'] as List?) ?? const [];
  final left = party.leftSeats;
  final others = [
    for (var i = 0; i < seats; i++)
      if (i != party.seat && (i >= bots.length || bots[i] == null) && !left.contains(i)) i,
  ];
  final anyBots = bots.any((b) => b != null);
  if (others.length == 1 && !anyBots && seats == 2) return '${party.nameAt(others.single)} wins if you go.';
  if (others.length <= 1) return 'The game ends for everyone if you go.';
  return 'The host can bring in a bot to play your seat, and you can come back to it.';
}

/// "Rejoin?" for someone who left. True to go back in.
Future<bool> askRejoin(BuildContext context, PartyService party) async {
  final name = gameName(party.match?['game'] as String?);
  final stake = party.match?['stake'] as int? ?? 0;
  final ok = await _ask(
    context,
    key: 'rejoin dialog',
    title: 'Back to $name?',
    body:
        'You take your seat back as it stands now (a bot may have been playing it).'
        '${stake > 0 ? ' Your stake goes back in, as if you never left.' : ''}',
    yes: 'Rejoin',
    yesColor: Toon.green,
  );
  return ok;
}

/// Host: "End the game for everyone?". True to end it.
Future<bool> askEndGame(BuildContext context, PartyService party) => _ask(
  context,
  key: 'end dialog',
  title: 'End ${gameName(party.match?['game'] as String?)}?',
  body: 'The game stops for everyone. Whoever is still playing gets their stake back.',
  yes: 'End it',
  yesColor: Toon.red,
);

Future<bool> _ask(
  BuildContext context, {
  required String key,
  required String title,
  required String body,
  required String yes,
  required Color yesColor,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      key: Key(key),
      backgroundColor: Colors.transparent,
      child: ToonBox(
        color: Toon.paper,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Toon.text(22, weight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Toon.text(16, weight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ToonButton(
                    key: const Key('not now'),
                    color: Toon.card,
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Not now'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ToonButton(
                    key: const Key('yes'),
                    color: yesColor,
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(yes),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return ok ?? false;
}

/// Over the table while the game waits for the host to decide about who
/// left: the host gets Bring in a bot / End the game, everyone sees the
/// countdown, and when it runs out any phone asks for the bot (the server
/// only takes that once the time is really up).
class PausedCard extends StatefulWidget {
  const PausedCard({super.key, required this.party});

  final PartyService party;

  @override
  State<PausedCard> createState() => _PausedCardState();
}

class _PausedCardState extends State<PausedCard> {
  late final Timer _tick = Timer.periodic(const Duration(seconds: 1), (_) => _second());

  /// When this phone first saw this pause (server clocks differ from ours).
  Object? _pauseAt;
  DateTime _heard = DateTime.now();
  var _asked = false;

  PartyService get party => widget.party;

  int get _msLeft {
    final p = party.paused;
    if (p == null) return 0;
    if (p['at'] != _pauseAt) {
      _pauseAt = p['at'];
      _heard = DateTime.now();
      _asked = false;
    }
    final total = (p['until']! as int) - (p['at']! as int);
    return total - DateTime.now().difference(_heard).inMilliseconds;
  }

  void _second() {
    if (!mounted) return;
    setState(() {});
    if (party.paused != null && _msLeft < -1500 && !_asked) {
      _asked = true;
      unawaited(party.decide('bot'));
    }
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = party.paused;
    if (p == null) return const SizedBox.shrink();
    final who = [for (final s in (p['seats']! as List).cast<int>()) party.nameAt(s)];
    final names = who.length == 1
        ? who.single
        : '${who.sublist(0, who.length - 1).join(', ')} and ${who.last}';
    final secs = (_msLeft / 1000).ceil().clamp(0, 99);
    final deciderSeat = ((party.match?['seats'] as List?) ?? const []).indexOf(p['decider']);
    final host = deciderSeat < 0 ? 'the host' : party.nameAt(deciderSeat);
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(20),
          child: ToonBox(
            key: const Key('paused'),
            color: Toon.paper,
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pause_circle_rounded, size: 40),
                const SizedBox(height: 6),
                Text(
                  '$names left',
                  textAlign: TextAlign.center,
                  style: Toon.text(22, weight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  party.deciding
                      ? 'Bring in a bot to play ${who.length == 1 ? 'their seat' : 'their seats'}, or end the game? '
                            'A bot sits in by itself in $secs s.'
                      : 'Waiting for $host to decide. A bot sits in by itself in $secs s.',
                  textAlign: TextAlign.center,
                  style: Toon.text(15, weight: FontWeight.w500),
                ),
                if (party.deciding) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ToonButton(
                          key: const Key('end game'),
                          color: Toon.card,
                          onPressed: party.busy ? null : () => party.decide('end'),
                          child: const FittedBox(child: Text('End the game')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ToonButton(
                          key: const Key('bring in bot'),
                          color: Toon.green,
                          onPressed: party.busy ? null : () => party.decide('bot'),
                          child: const FittedBox(child: Text('Bring in a bot')),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The party screen's line about the game being played: Back to it /
/// Rejoin, and for the host, End it.
class NowPlaying extends StatelessWidget {
  const NowPlaying({super.key, required this.party});

  final PartyService party;

  @override
  Widget build(BuildContext context) {
    if (!party.playing) return const SizedBox.shrink();
    final name = gameName(party.match?['game'] as String?);
    final note = party.inGame
        ? 'You’re playing.'
        : party.leftGame
        ? 'You left. Your seat is waiting.'
        : 'It started before you joined: you’re in the next one.';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ToonBox(
        key: const Key('now playing'),
        color: Toon.card,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Now playing: $name', style: Toon.text(18, weight: FontWeight.w700)),
            Text(
              note,
              style: Toon.text(14, weight: FontWeight.w500, color: Toon.muted),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (party.inGame)
                  ToonButton(
                    key: const Key('back to game'),
                    color: Toon.green,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    onPressed: () => openGame(context, party),
                    child: Text('Back to the game', style: Toon.text(15)),
                  ),
                if (party.leftGame)
                  ToonButton(
                    key: const Key('rejoin'),
                    color: Toon.green,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    onPressed: party.busy ? null : () => rejoin(context, party),
                    child: Text('Rejoin', style: Toon.text(15)),
                  ),
                if (party.isHost)
                  ToonButton(
                    key: const Key('end it'),
                    color: Toon.red,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    onPressed: party.busy
                        ? null
                        : () async {
                            if (!await askEndGame(context, party)) return;
                            final error = await party.endGame();
                            if (error != null && context.mounted) _snack(context, error);
                          },
                    child: Text('End game', style: Toon.text(15)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks, then rejoins: home opens the game by itself once you're back in.
/// True if you're back.
Future<bool> rejoin(BuildContext context, PartyService party) async {
  if (!await askRejoin(context, party)) return false;
  final error = await party.rejoin();
  if (error != null && context.mounted) _snack(context, error);
  return error == null;
}

/// Opens the party's game screen (if it isn't showing already).
void openGame(BuildContext context, PartyService party) {
  final open = games.where((g) => g.id == party.match?['game']).firstOrNull?.openOnline;
  if (open == null || party.onScreen) return;
  party.onScreen = true;
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => open(party)));
}

void _snack(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));
