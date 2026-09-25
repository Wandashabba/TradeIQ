import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';
import '../button/buttons.dart';
import 'choice_row.dart';
import 'text_field.dart';

/// One ruling a reviewer may reach.
@immutable
class VerdictOption<T> {
  const VerdictOption({
    required this.value,
    required this.label,
    required this.consequence,
    this.requiresNote = false,
    this.noteIsRequiredBecause,
  }) : assert(
         !requiresNote || noteIsRequiredBecause != null,
         'VerdictOption: a ruling that demands a note has to say why, or the '
         'reviewer reads the block as a bug. Pass noteIsRequiredBecause — '
         '"Say what evidence is missing, so somebody can go and get it".',
       );

  final T value;

  /// The ruling, in the reviewer's words. Never the wire value.
  final String label;

  /// **What recording it does.** A verdict without its consequence is a
  /// dropdown; a verdict with one is a decision. The same argument the
  /// skip-reason picker is built on, and it matters more here — one of these
  /// options says a person faked their work.
  final String consequence;

  /// The ruling cannot be recorded without free text.
  final bool requiresNote;

  /// Why, in words, shown where the note is blocking the commit.
  final String? noteIsRequiredBecause;
}

/// RECORDING A RULING ON SOMEBODY ELSE'S WORK — the canonical verdict control.
///
/// Three stacked rows and a commit. It is the fraud queue's control and it is
/// deliberately not a segmented row of chips: one of these options accuses a
/// person of faking their work, a mis-tap is not recoverable (a verdict is
/// INSERT-ONLY and the second ruling on one visit loses at the database), and
/// three 44dp targets side by side on a 360dp phone is a mis-tap waiting to
/// happen. [ChoiceRow.forceColumn] is what says so.
///
/// ```dart
/// VerdictControl<FraudVerdictKind>(
///   label: 'Your ruling',
///   options: <VerdictOption<FraudVerdictKind>>[…],
///   commitLabel: 'Record this ruling',
///   claimId: 'record-verdict',
///   onCommit: (kind, note) => repository.recordVerdict(…),
/// )
/// ```
///
/// ## Three rules live here, not in the screen
///
/// 1. **Nothing chosen is a state**, and it says so in words. A control that
///    pre-selected "cleared" would record a decision nobody made every time a
///    reviewer opened the sheet and closed it.
/// 2. **A ruling that needs a note cannot be committed without one.** "Needs
///    evidence" with no text is the hole this component exists to close:
///    a queue full of "inconclusive · null" is a queue that was processed
///    rather than reviewed. The primary goes to its disabled form and the
///    `blockedReason` above it says what is missing — never a silent button.
/// 3. **The commit is the only lit object the control can produce**, and it
///    asks `TorchScope` for that light like every other primary. The rows are
///    `lifted` + a 1px ink-1 border + a mark + weight 700, and never amber:
///    a selected verdict is a selection, and selection has one vocabulary.
class VerdictControl<T> extends StatefulWidget {
  const VerdictControl({
    super.key,
    required this.label,
    required this.options,
    required this.commitLabel,
    required this.claimId,
    required this.onCommit,
    this.noteLabel = 'Note',
    this.noteHint,
    this.noteHelp,
    this.notChosenLine = 'No ruling chosen yet',
    this.chooseFirstReason = 'Choose a ruling first.',
    this.busy = false,
    this.error,
    this.maximumNoteLength = 2000,
  });

  /// Names the decision, and is what a screen reader reads before the options.
  final String label;

  final List<VerdictOption<T>> options;

  /// A verb phrase. "Record this ruling", never "OK" and never "Submit".
  final String commitLabel;

  /// The id the route or the sheet declared to `TorchScope`.
  final String claimId;

  /// Called with the chosen ruling and the note, trimmed, or null where the
  /// reviewer left it blank. Null disables the whole control.
  final void Function(T value, String? note)? onCommit;

  final String noteLabel;
  final String? noteHint;

  /// Under the field, always — a note is welcome on any ruling, and the field
  /// says so rather than appearing only when one is demanded.
  final String? noteHelp;

  final String notChosenLine;

  /// The `blockedReason` while nothing is chosen.
  final String chooseFirstReason;

  final bool busy;

  /// A failure sentence from the last attempt — "Somebody else ruled this
  /// visit first". Rendered as the group's error, above the commit.
  final String? error;

  final int maximumNoteLength;

  @override
  State<VerdictControl<T>> createState() => _VerdictControlState<T>();
}

class _VerdictControlState<T> extends State<VerdictControl<T>> {
  final TextEditingController _note = TextEditingController();
  T? _value;

  /// True once a commit has been attempted, so the missing note is a finding
  /// rather than an accusation made before the reviewer had typed anything.
  bool _attempted = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  VerdictOption<T>? get _chosen {
    for (final option in widget.options) {
      if (option.value == _value) return option;
    }
    return null;
  }

  String get _trimmedNote => _note.text.trim();

  bool get _noteMissing =>
      (_chosen?.requiresNote ?? false) && _trimmedNote.isEmpty;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final chosen = _chosen;
    final enabled = widget.onCommit != null && !widget.busy;

    // The primary is disabled for exactly two reasons and it names whichever
    // one applies. A disabled commit with no sentence above it is a control
    // the reviewer reads as broken.
    final String? blocked = chosen == null
        ? widget.chooseFirstReason
        : (_noteMissing ? chosen.noteIsRequiredBecause : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ChoiceRow<T>(
          key: const ValueKey<String>('verdict-options'),
          label: widget.label,
          // Never side by side: see the class comment.
          forceColumn: true,
          notAnsweredLine: widget.notChosenLine,
          error: widget.error,
          value: _value,
          options: <ChoiceOption<T>>[
            for (final option in widget.options)
              ChoiceOption<T>(
                value: option.value,
                label: option.label,
                consequence: option.consequence,
              ),
          ],
          onChanged: enabled ? (value) => setState(() => _value = value) : null,
        ),
        const SizedBox(height: TiqSpace.s5),
        TorchTextField(
          key: const ValueKey<String>('verdict-note'),
          label: widget.noteLabel,
          controller: _note,
          hint: widget.noteHint,
          help: widget.noteHelp,
          enabled: enabled,
          minLines: 2,
          maximumLines: 4,
          maximumLength: widget.maximumNoteLength,
          // The finding is raised on the ATTEMPT, not while a reviewer is
          // still reading the options: a field that turns crimson before
          // anybody has done anything wrong teaches people to ignore it.
          error: _attempted && _noteMissing
              ? chosen?.noteIsRequiredBecause
              : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: TiqSpace.s6),
        TorchPrimaryButton(
          key: const ValueKey<String>('verdict-commit'),
          claimId: widget.claimId,
          label: widget.commitLabel,
          busy: widget.busy,
          blockedReason: blocked,
          onPressed: enabled && blocked == null ? _commit : null,
        ),
        if (chosen != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s3),
          // The consequence again, under the thumb, because the row that
          // carried it is two scroll positions away at 2.0x.
          Text(
            chosen.consequence,
            key: const ValueKey<String>('verdict-consequence'),
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
        ],
      ],
    );
  }

  void _commit() {
    setState(() => _attempted = true);
    final chosen = _chosen;
    if (chosen == null || _noteMissing) return;
    final note = _trimmedNote;
    widget.onCommit!(chosen.value, note.isEmpty ? null : note);
  }
}
