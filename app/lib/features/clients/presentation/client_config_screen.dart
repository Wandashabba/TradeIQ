import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dio/dio.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../data/clients_repository.dart';
import '../data/iana_time_zones.dart';

class ClientConfigScreen extends ConsumerWidget {
  const ClientConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(clientConfigProvider);

    return ManagerScaffold(
      title: 'Scoring Config',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AsyncSection<ClientConfig>(
            value: config,
            label: 'config',
            onRetry: () => ref.invalidate(clientConfigProvider),
            builder: (cfg) => _ConfigForm(config: cfg),
          ),
        ],
      ),
    );
  }
}

class _ConfigForm extends ConsumerStatefulWidget {
  const _ConfigForm({required this.config});

  final ClientConfig config;

  @override
  ConsumerState<_ConfigForm> createState() => _ConfigFormState();
}

class _ConfigFormState extends ConsumerState<_ConfigForm> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    widget.config.scorecardWeights.forEach((key, value) {
      _controllers[key] = TextEditingController(text: value.toString())
        // The share column has to move as you type, or the weights are just
        // opaque numbers.
        ..addListener(() => setState(() {}));
    });
  }

  Future<void> _submit() async {
    final map = <String, double>{};
    _controllers.forEach((key, controller) {
      map[key] = double.tryParse(controller.text) ?? 0;
    });

    // A failed save must not take the app down. Before this, a 403 from the
    // admin-only endpoint escaped as an unhandled DioException and crashed the
    // screen — after showing a manager an editable form they were never allowed
    // to submit.
    try {
      await ref.read(clientsRepositoryProvider).updateWeights(map);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
      ref.invalidate(clientConfigProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeSaveFailure(e))),
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double _weightOf(String key) =>
      double.tryParse(_controllers[key]!.text) ?? 0;

  /// The server scores with `weightedSum / weightSum`, so the weights are
  /// *relative* — they do not have to add up to 1. What actually matters is
  /// each dimension's share of the total, which is what we show.
  double get _total => _controllers.keys
      .map(_weightOf)
      .where((w) => w > 0)
      .fold(0.0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final total = _total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TimezonePanel(timezone: widget.config.timezone),
        const SizedBox(height: 16),
        _WorkingHoursPanel(config: widget.config),
        const SizedBox(height: 16),
        PanelCard(
          title: 'Scorecard weights',
          subtitle: 'Relative — the server normalises by their total',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Expanded(flex: 5, child: SectionLabel('Dimension')),
                  Expanded(flex: 3, child: SectionLabel('Weight')),
                  Expanded(flex: 3, child: SectionLabel('Share of score')),
                ],
              ),
              const SizedBox(height: 8),
              for (final entry in _controllers.entries)
                _WeightRow(
                  dimension: entry.key,
                  controller: entry.value,
                  weight: _weightOf(entry.key),
                  total: total,
                  // A field you can type into but never save is worse than one
                  // you cannot type into at all.
                  enabled: canEditConfig(ref),
                ),
              const SizedBox(height: 14),
              // PATCH /clients/me is admin-only. A manager who filled this form
              // in used to get a 403 — as an unhandled exception, which crashed
              // the screen. They can read it (it explains their own scores);
              // they simply cannot save it.
              if (canEditConfig(ref))
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton(
                    key: const ValueKey<String>('save-config'),
                    onPressed: _submit,
                    child: const Text('Save'),
                  ),
                )
              else
                const ReadOnlyNotice(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Weights are relative, not percentages: the score is the weighted '
          'average divided by the total weight, so doubling every weight changes '
          'nothing. A dimension weighted 0 is dropped from the score entirely.',
          style:
              TextStyle(fontSize: 11.5, color: context.colors.ink3, height: 1.5),
        ),
        const SizedBox(height: 16),
        _ThresholdsPanel(thresholds: widget.config.kpiThresholds),
      ],
    );
  }
}

/// The client's timezone (#309) — the calendar every day-based rule counts in.
///
/// Shown to anyone who can open the screen; changeable by a manager or an
/// admin. Picked from a list rather than typed, because the server accepts only
/// exact canonical IANA names and a free-text box would mostly produce 400s.
class _TimezonePanel extends ConsumerStatefulWidget {
  const _TimezonePanel({required this.timezone});

  final String timezone;

  @override
  ConsumerState<_TimezonePanel> createState() => _TimezonePanelState();
}

class _TimezonePanelState extends ConsumerState<_TimezonePanel> {
  bool _saving = false;

