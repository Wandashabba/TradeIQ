import 'package:flutter/material.dart'
    show Icons, TextCapitalization, showDatePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tiq_number.dart';
import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../outlets/data/outlets_repository.dart';
import '../data/campaigns_repository.dart';

/// CREATE OR EDIT A CAMPAIGN.
///
/// Create collects a name, an objective, a budget, a start/end range and an
/// outlet multi-select. Edit reuses name, objective and budget and adds a
/// status control; `PATCH /campaigns/:id` accepts no date or outlet change, so
/// those are not offered — a control the server will refuse is a trap.
///
/// ## The amber, counted
///
/// Not a tab root and no nav, so Night has two content grants and Day and Veld
/// have one. The only claim is the save action, declared only while the form
/// can be submitted: a busy form carries zero amber, a ready one exactly one.
///
/// ## Where the validation went
///
/// The `Form` and its validators are gone with the `TextFormField`s: a trough
/// owns its own error line, so each rule is state on this widget. Every rule
/// the old screen enforced is still enforced, and still before the request:
/// a name is required, a budget must parse, and on create both dates are
/// required with the end not before the start.
class CampaignFormScreen extends ConsumerStatefulWidget {
  const CampaignFormScreen({super.key, this.campaign});

  final Campaign? campaign;

  bool get isEditing => campaign != null;

  /// The id the save button claims under.
  static const String commitClaimId = 'campaign-save';

  @override
  ConsumerState<CampaignFormScreen> createState() => _CampaignFormScreenState();
}

