import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tiq_number.dart' show TiqNumber;
import '../../../../core/widgets/torchlight/input.dart';
import '../../../../l10n/l10n.dart';
import '../../data/capability_repository.dart';
import 'section_form.dart';

/// S7 — TEAM CAPABILITY. Confirmed staff headcount, rep training status, and
/// the quiz score. On save the capture is queued for sync (`POST /capability`).
///
/// **Amber:** one object, the inline Save, once something has changed.
class S7CapabilityScreen extends ConsumerStatefulWidget {
  const S7CapabilityScreen({super.key, required this.visitDraftId});

  final String visitDraftId;

  @override
  ConsumerState<S7CapabilityScreen> createState() => _S7State();
}

class _S7State extends ConsumerState<S7CapabilityScreen> {
  static const _trainingKeys = <String>[
    'productKnowledge',
    'merchandising',
    'posSystems',
  ];

  final _training = <String, bool>{for (final key in _trainingKeys) key: false};
  final _headcount = TextEditingController();
  final _quiz = TextEditingController();
  bool _dirty = false;

  @override
  void dispose() {
    _headcount.dispose();
    _quiz.dispose();
    super.dispose();
  }

  void _touch(VoidCallback change) => setState(() {
    change();
    _dirty = true;
  });

  Future<void> _save() async {
    final numbers = TiqNumber.of(context);
    await ref
        .read(capabilityRepositoryProvider)
        .saveCapability(
          visitDraftId: widget.visitDraftId,
          capture: CapabilityCapture(
            staffHeadcountConfirmed:
                numbers.parse(_headcount.text)?.toInt() ?? 0,
            repTrainingStatus: Map<String, bool>.from(_training),
            quizScore: numbers.parse(_quiz.text)?.toInt() ?? 0,
          ),
        );
    if (mounted) setState(() => _dirty = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final trainingOptions = <String, String>{
      'productKnowledge': l10n.s7TrainingProductKnowledge,
      'merchandising': l10n.s7TrainingMerchandising,
      'posSystems': l10n.s7TrainingPosSystems,
    };

    return SectionForm(
      title: l10n.visitSectionCapability,
      phase: 'capability',
      dirty: _dirty,
      onSave: _save,
      savedLine: l10n.s7Saved,
      children: <Widget>[
        SectionFieldGroup(
          children: <Widget>[
            TorchNumericField(
              key: const ValueKey<String>('headcount'),
              label: l10n.s7HeadcountLabel,
              controller: _headcount,
              help: l10n.s7HeadcountHint,
              minimum: 0,
              onChanged: (_) => _touch(() {}),
            ),
          ],
        ),
        SectionFieldGroup(
          title: l10n.s7TrainingLabel,
          children: <Widget>[
            TorchCheckboxGroup(
              label: l10n.s7TrainingLabel,
              children: <Widget>[
                for (final entry in trainingOptions.entries)
                  TorchCheckbox(
                    key: ValueKey<String>('training-${entry.key}'),
                    label: entry.value,
                    value: _training[entry.key] ?? false,
                    onChanged: (v) => _touch(() => _training[entry.key] = v),
                  ),
              ],
            ),
          ],
        ),
        SectionFieldGroup(
          children: <Widget>[
            TorchNumericField(
              key: const ValueKey<String>('quiz'),
              label: l10n.s7QuizLabel,
              controller: _quiz,
              minimum: 0,
              maximum: 100,
              onChanged: (_) => _touch(() {}),
            ),
          ],
        ),
      ],
    );
  }
}
