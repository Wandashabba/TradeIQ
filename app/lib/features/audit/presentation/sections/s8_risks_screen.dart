import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/lumen_glass.dart';
import '../../../../core/theme/lumen_palette.dart';
import '../../../../core/theme/tiq_colors.dart';
import '../../../../core/widgets/agent_kit.dart';
import '../../../../core/widgets/console.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/lumen_kit.dart';
import '../../../../l10n/l10n.dart';
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
    final l10n = context.l10n;
    final severityOptions = <({String value, String label})>[
      (value: 'critical', label: l10n.s8SeverityCritical),
      (value: 'high', label: l10n.s8SeverityHigh),
      (value: 'normal', label: l10n.s8SeverityNormal),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _flagTypes.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RiskCard(
              index: i,
              severity: _severitiesSelected[i],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AgentField(
                    label: l10n.s8FlagTypeLabel,
                    child: TextField(
                      key: ValueKey('risk-type-$i'),
                      controller: _flagTypes[i],
                      decoration: InputDecoration(
                        hintText: l10n.s8FlagTypeHint,
                      ),
                    ),
                  ),
                  Text(
                    l10n.s8SeverityLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.ink2,
                    ),
                  ),
                  const SizedBox(height: 7),
                  ChoiceRow<String>(
                    options: severityOptions,
                    selected: _severitiesSelected[i],
                    onChanged: (v) =>
                        setState(() => _severitiesSelected[i] = v),
                  ),
                  const SizedBox(height: 16),
                  AgentField(
                    label: l10n.s8NoteLabel,
                    child: TextField(
                      key: ValueKey('risk-note-$i'),
                      controller: _notes[i],
                      decoration: InputDecoration(
                        hintText: l10n.s8NoteHint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        AgentButton(
          key: const ValueKey('add-risk'),
          label: l10n.s8AddButton,
          icon: Icons.add,
          secondary: true,
          onPressed: _addRisk,
        ),
        const SizedBox(height: 12),
        AgentButton(label: l10n.s8SaveButton, onPressed: _save),
        if (_saved)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              l10n.s8Saved,
              style: TextStyle(color: colors.ink2),
            ),
          ),
      ],
    );
  }
}

/// The glass status of a severity: critical is a breach, high is at risk, and
/// normal carries no status at all.
LumenStatus? _statusOf(String severity) => switch (severity) {
  'critical' => LumenStatus.crit,
  'high' => LumenStatus.warn,
  _ => null,
};

/// One flagged risk. Glass: a no-blur tile (they repeat) headed by its number;
/// a critical or high risk turns the rim to its status and adds a note that
/// spells the severity out, so the finding never rides on colour alone.
class _RiskCard extends StatelessWidget {
  const _RiskCard({
    required this.index,
    required this.severity,
    required this.child,
  });

  final int index;
  final String severity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = context.l10n.s8RiskTitle(index + 1);
    if (!colors.glass) return PanelCard(title: title, child: child);
    final status = _statusOf(severity);
    return GlassPane(
      kind: GlassKind.tile,
      blur: false,
      radius: LumenGlass.radiusCard,
      rimColor: status?.swatchOf(colors).rim,
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusTile(
                status: status ?? LumenStatus.none,
                glyph: '${index + 1}',
                size: 26,
                radius: 8,
                mono: true,
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.lumen.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
          if (status != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: _SeverityNote(status: status, severity: severity),
            ),
        ],
      ),
    );
  }
}

/// The severity in words on an OPAQUE status wash, so the words clear AA on
/// their own rather than on whatever the glass lets through.
class _SeverityNote extends StatelessWidget {
  const _SeverityNote({required this.status, required this.severity});

  final LumenStatus status;

  /// `critical` or `high` — the note is never shown for a normal risk.
  final String severity;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sw = status.swatchOf(colors);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Color.alphaBlend(sw.tint, colors.surface1),
        borderRadius: BorderRadius.circular(LumenGlass.radiusIconTile),
        border: Border.all(color: sw.rim),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.warning_amber_outlined, size: 15, color: sw.ink),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.s8SeverityNote(severity),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: sw.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
