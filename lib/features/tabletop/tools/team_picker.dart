import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/account/account.dart';
import '../../../core/session/play_setup.dart';
import '../../../core/sound/sound.dart';
import '../../../core/theme/toon.dart';
import '../scorer/presets.dart';
import 'tool_page.dart';

/// Fair teams: the names (your party's to start with, kept for next time),
/// how many teams, and a shuffle that deals everyone out, as even as the
/// numbers allow.
class TeamPicker extends StatefulWidget {
  const TeamPicker({super.key, this.seed});

  final int? seed;

  @override
  State<TeamPicker> createState() => _TeamPickerState();
}

class _TeamPickerState extends State<TeamPicker> {
  late final Random _rng = Random(widget.seed);
  late final Account _account = AccountScope.read(context);
  late final List<String> _names = _load();
  var _teams = 2;
  List<List<String>>? _made;
  var _shuffles = 0;

  List<String> _load() {
    final saved = _account.toolState('teams')?['names'];
    if (saved is List && saved.length >= 2) return [for (final n in saved) '$n'];
    final party = context.dependOnInheritedWidgetOfExactType<PlaySetupScope>()?.notifier?.party;
    final members = party?.members.map((m) => m.persona.name).toList();
    return startingNames(context, party: members, me: _account.name);
  }

  void _save() => _account.saveToolState('teams', {'names': _names});

  void _make() {
    final shuffled = [..._names]..shuffle(_rng);
    final teams = List.generate(_teams, (_) => <String>[]);
    for (final (i, n) in shuffled.indexed) {
      teams[i % _teams].add(n);
    }
    setState(() {
      _made = teams;
      _shuffles++;
    });
    Sound.play(Sfx.shuffle);
    Sound.later(Sfx.place, 400);
  }

  Future<void> _add() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Toon.paper,
        title: const Text('Add a name'),
        content: TextField(
          key: const Key('team name'),
          controller: c,
          autofocus: true,
          maxLength: 20,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            key: const Key('team name ok'),
            onPressed: () => Navigator.of(context).pop(c.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      setState(() => _names.add(name));
      _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final made = _made;
    return ToolPage(
      title: 'Team picker',
      subtitle: 'Fair teams, picked at random',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        children: [
          Row(
            children: [
              Text('Teams', style: Toon.text(17, weight: FontWeight.w700)),
              const Spacer(),
              ToonButton(
                color: Toon.card,
                padding: const EdgeInsets.all(8),
                onPressed: _teams > 2 ? () => setState(() => _teams--) : null,
                child: const Icon(Icons.remove_rounded, size: 18),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '$_teams',
                  textAlign: TextAlign.center,
                  style: Toon.text(22, weight: FontWeight.w700),
                ),
              ),
              ToonButton(
                key: const Key('more teams'),
                color: Toon.card,
                padding: const EdgeInsets.all(8),
                onPressed: _teams < min(6, _names.length) ? () => setState(() => _teams++) : null,
                child: const Icon(Icons.add_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (i, n) in _names.indexed)
                InputChip(
                  label: Text(n, style: Toon.text(14, weight: FontWeight.w600)),
                  onDeleted: _names.length > 2
                      ? () {
                          setState(() => _names.removeAt(i));
                          _save();
                        }
                      : null,
                ),
              ActionChip(
                key: const Key('add name'),
                avatar: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
                onPressed: _add,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ToonButton(
            key: const Key('make teams'),
            color: Toon.green,
            padding: const EdgeInsets.symmetric(vertical: 14),
            onPressed: _names.length >= _teams ? _make : null,
            child: Text(made == null ? 'Make teams' : 'Shuffle again'),
          ),
          const SizedBox(height: 14),
          if (made != null)
            for (final (t, team) in made.indexed)
              _TeamCard(key: ValueKey('team $t $_shuffles'), index: t, names: team),
        ],
      ),
    );
  }
}

/// One team: its colour, its name, its people dropping in one by one.
class _TeamCard extends StatelessWidget {
  const _TeamCard({super.key, required this.index, required this.names});

  final int index;
  final List<String> names;

  static const _names = ['Red', 'Blue', 'Green', 'Gold', 'Purple', 'Pink'];

  @override
  Widget build(BuildContext context) {
    final color = scoreColor(index);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + index * 120),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, (1 - t) * 40),
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: Toon.box(color, radius: 16, shadow: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Team ${_names[index % _names.length]}',
              style: Toon.text(18, weight: FontWeight.w700, color: Toon.on(color)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (i, n) in names.indexed)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 300 + index * 120 + i * 160),
                    curve: Curves.elasticOut,
                    builder: (context, t, child) => Transform.scale(scale: t.clamp(0.0, 1.3), child: child),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: Toon.box(Toon.cardFace, radius: 12, shadow: 1),
                      child: Text(
                        n,
                        style: Toon.text(15, weight: FontWeight.w700, color: Toon.inkLight),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
