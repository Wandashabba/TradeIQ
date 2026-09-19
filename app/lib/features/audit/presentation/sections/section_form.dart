import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/torch_scope.dart';
import '../../../../core/theme/torchlight/agent_skin.dart';
import '../../../../core/theme/torchlight/tiq_skin.dart';
import '../../../../core/widgets/torchlight/button/buttons.dart';
import '../../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../../core/widgets/torchlight/row/row.dart';
import '../../../../core/widgets/torchlight/section_rule.dart';
import '../../../../core/widgets/torchlight/sheet.dart';
import '../../../../core/widgets/torchlight/skin_controls.dart';
import '../../../../l10n/l10n.dart';
import '../../data/visit_progress.dart';

/// THE SECTION FORM GRAMMAR — one shape for all nine capture sections.
///
/// An agent who learns one section has learned them all, and nobody designs a
/// tenth screen: an intro sentence, field groups, an optional photo, a save,
/// and a saved confirmation. Everything below the [SectionForm] constructor is
/// the grammar's own furniture — the group rule, the repeating card set, the
/// saved line, the leaving-dirty sheet — and no section may invent its own.
///
/// ```dart
/// SectionForm(
///   title: l10n.visitSectionCapability,
///   phase: 'capability',
///   dirty: _dirty,
///   onSave: _save,
///   savedLine: l10n.s7Saved,
///   children: <Widget>[
///     SectionFieldGroup(
///       title: l10n.s7TrainingLabel,
///       children: <Widget>[ ... ],
///     ),
///   ],
/// )
/// ```
///
/// ## Amber
///
/// A section is an **untabbed** route, so Night allows two content objects. It
/// spends **one**, and only when there is something to commit: the inline
/// `Save` takes `primaryCommit` the moment the form is dirty, and declares no
/// claim at all before the first edit or after a successful save. Day and Veld
/// are the same one object. The thumb zone's `Save and go back` is a **ghost**
/// in every skin — two amber saves in one frame is the repeated-fill violation
/// the law exists to stop, and the inline Save is the one the spec calls "the
/// only thing that persists".
///
/// The Phase 2 inputs ship no amber focus rule (see §15.5 of the design doc),
/// so the second Night grant stays unspent rather than being handed to
/// something that is not light.
///
/// ## The way out is back to the hub
///
/// No tabs, no stepper, no "next section": sections are done in any order
/// because a delivery blocking the aisle is why. Leaving with unsaved answers
/// opens a three-row sheet — save and go, go without saving, stay — never a
/// two-button dialog where *Discard* sits beside *Save*.
class SectionForm extends ConsumerStatefulWidget {
  const SectionForm({
    super.key,
    required this.title,
    required this.phase,
    required this.children,
    this.intro,
    this.onSave,
    this.dirty = false,
    this.savedLine,
    this.photo,
    this.skip,
    this.beforeSave,
    this.readOnlyActions = const <Widget>[],
    this.saveLabel,
    this.saveAndBackLabel,
  });

  /// The section's name. The header's title, and the sheet's subject.
  final String title;

  /// The route's phase id, for [TorchScope] and for a census failure message.
  /// The save state is appended, so a census names the exact frame.
  final String phase;

  /// The field groups, in order.
  final List<Widget> children;

  /// One sentence above the first group, when the section needs one.
  final String? intro;

  /// Persists the section. Null on a read-only section (the score), which then
  /// renders no Save at all rather than a disabled one.
  final Future<void> Function()? onSave;

  /// Whether anything has changed since the last successful save. The section
  /// owns this — every `onChanged` goes through its own `_touch`.
  final bool dirty;

  /// "Stock saved — queued for sync". Shown beside the saved line's square.
  final String? savedLine;

  /// The optional photo field, beneath the last group.
  final Widget? photo;

  /// Where an agent-declared "can't confirm" is recorded, on a section that
  /// can legitimately be empty. Null hides the control entirely.
  final SectionSkipTarget? skip;

  /// Runs before [onSave] and may refuse it by returning false — the stock
  /// section's uncounted-SKU gate. It is not a validator: a section that
  /// cannot be saved says so in its own words.
  final Future<bool> Function()? beforeSave;

