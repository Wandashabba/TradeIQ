import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/glass_page_scaffold.dart';
import '../../../core/widgets/lumen_kit.dart';
import '../../outlets/data/outlets_repository.dart';
import '../../territories/data/territories_repository.dart';
import '../../users/data/users_repository.dart';
import '../data/beatplans_repository.dart';

/// Manager/admin screen to build and assign a beat plan: pick a field agent, a
/// date, an optional territory, and an ordered list of outlet stops. The order
/// of the selected outlets becomes the stop sequence (`POST /beatplans`).
class BeatPlanFormScreen extends ConsumerStatefulWidget {
  const BeatPlanFormScreen({super.key});

  @override
  ConsumerState<BeatPlanFormScreen> createState() => _BeatPlanFormScreenState();
}

class _BeatPlanFormScreenState extends ConsumerState<BeatPlanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  String? _agentId;
  String? _territoryId;
  DateTime? _scheduledDate;
  final List<String> _selectedOutletIds = <String>[];
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? DateTime(2026, 1, 1),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _scheduledDate = picked);
  }

  void _addOutlet(String id) => setState(() => _selectedOutletIds.add(id));
  void _removeOutlet(String id) =>
      setState(() => _selectedOutletIds.remove(id));

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _selectedOutletIds.length) return;
    setState(() {
      final id = _selectedOutletIds.removeAt(index);
      _selectedOutletIds.insert(target, id);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_agentId == null) {
      _snack('Select a field agent.');
      return;
    }
    if (_scheduledDate == null) {
      _snack('Pick a scheduled date.');
      return;
    }
    if (_selectedOutletIds.isEmpty) {
      _snack('Add at least one outlet stop.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(beatPlansRepositoryProvider).createBeatPlan(
            agentId: _agentId!,
            name: _nameCtrl.text.trim(),
            scheduledDate: _fmt(_scheduledDate!),
            outletIds: List<String>.of(_selectedOutletIds),
            territoryId: _territoryId,
          );
      ref.invalidate(beatPlansListProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _snack('Failed to create beat plan: $e');
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
    final agents = ref.watch(usersListProvider);
    final territories = ref.watch(territoriesListProvider);
    final outlets = ref.watch(outletsListProvider);

    final planFields = <Widget>[
      TextFormField(
        key: const ValueKey<String>('beatplan-name-field'),
        controller: _nameCtrl,
        decoration: const InputDecoration(
            labelText: 'Name', border: OutlineInputBorder()),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      ),
      const SizedBox(height: 12),
      _DateRow(
        value: _scheduledDate == null ? null : _fmt(_scheduledDate!),
        onPressed: _pickDate,
      ),
      const SizedBox(height: 12),
      agents.when(
        loading: () => const LinearProgressIndicator(),
        error: (err, _) => Text('Failed to load agents: $err'),
        data: (list) {
          final fieldAgents =
              list.where((u) => u.role == 'field_agent').toList();
          return DropdownButtonFormField<String>(
            key: const ValueKey<String>('beatplan-agent-field'),
            initialValue: _agentId,
            decoration: const InputDecoration(
                labelText: 'Field agent', border: OutlineInputBorder()),
            items: [
              for (final u in fieldAgents)
                DropdownMenuItem(value: u.id, child: Text(u.label)),
            ],
            onChanged: (v) => setState(() => _agentId = v),
          );
        },
      ),
      const SizedBox(height: 12),
      territories.when(
        loading: () => const LinearProgressIndicator(),
        error: (err, _) => Text('Failed to load territories: $err'),
        data: (list) => DropdownButtonFormField<String>(
          key: const ValueKey<String>('beatplan-territory-field'),
          initialValue: _territoryId,
          decoration: const InputDecoration(
              labelText: 'Territory (optional)', border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem(value: null, child: Text('None')),
            for (final t in list)
              DropdownMenuItem(value: t.id, child: Text(t.name)),
          ],
          onChanged: (v) => setState(() => _territoryId = v),
        ),
      ),
    ];
    final lumen = context.lumen;
    final stops = outlets.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Text('Failed to load outlets: $err'),
      data: (list) => _StopBuilder(
        outlets: list,
        selectedIds: _selectedOutletIds,
        onAdd: _addOutlet,
        onRemove: _removeOutlet,
        onMove: _move,
      ),
    );

    return GlassPageScaffold(
      title: const Text('New Beat Plan'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: context.colors.glass
              // Glass: who works the day and when, then the stops in order.
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _GlassSection(label: 'Plan', children: planFields),
                    const SizedBox(height: 14),
                    _GlassSection(
                      label: 'Stops (in order)',
                      trailing: Text(
                        '${_selectedOutletIds.length} '
                        '${_selectedOutletIds.length == 1 ? 'stop' : 'stops'}',
                        style: LumenGlass.figure(
                          size: 11.5,
                          color: lumen.inkMuted,
                          weight: FontWeight.w500,
                        ),
                      ),
                      children: [stops],
                    ),
                    const SizedBox(height: 18),
                    GlassPrimaryButton(
                      key: const ValueKey<String>('beatplan-save-button'),
                      label: 'Create Beat Plan',
                      busy: _submitting,
                      onPressed: _submit,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...planFields,
                    const SizedBox(height: 20),
                    const Text('Stops (in order)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    stops,
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const ValueKey<String>('beatplan-save-button'),
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Create Beat Plan'),
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

class _DateRow extends StatelessWidget {
  const _DateRow({required this.value, required this.onPressed});

  final String? value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final lumen = context.lumen;
    final pick = OutlinedButton(
      key: const ValueKey<String>('beatplan-date-pick'),
      onPressed: onPressed,
      child: const Text('Pick'),
    );
    if (context.colors.glass) {
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Kicker('Scheduled date', size: 9.5),
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
        Expanded(
          child: Text(value == null ? 'Scheduled date: not set' : 'Scheduled date: $value'),
        ),
        pick,
      ],
    );
  }
}

/// Renders the ordered selection (with reorder/remove) above the pool of
/// outlets still available to add.
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
    Outlet? byId(String id) {
      for (final o in outlets) {
        if (o.id == id) return o;
      }
      return null;
    }

    final available =
        outlets.where((o) => !selectedIds.contains(o.id)).toList();

    if (context.colors.glass) return _glass(context, byId, available);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selectedIds.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No stops yet — add outlets below.'),
          )
        else
          for (var i = 0; i < selectedIds.length; i++)
            ListTile(
              key: ValueKey<String>('stop-selected-${selectedIds[i]}'),
              dense: true,
              leading: CircleAvatar(radius: 12, child: Text('${i + 1}')),
              title: Text(byId(selectedIds[i])?.name ?? selectedIds[i]),
              trailing: _reorderControls(i),
            ),
        const Divider(),
        const Text('Available outlets'),
        for (final o in available)
          ListTile(
            key: ValueKey<String>('stop-available-${o.id}'),
            dense: true,
            title: Text(o.name),
            subtitle: Text(o.code),
            trailing: const Icon(Icons.add_circle_outline),
            onTap: () => onAdd(o.id),
          ),
      ],
    );
  }

  Widget _reorderControls(int i) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            tooltip: 'Move up',
            onPressed: i == 0 ? null : () => onMove(i, -1),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward),
            tooltip: 'Move down',
            onPressed: i == selectedIds.length - 1 ? null : () => onMove(i, 1),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: 'Remove',
            onPressed: () => onRemove(selectedIds[i]),
          ),
        ],
      );

  /// Glass: each stop is a no-blur tile led by its sequence in a status tile
  /// (a count, so mono), and the pool below is a second run of tiles. Each
  /// tile carries its own transparent Material so the ink lands on the pane.
  Widget _glass(
    BuildContext context,
    Outlet? Function(String id) byId,
    List<Outlet> available,
  ) {
    final lumen = context.lumen;
    Widget tile(Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassPane(
            kind: GlassKind.tile,
            blur: false,
            shadow: false,
            radius: LumenGlass.radiusControl,
            child: Material(type: MaterialType.transparency, child: child),
          ),
        );
    final titleStyle = TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      color: lumen.ink,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selectedIds.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'No stops yet — add outlets below.',
              style: TextStyle(fontSize: 13, color: lumen.inkMuted),
            ),
          )
        else
          for (var i = 0; i < selectedIds.length; i++)
            tile(
              ListTile(
                key: ValueKey<String>('stop-selected-${selectedIds[i]}'),
                dense: true,
                leading: StatusTile(
                  status: LumenStatus.none,
                  glyph: '${i + 1}',
                  size: 28,
                  mono: true,
                ),
                title: Text(
                  byId(selectedIds[i])?.name ?? selectedIds[i],
                  style: titleStyle,
                ),
                trailing: _reorderControls(i),
              ),
            ),
        const SizedBox(height: 8),
        const Kicker('Available outlets', size: 9.5),
        const SizedBox(height: 10),
        for (final o in available)
          tile(
            ListTile(
              key: ValueKey<String>('stop-available-${o.id}'),
              dense: true,
              title: Text(o.name, style: titleStyle),
              subtitle: Text(
                o.code,
                style: LumenGlass.figure(
                  size: 11,
                  color: lumen.inkMuted,
                  weight: FontWeight.w500,
                ),
              ),
              trailing: Icon(
                Icons.add_circle_outline,
                color: lumen.accentInk,
              ),
              onTap: () => onAdd(o.id),
            ),
          ),
      ],
    );
  }
}
