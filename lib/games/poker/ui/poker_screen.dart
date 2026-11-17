import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/help/game_guide.dart';
import 'package:duel_engine/difficulty.dart';
import '../../../core/theme/toon.dart';
import 'action_bar.dart';
import '../../../core/account/account.dart';
import '../../../core/account/achievements.dart';
import '../../../core/account/stake.dart';
import '../../../core/avatars/faces.dart';
import '../../../core/table/table_bits.dart';
import '../../../core/online/party.dart';
import '../../../features/party/lobby.dart';
import 'poker_guide.dart';
import 'poker_controller.dart';
import 'package:duel_engine/poker/bot.dart';
import 'package:duel_engine/poker/tournament.dart';
import 'lounge_games.dart';
import 'rivals.dart';
import 'table_stats.dart';
import 'table_view.dart';

/// A Poker Lounge game against bots: a boss on the ladder, or a
/// tournament. [saved] picks one up again (the app closed mid-game).
class LoungeGame {
  const LoungeGame.boss(Boss this.boss, {this.saved}) : tier = null;
  const LoungeGame.tournament(TournamentTier this.tier, {this.saved}) : boss = null;

  final Boss? boss;
  final TournamentTier? tier;

  /// The game so far ([PokerController.snapshot]), to carry on from.
  final Map<String, Object?>? saved;

  /// For the stats.
  String get gameId => boss != null ? 'bosses' : 'tournament';

  /// The game in progress, as [Account.saveLoungeGame] keeps it.
  Map<String, Object?> save(Map<String, Object?> game, int stake) => {
    'kind': gameId,
    if (boss != null) 'boss': boss!.name,
    if (tier != null) 'tier': tier!.name,
    'stake': stake,
    'game': game,
  };

  /// A saved game ([save]), or null if it can't be read.
  static LoungeGame? fromSave(Map<String, Object?>? j) {
    if (j == null) return null;
    final game = (j['game'] as Map?)?.cast<String, Object?>();
    if (game == null) return null;
    if (Boss.byName('${j['boss']}') case final b?) return LoungeGame.boss(b, saved: game);
    final tier = TournamentTier.byName(j['tier'] as String?);
    return tier == null ? null : LoungeGame.tournament(tier, saved: game);
  }

  /// The stake a saved game was played for.
  static int savedStake(Map<String, Object?>? j) => j?['stake'] as int? ?? 0;

