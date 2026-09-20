import 'package:flutter/material.dart' show Icons, showDatePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tiq_number.dart';
import '../../../core/design/torch_scope.dart';
import '../../../core/network/human_error.dart';
import '../../../core/theme/torchlight/console_skin.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../../outlets/data/outlets_repository.dart';
import '../../territories/data/territories_repository.dart';
import '../../users/data/users_repository.dart';
import '../data/beatplans_repository.dart';

/// BUILD A DAY — who works it, when, and the stores in order.
///
/// ```text
///   ← Beat plans
///   New beat plan
///   ── The day ──────────────────────────────
///   Plan name · Scheduled date · Field agent
///   ── Stops, in order  3 ───────────────────
///   ▏ 1  Kasi Corner Spaza      [↑][↓][×]
///   ── Stores to add  9 ─────────────────────
///   ▏ Sunrise Spaza                  [ Add ]
///   [ ☾ ]  [        Create the plan        ]
/// ```
///
/// ## Every reorder control is a real button
///
/// The old screen put three `IconButton`s in a `ListTile.trailing` with
/// tooltips and no semantic labels, so a screen reader announced "button"
/// three times per stop with nothing to tell them apart. Each one now names
/// the store it acts on: "Move Kasi Corner Spaza earlier".
///
/// ## The amber, counted
///
/// Not a tab root: the thumb zone carries the one commit, armed only when the
/// plan is complete. One object in Night, one in Day and Veld, and zero while
/// the form is unfinished.
class BeatPlanFormScreen extends ConsumerWidget {
  const BeatPlanFormScreen({super.key});

  /// "Create the plan". Rung 1, and the only claim this route makes.
  static const String submitClaimId = 'beat-plan-submit';

  /// The wire's format for `scheduledDate`: a calendar date, zero-padded.
  ///
  /// Not `DateFormat`: this is a machine format the server parses, and it
  /// must not follow the reader's locale the way every date on screen does.
  static String wireDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ConsoleTorchlightRoute(child: _BeatPlanForm());
  }
}

class _BeatPlanForm extends ConsumerStatefulWidget {
  const _BeatPlanForm();

  @override
  ConsumerState<_BeatPlanForm> createState() => _BeatPlanFormState();
}

class _BeatPlanFormState extends ConsumerState<_BeatPlanForm> {
  final TextEditingController _nameCtrl = TextEditingController();

