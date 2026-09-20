import 'package:flutter/material.dart'
    show Icons, TextCapitalization, showDatePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../territories/data/territories_repository.dart';
import '../data/contests_repository.dart';
import 'contest_labels.dart';

/// CREATE OR EDIT A CONTEST (#124).
///
/// Every field is editable, dates included. Dates are calendar days,
/// inclusive, in the client's timezone. A new contest defaults to a week
/// starting today, so the common case needs no date picking at all.
///
/// ## The amber, counted
///
/// Not a tab root and no nav, so Night has two content grants and Day and Veld
/// have one. The only claim is the save action, and it is declared only while
/// the form can actually be submitted — a screen mid-save declares nothing, so
/// a busy form carries zero amber and a ready one carries exactly one in every
/// skin.
///
/// ## What the trough grammar changed, and what it did not
///
/// Every `TextFormField` became a [TorchTextField] and the `Form`/validator
/// pair went with them: a trough owns its own error line, so validation is
/// state on this widget rather than a `GlobalKey<FormState>`. The rules are
/// the same rules — a name is required, the end may not precede the start —
/// and both are still checked before the request rather than after it.
class ContestFormScreen extends ConsumerStatefulWidget {
  const ContestFormScreen({super.key, this.contest});

  final Contest? contest;

  bool get isEditing => contest != null;

  /// The id the save button claims under.
  static const String commitClaimId = 'contest-save';

  @override
  ConsumerState<ContestFormScreen> createState() => _ContestFormScreenState();
}