  /// Actions for a section with no save of its own (the score's Refresh).
  final List<Widget> readOnlyActions;

  /// Overrides the inline commit's word where the section's verb is not
  /// "Save" — the scorecard finalises rather than saves.
  final String? saveLabel;

  /// The same word, for the thumb zone's ghost.
  final String? saveAndBackLabel;

  /// The one claim id a section route ever declares.
  static const String saveClaimId = 'section-save';

  @override
  ConsumerState<SectionForm> createState() => SectionFormState();
}

/// Where the form is in its save cycle. Not a progress bar: four of these five
/// are things the agent has to be able to read and act on.
enum SectionSavePhase { untouched, dirty, saving, saved, failed }

class SectionFormState extends ConsumerState<SectionForm> {
  bool _saving = false;
  bool _failed = false;
  DateTime? _savedAt;

  SectionSavePhase get phase {
    if (_saving) return SectionSavePhase.saving;
    if (_failed) return SectionSavePhase.failed;
    if (widget.dirty) return SectionSavePhase.dirty;
    if (_savedAt != null) return SectionSavePhase.saved;
    return SectionSavePhase.untouched;
  }

  SkipReasonResult? get _skip {
    final target = widget.skip;
    if (target == null) return null;
    return ref.watch(sectionSkipsProvider)[target];
  }

  bool get _locked => _skip != null;

  /// Armed only when there is something to commit. A form that has just saved
  /// declares nothing, so the frame paints no amber at all.
  bool get _armed =>
      widget.onSave != null && !_locked && (widget.dirty || _saving);

