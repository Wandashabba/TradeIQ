import 'package:flutter/widgets.dart';

import '../../../design/torch_scope.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import '../button/buttons.dart';
import '../input/choice_row.dart';
import '../input/text_field.dart';
import 'torch_sheet.dart';

/// One reason, **with its consequence**.
@immutable
class SkipReason {
  const SkipReason({
    required this.id,
    required this.label,
    required this.consequence,
  });

  final String id;

  /// The reason in the agent's words: "The store would not let me".
  final String label;

  /// **What it does downstream**, at `meta` beneath the reason: "The manager is
  /// told the store refused". This is the whole argument for the component. A
  /// reason without its consequence is a dropdown; a reason with one is a
  /// decision, and an agent who knows a repair task will be raised picks
  /// differently from one who does not.
  final String consequence;

  /// The three the ruling names, plus the escape hatch every reason list
  /// needs. A screen may pass its own — these are the defaults, and they exist
  /// so that a skip is **always** recordable even when nothing is configured.
  static const SkipReason storeRefused = SkipReason(
    id: 'store-refused',
    label: 'The store would not let me',
    consequence: 'The manager is told the store refused',
  );

  static const SkipReason notStocked = SkipReason(
    id: 'not-stocked',
    label: 'They do not stock this',
    consequence: 'These lines are marked not-stocked for this outlet',
  );

  static const SkipReason equipmentUnavailable = SkipReason(
    id: 'equipment-unavailable',
    label: 'The equipment is broken',
    consequence: 'A repair task is raised',
  );

  static const SkipReason somethingElse = SkipReason(
    id: 'something-else',
    label: 'Something else',
    consequence: 'You write what happened',
  );

  static const List<SkipReason> standard = <SkipReason>[
    storeRefused,
    notStocked,
    equipmentUnavailable,
    somethingElse,
  ];

  /// The check-in variant's reasons. Different question, different answers —
  /// "I cannot get closer" is not "the store would not let me".
  static const List<SkipReason> checkIn = <SkipReason>[
    SkipReason(
      id: 'store-closed',
      label: 'The store is closed',
      consequence: 'The stop is recorded as closed, not as skipped work',
    ),
    SkipReason(
      id: 'cannot-reach',
      label: 'I cannot get to the store',
      consequence: 'The stop stays on your route for tomorrow',
    ),
    SkipReason(
      id: 'visit-refused',
      label: 'The store refused the visit',
      consequence: 'The manager is told the store refused',
    ),
    somethingElse,
  ];
}

/// What the picker popped with.
@immutable
class SkipReasonResult {
  const SkipReasonResult({required this.reason, this.note});

  final SkipReason reason;

  /// Required, and enforced, when [SkipReason.somethingElse] is chosen: "other"
  /// with no text is the exact hole this component exists to close.
  final String? note;
}

/// WHY A SECTION OR A STOP COULD NOT BE DONE — #395.
///
/// A skip becomes data instead of a hole, and the answer carries a consequence
/// the agent can see before they choose it.
///
/// ```dart
/// final result = await showTorchSheet<SkipReasonResult>(
///   context,
///   builder: (context) => SkipReasonPicker(
///     title: 'Why not?',
///     reasons: SkipReason.standard,
///     thresholdLine: 'That will be three sections you could not confirm. '
///         'Your manager sees that as a store you could not work.',
///   ),
/// );
/// ```
///
/// ## The threshold line is not a scold
///
/// A third can't-confirm in one visit renders a line saying what the manager
/// will see. It does **not** block, and it does not moralise. The agent simply
/// knows the shape of the record they are about to produce — which is the
/// thing they would otherwise find out a week later, from someone else.
///
/// ## Dismissal is always safe
///
/// Nothing is recorded and the section stays as it was. A picker that
/// half-committed on dismissal would be a picker people learn to be afraid of.
class SkipReasonPicker extends StatefulWidget {
  const SkipReasonPicker({
    super.key,
    required this.title,
    this.subtitle,
    this.reasons = SkipReason.standard,
    this.initial,
    this.initialNote,
    this.thresholdLine,
    this.noteLabel = 'What happened?',
    this.noteMaximum = 200,
    this.saveLabel = 'Save reason',
    this.changeLabel = 'Change reason',
    this.cancelLabel = 'Cancel',
    this.chooseFirstNote = 'Choose a reason first',
    this.sayWhatHappenedNote = 'Say what happened',
    this.usingStandardReasonsNote = 'Using the standard reasons',
    this.reasonsWereConfigured = true,
    this.busy = false,
    this.failure,
  });

  final String title;
  final String? subtitle;

  final List<SkipReason> reasons;

  /// Already skipped: the previous reason renders selected and the primary
  /// becomes [changeLabel].
  final SkipReason? initial;
  final String? initialNote;