class _ContestFormScreenState extends ConsumerState<ContestFormScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _prizeCtrl;
  late DateTime _startDate;
  late DateTime _endDate;
  String? _territoryId;
  late final Set<String> _eventTypes;
  bool _submitting = false;

  /// The trough's own error line, or null. Set on submit and cleared on the
  /// next keystroke — a field that goes on shouting after it has been fixed
  /// teaches people to ignore it.
  String? _nameError;
  String? _dateError;
  TorchErrorMessage? _failure;

  @override
  void initState() {
    super.initState();
    final c = widget.contest;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _descriptionCtrl = TextEditingController(text: c?.description ?? '');
    _prizeCtrl = TextEditingController(text: c?.prizeDescription ?? '');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _startDate = (c == null ? null : DateTime.tryParse(c.startDate)) ?? today;
    _endDate =
        (c == null ? null : DateTime.tryParse(c.endDate)) ??
        today.add(const Duration(days: 6));
    _territoryId = c?.territoryId;
    _eventTypes = <String>{...?c?.eventTypes};
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _prizeCtrl.dispose();
    super.dispose();
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
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

  String? _optional(TextEditingController ctrl) {
    final text = ctrl.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _submit() async {
    final nameBlank = _nameCtrl.text.trim().isEmpty;
    final endsFirst = _endDate.isBefore(_startDate);
    if (nameBlank || endsFirst) {
      setState(() {
        _nameError = nameBlank ? 'A contest needs a name.' : null;
        _dateError = endsFirst
            ? 'The end date cannot be before the start date.'
            : null;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _failure = null;
    });
    final repo = ref.read(contestsRepositoryProvider);
    final input = ContestInput(
      name: _nameCtrl.text.trim(),
      description: _optional(_descriptionCtrl),
      prizeDescription: _optional(_prizeCtrl),
      startDate: _fmt(_startDate),
      endDate: _fmt(_endDate),
      territoryId: _territoryId,
      // Canonical order, whatever order they were ticked in.
      eventTypes: <String>[
        for (final type in contestEventTypes)
          if (_eventTypes.contains(type)) type,
      ],
    );
    try {
      if (widget.isEditing) {
        final id = widget.contest!.id;
        await repo.updateContest(id, input);
        ref.invalidate(contestStandingsProvider(id));
      } else {
        await repo.createContest(input);
      }
      ref.invalidate(contestsListProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      // The screen stays up with everything typed still in it.
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
    final label = widget.isEditing ? 'Save the contest' : 'Create the contest';

    return TorchScope(
      skin: skin,
      phase: _submitting ? 'saving' : 'editing',
      navRenders: false,
      tabbedRoute: false,
      claims: <TorchClaim>[
        if (!_submitting)
          TorchPrimaryButton.claim(ContestFormScreen.commitClaimId),
      ],
      child: TorchShell(
        profile: TorchShellProfile.console,
        header: TorchAppHeader(
          title: widget.isEditing ? widget.contest!.name : 'New contest',
          facts: <String>[
            widget.isEditing ? 'Editing a contest' : 'A new contest',
          ],
          back: TorchIconButton(
            key: const ValueKey<String>('contest-form-back'),
            icon: Icons.arrow_back,
            semanticLabel: 'Back to Contests',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        primary: TorchPrimaryButton(
          key: const ValueKey<String>('contest-save-button'),
          claimId: ContestFormScreen.commitClaimId,
          label: label,
          busy: _submitting,
          onPressed: _submitting ? null : _submit,
          blockedReason: _submitting ? 'Saving.' : null,
        ),
        children: <Widget>[
          SectionRule('Details'),
          const SizedBox(height: TiqSpace.s5),
          TorchTextField(
            key: const ValueKey<String>('contest-name-field'),
            label: 'Name',
            controller: _nameCtrl,
            error: _nameError,
            maximumLength: 120,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          const SizedBox(height: TiqSpace.s5),
          TorchTextField(
            key: const ValueKey<String>('contest-description-field'),
            label: 'Description',
            help: 'Optional.',
            controller: _descriptionCtrl,
            minLines: 2,
            maximumLines: 4,
          ),
          const SizedBox(height: TiqSpace.s5),
          TorchTextField(
            key: const ValueKey<String>('contest-prize-field'),
            label: 'Prize',
            help: 'Optional. For example: R500 voucher for first place.',
            controller: _prizeCtrl,
          ),

          SizedBox(height: skin.space.blockGap),
          SectionRule('Schedule'),
          const SizedBox(height: TiqSpace.s5),
          _DateRow(
            label: 'Start date',
            value: _fmt(_startDate),
            buttonKey: 'contest-start-date',
            onPressed: () => _pickDate(isStart: true),
          ),
          const SizedBox(height: TiqSpace.s4),
          _DateRow(
            label: 'End date',
            value: _fmt(_endDate),
            buttonKey: 'contest-end-date',
            onPressed: () => _pickDate(isStart: false),
          ),
          const SizedBox(height: TiqSpace.s3),
          if (_dateError != null)
            Text(
              _dateError!,
              key: const ValueKey<String>('contest-date-error'),
              style: skin.text.meta.style(color: skin.palette.bad),
            )
          else
            Text(
              'Both days count in full, in your timezone.',
              style: skin.text.meta.style(color: skin.palette.ink3),
            ),

          SizedBox(height: skin.space.blockGap),
          SectionRule('Who and what counts'),
          const SizedBox(height: TiqSpace.s5),
          _TerritoryField(
            value: _territoryId,
            onChanged: (id) => setState(() => _territoryId = id),
          ),
          const SizedBox(height: TiqSpace.s5),
          _EventTypesField(
            selected: _eventTypes,
            onToggle: (type, on) => setState(
              () => on ? _eventTypes.add(type) : _eventTypes.remove(type),
            ),
          ),

          if (_failure != null) ...<Widget>[
            SizedBox(height: skin.space.intraBlock),
            TorchErrorRegion(
              name: 'contest form',
              child: ErrorState(
                key: const ValueKey<String>('contest-save-error'),
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

/// A date and the way to change it. The date is a figure in mono, the label a
/// word above it, and "Pick" is a ghost — changing a date is not a commit.
class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.buttonKey,
    required this.onPressed,
  });

  final String label;
  final String value;
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
                value,
                style: skin.text.figureS.style(color: skin.palette.ink1),
              ),
            ],
          ),
        ),
        const SizedBox(width: TiqSpace.s3),
        TorchSecondaryButton(
          key: ValueKey<String>(buttonKey),
          label: 'Pick',
          // The button names what it changes: "Pick" alone, repeated twice on
          // one screen, is two identical nodes for a screen reader.
          semanticLabel: 'Pick the ${label.toLowerCase()}',
          onPressed: onPressed,
        ),
      ],
    );
  }
}

/// All territories, or one of the client's. Loading or failing to load the
/// list keeps the current choice rather than silently widening the contest.
class _TerritoryField extends ConsumerWidget {
  const _TerritoryField({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  /// The sentinel for "all territories". `ChoiceRow<String?>` cannot use null
  /// as a value, because null is how it says *nothing is selected*.
  static const String all = '__all__';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = context.skin;
    final territories = ref.watch(territoriesListProvider);
    final list = territories.value ?? const <Territory>[];
    final known = value == null || list.any((t) => t.id == value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ChoiceRow<String>(
          key: const ValueKey<String>('contest-territory-field'),
          label: 'Territory',
          value: known ? (value ?? all) : all,
          options: <ChoiceOption<String>>[
            const ChoiceOption<String>(
              value: all,
              label: 'All territories',
              consequence: 'Every agent in the client takes part.',
            ),
            for (final t in list)
              ChoiceOption<String>(
                value: t.id,
                label: '${t.name} (${t.code})',
                consequence: 'Only agents assigned to it take part.',
              ),
          ],
          onChanged: territories.hasValue
              ? (picked) => onChanged(picked == all ? null : picked)
              : null,
        ),
        if (territories.hasError) ...<Widget>[
          const SizedBox(height: TiqSpace.s3),
          Text(
            'The territory list did not load, so the contest keeps the scope '
            'it has.',
            key: const ValueKey<String>('contest-territory-error'),
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
        ],
      ],
    );
  }
}

/// Which kinds of points count. Nothing ticked counts all of them, and that
/// is a state with a sentence rather than a blank.
class _EventTypesField extends StatelessWidget {
  const _EventTypesField({required this.selected, required this.onToggle});

  final Set<String> selected;
  final void Function(String type, bool on) onToggle;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TorchCheckboxGroup(
          label: 'What counts',
          children: <Widget>[
            for (final type in contestEventTypes)
              TorchCheckbox(
                key: ValueKey<String>('contest-event-$type'),
                label: contestEventWord(type),
                value: selected.contains(type),
                onChanged: (on) => onToggle(type, on),
              ),
          ],
        ),
        const SizedBox(height: TiqSpace.s3),
        Text(
          selected.isEmpty
              ? 'Nothing ticked counts all points. Tick kinds to count only '
                    'those.'
              : 'Counts only the ticked kinds of points.',
          key: const ValueKey<String>('contest-event-note'),
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
      ],
    );
  }
}