  Future<void> _save() async {
    final save = widget.onSave;
    if (save == null || _saving) return;
    final gate = widget.beforeSave;
    if (gate != null && !await gate()) return;
    if (!mounted) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await save();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _savedAt = DateTime.now();
      });
      TorchBuzz.tick();
    } catch (error, stack) {
      debugPrint('Section save failed (${widget.phase}): $error\n$stack');
      if (!mounted) return;
      // The values are untouched. A failed save never clears the form — the
      // answers are still in the shop, and so are they.
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  Future<void> _saveAndBack() async {
    await _save();
    if (!mounted || _failed) return;
    Navigator.of(context).pop();
  }

  /// The way out. Clean forms leave silently; a dirty one asks, with three
  /// unequal rows and no Discard sitting beside Save.
  Future<void> _leave() async {
    if (!widget.dirty || widget.onSave == null || _locked) {
      Navigator.of(context).pop();
      return;
    }
    final outcome = await showTorchSheet<_LeaveOutcome>(
      context,
      builder: (sheetContext) => _LeaveSheet(title: widget.title),
    );
    if (!mounted) return;
    switch (outcome) {
      case _LeaveOutcome.save:
        await _saveAndBack();
      case _LeaveOutcome.discard:
        Navigator.of(context).pop();
      case _LeaveOutcome.stay:
      case null:
        break;
    }
  }

  Future<void> _openSkipPicker() async {
    final target = widget.skip;
    if (target == null) return;
    final l10n = context.l10n;
    final existing = _skip;
    final result = await showTorchSheet<SkipReasonResult>(
      context,
      builder: (sheetContext) => SkipReasonPicker(
        key: const ValueKey<String>('section-skip-picker'),
        title: l10n.sectionCantConfirmWhy,
        subtitle: widget.title,
        reasons: sectionSkipReasons(l10n),
        initial: existing?.reason,
        initialNote: existing?.note,
        // What this produces, said before it is chosen. The picker's
        // consequence lines ("the manager is told…") describe a wire that does
        // not exist yet, and a consequence the agent is promised and never
        // gets is worse than none — so the reasons carry no consequence and
        // this one true sentence stands in for all of them.
        thresholdLine: l10n.sectionCantConfirmHeld,
        noteLabel: l10n.skipReasonNoteLabel,
        saveLabel: l10n.skipReasonSave,
        changeLabel: l10n.skipReasonChange,
        cancelLabel: l10n.skipReasonCancel,
        chooseFirstNote: l10n.skipReasonChooseFirst,
        sayWhatHappenedNote: l10n.skipReasonSayWhatHappened,
      ),
    );
    if (result == null || !mounted) return;
    ref.read(sectionSkipsProvider.notifier).record(target, result);
  }

  void _unskip() {
    final target = widget.skip;
    if (target == null) return;
    ref.read(sectionSkipsProvider.notifier).clear(target);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final state = phase;

    return TorchlightRoute(
      child: TorchSheetAware(
        builder: (context, beneathSheet) => TorchScope(
          skin: skin,
          phase: '${widget.phase}/${state.name}',
          navRenders: false,
          tabbedRoute: false,
          beneathSheet: beneathSheet,
          claims: <TorchClaim>[
            if (_armed) const TorchClaim.primaryCommit(SectionForm.saveClaimId),
          ],
          child: TorchShell(
            profile: TorchShellProfile.agent,
            header: TorchAppHeader(
              title: widget.title,
              facts: <String>[l10n.visitSectionSavesAsYouGo],
              back: TorchIconButton(
                icon: Icons.arrow_back,
                semanticLabel: l10n.agentBackTooltip,
                onPressed: _leave,
              ),
            ),
            skinCycle: const AgentSkinCycle(),
            primary: widget.onSave == null
                ? null
                : TorchSecondaryButton(
                    key: const ValueKey<String>('section-save-and-back'),
                    label: widget.saveAndBackLabel ?? l10n.sectionSaveAndBack,
                    onPressed: _locked || _saving ? null : _saveAndBack,
                    blockedReason: _locked ? l10n.sectionLockedBlock : null,
                  ),
            children: _body(skin, l10n, state),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(
    TiqSkin skin,
    AppLocalizations l10n,
    SectionSavePhase state,
  ) {
    final skip = _skip;
    return <Widget>[
      if (widget.intro != null) ...<Widget>[
        Text(
          widget.intro!,
          style: skin.text.body.style(color: skin.palette.ink2),
        ),
        const SizedBox(height: TiqSpace.s6),
      ],
      if (skip != null) ...<Widget>[
        _CantConfirmLine(skip: skip, onUndo: _unskip),
        const SizedBox(height: TiqSpace.s6),
      ],
      // Locked, not dimmed: opacity is banned as a state channel, so the
      // answers stay legible and the controls simply stop answering. The line
      // above says which, in words, and the ghost beneath it unlocks.
      IgnorePointer(
        ignoring: skip != null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final (i, group) in widget.children.indexed) ...<Widget>[
              if (i > 0) const SizedBox(height: TiqSpace.s7),
              group,
            ],
            if (widget.photo != null) ...<Widget>[
              const SizedBox(height: TiqSpace.s7),
              widget.photo!,
            ],
          ],
        ),
      ),
      if (widget.readOnlyActions.isNotEmpty) ...<Widget>[
        const SizedBox(height: TiqSpace.s7),
        for (final action in widget.readOnlyActions) ...<Widget>[
          Align(alignment: AlignmentDirectional.centerStart, child: action),
          const SizedBox(height: TiqSpace.s3),
        ],
      ],
      if (widget.onSave != null && skip == null) ...<Widget>[
        const SizedBox(height: TiqSpace.s7),
        _SaveAction(
          state: state,
          onSave: _save,
          label: widget.saveLabel ?? l10n.sectionSave,
        ),
        if (state == SectionSavePhase.saved &&
            widget.savedLine != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s3),
          _SavedLine(line: widget.savedLine!, at: _savedAt!),
        ],
        if (state == SectionSavePhase.failed) ...<Widget>[
          const SizedBox(height: TiqSpace.s3),
          const _FailedLine(),
        ],
      ],
      if (widget.skip != null && skip == null) ...<Widget>[
        const SizedBox(height: TiqSpace.s4),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TorchTertiaryButton(
            key: const ValueKey<String>('section-cant-confirm'),
            label: l10n.sectionCantConfirm,
            onPressed: _openSkipPicker,
          ),
        ),
      ],
    ];
  }
}

/// The inline Save — the only thing that persists.
///
/// Ghost before the first edit, so a section that needs no change does not
/// nag; the amber block the moment there is something to commit; three dots
/// while it is committing.
class _SaveAction extends StatelessWidget {
  const _SaveAction({
    required this.state,
    required this.onSave,
    required this.label,
  });

