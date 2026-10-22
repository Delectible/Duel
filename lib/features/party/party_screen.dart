import 'dart:math';

import 'package:duel_engine/difficulty.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/avatars/faces.dart';
import '../../core/online/party.dart';
import 'lobby.dart';
import '../../core/table/table_bits.dart';
import '../../core/theme/split_page.dart';
import '../../core/theme/toon.dart';

/// Your party: start one (and send the code), or join a friend's with
/// theirs. Once you're together, the host picks games from home and both
/// phones go to the table.
class PartyScreen extends StatefulWidget {
  const PartyScreen({super.key});

  @override
  State<PartyScreen> createState() => _PartyScreenState();
}

class _PartyScreenState extends State<PartyScreen> {
  final _code = TextEditingController();

  /// How the new party will pick its games.
  var _mode = 'host';

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _say(String? message) {
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final party = PartyScope.of(context);
    final header = Row(
      children: [
        ToonButton(
          color: Toon.card,
          padding: const EdgeInsets.all(8),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 12),
        Text('Your party', style: Toon.text(26, weight: FontWeight.w700)),
      ],
    );
    if (party == null) {
      return Scaffold(
        body: SplitPage(
          left: [
            header,
            const SizedBox(height: 16),
            ToonBox(
              child: Text(
                "Playing with friends needs the internet. Connect, then close and reopen Duel. "
                'Bots work any time.',
                style: Toon.text(16, weight: FontWeight.w500),
              ),
            ),
          ],
          right: const [],
        ),
      );
    }
    return Scaffold(
      body: SplitPage(
        left: [header, const SizedBox(height: 16), ...party.inParty ? _inParty(party) : _start(party)],
        right: party.inParty ? _members(party) : _join(party),
      ),
    );
  }

  // --- Not in a party yet ----------------------------------------------------

