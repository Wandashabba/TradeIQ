import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/human_error.dart';
import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/glass_page_scaffold.dart';
import '../../../core/widgets/lumen_kit.dart';
import '../../territories/data/territories_repository.dart';
import '../data/contests_repository.dart';
import 'contest_labels.dart';

/// Create or edit a contest (#124).
///
/// Every field is editable, dates included. Dates are calendar days, inclusive,
/// in the client's timezone. A new contest defaults to a week starting today,
/// so the common case needs no date picking at all.
class ContestFormScreen extends ConsumerStatefulWidget {
  const ContestFormScreen({super.key, this.contest});

  final Contest? contest;

  bool get isEditing => contest != null;

  @override
  ConsumerState<ContestFormScreen> createState() => _ContestFormScreenState();
}

class _ContestFormScreenState extends ConsumerState<ContestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _prizeCtrl;
  late DateTime _startDate;
  late DateTime _endDate;
  String? _territoryId;
  late final Set<String> _eventTypes;
  bool _submitting = false;

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
    _endDate = (c == null ? null : DateTime.tryParse(c.endDate)) ??
        today.add(const Duration(days: 6));
    _territoryId = c?.territoryId;
    _eventTypes = {...?c?.eventTypes};
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _prizeCtrl.dispose();
    super.dispose();
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() => isStart ? _startDate = picked : _endDate = picked);
  }

  String? _optional(TextEditingController ctrl) {
    final text = ctrl.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_endDate.isBefore(_startDate)) {
      _snack('End date cannot be before the start date.');
      return;
    }

    setState(() => _submitting = true);
    final repo = ref.read(contestsRepositoryProvider);
    final input = ContestInput(
      name: _nameCtrl.text.trim(),
      description: _optional(_descriptionCtrl),
      prizeDescription: _optional(_prizeCtrl),
      startDate: _fmt(_startDate),
      endDate: _fmt(_endDate),
      territoryId: _territoryId,
      // Canonical order, whatever order they were ticked in.
      eventTypes: [
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
    } catch (e) {
      _snack('Failed to save contest. ${humanErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.colors.glass;
    final label = widget.isEditing ? 'Save Changes' : 'Create Contest';

    final nameField = TextFormField(
      key: const ValueKey<String>('contest-name-field'),
      controller: _nameCtrl,
      maxLength: 120,
      decoration: const InputDecoration(
        labelText: 'Name',
        border: OutlineInputBorder(),
      ),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
    final descriptionField = TextFormField(
      key: const ValueKey<String>('contest-description-field'),
      controller: _descriptionCtrl,
      minLines: 2,
      maxLines: 4,
      decoration: const InputDecoration(
        labelText: 'Description (optional)',
        border: OutlineInputBorder(),
      ),
    );
    final prizeField = TextFormField(
      key: const ValueKey<String>('contest-prize-field'),
      controller: _prizeCtrl,
      decoration: const InputDecoration(
        labelText: 'Prize (optional)',
        hintText: 'e.g. R500 voucher for first place',
        border: OutlineInputBorder(),
      ),
    );
    final startRow = _DateRow(
      label: 'Start date',
      value: _fmt(_startDate),
      buttonKey: 'contest-start-date',
      onPressed: () => _pickDate(isStart: true),
    );
    final endRow = _DateRow(
      label: 'End date',
      value: _fmt(_endDate),
      buttonKey: 'contest-end-date',
      onPressed: () => _pickDate(isStart: false),
    );
    final territoryField = _TerritoryField(
      value: _territoryId,
      onChanged: (id) => setState(() => _territoryId = id),
    );
    final eventTypes = _EventTypesField(
      selected: _eventTypes,
      onToggle: (type, on) => setState(
        () => on ? _eventTypes.add(type) : _eventTypes.remove(type),
      ),
    );
    const scheduleNote = _Note(
      'Both days count in full, in your timezone.',
    );

    final sections = <(String, List<Widget>)>[
      ('Details', [
        nameField,
        const SizedBox(height: 8),
        descriptionField,
        const SizedBox(height: 12),
        prizeField,
      ]),
      ('Schedule', [
        startRow,
        const SizedBox(height: 10),
        endRow,
        const SizedBox(height: 6),
        scheduleNote,
      ]),
      ('Who and what counts', [
        territoryField,
        const SizedBox(height: 12),
        eventTypes,
      ]),
    ];

    return GlassPageScaffold(
      title: Text(widget.isEditing ? 'Edit Contest' : 'New Contest'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (title, children) in sections) ...[
                if (glass)
                  _GlassSection(label: title, children: children)
                else ...[
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ...children,
                ],
                const SizedBox(height: 16),
              ],
              if (glass)
                GlassPrimaryButton(
                  key: const ValueKey<String>('contest-save-button'),
                  label: label,
                  busy: _submitting,
                  onPressed: _submit,
                )
              else
                FilledButton(
                  key: const ValueKey<String>('contest-save-button'),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(label),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A glass panel with its kicker — one group of the form.
class _GlassSection extends StatelessWidget {
  const _GlassSection({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassPane(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [Kicker(label), const SizedBox(height: 12), ...children],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final muted =
        context.colors.glass ? context.lumen.inkMuted : context.colors.ink3;
    return Text(text, style: TextStyle(fontSize: 12, color: muted));
  }
}

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
    final glass = context.colors.glass;
    final pick = OutlinedButton(
      key: ValueKey<String>(buttonKey),
      onPressed: onPressed,
      child: const Text('Pick'),
    );
    return Row(
      children: [
        Expanded(
          child: glass
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Kicker(label, size: 9.5),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: LumenGlass.figure(color: context.lumen.ink),
                    ),
                  ],
                )
              : Text('$label: $value'),
        ),
        pick,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final territories = ref.watch(territoriesListProvider);
    final list = territories.value ?? const <Territory>[];
    final known = value == null || list.any((t) => t.id == value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String?>(
          key: const ValueKey<String>('contest-territory-field'),
          initialValue: known ? value : null,
          decoration: const InputDecoration(
            labelText: 'Territory',
            helperText: 'Only agents assigned to it take part',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All territories'),
            ),
            for (final t in list)
              DropdownMenuItem<String?>(
                value: t.id,
                child: Text('${t.name} (${t.code})'),
              ),
          ],
          onChanged: territories.hasValue ? onChanged : null,
        ),
        if (territories.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _Note(
              'Failed to load territories. '
              '${humanErrorMessage(territories.error!)}',
            ),
          ),
      ],
    );
  }
}

class _EventTypesField extends StatelessWidget {
  const _EventTypesField({required this.selected, required this.onToggle});

  final Set<String> selected;
  final void Function(String type, bool on) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Note(
          selected.isEmpty
              ? 'Counts all points. Tick kinds to count only those.'
              : 'Counts only the ticked kinds of points.',
        ),
        for (final type in contestEventTypes)
          Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              key: ValueKey<String>('contest-event-$type'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(contestEventWord(type)),
              value: selected.contains(type),
              onChanged: (on) => onToggle(type, on ?? false),
            ),
          ),
      ],
    );
  }
}