  /// "Lucky Lou" / "Regular tournament", for the Continue button.
  String get label => boss?.name ?? '${tier!.label} tournament';
}

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
  }) : party = null,
       lounge = null;

  /// With your party (and its bots), online: the referee deals.
  const PokerScreen.online({super.key, required PartyService this.party, this.pace = 1})
    : bots = 0,
      difficulty = Difficulty.normal,
      seed = null,
      resultTimeout = null,
      stake = null,
      lounge = null;

  /// A boss or a tournament from the Poker Lounge ([stake]: the buy-in or
  /// the boss's stake, already taken).
  PokerScreen.lounge({super.key, required LoungeGame this.lounge, this.stake, this.pace = 1, this.seed})
    : party = null,
      bots = lounge.boss != null ? 3 : tournamentSeats - 1,
      difficulty = lounge.boss?.tableDifficulty ?? lounge.tier!.difficulty,
      resultTimeout = null;

  final PartyService? party;

  /// The lounge game (bosses, tournaments).
  final LoungeGame? lounge;

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
      party.showing(this, 'holdem');
      party.addListener(_follow);
    }
    _saved = widget.lounge?.saved;
    _ticket =
        widget.stake ??
        StakeTicket(
          account: _account,
          gameId: widget.lounge?.gameId ?? 'holdem',
          // A game picked up again: its stake was taken when it began.
          stake: widget.lounge == null ? 0 : LoungeGame.savedStake(_account.loungeGame),
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
          // A new match: its stake (the referee takes it and pays out).
          _matchId = m['id'] as String?;
          _ticket = party.ticket(_account, m);
        }
        _c = online;
        online
          ..addListener(_settle)
          ..start();
        return online;
      }
    }
    if (widget.lounge case final lounge?) return _loungeTable(lounge);
    // A rival sits in (the one you've played least) and one bot carries a
    // bounty.
    final extras = widget.seed == null ? Random() : Random(widget.seed! + 7);
    final rival = Rival.pick(extras, (name) {
      final r = _account.rivalRecord(name);
      return r.wins + r.losses;
    });
    final record = _account.rivalRecord(rival.name);
    _bountyPaid = _rivalDone = false;
    final c = _c = PokerController(
      bots: widget.bots,
      difficulty: widget.difficulty,
      pace: widget.pace,
      resultTimeout: widget.resultTimeout,
      rng: widget.seed == null ? null : Random(widget.seed),
      you: _account.persona,
      rival: rival,
      rivalRecord: (theirs: record.losses, yours: record.wins),
      rivalMemory: _account.memoryOf(rival.name),
      bountySeat: widget.bots == 1 ? 1 : 2 + extras.nextInt(widget.bots - 1),
    );
    c
      ..addListener(_settle)
      ..start();
    return c;
  }

  /// Your tournament's over: win only for first place. Along the way:
  /// achievements, the bounty, the rival's record.
  void _settle() {
    if (widget.lounge != null) {
      _settleLounge();
    } else if (_c.phase == TablePhase.finished && !_ticket.settled) {
      _ticket.settle(_c.yourPlace == 1 ? Outcome.win : Outcome.loss);
    }
    if (widget.party != null) return;
    if (_c.bountyBy == 0 && !_bountyPaid) {
      _bountyPaid = true;
      final pay = _ticket.stake == 0 ? 0 : max(1, _ticket.stake ~/ 2);
      _account.bonus('holdem', pay);
      _toast('BOUNTY!', pay > 0 ? '+${_account.money(pay)}' : 'You knocked out the bounty bot');
    }
    final rival = _c.rival;
    if (rival != null && !_rivalDone && _c.phase == TablePhase.finished) {
      _rivalDone = true;
      _account.rivalResult(rival.name, won: _c.beatRival);
      _account.remember(rival.name, _c.reads.players[0]);
      if (_c.beatRival && _c.boss == null) _c.found.add(Achievement.rival);
    }
    while (_c.found.isNotEmpty) {
      final a = _c.found.removeAt(0);
      if (_account.earn(a)) _toast('Achievement!', a.title);
    }
  }

  var _bountyPaid = false, _rivalDone = false;

  /// Pop-ups waiting their turn, and the one showing.
  final _toasts = <({String title, String text})>[];
  ({String title, String text})? _showing;
  Timer? _toastTimer;

  void _toast(String title, String text) {
    _toasts.add((title: title, text: text));
    if (_showing == null) _nextToast();
  }

  void _nextToast() {
    _toastTimer?.cancel();
    if (!mounted) return;
    setState(() => _showing = _toasts.isEmpty ? null : _toasts.removeAt(0));
    if (_showing != null) {
      _toastTimer = Timer(Duration(milliseconds: (3000 * max(widget.pace, 0.3)).round()), _nextToast);
    }
  }

  void _playAgain() {
    setState(() {
      _c.dispose();
      _ticket = _ticket.again();
      _c = _newTable();
    });
  }

  /// A lounge game picked up again (used once, by the first table).
  Map<String, Object?>? _saved;

  /// The boss's table (the boss in seat 1, three bots) or your table in a
  /// tournament; saved after every hand.
  PokerController _loungeTable(LoungeGame lounge) {
    final saved = _saved;
    _saved = null;
    final rng = widget.seed == null ? null : Random(widget.seed);
    final PokerController c;
    if (lounge.boss case final b?) {
      final record = _account.rivalRecord(b.name);
      _rivalDone = false;
      c = _c = PokerController(
        bots: widget.bots,
        difficulty: widget.difficulty,
        pace: widget.pace,
        rng: rng,
        you: _account.persona,
        rival: b.rival,
        rivalRecord: (theirs: record.losses, yours: record.wins),
        boss: b,
        rivalMemory: _account.memoryOf(b.name),
        saved: saved,
      );
    } else {
      final r = rng ?? Random();
      final t = saved != null
          ? Tournament.fromJson(saved)
          : Tournament.fresh(
              you: _account.persona.name,
              yourLook: _account.persona.look.name,
              bots: _tournamentBots(r),
              rng: r,
            );
      c = _c = TournamentController.seat(
        t: t,
        tier: lounge.tier!,
        you: _account.persona,
        memoryOf: _account.memoryOf,
        pace: widget.pace,
        rng: r,
      );
    }
    void save() => _account.saveLoungeGame(lounge.save(c.snapshot(), _ticket.stake));
    c
      ..afterHand = save
      ..addListener(_settle)
      ..start();
    save();
    return c;
  }

  /// The tournament's 17 bots: the three rivals and fourteen others, each
  /// with a way of playing.
  static List<({String name, String look, String style})> _tournamentBots(Random rng) {
    final rivals = [for (final r in Rival.all) (name: r.name, look: r.look.name, style: r.style.name)];
    final others = Persona.bots(
      tournamentPlayers - 1,
      rng,
    ).where((p) => !rivals.any((r) => r.name == p.name));
    final styles = [...BotStyle.values]..shuffle(rng);
    return [
      ...rivals,
      for (final (k, p) in others.take(tournamentPlayers - 1 - rivals.length).indexed)
        (name: p.name, look: p.look.name, style: styles[k % styles.length].name),
    ];
  }

  /// A lounge game's over: the prize, the ladder or the tournament record,
  /// achievements, and what the boss (or rivals) remember of you.
  void _settleLounge() {
    if (_c.phase != TablePhase.finished || _ticket.settled) return;
    final lounge = widget.lounge!;
    _account.saveLoungeGame(null);
    if (lounge.boss case final b?) {
      final won = _c.beatRival;
      _ticket.settlePrize(won ? b.prize + (_c.yourPlace == 1 ? b.tableBonus : 0) : 0);
      if (won) {
        _account.bossBeaten(b.rung);
        _c.found.add(b.achievement);
        if (_account.bossesBeaten >= Boss.ladder.length) _c.found.add(Achievement.ladder);
      }
      return;
    }
    final c = _c as TournamentController;
    final tier = lounge.tier!;
    final place = c.yourPlace ?? c.tournament.left + 1;
    _ticket.settlePrize(Tournament.prize(tier.pool, place));
    _account.tourneyResult(tier.name, place);
    for (final r in c.rivalsMet) {
      _account.remember(r.name, r.reads);
    }
    if (place <= 3) _c.found.add(Achievement.tourneyCash);
    if (place == 1) _c.found.add(Achievement.tourneyWin);
    if (place == 1 && tier == TournamentTier.main) _c.found.add(Achievement.mainEvent);
  }

  /// Play again: the same boss, or another tournament of the same kind
  /// (not the Daily Freeroll: once a day).
  VoidCallback? get _again {
    final lounge = widget.lounge;
    if (lounge == null) return _playAgain;
    if (lounge.tier == TournamentTier.freeroll) return null;
    return () {
      setState(() {
        _c.dispose();
        _ticket = _ticket.again();
        _c = _newTable();
      });
    };
  }

  @override
  void dispose() {
    widget.party?.removeListener(_follow);
    widget.party?.hidden(this);
    _toastTimer?.cancel();
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
      // Leaving a lounge game for good: you're out.
      if (widget.lounge != null && _c.phase != TablePhase.finished) _account.saveLoungeGame(null);
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
                      onAgain: widget.party == null ? _again : _rematch(),
                      againLabel: _againLabel(),
                      leaveLabel: widget.lounge != null
                          ? 'Lounge'
                          : widget.party == null
                          ? 'Games'
                          : 'Back to party',
                      onLeave: widget.party == null ? () => Navigator.of(context).pop() : _leave,
                    ),
                  ),
                if (_showing case final t?)
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: Pop(
                          key: ValueKey(t),
                          child: Container(
                            key: const Key('toast'),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: Toon.box(Toon.yellow, radius: 14, shadow: 3),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  t.title,
                                  style: Toon.text(13, weight: FontWeight.w800, color: Toon.inkLight),
                                ),
                                Text(
                                  t.text,
                                  style: Toon.text(17, weight: FontWeight.w700, color: Toon.inkLight),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
    if (widget.lounge?.tier == TournamentTier.freeroll) return 'Tomorrow';
    if (widget.lounge?.boss != null) return 'Rematch';
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
                    Text(c.title, maxLines: 1, style: Toon.text(18, weight: FontWeight.w700)),
                    StakeBadge(ticket),
                  ],
                ),
                Text(
                  '${narrow ? 'Hand $hand · ' : ''}'
                  '${c is TournamentController ? '${(c as TournamentController).tournament.left} left · ' : ''}'
                  'Blinds ${chips(sb)} / ${chips(bb)}'
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
    final players = c.fieldSize;
    final boss = c.boss;
    final tour = c is TournamentController ? c as TournamentController : null;
    final title = boss != null
        ? (c.beatRival ? 'You beat ${boss.name}!' : '${boss.name} wins')
        : tour != null && won
        ? 'Champion!'
        : won
        ? 'You won!'
        : 'Out in ${_ordinal(place)}';
    final subtitle = boss != null
        ? 'You finished ${_ordinal(place)} of $players.'
              '${c.beatRival && boss.last ? ' The whole ladder is yours!' : ''}'
        : tour != null
        ? (won
              ? 'You beat all $players players.'
              : place <= Tournament.paid.length
              ? 'In the money: ${_ordinal(place)} of $players.'
              : 'Of $players players. The top ${Tournament.paid.length} are paid.')
        : won
        ? 'You took every chip at a table of $players.'
        : 'Of $players players.';
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
                      title,
                      key: const Key('over title'),
                      textAlign: TextAlign.center,
                      style: Toon.text(30, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: Toon.text(16, weight: FontWeight.w500),
                    ),
                    Text(
                      '${c.game.handsPlayed} hand${c.game.handsPlayed == 1 ? '' : 's'}',
                      style: Toon.text(14, weight: FontWeight.w500, color: Toon.muted),
                    ),
                    GameSummary(
                      c: c,
                      footer: c is OnlinePokerController
                          ? _Lineup(c: c as OnlinePokerController)
                          : tour != null
                          ? _Podium(c: tour)
                          : null,
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

/// A tournament's prize places (and yours, if you were out before).
class _Podium extends StatelessWidget {
  const _Podium({required this.c});

  final TournamentController c;

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.maybeRead(context) ?? Account();
    final t = c.tournament;
    final order = t.standings;
    final me = order.indexWhere((e) => e.you);
    return Container(
      key: const Key('podium'),
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(8),
      decoration: Toon.box(Toon.card, radius: 12, shadow: 2),
      child: Column(
        children: [
          Text(
            t.over ? 'Prize places' : 'Still playing: ${t.left} left',
            style: Toon.text(14, weight: FontWeight.w700),
          ),
          for (var k = 0; k < Tournament.paid.length && k < order.length; k++)
            Text(
              '${_ordinal(k + 1)}  ${order[k].you ? 'You' : order[k].name}'
              '${t.over ? '  ${account.money(Tournament.prize(c.tier.pool, k + 1))}' : ''}',
              style: Toon.text(13, weight: order[k].you ? FontWeight.w800 : FontWeight.w500),
            ),
          if (me >= Tournament.paid.length) Text('${_ordinal(me + 1)}  You', style: Toon.text(13)),
        ],
      ),
    );
  }
}