  String? _agentId;
  String? _territoryId;
  DateTime? _scheduledDate;
  final List<String> _stopIds = <String>[];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_onTyped);
  }

  void _onTyped() => setState(() {});

  @override
  void dispose() {
    _nameCtrl
      ..removeListener(_onTyped)
      ..dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    // The one Material control left on a Torchlight route. The kit has no
    // calendar, and a date is the one value nobody should type: see the
    // migration notes.
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _scheduledDate = picked);
  }

  void _addStop(String id) => setState(() => _stopIds.add(id));

  void _removeStop(String id) => setState(() => _stopIds.remove(id));

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _stopIds.length) return;
    setState(() {
      final id = _stopIds.removeAt(index);
      _stopIds.insert(target, id);
    });
  }

  bool get _complete =>
      _nameCtrl.text.trim().isNotEmpty &&
      _agentId != null &&
      _scheduledDate != null &&
      _stopIds.isNotEmpty;

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (!_complete) return;

    setState(() => _submitting = true);
    final bool created;
    try {
      await ref
          .read(beatPlansRepositoryProvider)
          .createBeatPlan(
            agentId: _agentId!,
            name: _nameCtrl.text.trim(),
            scheduledDate: BeatPlanFormScreen.wireDate(_scheduledDate!),
            outletIds: List<String>.of(_stopIds),
            territoryId: _territoryId,
          );
      ref.invalidate(beatPlansPageProvider);
      created = true;
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showTorchToast(
        context,
        message: l10n.beatPlanFormFailed,
        kind: ToastKind.failure,
      );
      return;
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    if (created && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final agents = ref.watch(usersListProvider);
    final territories = ref.watch(territoriesListProvider);
    final outlets = ref.watch(outletsListProvider);

    return TorchScope(
      skin: skin,
      phase: _submitting ? 'submitting' : (_complete ? 'ready' : 'form'),
      navRenders: false,
      tabbedRoute: false,
      claims: <TorchClaim>[
        TorchPrimaryButton.claim(BeatPlanFormScreen.submitClaimId),
      ],
      child: TorchShell(
        profile: TorchShellProfile.console,
        header: TorchAppHeader(
          title: l10n.beatPlanFormTitle,
          back: TorchIconButton(
            icon: Icons.arrow_back,
            semanticLabel: l10n.beatPlanFormBack,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        skinCycle: const ConsoleSkinCycle(),
        primary: TorchPrimaryButton(
          key: const ValueKey<String>('beatplan-save-button'),
          label: l10n.beatPlanFormSubmit,
          claimId: BeatPlanFormScreen.submitClaimId,
          busy: _submitting,
          blockedReason: _complete ? null : l10n.beatPlanFormBlocked,
          onPressed: _complete && !_submitting ? _submit : null,
        ),
        children: <Widget>[
          SectionRule(l10n.beatPlanFormPlanHeading),
          const SizedBox(height: TiqSpace.s4),
          TorchTextField(
            key: const ValueKey<String>('beatplan-name-field'),
            label: l10n.beatPlanFormName,
            controller: _nameCtrl,
            help: l10n.beatPlanFormNameHelp,
          ),
          const SizedBox(height: TiqSpace.s5),
          _DateField(date: _scheduledDate, onPick: _pickDate),
          const SizedBox(height: TiqSpace.s5),
          agents.when(
            loading: () => Skeleton(
              label: l10n.beatPlanFormAgent,
              child: const SkeletonShell(height: 72, outlined: true),
            ),
            error: (error, stack) => ErrorState(
              scope: ErrorScope.inline,
              message: TorchErrorMessage(
                kind: TorchErrorKind.unknown,
                headline: l10n.beatPlanFormAgentsFailed,
                body: humanErrorMessage(error, l10n),
                offersRetry: true,
              ),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('beatplan-agents-retry'),
                label: l10n.beatPlansRetry,
                onPressed: () => ref.invalidate(usersListProvider),
              ),
            ),
            data: (list) {
              final fieldAgents = list
                  .where((u) => u.role == 'field_agent')
                  .toList();
              return TorchPickerField<String>(
                key: const ValueKey<String>('beatplan-agent-field'),
                label: l10n.beatPlanFormAgent,
                value: _agentId,
                options: <PickerOption<String>>[
                  for (final agent in fieldAgents)
                    PickerOption<String>(
                      value: agent.id,
                      label: agent.label,
                      detail: agent.email,
                    ),
                ],
                notChosenLine: l10n.beatPlanFormAgentNotChosen,
                emptyHeadline: l10n.beatPlanFormNoAgents,
                onChanged: (id) => setState(() => _agentId = id),
              );
            },
          ),
          const SizedBox(height: TiqSpace.s5),
          territories.when(
            loading: () => Skeleton(
              label: l10n.beatPlanFormTerritory,
              child: const SkeletonShell(height: 72, outlined: true),
            ),
            // A territory is optional, so a territory list that will not load
            // must not block the plan. It says so and gets out of the way.
            error: (error, stack) => Text(
              l10n.beatPlanFormAgentsFailed,
              style: skin.text.meta.style(color: skin.palette.ink3),
            ),
            data: (list) => TorchPickerField<String>(
              key: const ValueKey<String>('beatplan-territory-field'),
              label: l10n.beatPlanFormTerritory,
              value: _territoryId,
              options: <PickerOption<String>>[
                PickerOption<String>(
                  value: '',
                  label: l10n.beatPlanFormTerritoryNone,
                ),
                for (final territory in list)
                  PickerOption<String>(
                    value: territory.id,
                    label: territory.name,
                    identifier: territory.code,
                  ),
              ],
              notChosenLine: l10n.beatPlanFormTerritoryOptional,
              help: l10n.beatPlanFormTerritoryOptional,
              onChanged: (id) =>
                  setState(() => _territoryId = id.isEmpty ? null : id),
            ),
          ),
          const SizedBox(height: TiqSpace.s7),

          outlets.when(
            loading: () => Skeleton(
              label: l10n.beatPlanFormStopsHeading,
              child: const SkeletonRows(count: 4, rowHeight: 64),
            ),
            error: (error, stack) => ErrorState(
              scope: ErrorScope.inline,
              message: TorchErrorMessage(
                kind: TorchErrorKind.unknown,
                headline: l10n.beatPlanFormStoresFailed,
                body: humanErrorMessage(error, l10n),
                offersRetry: true,
              ),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('beatplan-outlets-retry'),
                label: l10n.beatPlansRetry,
                onPressed: () => ref.invalidate(outletsListProvider),
              ),
            ),
            data: (list) => _StopBuilder(
              outlets: list,
              selectedIds: _stopIds,
              onAdd: _addStop,
              onRemove: _removeStop,
              onMove: _move,
            ),
          ),
        ],
      ),
    );
  }
}

/// The scheduled date: a read-only trough with the verb beneath it.
///
/// It is a trough rather than a button so it sits in the same column, at the
/// same label position, as every other value on the form — and nothing
/// selected is a state, said in words.
class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onPick});

  final DateTime? date;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      key: const ValueKey<String>('beatplan-date'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TorchTextField(
          label: l10n.beatPlanFormDate,
          readOnly: true,
          controller: TextEditingController(
            text: date == null ? '' : formatDayHeading(context, date!),
          ),
          help: date == null ? l10n.beatPlanFormDateNotChosen : null,
        ),
        const SizedBox(height: TiqSpace.s2),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TorchTertiaryButton(
            key: const ValueKey<String>('beatplan-date-pick'),
            label: date == null
                ? l10n.beatPlanFormPickDate
                : l10n.beatPlanFormChangeDate,
            onPressed: onPick,
          ),
        ),
      ],
    );
  }
}