class _CampaignFormScreenState extends ConsumerState<CampaignFormScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _objectiveCtrl;
  late final TextEditingController _budgetCtrl;

  DateTime? _startDate;
  DateTime? _endDate;
  final Set<String> _selectedOutletIds = <String>{};
  late String _status;
  bool _submitting = false;

  String? _nameError;
  String? _budgetError;
  String? _dateError;
  TorchErrorMessage? _failure;

  @override
  void initState() {
    super.initState();
    final c = widget.campaign;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _objectiveCtrl = TextEditingController(text: c?.objective ?? '');
    _budgetCtrl = TextEditingController(
      text: c?.budget != null ? '${c!.budget}' : '',
    );
    _status = c?.status ?? 'draft';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _objectiveCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate({required bool isStart}) async {
    final initial = (isStart ? _startDate : _endDate) ?? DateTime(2026, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
      _dateError = null;
    });
  }

  double? _parsedBudget() {
    final raw = _budgetCtrl.text.trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  Future<void> _submit() async {
    final nameBlank = _nameCtrl.text.trim().isEmpty;
    final budgetRaw = _budgetCtrl.text.trim();
    final budgetBad =
        budgetRaw.isNotEmpty && double.tryParse(budgetRaw) == null;
    String? dateError;
    if (!widget.isEditing) {
      if (_startDate == null || _endDate == null) {
        dateError = 'A campaign needs a start date and an end date.';
      } else if (_endDate!.isBefore(_startDate!)) {
        dateError = 'The end date cannot be before the start date.';
      }
    }

    if (nameBlank || budgetBad || dateError != null) {
      setState(() {
        _nameError = nameBlank ? 'A campaign needs a name.' : null;
        _budgetError = budgetBad ? 'That is not a number.' : null;
        _dateError = dateError;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _failure = null;
    });
    final repo = ref.read(campaignsRepositoryProvider);
    final objective = _objectiveCtrl.text.trim();
    try {
      if (widget.isEditing) {
        await repo.updateCampaign(
          widget.campaign!.id,
          name: _nameCtrl.text.trim(),
          objective: objective.isEmpty ? null : objective,
          budget: _parsedBudget(),
          status: _status,
        );
      } else {
        await repo.createCampaign(
          name: _nameCtrl.text.trim(),
          startDate: _fmt(_startDate!),
          endDate: _fmt(_endDate!),
          objective: objective.isEmpty ? null : objective,
          budget: _parsedBudget(),
          outletIds: _selectedOutletIds.isEmpty
              ? null
              : _selectedOutletIds.toList(),
        );
      }
      ref.invalidate(campaignsListProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _failure = TorchErrorMessage.sanitise(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final label = widget.isEditing
        ? 'Save the campaign'
        : 'Create the campaign';

    return TorchScope(
      skin: skin,
      phase: _submitting ? 'saving' : 'editing',
      navRenders: false,
      tabbedRoute: false,
      claims: <TorchClaim>[
        if (!_submitting)
          TorchPrimaryButton.claim(CampaignFormScreen.commitClaimId),
      ],
      child: TorchShell(
        profile: TorchShellProfile.console,
        header: TorchAppHeader(
          title: widget.isEditing ? widget.campaign!.name : 'New campaign',
          facts: <String>[
            widget.isEditing ? 'Editing a campaign' : 'A new campaign',
          ],
          back: TorchIconButton(
            key: const ValueKey<String>('campaign-form-back'),
            icon: Icons.arrow_back,
            semanticLabel: 'Back to Campaigns',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        primary: TorchPrimaryButton(
          key: const ValueKey<String>('campaign-save-button'),
          claimId: CampaignFormScreen.commitClaimId,
          label: label,
          busy: _submitting,
          onPressed: _submitting ? null : _submit,
          blockedReason: _submitting ? 'Saving.' : null,
        ),
        children: <Widget>[
          SectionRule('Details'),
          const SizedBox(height: TiqSpace.s5),
          TorchTextField(
            key: const ValueKey<String>('campaign-name-field'),
            label: 'Name',
            controller: _nameCtrl,
            error: _nameError,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          const SizedBox(height: TiqSpace.s5),
          TorchTextField(
            key: const ValueKey<String>('campaign-objective-field'),
            label: 'Objective',
            help: 'Optional.',
            controller: _objectiveCtrl,
            minLines: 2,
            maximumLines: 4,
          ),
          const SizedBox(height: TiqSpace.s5),
          TorchNumericField(
            key: const ValueKey<String>('campaign-budget-field'),
            label: 'Budget',
            controller: _budgetCtrl,
            unit: TiqUnit.currency,
            decimals: 2,
            error: _budgetError,
            help: 'Optional. The return is measured against it.',
            onChanged: (_) {
              if (_budgetError != null) setState(() => _budgetError = null);
            },
          ),

          if (widget.isEditing) ...<Widget>[
            SizedBox(height: skin.space.blockGap),
            SectionRule('Status'),
            const SizedBox(height: TiqSpace.s5),
            ChoiceRow<String>(
              key: const ValueKey<String>('campaign-status-field'),
              label: 'Status',
              value: _status,
              options: const <ChoiceOption<String>>[
                ChoiceOption<String>(
                  value: 'draft',
                  label: 'Draft',
                  consequence: 'Nothing is measured against it yet.',
                ),
                ChoiceOption<String>(
                  value: 'active',
                  label: 'Active',
                  consequence: 'Visits in the window count toward it.',
                ),
                ChoiceOption<String>(
                  value: 'completed',
                  label: 'Completed',
                  consequence: 'It keeps its figures and stops collecting.',
                ),
              ],
              onChanged: (value) => setState(() => _status = value),
            ),
            const SizedBox(height: TiqSpace.s3),
            Text(
              'Dates and outlets are fixed once a campaign exists — the server '
              'accepts neither on an edit.',
              key: const ValueKey<String>('campaign-edit-note'),
              style: skin.text.meta.style(color: skin.palette.ink3),
            ),
          ] else ...<Widget>[
            SizedBox(height: skin.space.blockGap),
            SectionRule('Schedule'),
            const SizedBox(height: TiqSpace.s5),
            _DateRow(
              label: 'Start date',
              value: _startDate == null ? null : _fmt(_startDate!),
              buttonKey: 'campaign-start-date',
              onPressed: () => _pickDate(isStart: true),
            ),
            const SizedBox(height: TiqSpace.s4),
            _DateRow(
              label: 'End date',
              value: _endDate == null ? null : _fmt(_endDate!),
              buttonKey: 'campaign-end-date',
              onPressed: () => _pickDate(isStart: false),
            ),
            if (_dateError != null) ...<Widget>[
              const SizedBox(height: TiqSpace.s3),
              Text(
                _dateError!,
                key: const ValueKey<String>('campaign-date-error'),
                style: skin.text.meta.style(color: skin.palette.bad),
              ),
            ],

            SizedBox(height: skin.space.blockGap),
            SectionRule(
              'Outlets',
              count: _selectedOutletIds.isEmpty
                  ? null
                  : _selectedOutletIds.length,
            ),
            const SizedBox(height: TiqSpace.s5),
            _OutletMultiSelect(
              selected: _selectedOutletIds,
              onToggle: (id, on) => setState(() {
                if (on) {
                  _selectedOutletIds.add(id);
                } else {
                  _selectedOutletIds.remove(id);
                }
              }),
            ),
          ],

          if (_failure != null) ...<Widget>[
            SizedBox(height: skin.space.intraBlock),
            TorchErrorRegion(
              name: 'campaign form',
              child: ErrorState(
                key: const ValueKey<String>('campaign-save-error'),
                scope: ErrorScope.inline,
                message: _failure!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A date and the way to change it. "Not set" in words, never a blank.
class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.buttonKey,
    required this.onPressed,
  });

  final String label;
  final String? value;
  final String buttonKey;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: skin.text.meta.style(color: skin.palette.ink3),
              ),
              const SizedBox(height: 2),
              Text(
                value ?? 'Not set',
                style: value == null
                    ? skin.text.body.style(color: skin.palette.ink3)
                    : skin.text.figureS.style(color: skin.palette.ink1),
              ),
            ],
          ),
        ),
        const SizedBox(width: TiqSpace.s3),
        TorchSecondaryButton(
          key: ValueKey<String>(buttonKey),
          label: 'Pick',
          semanticLabel: 'Pick the ${label.toLowerCase()}',
          onPressed: onPressed,
        ),
      ],
    );
  }
}

/// Which outlets a new campaign covers. Nothing ticked is a state, and it says
/// so in words rather than leaving a manager to guess what an empty list means.
class _OutletMultiSelect extends ConsumerWidget {
  const _OutletMultiSelect({required this.selected, required this.onToggle});

  final Set<String> selected;
  final void Function(String id, bool on) onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = context.skin;
    final outlets = ref.watch(outletsListProvider);

    return outlets.when(
      loading: () => Skeleton(
        label: 'outlets',
        child: const SkeletonRows(count: 4, rowHeight: 48),
      ),
      error: (error, stack) => TorchErrorRegion(
        name: 'outlets',
        child: ErrorState(
          key: const ValueKey<String>('campaign-outlets-error'),
          scope: ErrorScope.inline,
          message: TorchErrorMessage.sanitise(error),
          action: TorchSecondaryButton(
            key: const ValueKey<String>('campaign-outlets-retry'),
            label: 'Try again',
            onPressed: () => ref.invalidate(outletsListProvider),
          ),
        ),
      ),
      data: (list) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (list.isEmpty)
            const EmptyState(
              key: ValueKey<String>('campaign-outlets-empty'),
              scope: EmptyScope.inline,
              headline: 'No outlets yet.',
              body:
                  'A campaign with no outlets covers every outlet you add '
                  'later.',
            )
          else ...<Widget>[
            TorchCheckboxGroup(
              label: 'Outlets covered',
              children: <Widget>[
                for (final outlet in list)
                  TorchCheckbox(
                    key: ValueKey<String>('outlet-option-${outlet.id}'),
                    label: '${outlet.name} · ${outlet.code}',
                    value: selected.contains(outlet.id),
                    onChanged: (on) => onToggle(outlet.id, on),
                  ),
              ],
            ),
            const SizedBox(height: TiqSpace.s3),
            Text(
              selected.isEmpty
                  ? 'Nothing ticked covers every outlet.'
                  : 'Covers the ticked outlets only.',
              key: const ValueKey<String>('campaign-outlets-note'),
              style: skin.text.meta.style(color: skin.palette.ink3),
            ),
          ],
        ],
      ),
    );
  }
}