  Future<void> _change() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => _TimezonePickerDialog(current: widget.timezone),
    );
    if (picked == null || picked == widget.timezone || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref.read(clientsRepositoryProvider).updateTimezone(picked);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Timezone set to $picked')),
      );
      ref.invalidate(clientConfigProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            describeSaveFailure(
              e,
              forbidden:
                  'Only a manager or administrator can change the timezone.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final canEdit = canEditTimezone(ref);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelCard(
          title: 'Timezone',
          subtitle: "The calendar your team's days are counted in",
          child: Container(
            key: const ValueKey<String>('timezone-current'),
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
            // Same ground as the read-only notice: opaque surface2, so the zone
            // name measures true; only the hairline becomes the pane rim.
            decoration: BoxDecoration(
              color: colors.surface2,
              border: Border.all(
                color: colors.glass ? context.lumen.panelRim : colors.lineStrong,
              ),
              borderRadius: BorderRadius.circular(
                colors.glass ? LumenGlass.radiusControl : AppColors.radiusControl,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule_outlined, size: 16, color: colors.ink3),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      widget.timezone,
                      key: const ValueKey<String>('timezone-value'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.ink1,
                      ),
                    ),
                  ),
                ),
                if (canEdit)
                  TextButton(
                    key: const ValueKey<String>('change-timezone'),
                    onPressed: _saving ? null : _change,
                    child: Text(_saving ? 'Saving…' : 'Change'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Decides which day a check-in counts toward — a visit at 00:30 belongs '
          "to that morning's route, not yesterday's — and where trend days and "
          'weeks begin. A change applies to trends straight away; stops already '
          'ticked on past routes stay as they are.',
          style: TextStyle(fontSize: 11.5, color: colors.ink3, height: 1.5),
        ),
      ],
    );
  }
}

/// The team's working hours (#153 T2) — the window background location
/// tracking is allowed to run in, on the clock of the timezone above.
///
/// Changeable by a manager or an admin, like the timezone and for the same
/// reason: when the team works is a fact about the team, not a scoring policy.
///
/// It is stated plainly on the panel that this is not a shift model and not
/// attendance, because a field called "working hours" in a field-sales product
/// will otherwise be read as both. Nothing is scored against it and no agent is
/// measured by it; it exists only to put an outer boundary on tracking.
class _WorkingHoursPanel extends ConsumerStatefulWidget {
  const _WorkingHoursPanel({required this.config});

  final ClientConfig config;

  @override
  ConsumerState<_WorkingHoursPanel> createState() => _WorkingHoursPanelState();
}

class _WorkingHoursPanelState extends ConsumerState<_WorkingHoursPanel> {
  bool _saving = false;

  Future<void> _change() async {
    final picked = await showDialog<({String start, String end, List<int> days})>(
      context: context,
      builder: (_) => _WorkingHoursDialog(config: widget.config),
    );
    if (picked == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(clientsRepositoryProvider)
          .updateWorkingHours(
            start: picked.start,
            end: picked.end,
            days: picked.days,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Working hours saved')),
      );
      ref.invalidate(clientConfigProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            describeSaveFailure(
              e,
              forbidden:
                  'Only a manager or administrator can change working hours.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Same split as the timezone: managers as well as admins.
    final canEdit = canEditTimezone(ref);
    final config = widget.config;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelCard(
          title: 'Working hours',
          subtitle: 'The only hours background location tracking may run in',
          child: Container(
            key: const ValueKey<String>('working-hours-current'),
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
            decoration: BoxDecoration(
              color: colors.surface2,
              border: Border.all(
                color: colors.glass ? context.lumen.panelRim : colors.lineStrong,
              ),
              borderRadius: BorderRadius.circular(
                colors.glass ? LumenGlass.radiusControl : AppColors.radiusControl,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.route_outlined, size: 16, color: colors.ink3),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${config.workHoursStart} – ${config.workHoursEnd}',
                          key: const ValueKey<String>('working-hours-value'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.ink1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          describeWorkDays(config.workDays),
                          key: const ValueKey<String>('working-days-value'),
                          style: TextStyle(fontSize: 11, color: colors.ink3),
                        ),
                      ],
                    ),
                  ),
                ),
                if (canEdit)
                  TextButton(
                    key: const ValueKey<String>('change-working-hours'),
                    onPressed: _saving ? null : _change,
                    child: Text(_saving ? 'Saving…' : 'Change'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Read by one thing only: an agent who has switched on background '
          'route tracking is tracked inside this window and at no other time — '
          'never at night, never at a weekend. It is not a shift model and not '
          'attendance: nothing is scored against it and no agent is measured by '
          'it. The times are read on the clock of the timezone above '
          '(${config.timezone}), and the end time is exclusive — a point '
          'recorded at exactly ${config.workHoursEnd} is outside the window.',
          style: TextStyle(fontSize: 11.5, color: colors.ink3, height: 1.5),
        ),
      ],
    );
  }
}

/// The working days in words: "Monday to Friday" when they run together,
/// otherwise the list. A manager should be able to check this at a glance
/// rather than decode `[1, 2, 3, 4, 5]`.
String describeWorkDays(List<int> days) {
  final sorted = [...days]..sort();
  if (sorted.isEmpty) return 'No days';
  if (sorted.length == 7) return 'Every day';
  final runsTogether = sorted.last - sorted.first == sorted.length - 1;
  if (runsTogether && sorted.length > 2) {
    return '${weekdayNames[sorted.first]} to ${weekdayNames[sorted.last]}';
  }
  return sorted.map((d) => weekdayNames[d]).join(', ');
}

/// Validates an edit the way the server does, so a manager is told what is
/// wrong before a round trip rather than after one.
String? validateWorkingHoursEdit({
  required String start,
  required String end,
  required List<int> days,
}) {
  final startMinutes = parseWallClock(start);
  final endMinutes = parseWallClock(end);
  if (startMinutes == null) return 'Start must be a 24-hour time like 07:00.';
  if (endMinutes == null) return 'End must be a 24-hour time like 17:00.';
  if (startMinutes >= endMinutes) {
    return 'Start must be before end on the same day.';
  }
  if (days.isEmpty) return 'Pick at least one working day.';
  return null;
}

/// `HH:MM` as minutes since midnight, or null. Mirrors the server exactly —
/// `7:00` and `07:00:00` are refused there, so they are refused here.
int? parseWallClock(String value) {
  final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(value.trim());
  if (match == null) return null;
  return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
}

class _WorkingHoursDialog extends StatefulWidget {
  const _WorkingHoursDialog({required this.config});