  List<Widget> _start(PartyService party) => [
    Text(
      'Play with a friend on their own phone. Start a party and send them the code, '
      'or type in the code they sent you.',
      style: Toon.text(16, weight: FontWeight.w500),
    ),
    const SizedBox(height: 16),
    Text('Who picks the games?', style: Toon.text(18, weight: FontWeight.w700)),
    const SizedBox(height: 8),
    for (final (mode, title, about, icon) in const [
      ('host', 'The host', 'You pick; it starts on every phone.', Icons.star_rounded),
      (
        'vote',
        'A vote',
        'Everyone picks; most votes wins (a coin toss on a tie).',
        Icons.how_to_vote_rounded,
      ),
      ('first', 'First come', 'Whoever hits Play first picks.', Icons.bolt_rounded),
    ])
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ToonButton(
          key: Key('mode $mode'),
          color: _mode == mode ? Toon.yellow : Toon.card,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          onPressed: () => setState(() => _mode = mode),
          child: Row(
            children: [
              Icon(icon, color: Toon.on(_mode == mode ? Toon.yellow : Toon.card)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Toon.text(16, color: Toon.on(_mode == mode ? Toon.yellow : Toon.card)),
                    ),
                    Text(
                      about,
                      style: Toon.text(
                        13,
                        weight: FontWeight.w500,
                        color: Toon.on(_mode == mode ? Toon.yellow : Toon.card),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    const SizedBox(height: 8),
    ToonButton(
      key: const Key('create party'),
      color: Toon.purple,
      padding: const EdgeInsets.all(16),
      onPressed: party.busy ? null : () async => _say(await party.create(mode: _mode)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.celebration_rounded),
          const SizedBox(width: 8),
          Text('Start a party', style: Toon.text(20, weight: FontWeight.w700)),
        ],
      ),
    ),
    const SizedBox(height: 16),
  ];

  List<Widget> _join(PartyService party) => [
    ToonBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Got a code?', style: Toon.text(18, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: Toon.box(Toon.paper, radius: 12, shadow: 0),
                  child: TextField(
                    key: const Key('code field'),
                    controller: _code,
                    maxLength: 6,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    enableSuggestions: false,
                    style: Toon.text(24, weight: FontWeight.w700).copyWith(letterSpacing: 4),
                    cursorColor: Toon.fg,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                      hintText: 'ABC123',
                    ),
                    onSubmitted: (_) => _joinNow(party),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ToonButton(
                key: const Key('join'),
                color: Toon.green,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                onPressed: party.busy ? null : () => _joinNow(party),
                child: Text('Join', style: Toon.text(18, weight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
  ];

  Future<void> _joinNow(PartyService party) async {
    FocusScope.of(context).unfocus();
    _say(await party.join(_code.text));
  }

  // --- In a party --------------------------------------------------------------

  List<Widget> _inParty(PartyService party) {
    final code = party.code ?? '';
    final alone = party.size < 2;
    return [
      NowPlaying(party: party),
      ToonBox(
        color: Toon.yellow,
        child: Column(
          children: [
            Text('Party code', style: Toon.text(15, color: Toon.inkLight)),
            FittedBox(
              child: Text(
                code,
                key: const Key('party code'),
                style: Toon.text(
                  44,
                  weight: FontWeight.w700,
                  color: Toon.inkLight,
                ).copyWith(letterSpacing: 8),
              ),
            ),
            const SizedBox(height: 6),
            ToonButton(
              key: const Key('copy code'),
              color: Toon.card,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: 'Play Duel with me! Party code: $code'));
                _say('Copied. Paste it to your friend.');
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.copy_rounded, size: 20),
                  const SizedBox(width: 6),
                  Text('Copy invite', style: Toon.text(16)),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Text(
        alone
            ? 'Send your friend the code. When they type it in on their phone, they pop up here.'
            : switch (party.mode) {
                'vote' =>
                  'Everyone is here. Each of you votes for a game on the home screen; '
                      'when everyone has voted, the winner starts (a coin toss on a tie).'
                      '${party.votes.isEmpty ? '' : ' ${party.votes.length} of ${party.members.length} voted.'}',
                'first' => 'Everyone is here. Whoever picks a game first on the home screen starts it.',
                _ =>
                  party.isHost
                      ? 'Everyone is here. Pick a game on the home screen and it starts on every phone.'
                      : '${party.hostName} picks the game. It starts here by itself.',
              },
        style: Toon.text(16, weight: FontWeight.w500),
      ),
      const SizedBox(height: 12),
      if (!alone && party.isHost)
        ToonButton(
          key: const Key('pick game'),
          color: Toon.green,
          padding: const EdgeInsets.all(14),
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          child: Text('Pick a game', style: Toon.text(20, weight: FontWeight.w700)),
        ),
      const SizedBox(height: 12),
    ];
  }

  List<Widget> _members(PartyService party) => [
    Text('Who’s here', style: Toon.text(18, weight: FontWeight.w700)),
    const SizedBox(height: 8),
    for (final m in party.members)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Pop(
          key: ValueKey(m.uid),
          child: ToonBox(
            key: Key('member ${m.you ? 'you' : m.persona.name}'),
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                _HostFace(member: m),
                const SizedBox(width: 12),
                Expanded(child: Text(m.persona.name, style: Toon.text(18))),
                if (m.host) Text('Host', style: Toon.text(14, color: Toon.muted)),
              ],
            ),
          ),
        ),
      ),
    if (party.members.length < 2) const _Waiting(),
    ..._bots(party),
    const SizedBox(height: 8),
    Align(
      alignment: Alignment.centerLeft,
      child: ToonButton(
        key: const Key('leave party'),
        color: Toon.card,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        onPressed: party.busy ? null : () async => _say(await party.leave()),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.logout_rounded, size: 20),
            const SizedBox(width: 6),
            Text('Leave party', style: Toon.text(16)),
          ],
        ),
      ),
    ),
    const SizedBox(height: 16),
  ];

  /// Bots fill seats (each with its own difficulty). Only the host changes
  /// them; everyone sees who's sitting in.
  List<Widget> _bots(PartyService party) {
    final bots = party.bots;
    if (bots.isEmpty && !party.isHost) return const [];
    void save(List<PartyBot> next) async => _say(await party.setBots(next));
    return [
      const SizedBox(height: 6),
      Text('Bots', style: Toon.text(18, weight: FontWeight.w700)),
      const SizedBox(height: 8),
      for (final (i, b) in bots.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Pop(
            key: ValueKey('bot ${b.name}'),
            child: ToonBox(
              key: Key('bot $i'),
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Padding(padding: const EdgeInsets.only(left: 4), child: Face(b.persona, size: 44)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(b.name, style: Toon.text(18))),
                  _DifficultyChip(
                    key: Key('bot $i difficulty'),
                    difficulty: b.difficulty,
                    onTap: party.isHost && !party.busy
                        ? () => save([
                            for (final (k, x) in bots.indexed)
                              k == i
                                  ? x.copyWith(
                                      difficulty: Difficulty
                                          .values[(x.difficulty.index + 1) % Difficulty.values.length],
                                    )
                                  : x,
                          ])
                        : null,
                  ),
                  if (party.isHost) ...[
                    const SizedBox(width: 6),
                    ToonButton(
                      key: Key('bot $i remove'),
                      color: Toon.card,
                      padding: const EdgeInsets.all(6),
                      radius: 10,
                      tooltip: 'Remove ${b.name}',
                      onPressed: party.busy ? null : () => save([...bots]..removeAt(i)),
                      child: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      if (party.isHost)
        Align(
          alignment: Alignment.centerLeft,
          child: ToonButton(
            key: const Key('add bot'),
            color: Toon.teal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            onPressed: party.busy || party.size >= PartyService.maxTable
                ? null
                : () {
                    final used = {for (final b in bots) b.name};
                    final pick = Persona.bots(4, Random()).firstWhere(
                      (p) => !used.contains(p.name),
                      orElse: () => Persona.bots(1, Random()).single,
                    );
                    save([
                      ...bots,
                      PartyBot(name: pick.name, look: pick.look, difficulty: Difficulty.normal),
                    ]);
                  },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.smart_toy_rounded, size: 20),
                const SizedBox(width: 6),
                Text(
                  party.size >= PartyService.maxTable ? 'Table full (6)' : 'Add a bot',
                  style: Toon.text(16),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 12),
    ];
  }
}

/// Easy / Normal / Hard, tap to change (host).
class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({super.key, required this.difficulty, required this.onTap});

  final Difficulty difficulty;
  final VoidCallback? onTap;

  static const _colors = {
    Difficulty.easy: Toon.green,
    Difficulty.normal: Toon.yellow,
    Difficulty.hard: Toon.red,
  };

  @override
  Widget build(BuildContext context) => ToonButton(
    color: _colors[difficulty]!,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    radius: 10,
    tooltip: onTap == null ? null : 'Bot difficulty',
    onPressed: onTap ?? () {},
    child: Text(difficulty.label, style: Toon.text(14, color: Toon.inkLight)),
  );
}

/// A face, with a little crown on the host's.
class _HostFace extends StatelessWidget {
  const _HostFace({required this.member});

  final PartyMember member;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 56,
    height: 56,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(left: 4, top: 6, child: Face(member.persona, size: 48)),
        if (member.host)
          Positioned(
            right: -6,
            top: -8,
            child: Transform.rotate(
              angle: 0.35,
              child: const Face.part(key: Key('crown'), Avatar(hat: Hat.crown), FacePart.hat, size: 30),
            ),
          ),
      ],
    ),
  );
}

/// An empty seat, gently pulsing, while you wait for a friend.
class _Waiting extends StatefulWidget {
  const _Waiting();

  @override
  State<_Waiting> createState() => _WaitingState();
}

class _WaitingState extends State<_Waiting> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_pulse),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Toon.muted, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Toon.muted, width: 2),
              ),
              child: Icon(Icons.question_mark_rounded, color: Toon.muted),
            ),
            const SizedBox(width: 12),
            Text('Waiting for a friend…', style: Toon.text(17, color: Toon.muted)),
          ],
        ),
      ),
    ),
  );
}
