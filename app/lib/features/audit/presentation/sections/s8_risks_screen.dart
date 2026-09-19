import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/torchlight/tiq_skin.dart';
import '../../../../core/widgets/torchlight/input.dart';
import '../../../../core/widgets/torchlight/marks.dart';
import '../../../../l10n/l10n.dart';
import '../../data/risks_repository.dart';
import '../../data/visit_progress.dart';
import 'section_form.dart';

/// S8 — RISKS. A dynamic list of flagged risks: what was flagged, how serious
/// it is, and a note. On save the entries are queued for sync (`POST /risks`)
/// and the backend auto-creates follow-up tasks.
///
/// Severity is a **choice row plus a status chip**: crimson at two commitment
/// levels, a silhouette and the word, and a sentence saying that saving raises
/// a task. It is never the hue alone, and the entry card never turns red.
///
/// **Amber:** one object, the inline Save, once something has changed.
class S8RisksScreen extends ConsumerStatefulWidget {
  const S8RisksScreen({super.key, required this.visitDraftId});

  final String visitDraftId;

  @override
  ConsumerState<S8RisksScreen> createState() => _S8State();
}

class _S8Entry {
  _S8Entry()
    : flagType = TextEditingController(),
      note = TextEditingController();

  final TextEditingController flagType;
  final TextEditingController note;
  String severity = 'normal';

  void dispose() {
    flagType.dispose();
    note.dispose();
  }
}

class _S8State extends ConsumerState<S8RisksScreen> {
  final _entries = <_S8Entry>[];
  bool _dirty = false;

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  void _touch(VoidCallback change) => setState(() {
    change();
    _dirty = true;
  });

  Future<void> _save() async {
    // Rows without a flag type are skipped.
    final entries = <RiskEntry>[
      for (final entry in _entries)
        if (entry.flagType.text.trim().isNotEmpty)
          RiskEntry(
            flagType: entry.flagType.text.trim(),
            severity: entry.severity,
            note: entry.note.text.trim(),
          ),
    ];

    await ref
        .read(risksRepositoryProvider)
        .saveRisks(visitDraftId: widget.visitDraftId, entries: entries);
    if (mounted) setState(() => _dirty = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final severityOptions = <ChoiceOption<String>>[
      ChoiceOption<String>(value: 'critical', label: l10n.s8SeverityCritical),
      ChoiceOption<String>(value: 'high', label: l10n.s8SeverityHigh),
      ChoiceOption<String>(value: 'normal', label: l10n.s8SeverityNormal),
    ];

    return SectionForm(
      title: l10n.visitSectionRisks,
      phase: 'risks',
      dirty: _dirty,
      onSave: _save,
      savedLine: l10n.s8Saved,
      skip: SectionSkipTarget(widget.visitDraftId, AuditSection.risks),
      children: <Widget>[
        SectionEntries(
          kind: 'risk',
          summaries: <String?>[
            for (final entry in _entries) entry.flagType.text,
          ],
          addLabel: l10n.s8AddButton,
          emptyLine: l10n.s8NoRisks,
          onAdd: () => _touch(() => _entries.add(_S8Entry())),
          onRemove: (i) => _touch(() => _entries.removeAt(i).dispose()),
          entries: <Widget>[
            for (final (i, entry) in _entries.indexed)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TorchTextField(
                    key: ValueKey<String>('risk-type-$i'),
                    label: l10n.s8FlagTypeLabel,
                    controller: entry.flagType,
                    hint: l10n.s8FlagTypeHint,
                    onChanged: (_) => _touch(() {}),
                  ),
                  const SizedBox(height: TiqSpace.s4),
                  ChoiceRow<String>(
                    key: ValueKey<String>('risk-severity-$i'),
                    label: l10n.s8SeverityLabel,
                    options: severityOptions,
                    value: entry.severity,
                    notAnsweredLine: l10n.sectionNotAnsweredYet,
                    onChanged: (v) => _touch(() => entry.severity = v),
                  ),
                  if (entry.severity != 'normal') ...<Widget>[
                    const SizedBox(height: TiqSpace.s3),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: StatusChip(
                        key: ValueKey<String>('risk-severity-note-$i'),
                        level: entry.severity == 'critical'
                            ? StatusLevel.critical
                            : StatusLevel.watch,
                        label: l10n.s8SeverityNote(entry.severity),
                      ),
                    ),
                  ],
                  const SizedBox(height: TiqSpace.s4),
                  TorchTextField(
                    key: ValueKey<String>('risk-note-$i'),
                    label: l10n.s8NoteLabel,
                    controller: entry.note,
                    hint: l10n.s8NoteHint,
                    minLines: 3,
                    maximumLines: 3,
                    maximumLength: 200,
                    onChanged: (_) => _touch(() {}),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
