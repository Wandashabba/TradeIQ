import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/risks_repository.dart';

/// S8 — Opportunities & Risks capture: a dynamic list of flagged risks
/// (flag type, severity, note). On save the entries are queued for sync
/// (POST /risks) and the backend auto-creates follow-up tasks.
class S8RisksScreen extends ConsumerStatefulWidget {
  const S8RisksScreen({super.key, required this.visitDraftId});

  final String visitDraftId;

  @override
  ConsumerState<S8RisksScreen> createState() => _S8State();
}

class _S8State extends ConsumerState<S8RisksScreen> {
  static const _severities = ['critical', 'high', 'normal'];

  final _flagTypes = <TextEditingController>[];
  final _notes = <TextEditingController>[];
  final _severitiesSelected = <String>[];
  bool _saved = false;

  @override
  void dispose() {
    for (final c in [..._flagTypes, ..._notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _addRisk() {
    setState(() {
      _flagTypes.add(TextEditingController());
      _notes.add(TextEditingController());
      _severitiesSelected.add('normal');
    });
  }

  Future<void> _save() async {
    // Rows without a flag type are skipped.
    final entries = <RiskEntry>[
      for (var i = 0; i < _flagTypes.length; i++)
        if (_flagTypes[i].text.trim().isNotEmpty)
          RiskEntry(
            flagType: _flagTypes[i].text.trim(),
            severity: _severitiesSelected[i],
            note: _notes[i].text.trim(),
          ),
    ];

    await ref.read(risksRepositoryProvider).saveRisks(
          visitDraftId: widget.visitDraftId,
          entries: entries,
        );
    if (mounted) setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('S8 Opportunities & Risks'),
        const SizedBox(height: 8),
        for (var i = 0; i < _flagTypes.length; i++)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Risk ${i + 1}', style: Theme.of(context).textTheme.titleMedium),
                  TextField(
                    key: ValueKey('risk-type-$i'),
                    controller: _flagTypes[i],
                    decoration: const InputDecoration(labelText: 'Flag type', isDense: true),
                  ),
                  DropdownButtonFormField<String>(
                    key: ValueKey('risk-severity-$i'),
                    initialValue: _severitiesSelected[i],
                    decoration: const InputDecoration(labelText: 'Severity', isDense: true),
                    items: [
                      for (final severity in _severities)
                        DropdownMenuItem(value: severity, child: Text(severity)),
                    ],
                    onChanged: (v) => setState(() => _severitiesSelected[i] = v ?? 'normal'),
                  ),
                  TextField(
                    key: ValueKey('risk-note-$i'),
                    controller: _notes[i],
                    decoration: const InputDecoration(labelText: 'Note', isDense: true),
                  ),
                ],
              ),
            ),
          ),
        TextButton(
          key: const ValueKey('add-risk'),
          onPressed: _addRisk,
          child: const Text('Flag a risk'),
        ),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _save, child: const Text('Save risks')),
        if (_saved)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Risks saved — queued for sync; follow-up tasks will be auto-created'),
          ),
      ],
    );
  }
}