/// The ordered selection, and the pool of stores still to add.
class _StopBuilder extends StatelessWidget {
  const _StopBuilder({
    required this.outlets,
    required this.selectedIds,
    required this.onAdd,
    required this.onRemove,
    required this.onMove,
  });

  final List<Outlet> outlets;
  final List<String> selectedIds;
  final void Function(String id) onAdd;
  final void Function(String id) onRemove;
  final void Function(int index, int delta) onMove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final numbers = TiqNumber.of(context);
    final gutter = skin.space.gutterFor(MediaQuery.sizeOf(context).width);

    String nameFor(String id) =>
        outlets.where((o) => o.id == id).map((o) => o.name).firstOrNull ?? id;

    final available = outlets
        .where((o) => !selectedIds.contains(o.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionRule(
          l10n.beatPlanFormStopsHeading,
          count: selectedIds.isEmpty ? null : selectedIds.length,
          emptyLine: selectedIds.isEmpty ? l10n.beatPlanFormStopsEmpty : null,
        ),
        const SizedBox(height: TiqSpace.s4),
        if (selectedIds.isNotEmpty)
          TorchBleed(
            extra: gutter.left * 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < selectedIds.length; i++)
                  SoftRow(
                    key: ValueKey<String>('stop-selected-${selectedIds[i]}'),
                    density: SoftRowDensity.tall,
                    title: nameFor(selectedIds[i]),
                    titleTruncation: SoftRowTruncation.middle,
                    subtitle: l10n.beatPlanStopLabel(numbers.format(i + 1)),
                    // The verbs live in `actions`, where they keep their own
                    // semantics nodes. In `trailing` the row's label would
                    // swallow all three.
                    actions: Wrap(
                      spacing: TiqSpace.s2,
                      children: <Widget>[
                        TorchIconButton(
                          key: ValueKey<String>('stop-up-${selectedIds[i]}'),
                          icon: Icons.arrow_upward,
                          semanticLabel: l10n.beatPlanFormMoveUp(
                            nameFor(selectedIds[i]),
                          ),
                          onPressed: i == 0 ? null : () => onMove(i, -1),
                        ),
                        TorchIconButton(
                          key: ValueKey<String>('stop-down-${selectedIds[i]}'),
                          icon: Icons.arrow_downward,
                          semanticLabel: l10n.beatPlanFormMoveDown(
                            nameFor(selectedIds[i]),
                          ),
                          onPressed: i == selectedIds.length - 1
                              ? null
                              : () => onMove(i, 1),
                        ),
                        TorchIconButton(
                          key: ValueKey<String>(
                            'stop-remove-${selectedIds[i]}',
                          ),
                          icon: Icons.remove_circle_outline,
                          semanticLabel: l10n.beatPlanFormRemoveStop(
                            nameFor(selectedIds[i]),
                          ),
                          onPressed: () => onRemove(selectedIds[i]),
                        ),
                      ],
                    ),
                    separator: i == selectedIds.length - 1
                        ? SoftRowSeparator.none
                        : SoftRowSeparator.auto,
                  ),
              ],
            ),
          ),
        const SizedBox(height: TiqSpace.s7),

        SectionRule(
          l10n.beatPlanFormAvailableHeading,
          count: available.isEmpty ? null : available.length,
          emptyLine: available.isEmpty ? l10n.beatPlanFormAvailableEmpty : null,
        ),
        const SizedBox(height: TiqSpace.s4),
        if (available.isNotEmpty)
          TorchBleed(
            extra: gutter.left * 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < available.length; i++)
                  SoftRow(
                    key: ValueKey<String>('stop-available-${available[i].id}'),
                    density: SoftRowDensity.standard,
                    title: available[i].name,
                    titleTruncation: SoftRowTruncation.middle,
                    meta: Text(
                      available[i].code,
                      style: skin.text.monoIdent.style(
                        color: skin.palette.ink3,
                      ),
                    ),
                    trailingIsControl: true,
                    trailing: TorchIconButton(
                      key: ValueKey<String>('stop-add-${available[i].id}'),
                      icon: Icons.add_circle_outline,
                      semanticLabel: l10n.beatPlanFormAddStop(
                        available[i].name,
                      ),
                      onPressed: () => onAdd(available[i].id),
                    ),
                    // The row is the target too: a thumb aims at the row, not
                    // at a 40dp glyph.
                    onTap: () => onAdd(available[i].id),
                    separator: i == available.length - 1
                        ? SoftRowSeparator.none
                        : SoftRowSeparator.auto,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
