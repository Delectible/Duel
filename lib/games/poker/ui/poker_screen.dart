import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/help/game_guide.dart';
import 'package:duel_engine/difficulty.dart';
import '../../../core/theme/toon.dart';
import 'action_bar.dart';
import '../../../core/account/account.dart';
import '../../../core/account/stake.dart';
import '../../../core/avatars/faces.dart';
import '../../../core/table/table_bits.dart';
import '../../../core/online/party.dart';
import '../../../features/party/lobby.dart';
import 'poker_guide.dart';
import 'poker_controller.dart';
import 'table_stats.dart';
import 'table_view.dart';

/// Texas Hold'em Sit & Go against [bots] bots.
class PokerScreen extends StatefulWidget {
  const PokerScreen({
    super.key,
    required this.bots,
    required this.difficulty,
    this.pace = 1,
    this.seed,
    this.resultTimeout,
    this.stake,
  }) : party = null;

  /// With your party (and its bots), online: the referee deals.
  const PokerScreen.online({super.key, required PartyService this.party, this.pace = 1})
    : bots = 0,
      difficulty = Difficulty.normal,
      seed = null,
      resultTimeout = null,
      stake = null;

  final PartyService? party;

  final int bots;
  final Difficulty difficulty;

  /// Multiplies every delay (tests).
  final double pace;

  /// Fixed shuffles and bot choices (tests).
  final int? seed;

  /// Showdown results wait this long for Next hand; null waits for you
  /// (bot games). Online games will pass 10 seconds.
  final Duration? resultTimeout;

  /// The stake taken when you hit Play! (null: a free game).
  final StakeTicket? stake;

  @override
  State<PokerScreen> createState() => _PokerScreenState();
}

class _PokerScreenState extends State<PokerScreen> {
  late PokerController _c;
  late StakeTicket _ticket;
  late Account _account;

  /// Online: the match this table (and its stake) is for.
  String? _matchId;

  @override
  void initState() {
    super.initState();
    _account = AccountScope.maybeRead(context) ?? Account();
    final party = widget.party;
    if (party != null) {
      party.onScreen = true;
      party.addListener(_follow);
    }
    _ticket =
        widget.stake ??
        StakeTicket(
          account: _account,
          gameId: 'holdem',
          stake: 0,
          opponents: widget.bots,
          difficulty: widget.difficulty,
        );
    _c = _newTable();
  }

  /// Who's sitting where online (people who left, bots sitting in): the
  /// table is rebuilt when it changes, so names and bots stay right.
  String? _seating;

  String _seatingOf(Doc m) => '${m['left']}|${((m['standIns'] as Map?) ?? const {}).keys.toList()}';

  /// Online: a rematch has started, the seating changed, or the game ended
  /// early (people left / the host ended it).
  void _follow() {
    final m = widget.party?.match;
    final id = m?['id'];
    if (m == null || !mounted) return;
    if (id != _matchId) {
      _rebuild();
      return;
    }
    final seating = _seatingOf(m);
    if (_seating != null && seating != _seating && m['status'] == 'live') {
      _seating = seating;
      _rebuild();
      return;
    }
    _seating = seating;
    _settleEarly();
  }

  /// The game stopped before its end: why (null if it didn't).
  String? get _endedEarly {
    final m = widget.party?.match;
    if (m == null || m['id'] != _matchId || m['status'] != 'over') return null;
    final r = (m['result'] as Map?) ?? const {};
    final reason = r['reason'];
    return reason == 'won' || reason == 'draw' ? null : reason as String?;
  }

  /// Settles the stake when the game stops early: stakes back when it was
  /// ended; a win when you're the one left in a one-on-one.
  void _settleEarly() {
    final why = _endedEarly;
    if (why == null || _ticket.settled || _c.phase == TablePhase.finished) return;
    final party = widget.party!;
    final winner = (party.match!['result'] as Map)['winner'];
    _ticket.settle(why == 'ended' ? Outcome.tie : (winner == party.seat ? Outcome.win : Outcome.loss));
    setState(() {});
  }

  void _rebuild() {
    setState(() {
      _c.dispose();
      _c = _newTable();
    });
  }