  final SectionSavePhase state;
  final VoidCallback onSave;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (state == SectionSavePhase.untouched ||
        state == SectionSavePhase.saved) {
      return TorchSecondaryButton(
        key: const ValueKey<String>('section-save'),
        label: label,
        onPressed: onSave,
      );
    }
    return TorchPrimaryButton(
      key: const ValueKey<String>('section-save'),
      claimId: SectionForm.saveClaimId,
      label: label,
      busy: state == SectionSavePhase.saving,
      onPressed: state == SectionSavePhase.saving ? null : onSave,
    );
  }
}

/// "Saved on this phone · 07:58" — a square, a fact and a time, announced once.
class _SavedLine extends StatelessWidget {
  const _SavedLine({required this.line, required this.at});

  final String line;
  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final text = '$line · ${_hhmm(at)}';
    return Semantics(
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      child: Row(
        key: const ValueKey<String>('section-saved'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const RowMarkTile(mark: RowMark.square),
          const SizedBox(width: TiqSpace.s3),
          Expanded(
            child: Text(
              text,
              style: skin.text.body.style(color: skin.palette.ink2),
            ),
          ),
        ],
      ),
    );
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// A save that did not land. The answers are still here, and the line says so
/// before it says anything else — severity as a silhouette plus a word, never
/// a hue on its own, and no Retry of its own because Save *is* the retry.
class _FailedLine extends StatelessWidget {
  const _FailedLine();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    return Semantics(
      liveRegion: true,
      label: '${l10n.sectionSaveFailedTitle} ${l10n.sectionSaveFailedBody}',
      excludeSemantics: true,
      child: Row(
        key: const ValueKey<String>('section-save-failed'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const RowMarkTile(mark: RowMark.triangle, tone: RowMarkTone.severe),
          const SizedBox(width: TiqSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.sectionSaveFailedTitle,
                  style: skin.text.bodyStrong.style(color: skin.palette.ink1),
                ),
                const SizedBox(height: TiqSpace.s1),
                Text(
                  l10n.sectionSaveFailedBody,
                  style: skin.text.body.style(color: skin.palette.ink2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The fourth silhouette and the reason, above a locked body.
class _CantConfirmLine extends StatelessWidget {
  const _CantConfirmLine({required this.skip, required this.onUndo});

  final SkipReasonResult skip;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final reason = skip.note?.trim().isNotEmpty == true
        ? skip.note!.trim()
        : skip.reason.label;
    return Column(
      key: const ValueKey<String>('section-cant-confirm-line'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          liveRegion: true,
          label: l10n.sectionCantConfirmLocked(reason),
          excludeSemantics: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const RowMarkTile(mark: RowMark.barredRing),
              const SizedBox(width: TiqSpace.s3),
              Expanded(
                child: Text(
                  l10n.sectionCantConfirmLocked(reason),
                  style: skin.text.body.style(color: skin.palette.ink1),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: TiqSpace.s2),
        // Held, and honest about it: nothing carries this reason to the
        // manager yet. See the PR — the wire has no field for it.
        Text(
          l10n.sectionCantConfirmHeld,
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
        const SizedBox(height: TiqSpace.s3),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TorchTertiaryButton(
            key: const ValueKey<String>('section-can-confirm'),
            label: l10n.sectionCanConfirmAfterAll,
            onPressed: onUndo,
          ),
        ),
      ],
    );
  }
}

enum _LeaveOutcome { save, discard, stay }

/// LEAVING WITH UNSAVED ANSWERS. Three rows, unequal, and the destructive one
/// is never the bottom-most thing under a travelling thumb.
class _LeaveSheet extends StatelessWidget {
  const _LeaveSheet({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TorchSheet(
      title: l10n.sectionLeaveTitle,
      subtitle: title,
      claims: const <TorchClaim>[
        TorchClaim.primaryCommit('section-leave-save'),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TorchPrimaryButton(
            key: const ValueKey<String>('leave-save'),
            claimId: 'section-leave-save',
            label: l10n.sectionSaveAndBack,
            onPressed: () => Navigator.of(context).pop(_LeaveOutcome.save),
          ),
          const SizedBox(height: TiqSpace.s3),
          TorchSecondaryButton(
            key: const ValueKey<String>('leave-discard'),
            label: l10n.sectionLeaveWithoutSaving,
            onPressed: () => Navigator.of(context).pop(_LeaveOutcome.discard),
          ),
          const SizedBox(height: TiqSpace.s3),
          Align(
            child: TorchTertiaryButton(
              key: const ValueKey<String>('leave-stay'),
              label: l10n.sectionStayHere,
              onPressed: () => Navigator.of(context).pop(_LeaveOutcome.stay),
            ),
          ),
        ],
      ),
    );
  }
}

/// ONE GROUP OF FIELDS, under an optional rule.
///
/// The rule is [SectionRule] — the system's one section marker — not an
/// uppercase eyebrow, which unify §1.17 legalises in exactly three places and
/// this is not one of them.
class SectionFieldGroup extends StatelessWidget {
  const SectionFieldGroup({super.key, required this.children, this.title});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (title != null) ...<Widget>[
          SectionRule(title!),
          const SizedBox(height: TiqSpace.s5),
        ],
        for (final (i, child) in children.indexed) ...<Widget>[
          if (i > 0) const SizedBox(height: TiqSpace.s4),
          child,
        ],
      ],
    );
  }
}

/// A CHOICE ROW WITH ITS QUESTION ABOVE IT.
///
/// `ChoiceRow` names its question to a screen reader and draws nothing above
/// the options — a sheet puts the question in its title. Inside a section the
/// question has to be on the page, above the chips, where every other field in
/// the grammar keeps its label: three chips reading "Critical · High · Normal"
/// with nothing saying *of what* is a question the agent has to guess. The
/// visible line is excluded from semantics because the row already speaks it.
class SectionChoice extends StatelessWidget {
  const SectionChoice({super.key, required this.label, required this.child});

  final String label;

  /// The `ChoiceRow`, carrying the same [label].
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ExcludeSemantics(
          child: Text(
            label,
            style: skin.text.label.style(color: skin.palette.ink2),
          ),
        ),
        const SizedBox(height: TiqSpace.s2),
        child,
      ],
    );
  }
}

/// THE REPEATING SET — competitor observations, risks.
///
/// Built from the row grammar, not from cards (unify §3.18: the soft row
/// *replaces* ListTile/Card usage). Each entry opens with a list-form
/// [SoftRow] carrying its number in mono ("Competitor 2 of 3", never "02")
/// and what the agent has typed so far, a 48dp remove control beside it that
/// names what it removes, then the entry's fields; entries are separated by
/// the same structure rule the stock counter draws between SKUs. A ghost
/// "Add another" sits beneath the set. No fill, no radius, no shadow — a list
/// of six risks down a phone is a list, not six boxes.
///
/// The remove control sits *beside* the row rather than in its trailing slot:
/// a soft row is one semantics node and excludes its children, and a remove
/// button a screen reader cannot reach is not a remove button.
class SectionEntries extends StatelessWidget {
  const SectionEntries({
    super.key,
    required this.kind,
    required this.entries,
    required this.onAdd,
    required this.onRemove,
    this.summaries = const <String?>[],
    this.addLabel,
    this.emptyLine,
  });

