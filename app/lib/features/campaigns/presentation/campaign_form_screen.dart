import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/glass_page_scaffold.dart';
import '../../../core/widgets/lumen_kit.dart';
import '../../outlets/data/outlets_repository.dart';
import '../data/campaigns_repository.dart';

/// Create or edit a campaign.
///
/// Create mode (campaign == null) collects name, objective, budget, a start/end
/// date range and an outlet multi-select. Edit mode reuses name/objective/budget
/// and adds a status control; the backend `PATCH /campaigns/:id` does not accept
/// date or outlet changes, so those are shown read-only.
class CampaignFormScreen extends ConsumerStatefulWidget {
  const CampaignFormScreen({super.key, this.campaign});

  final Campaign? campaign;

  bool get isEditing => campaign != null;

  @override
  ConsumerState<CampaignFormScreen> createState() => _CampaignFormScreenState();
}

class _CampaignFormScreenState extends ConsumerState<CampaignFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _objectiveCtrl;
  late final TextEditingController _budgetCtrl;

  DateTime? _startDate;
  DateTime? _endDate;
  final Set<String> _selectedOutletIds = <String>{};
  late String _status;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final c = widget.campaign;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _objectiveCtrl = TextEditingController(text: c?.objective ?? '');
    _budgetCtrl =
        TextEditingController(text: c?.budget != null ? '${c!.budget}' : '');
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
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
    });
  }

  double? _parsedBudget() {
    final raw = _budgetCtrl.text.trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Create-only invariants: both dates required, end not before start.
    if (!widget.isEditing) {
      if (_startDate == null || _endDate == null) {
        _snack('Start and end dates are required.');
        return;
      }
      if (_endDate!.isBefore(_startDate!)) {
        _snack('End date cannot be before the start date.');
        return;
      }
    }

    setState(() => _submitting = true);
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
          outletIds:
              _selectedOutletIds.isEmpty ? null : _selectedOutletIds.toList(),
        );
      }
      ref.invalidate(campaignsListProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _snack('Failed to save campaign: $e');
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
    final nameField = TextFormField(
      key: const ValueKey<String>('campaign-name-field'),
      controller: _nameCtrl,
      decoration: const InputDecoration(
          labelText: 'Name', border: OutlineInputBorder()),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
    final objectiveField = TextFormField(
      controller: _objectiveCtrl,
      decoration: const InputDecoration(
          labelText: 'Objective (optional)', border: OutlineInputBorder()),
    );
    final budgetField = TextFormField(
      controller: _budgetCtrl,
      decoration: const InputDecoration(
          labelText: 'Budget (optional)',
          prefixText: 'R ',
          border: OutlineInputBorder()),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      validator: (v) {
        final raw = v?.trim() ?? '';
        if (raw.isEmpty) return null;
        return double.tryParse(raw) == null ? 'Invalid number' : null;
      },
    );
    final statusField = _StatusField(
      value: _status,
      onChanged: (v) => setState(() => _status = v),
    );
    final startRow = _DateRow(
      label: 'Start date',
      value: _startDate == null ? null : _fmt(_startDate!),
      buttonKey: 'campaign-start-date',
      onPressed: () => _pickDate(isStart: true),
    );
    final endRow = _DateRow(
      label: 'End date',
      value: _endDate == null ? null : _fmt(_endDate!),
      buttonKey: 'campaign-end-date',
      onPressed: () => _pickDate(isStart: false),
    );
    final outletSelect = _OutletMultiSelect(
      selected: _selectedOutletIds,
      onToggle: (id, on) => setState(() {
        if (on) {
          _selectedOutletIds.add(id);
        } else {
          _selectedOutletIds.remove(id);
        }
      }),
    );
    final lumen = context.lumen;
    final label = widget.isEditing ? 'Save Changes' : 'Create Campaign';

    return GlassPageScaffold(
      title: Text(widget.isEditing ? 'Edit Campaign' : 'New Campaign',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: context.colors.glass
              // Glass: the same controls, grouped into panels — what the
              // campaign is, when it runs (or its status), and where.
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _GlassSection(
                      label: 'Details',
                      children: [
                        nameField,
                        const SizedBox(height: 12),
                        objectiveField,
                        const SizedBox(height: 12),
                        budgetField,
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (widget.isEditing)
                      _GlassSection(label: 'Status', children: [statusField])
                    else ...[
                      _GlassSection(
                        label: 'Schedule',
                        children: [startRow, const SizedBox(height: 10), endRow],
                      ),
                      const SizedBox(height: 14),
                      _GlassSection(
                        label: 'Outlets',
                        trailing: Text(
                          '${_selectedOutletIds.length} selected',
                          style: LumenGlass.figure(
                            size: 11.5,
                            color: lumen.inkMuted,
                            weight: FontWeight.w500,
                          ),
                        ),
                        children: [outletSelect],
                      ),
                    ],
                    const SizedBox(height: 18),
                    GlassPrimaryButton(
                      key: const ValueKey<String>('campaign-save-button'),
                      label: label,
                      busy: _submitting,
                      onPressed: _submit,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    nameField,
                    const SizedBox(height: 12),
                    objectiveField,
                    const SizedBox(height: 12),
                    budgetField,
                    const SizedBox(height: 16),
                    if (widget.isEditing)
                      statusField
                    else ...[
                      startRow,
                      const SizedBox(height: 8),
                      endRow,
                      const SizedBox(height: 16),
                      const Text('Outlets',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      outletSelect,
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const ValueKey<String>('campaign-save-button'),
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
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
  const _GlassSection({
    required this.label,
    required this.children,
    this.trailing,
  });

  final String label;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GlassPane(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [Kicker(label), const Spacer(), ?trailing]),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _StatusField extends StatelessWidget {
  const _StatusField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: const ValueKey<String>('campaign-status-field'),
      initialValue: value,
      decoration: const InputDecoration(
          labelText: 'Status', border: OutlineInputBorder()),
      items: const [
        DropdownMenuItem(value: 'draft', child: Text('Draft')),
        DropdownMenuItem(value: 'active', child: Text('Active')),
        DropdownMenuItem(value: 'completed', child: Text('Completed')),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
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
  final String? value;
  final String buttonKey;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final lumen = context.lumen;
    final pick = OutlinedButton(
      key: ValueKey<String>(buttonKey),
      onPressed: onPressed,
      child: const Text('Pick'),
    );
    if (context.colors.glass) {
      // Glass: the label as a kicker over the date as a figure — or the words
      // "Not set", never a blank.
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Kicker(label, size: 9.5),
                const SizedBox(height: 4),
                value == null
                    ? Text(
                        'Not set',
                        style: TextStyle(
                          fontSize: 13,
                          color: lumen.inkMuted,
                        ),
                      )
                    : Text(value!, style: LumenGlass.figure(color: lumen.ink)),
              ],
            ),
          ),
          pick,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: Text(value == null ? '$label: not set' : '$label: $value')),
        pick,
      ],
    );
  }
}

class _OutletMultiSelect extends ConsumerWidget {
  const _OutletMultiSelect({required this.selected, required this.onToggle});

  final Set<String> selected;
  final void Function(String id, bool on) onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outlets = ref.watch(outletsListProvider);
    final glass = context.colors.glass;
    final lumen = context.lumen;
    return outlets.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Failed to load outlets: $err'),
      ),
      data: (list) => Column(
        children: [
          for (final outlet in list)
            if (glass)
              // A no-blur tile per outlet, with its own transparent Material
              // so the tile's ink lands on top of the pane, not behind it.
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassPane(
                  kind: GlassKind.tile,
                  blur: false,
                  shadow: false,
                  radius: LumenGlass.radiusControl,
                  child: Material(
                    type: MaterialType.transparency,
                    child: CheckboxListTile(
                      key: ValueKey<String>('outlet-option-${outlet.id}'),
                      dense: true,
                      title: Text(
                        outlet.name,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: lumen.ink,
                        ),
                      ),
                      subtitle: Text(
                        outlet.code,
                        style: LumenGlass.figure(
                          size: 11,
                          color: lumen.inkMuted,
                          weight: FontWeight.w500,
                        ),
                      ),
                      value: selected.contains(outlet.id),
                      onChanged: (on) => onToggle(outlet.id, on ?? false),
                    ),
                  ),
                ),
              )
            else
              CheckboxListTile(
                key: ValueKey<String>('outlet-option-${outlet.id}'),
                dense: true,
                title: Text(outlet.name),
                subtitle: Text(outlet.code),
                value: selected.contains(outlet.id),
                onChanged: (on) => onToggle(outlet.id, on ?? false),
              ),
        ],
      ),
    );
  }
}