  /// A fresh table. Stored in [_c] before it starts: [_settle] reads it.
  PokerController _newTable() {
    final party = widget.party;
    if (party != null) {
      final online = OnlinePokerController.forMatch(
        party,
        you: _account.persona,
        pace: widget.pace,
        onReset: () => WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _rebuild();
        }),
      );
      if (online != null) {
        final m = party.match!;
        if (m['id'] != _matchId) {
          // A new match: put in its stake (after this frame: taking pips
          // redraws everything that shows your balance).
          _matchId = m['id'] as String?;
          final stake = m['stake'] as int? ?? 0;
          final opponents = (m['seats']! as List).length - 1;
          _ticket = StakeTicket(
            account: _account,
            gameId: 'holdem',
            stake: 0,
            opponents: opponents,
            difficulty: Difficulty.normal,
          );
          if (stake > 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _ticket.settled) return;
              setState(
                () => _ticket = StakeTicket(
                  account: _account,
                  gameId: 'holdem',
                  stake: _account.placeStake(stake),
                  opponents: opponents,
                  difficulty: Difficulty.normal,
                ),
              );
            });
          }
        }
        _c = online;
        online
          ..addListener(_settle)
          ..start();
        return online;
      }
    }
    final c = _c = PokerController(
      bots: widget.bots,
      difficulty: widget.difficulty,
      pace: widget.pace,
      resultTimeout: widget.resultTimeout,
      rng: widget.seed == null ? null : Random(widget.seed),
      you: _account.persona,
    );
    c
      ..addListener(_settle)
      ..start();
    return c;
  }

  /// Your tournament's over: win only for first place.
  void _settle() {
    if (_c.phase == TablePhase.finished && !_ticket.settled) {
      _ticket.settle(_c.yourPlace == 1 ? Outcome.win : Outcome.loss);
    }
  }

  void _playAgain() {
    setState(() {
      _c.dispose();
      _ticket = _ticket.again();
      _c = _newTable();
    });
  }

  @override
  void dispose() {
    widget.party?.removeListener(_follow);
    widget.party?.onScreen = false;
    _c.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    final party = widget.party;
    if (party != null) {
      // Still in: what happens depends on who's left (see leaveNote). The
      // stake goes, and comes back if you rejoin.
      if (party.inGame && _c.phase != TablePhase.finished) {
        if (!await confirmLeave(context, _ticket, online: leaveNote(party))) return;
        await party.forfeit(stake: _ticket.stake);
      }
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }
    if (_c.phase == TablePhase.finished || await confirmLeave(context, _ticket)) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _c,
            builder: (context, _) => Stack(
              children: [
                GameLayout(
                  top: _Hud(c: _c, ticket: _ticket, onLeave: _leave),
                  commentary: TableInfo(c: _c),
                  table: TableView(c: _c),
                  controls: ActionBar(c: _c),
                ),
                // Someone left: the host decides (bot or end).
                if (widget.party?.paused != null && _endedEarly == null)
                  Positioned.fill(child: PausedCard(party: widget.party!)),
                if (_endedEarly != null && _c.phase != TablePhase.finished)
                  Positioned.fill(child: _endedCard()),
                if (_c.phase == TablePhase.finished)
                  Positioned.fill(
                    child: _GameOver(
                      c: _c,
                      ticket: _ticket,
                      onAgain: widget.party == null ? _playAgain : _rematch(),
                      againLabel: _againLabel(),
                      leaveLabel: widget.party == null ? 'Games' : 'Back to party',
                      onLeave: widget.party == null ? () => Navigator.of(context).pop() : _leave,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension on _PokerScreenState {
  /// The game stopped early: why, and what happened to the stake.
  Widget _endedCard() {
    final party = widget.party!;
    final r = (party.match!['result'] as Map?) ?? const {};
    final left = ((r['left'] as List?) ?? const []).cast<int>();
    final names = [for (final s in left) party.nameAt(s)];
    final who = names.isEmpty ? 'The host' : names.join(' and ');
    final won = r['winner'] == party.seat;
    final why = _endedEarly;
    return GameOverCard(
      face: _account.persona,
      title: why == 'ended' ? 'Game ended' : (won ? 'You win!' : 'Game over'),
      subtitle: why == 'ended'
          ? '${names.isEmpty ? 'The host ended it.' : '$who left.'}'
                '${_ticket.stake > 0 ? ' Your stake is back.' : ''}'
          : won
          ? '$who left the game.'
          : 'You ran out of time.',
      ticket: _ticket,
      won: won,
      onAgain: _rematch(),
      againLabel: _againLabel(),
      leaveLabel: 'Back to party',
      onLeave: _leave,
    );
  }

  /// Online: Rematch once the whole table is done (everyone asks).
  VoidCallback? _rematch() {
    final party = widget.party!;
    final m = party.match;
    if (m == null || m['status'] != 'over') return null;
    if (((m['rematch'] as List?) ?? const []).contains(party.uid)) return null;
    return () => party.rematch().then((e) {
      if (e != null && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e)));
      }
    });
  }

  String _againLabel() {
    final party = widget.party;
    if (party == null) return 'Play again';
    final m = party.match;
    if (m == null || m['status'] != 'over') return 'Still playing…';
    if (((m['rematch'] as List?) ?? const []).contains(party.uid)) return 'Waiting…';
    return 'Rematch';
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.c, required this.ticket, required this.onLeave});

  final PokerController c;
  final StakeTicket ticket;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final (sb, bb) = c.game.blinds;
    final left = c.game.handsToNextLevel;
    // In the landscape side panel the hand number joins the subtitle.
    final narrow = SidePanel.of(context);
    final hand = c.handNumber + (c.phase == TablePhase.shuffle ? 1 : 0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          ToonButton(
            color: Toon.card,
            padding: const EdgeInsets.all(8),
            tooltip: 'Leave table',
            onPressed: onLeave,
            child: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The stake badge wraps under the name when space is tight
                // (on its side), rather than squeezing it.
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text("Texas Hold'em", maxLines: 1, style: Toon.text(18, weight: FontWeight.w700)),
                    StakeBadge(ticket),
                  ],
                ),
                Text(
                  '${narrow ? 'Hand $hand · ' : ''}Blinds ${chips(sb)} / ${chips(bb)}'
                  '${left == null ? '' : ' · up in $left hand${left == 1 ? '' : 's'}'}',
                  style: Toon.text(14, weight: FontWeight.w500, color: Toon.muted),
                ),
              ],
            ),
          ),
          if (!narrow) ...[
            ToonBox(
              color: Toon.card,
              shadow: 3,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              // While you shuffle, the coming hand's number; online, on
              // your turn, the time you have left.
              child: c.yourTurn && c.turnSecondsLeft != null
                  ? Text(
                      '${c.turnSecondsLeft}s',
                      key: const Key('your clock'),
                      style: Toon.text(14, color: c.turnSecondsLeft! <= 10 ? Toon.red : null),
                    )
                  : Text('Hand $hand', style: Toon.text(14)),
            ),
          ],
          const SizedBox(width: 8),
          GuideButton(title: "Texas Hold'em", stages: pokerGuide, current: () => pokerStage(c)),
        ],
      ),
    );
  }
}