  /// `competitor`, `risk` or `task` — selects the entry's name in both cases
  /// ("Competitor 2 of 3" in the header, "Remove competitor 2 of 3" spoken).
  final String kind;

  final List<Widget> entries;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  /// What each entry is, so far — the competitor's SKU, the flag type. Null or
  /// blank reads "Not named yet". Indexed like [entries].
  final List<String?> summaries;

  final String? addLabel;

  /// What an empty set says. A set with no entries is a state, not a blank.
  final String? emptyLine;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final total = entries.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (total == 0 && emptyLine != null) ...<Widget>[
          Text(
            emptyLine!,
            style: skin.text.body.style(color: skin.palette.ink2),
          ),
          const SizedBox(height: TiqSpace.s4),
        ],
        for (final (i, entry) in entries.indexed) ...<Widget>[
          _Entry(
            index: i,
            total: total,
            kind: kind,
            summary: i < summaries.length ? summaries[i] : null,
            onRemove: () => onRemove(i),
            child: entry,
          ),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TorchSecondaryButton(
            key: const ValueKey<String>('section-add-entry'),
            label: addLabel ?? l10n.sectionAddAnother,
            icon: Icons.add,
            onPressed: onAdd,
          ),
        ),
      ],
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.index,
    required this.total,
    required this.kind,
    required this.summary,
    required this.onRemove,
    required this.child,
  });

  final int index;
  final int total;
  final String kind;
  final String? summary;
  final VoidCallback onRemove;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final position = l10n.sectionEntryPosition(index + 1, total);
    final title = '${l10n.sectionEntryName(kind)} $position';
    final named = summary?.trim().isNotEmpty == true;
    final subtitle = named ? summary!.trim() : l10n.sectionEntryUnnamed;
    return Column(
      key: ValueKey<String>('entry-$index'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (index > 0)
          Container(
            height: skin.depth.borderWidth,
            color: skin.palette.edgeStructure,
          ),
        Row(
          children: <Widget>[
            Expanded(
              child: SoftRow(
                density: SoftRowDensity.compact,
                title: title,
                subtitle: subtitle,
                separator: SoftRowSeparator.none,
                semanticsLabel: '$title. $subtitle',
              ),
            ),
            const SizedBox(width: TiqSpace.s2),
            TorchIconButton(
              key: ValueKey<String>('entry-remove-$index'),
              icon: Icons.close,
              semanticLabel: l10n.sectionRemoveEntry(
                l10n.sectionEntryNameLower(kind),
                position,
              ),
              onPressed: onRemove,
            ),
          ],
        ),
        const SizedBox(height: TiqSpace.s3),
        child,
        const SizedBox(height: TiqSpace.s6),
      ],
    );
  }
}