  /// Rendered above the actions when this skip crosses a threshold worth
  /// knowing about.
  final String? thresholdLine;

  final String noteLabel;
  final int noteMaximum;

  final String saveLabel;
  final String changeLabel;
  final String cancelLabel;
  final String chooseFirstNote;
  final String sayWhatHappenedNote;
  final String usingStandardReasonsNote;

  /// False where the outlet has no configured reasons: the standard four
  /// render anyway — **a skip must always be recordable** — with a meta line
  /// saying so.
  final bool reasonsWereConfigured;

  final bool busy;

  /// A bad-outlined line above the actions. The sheet **stays open** on a
  /// failure; the chosen reason is not thrown away.
  final Widget? failure;

  @override
  State<SkipReasonPicker> createState() => _SkipReasonPickerState();
}

class _SkipReasonPickerState extends State<SkipReasonPicker> {
  late String? _chosen = widget.initial?.id;
  late final TextEditingController _note = TextEditingController(
    text: widget.initialNote ?? '',
  );
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    _note.addListener(_onNote);
  }

  @override
  void dispose() {
    _note.removeListener(_onNote);
    _note.dispose();
    super.dispose();
  }

  void _onNote() {
    if (mounted) setState(() {});
  }

  bool get _needsNote => _chosen == SkipReason.somethingElse.id;
  bool get _noteEmpty => _note.text.trim().isEmpty;

  String? get _blockedReason {
    if (_chosen == null) return widget.chooseFirstNote;
    if (_needsNote && _noteEmpty) return widget.sayWhatHappenedNote;
    return null;
  }

  void _save() {
    final chosen = widget.reasons.firstWhere((r) => r.id == _chosen);
    Navigator.of(context).pop<SkipReasonResult>(
      SkipReasonResult(
        reason: chosen,
        note: _needsNote ? _note.text.trim() : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final blocked = _blockedReason;
    // In `build` and not in the constructor because `List.length` is not a
    // constant expression in Dart, and `SkipReason.standard` is a const list —
    // a constructor assert on it would make the default configuration
    // uncompilable.
    assert(
      widget.reasons.length >= 2 && widget.reasons.length <= 4,
      'Two to four reasons. A single reason is not a question, and a fifth '
      'belongs behind "Something else".',
    );

    return TorchSheet(
      title: widget.title,
      subtitle: widget.subtitle,
      claims: <TorchClaim>[TorchPrimaryButton.claim('skip-save')],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ChoiceRow<String>(
            label: widget.title,
            value: _chosen,
            onChanged: widget.busy
                ? null
                : (id) => setState(() => _chosen = id),
            options: <ChoiceOption<String>>[
              for (final reason in widget.reasons)
                ChoiceOption<String>(
                  value: reason.id,
                  label: reason.label,
                  // The consequence rides with the reason, into the layout AND
                  // into the semantics node.
                  consequence: reason.consequence,
                ),
            ],
          ),
          if (!widget.reasonsWereConfigured) ...<Widget>[
            const SizedBox(height: TiqSpace.s2),
            Text(
              widget.usingStandardReasonsNote,
              style: skin.text.meta.style(color: p.ink3),
            ),
          ],
          if (_needsNote) ...<Widget>[
            SizedBox(height: skin.space.intraBlock),
            TorchTextField(
              label: widget.noteLabel,
              controller: _note,
              minLines: 3,
              maximumLines: 8,
              maximumLength: widget.noteMaximum,
              // No error until a save is attempted: a field that is red before
              // anybody has typed in it is a field accusing someone of nothing.
              error: _attempted && _noteEmpty
                  ? widget.sayWhatHappenedNote
                  : null,
            ),
          ],
          if (widget.thresholdLine != null) ...<Widget>[
            SizedBox(height: skin.space.intraBlock),
            Semantics(
              liveRegion: true,
              child: Text(
                widget.thresholdLine!,
                style: skin.text.body.style(color: p.ink2),
              ),
            ),
          ],
          if (widget.failure != null) ...<Widget>[
            SizedBox(height: skin.space.intraBlock),
            widget.failure!,
          ],
          SizedBox(height: skin.space.blockGap),
          TorchPrimaryButton(
            label: widget.initial == null
                ? widget.saveLabel
                : widget.changeLabel,
            claimId: 'skip-save',
            busy: widget.busy,
            blockedReason: blocked,
            onPressed: blocked != null || widget.busy
                ? null
                : () {
                    setState(() => _attempted = true);
                    _save();
                  },
          ),
          const SizedBox(height: TiqSpace.s3),
          TorchSecondaryButton(
            label: widget.cancelLabel,
            // Dismissal is always safe: nothing is recorded.
            onPressed: widget.busy ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
