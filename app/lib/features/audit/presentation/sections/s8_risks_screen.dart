import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tiq_colors.dart';
import '../../../../core/widgets/agent_kit.dart';
import '../../../../core/widgets/console.dart';
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
  static const _severityOptions = <({String value, String label})>[
    (value: 'critical', label: 'Critical'),
    (value: 'high', label: 'High'),
    (value: 'normal', label: 'Normal'),
  ];

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

    await ref
        .read(risksRepositoryProvider)
        .saveRisks(visitDraftId: widget.visitDraftId, entries: entries);
    if (mounted) setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _flagTypes.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PanelCard(
              title: 'Risk ${i + 1}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AgentField(
                    label: 'Flag type',
                    child: TextField(
                      key: ValueKey('risk-type-$i'),
                      controller: _flagTypes[i],
                      decoration: const InputDecoration(
                        hintText: 'What was flagged',
                      ),
                    ),
                  ),
                  Text(
                    'Severity',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.ink2,
                    ),
                  ),
                  const SizedBox(height: 7),
                  ChoiceRow<String>(
                    options: _severityOptions,
                    selected: _severitiesSelected[i],
                    onChanged: (v) =>
                        setState(() => _severitiesSelected[i] = v),
                  ),
                  const SizedBox(height: 16),
                  AgentField(
                    label: 'Note',
                    child: TextField(
                      key: ValueKey('risk-note-$i'),
                      controller: _notes[i],
                      decoration: const InputDecoration(
                        hintText: 'Optional detail',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        AgentButton(
          key: const ValueKey('add-risk'),
          label: 'Flag a risk',
          icon: Icons.add,
          secondary: true,
          onPressed: _addRisk,
        ),
        const SizedBox(height: 12),
        AgentButton(label: 'Save risks', onPressed: _save),
        if (_saved)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Risks saved — queued for sync; follow-up tasks will be auto-created',
              style: TextStyle(color: colors.ink2),
            ),
          ),
      ],
    );
  }
}