// ── The agent-declared "can't confirm", held on this phone ─────────────────

/// The standard reasons, in the screen's language.
///
/// The ids are [SkipReason.standard]'s, so a reason recorded here is the same
/// reason the day the wire carries it. No consequence lines yet — see
/// [SectionFormState._openSkipPicker]; the `skipReason…Consequence` strings are
/// translated and waiting for the field that makes them true.
List<SkipReason> sectionSkipReasons(AppLocalizations l10n) => <SkipReason>[
  SkipReason(
    id: SkipReason.storeRefused.id,
    label: l10n.skipReasonStoreRefused,
    consequence: '',
  ),
  SkipReason(
    id: SkipReason.notStocked.id,
    label: l10n.skipReasonNotStocked,
    consequence: '',
  ),
  SkipReason(
    id: SkipReason.equipmentUnavailable.id,
    label: l10n.skipReasonEquipment,
    consequence: '',
  ),
  SkipReason(
    id: SkipReason.somethingElse.id,
    label: l10n.skipReasonSomethingElse,
    consequence: '',
  ),
];

/// Which section of which visit a skip belongs to.
@immutable
class SectionSkipTarget {
  const SectionSkipTarget(this.visitDraftId, this.section);

  final String visitDraftId;
  final AuditSection section;

  @override
  bool operator ==(Object other) =>
      other is SectionSkipTarget &&
      other.visitDraftId == visitDraftId &&
      other.section == section;

  @override
  int get hashCode => Object.hash(visitDraftId, section);
}

/// The skip reasons an agent has given during this session.
///
/// In memory, for the life of the app process — the same shape as
/// `pinReportsProvider` (#386) and for the same reason: the fact is real, the
/// agent needs it to survive walking out of the section and back in, and there
/// is nowhere to send it yet. `visit_progress.dart` documents the data-layer
/// change that turns an agent-declared can't-confirm into a non-blocking
/// section; until that lands the reason is held here and the section says so.
class SectionSkips extends Notifier<Map<SectionSkipTarget, SkipReasonResult>> {
  @override
  Map<SectionSkipTarget, SkipReasonResult> build() =>
      const <SectionSkipTarget, SkipReasonResult>{};

  void record(SectionSkipTarget target, SkipReasonResult result) =>
      state = <SectionSkipTarget, SkipReasonResult>{...state, target: result};

  void clear(SectionSkipTarget target) =>
      state = <SectionSkipTarget, SkipReasonResult>{...state}..remove(target);
}

final sectionSkipsProvider =
    NotifierProvider<SectionSkips, Map<SectionSkipTarget, SkipReasonResult>>(
      SectionSkips.new,
    );