class _GameOver extends StatelessWidget {
  const _GameOver({
    required this.c,
    required this.ticket,
    required this.onAgain,
    required this.onLeave,
    this.againLabel = 'Play again',
    this.leaveLabel = 'Games',
  });

  final PokerController c;
  final StakeTicket ticket;
  final VoidCallback? onAgain;
  final VoidCallback onLeave;
  final String againLabel;
  final String leaveLabel;

  @override
  Widget build(BuildContext context) {
    final place = c.yourPlace ?? 1;
    final won = place == 1;
    final players = c.personas.length;
    return ColoredBox(
      color: Toon.ink.withValues(alpha: 0.5),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.7, end: 1),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          builder: (context, s, child) => Transform.scale(scale: s, child: child),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: ToonBox(
                color: Toon.paper,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Face(c.personas[0], size: 72),
                    const SizedBox(height: 10),
                    Text(
                      won ? 'You won!' : 'Out in ${_ordinal(place)}',
                      style: Toon.text(30, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      won ? 'You took every chip at a table of $players.' : 'Of $players players.',
                      textAlign: TextAlign.center,
                      style: Toon.text(16, weight: FontWeight.w500),
                    ),
                    Text(
                      '${c.game.handsPlayed} hand${c.game.handsPlayed == 1 ? '' : 's'}',
                      style: Toon.text(14, weight: FontWeight.w500, color: Toon.muted),
                    ),
                    GameSummary(
                      c: c,
                      footer: c is OnlinePokerController ? _Lineup(c: c as OnlinePokerController) : null,
                    ),
                    const SizedBox(height: 10),
                    StakeResult(ticket),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ToonButton(
                            key: const Key('over leave'),
                            color: Toon.card,
                            onPressed: onLeave,
                            child: FittedBox(child: Text(leaveLabel, maxLines: 1)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ToonButton(
                            key: const Key('again'),
                            color: Toon.green,
                            onPressed: onAgain,
                            child: FittedBox(child: Text(againLabel, maxLines: 1)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _ordinal(int n) => switch (n) {
  1 => '1st',
  2 => '2nd',
  3 => '3rd',
  _ => '${n}th',
};

/// Online: a note under the finishing order.
class _Lineup extends StatelessWidget {
  const _Lineup({required this.c});

  final OnlinePokerController c;

  @override
  Widget build(BuildContext context) {
    final note = c.matchOver && c.simulated
        ? 'No people left at the table, so the bots were placed by their chances (bigger stacks, better odds).'
        : !c.matchOver
        ? 'The others are still playing…'
        : null;
    if (note == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        note,
        textAlign: TextAlign.center,
        style: Toon.text(13, weight: FontWeight.w500, color: Toon.muted),
      ),
    );
  }
}