  final ClientConfig config;

  @override
  State<_WorkingHoursDialog> createState() => _WorkingHoursDialogState();
}

class _WorkingHoursDialogState extends State<_WorkingHoursDialog> {
  late final TextEditingController _start = TextEditingController(
    text: widget.config.workHoursStart,
  );
  late final TextEditingController _end = TextEditingController(
    text: widget.config.workHoursEnd,
  );
  late final Set<int> _days = {...widget.config.workDays};
  String? _error;

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  void _save() {
    final days = _days.toList()..sort();
    final error = validateWorkingHoursEdit(
      start: _start.text.trim(),
      end: _end.text.trim(),
      days: days,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop((
      start: _start.text.trim(),
      end: _end.text.trim(),
      days: days,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AlertDialog(
      title: const Text('Working hours'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey<String>('work-hours-start'),
                    controller: _start,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Start',
                      hintText: '07:00',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const ValueKey<String>('work-hours-end'),
                    controller: _end,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'End (exclusive)',
                      hintText: '17:00',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const SectionLabel('Working days'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var day = 1; day <= 7; day++)
                  FilterChip(
                    key: ValueKey<String>('work-day-$day'),
                    label: Text(weekdayNames[day].substring(0, 3)),
                    selected: _days.contains(day),
                    onSelected: (on) => setState(() {
                      if (on) {
                        _days.add(day);
                      } else {
                        _days.remove(day);
                      }
                      _error = null;
                    }),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const ValueKey<String>('work-hours-error'),
                // critText, not crit: crit is a mark colour and does not clear
                // 4.5:1 when it has to carry words.
                style: TextStyle(fontSize: 12, color: colors.critText),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey<String>('save-working-hours'),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Zones offered above the full list. Johannesburg leads: it is where every
/// current field team works, and the zone a new client starts in.
const suggestedTimeZones = <String>[defaultClientTimeZone];

/// The picker's two sections for a search [query].
///
/// With no query, [suggested] holds [suggestedTimeZones] followed by [current]
/// (when it is not already one of them), and [all] holds every other zone, so
/// nothing is listed twice. With a query, matching is case-insensitive and
/// treats a space as the underscore IANA names use ("new york" finds
/// `America/New_York`); [suggested] is empty and any suggested zone that
/// matches leads [all].
({List<String> suggested, List<String> all}) timezoneOptions(
  String query, {
  required String current,
}) {
  final needle = query.trim().toLowerCase().replaceAll(' ', '_');
  if (needle.isEmpty) {
    final suggested = <String>[
      ...suggestedTimeZones,
      if (!suggestedTimeZones.contains(current)) current,
    ];
    return (
      suggested: suggested,
      all: [
        for (final zone in ianaTimeZones)
          if (!suggested.contains(zone)) zone,
      ],
    );
  }
  final matches = [
    for (final zone in ianaTimeZones)
      if (zone.toLowerCase().contains(needle)) zone,
  ];
  return (
    suggested: const [],
    all: [
      for (final zone in suggestedTimeZones)
        if (matches.contains(zone)) zone,
      for (final zone in matches)
        if (!suggestedTimeZones.contains(zone)) zone,
    ],
  );
}

class _TimezonePickerDialog extends StatefulWidget {
  const _TimezonePickerDialog({required this.current});

  final String current;

  @override
  State<_TimezonePickerDialog> createState() => _TimezonePickerDialogState();
}

class _TimezonePickerDialogState extends State<_TimezonePickerDialog> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final options = timezoneOptions(_search.text, current: widget.current);
    // Headers and zones in one lazily built list: there are ~420 zones, and
    // building every row up front for a dialog most people search is waste.
    final rows = <Object>[
      if (options.suggested.isNotEmpty) ...[
        const _PickerHeader('Suggested'),
        ...options.suggested,
        const _PickerHeader('All timezones'),
      ],
      ...options.all,
    ];

    return AlertDialog(
      title: const Text('Choose timezone'),
      content: SizedBox(
        width: 440,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey<String>('timezone-search'),
              controller: _search,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 18),
                hintText: 'Search — e.g. Johannesburg, New York',
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: options.all.isEmpty && options.suggested.isEmpty
                  ? Center(
                      child: Text(
                        'No timezone matches "${_search.text.trim()}".',
                        key: const ValueKey<String>('timezone-no-match'),
                        style: TextStyle(fontSize: 12.5, color: colors.ink3),
                      ),
                    )
                  : ListView.builder(
                      key: const ValueKey<String>('timezone-options'),
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        if (row is _PickerHeader) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                            child: SectionLabel(row.label),
                          );
                        }
                        final zone = row as String;
                        return _ZoneRow(
                          zone: zone,
                          selected: zone == widget.current,
                          onTap: () => Navigator.of(context).pop(zone),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _PickerHeader {
  const _PickerHeader(this.label);
  final String label;
}

class _ZoneRow extends StatelessWidget {
  const _ZoneRow({
    required this.zone,
    required this.selected,
    required this.onTap,
  });

  final String zone;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // The place a manager recognises first, the exact IANA name under it.
    final place = zone.split('/').last.replaceAll('_', ' ');

    return InkWell(
      key: ValueKey<String>('timezone-option-$zone'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          // Glass rule is the pane rim — see _WeightRow.
          border: Border(
            top: BorderSide(
              color: colors.glass ? context.lumen.panelRim : colors.line,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place, style: TextStyle(fontSize: 13, color: colors.ink1)),
                  if (place != zone) ...[
                    const SizedBox(height: 2),
                    Text(
                      zone,
                      style: TextStyle(fontSize: 11, color: colors.ink3),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              Icon(
                Icons.check,
                key: const ValueKey<String>('timezone-selected'),
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

/// The four KPI thresholds the engine reads. Two set the scorecard's RAG bands;
/// two decide when a capture opens a task on its own.
class _ThresholdsPanel extends ConsumerStatefulWidget {
  const _ThresholdsPanel({required this.thresholds});

  final Map<String, double> thresholds;

  @override
  ConsumerState<_ThresholdsPanel> createState() => _ThresholdsPanelState();
}

class _ThresholdsPanelState extends ConsumerState<_ThresholdsPanel> {
  late final Map<KpiThreshold, TextEditingController> _controllers = {
    for (final t in KpiThreshold.values)
      t: TextEditingController(
        text: (widget.thresholds[t.key] ?? t.fallback).toString(),
      ),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final map = <String, double>{};
    _controllers.forEach((threshold, controller) {
      final parsed = double.tryParse(controller.text.trim());
      // A blank or unparseable box must not silently become 0 — that would turn
      // "leave it alone" into "never trigger". Fall back to what the engine
      // already uses.
      map[threshold.key] = parsed ?? threshold.fallback;
    });

    try {
      await ref.read(clientsRepositoryProvider).updateThresholds(map);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
      ref.invalidate(clientConfigProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeSaveFailure(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelCard(
          title: 'KPI thresholds',
          subtitle: 'What counts as green, and what opens a task',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final t in KpiThreshold.values)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    // Glass rule is the pane rim — see _WeightRow.
                    border: Border(
                      top: BorderSide(
                        color: colors.glass
                            ? context.lumen.panelRim
                            : colors.line,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.label,
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.ink1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t.help,
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.ink3,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          key: ValueKey<String>('threshold-${t.key}'),
                          controller: _controllers[t],
                          enabled: canEditConfig(ref),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            isDense: true,
                            suffixText: t.suffix.isEmpty ? null : t.suffix,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              // Only an admin may PATCH /clients/me. Do not offer a manager a
              // button that can only ever 403 at them.
              if (canEditConfig(ref))
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton(
                    key: const ValueKey<String>('save-thresholds'),
                    onPressed: _submit,
                    child: const Text('Save thresholds'),
                  ),
                )
              else
                const ReadOnlyNotice(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'These four keys are the whole contract — the engine reads nothing '
          'else. Changing a band re-grades new scorecards only; it does not '
          'retroactively re-score past visits.',
          style: TextStyle(fontSize: 11.5, color: colors.ink3, height: 1.5),
        ),
      ],
    );
  }
}

class _WeightRow extends StatelessWidget {
  const _WeightRow({
    required this.dimension,
    required this.controller,
    required this.weight,
    required this.total,
    this.enabled = true,
  });

  final String dimension;
  final TextEditingController controller;
  final double weight;
  final double total;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final excluded = weight <= 0;
    final share = (excluded || total <= 0) ? 0.0 : (weight / total) * 100;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        // Glass rules are the pane's own rim — a grey hairline reads as dirt
        // on a lit pane.
        border: Border(
          top: BorderSide(
            color: colors.glass ? context.lumen.panelRim : colors.line,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              _humanise(dimension),
              style: TextStyle(fontSize: 13, color: colors.ink1),
            ),
          ),
          Expanded(
            flex: 3,
            child: TextField(
              key: ValueKey<String>('weight-$dimension'),
              controller: controller,
              enabled: enabled,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(isDense: true),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              // A dropped dimension is stated in words, not implied by a 0.
              child: excluded
                  ? const StatusChip(label: 'Excluded', level: StatusLevel.warning)
                  : Text(
                      '${share.toStringAsFixed(1)}%',
                      style: colors.glass
                          ? LumenGlass.figure(size: 13, color: colors.ink1)
                          : TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.ink1,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  static String _humanise(String key) {
    final spaced = key.replaceAllMapped(
      RegExp('([a-z])([A-Z])'),
      (m) => '${m[1]} ${m[2]!.toLowerCase()}',
    );
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}

/// Whether the signed-in user may actually change the scoring config.
///
/// `PATCH /clients/me` is `requireRole('admin')`. A manager can *read* the
/// config — they should, it explains their own scores — but offering them a Save
/// button they can never use is a trap: it fails with a 403 after they have done
/// the work of filling the form in.
bool canEditConfig(WidgetRef ref) =>
    ref.watch(sessionControllerProvider).value?.role == 'admin';

/// Whether the signed-in user may change the client's timezone.
///
/// Wider than [canEditConfig]: `PATCH /clients/me` accepts `timezone` from a
/// manager too (#309), while weights and thresholds stay admin-only.
bool canEditTimezone(WidgetRef ref) {
  final role = ref.watch(sessionControllerProvider).value?.role;
  return role == 'manager' || role == 'admin';
}

/// A save failure in words a human can act on, rather than a stack trace.
///
/// [forbidden] is what a 403 means for the thing being saved.
String describeSaveFailure(
  Object error, {
  String forbidden = 'Only an administrator can change scoring config.',
}) {
  if (error is DioException && error.response?.statusCode == 403) {
    return forbidden;
  }
  if (error is DioException && error.response?.statusCode == 400) {
    final message = error.response?.data;
    if (message is Map && message['error'] is String) {
      return message['error'] as String;
    }
    return 'The server rejected those values.';
  }
  return 'Could not save: $error';
}

/// Shown to a manager in place of the controls they cannot use.
class ReadOnlyNotice extends StatelessWidget {
  const ReadOnlyNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      key: const ValueKey<String>('read-only-notice'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      // Glass keeps the opaque surface2 ground, so the ink3 words still
      // measure true; only the hairline turns into the pane rim.
      decoration: BoxDecoration(
        color: colors.surface2,
        border: Border.all(
          color: colors.glass ? context.lumen.panelRim : colors.lineStrong,
        ),
        borderRadius: BorderRadius.circular(
          colors.glass ? LumenGlass.radiusControl : AppColors.radiusControl,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 15, color: colors.ink3),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Read-only. Only an administrator can change scoring config — '
              'these figures are shown because they explain your scores.',
              style: TextStyle(
                fontSize: 12,
                color: colors.ink3,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
