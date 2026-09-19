import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../data/outlets_repository.dart';

/// One outlet, and the screen where a wrong pin gets fixed (#386).
///
/// Until this existed an outlet's coordinates were write-once, taken from
/// wherever the manager's phone happened to be when they submitted the create
/// form. Forty stores onboarded during a Monday planning session at the depot
/// were forty stores pinned to the depot car park, and the agent standing
/// inside one of them on Tuesday measured 8.4 km with nothing to press but
/// Retry — because the outlets screen listed and created, and the backend
/// exposed only GET and POST.
///
/// **No map picker, on purpose.** #386's own ruling is that manual entry plus
/// the attempt evidence covers it, and the evidence is the better half of
/// that: a manager guessing at a map tile is guessing, while an agent's
/// recorded position is where somebody actually stood holding the phone.
///
/// Deliberately plain. Every widget here is one the app already has, because a
/// later pass restyles these screens and inventing a look now would only have
/// to be undone.
class OutletDetailScreen extends ConsumerWidget {
  const OutletDetailScreen({super.key, required this.outletId});

  final String outletId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(outletDetailProvider(outletId));
    return ManagerScaffold(
      title: 'Outlet',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AsyncSection<OutletDetail>(
            value: detail,
            label: 'this outlet',
            onRetry: () => ref.invalidate(outletDetailProvider(outletId)),
            builder: (data) => _OutletDetailBody(detail: data),
          ),
        ],
      ),
    );
  }
}

class _OutletDetailBody extends ConsumerStatefulWidget {
  const _OutletDetailBody({required this.detail});

  final OutletDetail detail;

  @override
  ConsumerState<_OutletDetailBody> createState() => _OutletDetailBodyState();
}

class _OutletDetailBodyState extends ConsumerState<_OutletDetailBody> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  late String _status;

  /// The check-in attempt whose position the manager chose to adopt, or null
  /// when they are typing coordinates in themselves.
  ///
  /// The two are exclusive because the backend makes them exclusive: a PATCH
  /// carrying both a typed pair and an attempt id is a 400, so that the audit
  /// trail cannot say "moved to the agent's recorded position" beside numbers
  /// that were never any agent's position.
  String? _fromAttemptId;

  /// The claim this edit answers, when the manager came here to answer one.
  String? _disputeId;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final o = widget.detail.outlet;
    _nameCtrl = TextEditingController(text: o.name);
    _latCtrl = TextEditingController(text: o.lat.toString());
    _lngCtrl = TextEditingController(text: o.lng.toString());
    _status = o.status;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  /// Adopt an agent's recorded position as the new pin.
  ///
  /// The coordinates are shown so the manager can see what they are about to
  /// agree to, but they are NOT what gets sent: the request carries the
  /// attempt id and the server reads the numbers out of that row itself.
  void _useAttempt(CheckInAttemptEvidence attempt, {String? disputeId}) {
    setState(() {
      _fromAttemptId = attempt.id;
      _disputeId = disputeId ?? _disputeId;
      _latCtrl.text = attempt.lat.toString();
      _lngCtrl.text = attempt.lng.toString();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final o = widget.detail.outlet;
    final typedLat = double.parse(_latCtrl.text.trim());
    final typedLng = double.parse(_lngCtrl.text.trim());
    final pinMoved = typedLat != o.lat || typedLng != o.lng;

    setState(() => _saving = true);
    try {
      await ref.read(outletAdminRepositoryProvider).updateOutlet(
            id: o.id,
            name: _nameCtrl.text.trim() == o.name ? null : _nameCtrl.text.trim(),
            status: _status == o.status ? null : _status,
            // Either the attempt id or the typed numbers reach the wire, never
            // both — see _fromAttemptId.
            fromAttemptId: _fromAttemptId,
            lat: _fromAttemptId == null && pinMoved ? typedLat : null,
            lng: _fromAttemptId == null && pinMoved ? typedLng : null,
            disputeId: _disputeId,
          );
      ref.invalidate(outletDetailProvider(o.id));
      ref.invalidate(outletsListProvider);
      ref.invalidate(openPinDisputesProvider);
      if (mounted) {
        setState(() {
          _fromAttemptId = null;
          _disputeId = null;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Outlet updated.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final o = detail.outlet;
    final openDisputes = detail.disputes.where((d) => d.isOpen).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(o.name, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(o.channelType.isEmpty ? o.code : '${o.code} · ${o.channelType}'),
        const SizedBox(height: 16),

        if (openDisputes.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${openDisputes.length} agent'
                    '${openDisputes.length == 1 ? '' : 's'} '
                    'reported this pin as wrong',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Each of these checked in anyway, flagged, and the visit is '
                    'on the manager review queue. Correcting the pin closes the '
                    'report; saving without moving it records that you looked '
                    'and the pin stands.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── The edit form ────────────────────────────────────────────────
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const ValueKey<String>('outlet-name'),
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Store name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey<String>('outlet-lat'),
                controller: _latCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true, decimal: true),
                // Coordinates are typed by hand here, so the field must not
                // silently accept a comma decimal or a pasted "-26.2041, 28.04"
                // pair and turn it into a pin nobody meant.
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  helperText: 'Between -90 and 90. Johannesburg is about -26.2',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _fromAttemptId = null),
                validator: (v) => _coordinate(v, 90, 'latitude'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey<String>('outlet-lng'),
                controller: _lngCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true, decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  helperText: 'Between -180 and 180. Johannesburg is about 28.0',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _fromAttemptId = null),
                validator: (v) => _coordinate(v, 180, 'longitude'),
              ),
              if (_fromAttemptId != null) ...[
                const SizedBox(height: 8),
                const Text(
                  'Using an agent\'s recorded position. The server reads the '
                  'coordinates from that check-in itself.',
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey<String>('outlet-status'),
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  helperText:
                      'Closed keeps the store out of planning. It does not block '
                      'check-in — an agent standing at the door must still be able '
                      'to work.',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<String>(value: 'active', child: Text('Active')),
                  DropdownMenuItem<String>(value: 'closed', child: Text('Closed')),
                ],
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey<String>('save-outlet'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        _FailedAttempts(
          attempts: detail.failedAttempts,
          onUse: _useAttempt,
        ),
        const SizedBox(height: 24),
        _Disputes(
          disputes: detail.disputes,
          attempts: detail.failedAttempts,
          onUse: _useAttempt,
          onAnswer: (id) => setState(() => _disputeId = id),
          answering: _disputeId,
        ),
        const SizedBox(height: 24),
        _ChangeLedger(changes: detail.changes),
      ],
    );
  }
}

String? _coordinate(String? value, double bound, String what) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Required';
  final parsed = double.tryParse(text);
  if (parsed == null) return 'Enter a number, e.g. -26.2041';
  if (parsed < -bound || parsed > bound) {
    return 'A $what is between -${bound.toInt()} and ${bound.toInt()}';
  }
  return null;
}

/// The evidence. Each row is an agent who stood somewhere and was told they
/// were not at the shop, with where they actually were — several of them
/// clustered on one spot hundreds of metres from the pin is what a wrong pin
/// looks like in data.
class _FailedAttempts extends StatelessWidget {
  const _FailedAttempts({required this.attempts, required this.onUse});

  final List<CheckInAttemptEvidence> attempts;
  final void Function(CheckInAttemptEvidence attempt) onUse;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Rejected check-ins', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text(
          'Where agents actually were when this store turned them away.',
        ),
        const SizedBox(height: 8),
        if (attempts.isEmpty)
          const Card(
            child: ListTile(
              title: Text('No rejected check-ins'),
              subtitle: Text('Nobody has been turned away by this pin.'),
            ),
          )
        else
          for (final a in attempts)
            Card(
              key: ValueKey<String>('attempt-${a.id}'),
              child: ListTile(
                title: Text(
                  '${a.lat.toStringAsFixed(5)}, ${a.lng.toStringAsFixed(5)}',
                ),
                subtitle: Text(
                  '${_metres(a.distanceM)} away · ${a.agentLabel} · '
                  '${_when(a.createdAt)}',
                ),
                trailing: TextButton(
                  key: ValueKey<String>('use-attempt-${a.id}'),
                  onPressed: () => onUse(a),
                  child: const Text('Use this'),
                ),
              ),
            ),
      ],
    );
  }
}

class _Disputes extends StatelessWidget {
  const _Disputes({
    required this.disputes,
    required this.attempts,
    required this.onUse,
    required this.onAnswer,
    required this.answering,
  });

  final List<PinDispute> disputes;
  final List<CheckInAttemptEvidence> attempts;
  final void Function(CheckInAttemptEvidence attempt, {String? disputeId}) onUse;
  final void Function(String disputeId) onAnswer;
  final String? answering;

  @override
  Widget build(BuildContext context) {
    if (disputes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Pin reports', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final d in disputes)
          Card(
            key: ValueKey<String>('dispute-${d.id}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${d.agentLabel} · ${_when(d.createdAt)}'),
                  const SizedBox(height: 4),
                  Text(
                    'Stood at ${d.lat.toStringAsFixed(5)}, '
                    '${d.lng.toStringAsFixed(5)} — ${_metres(d.distanceM)} from '
                    'the pin, which then read ${d.outletLat.toStringAsFixed(5)}, '
                    '${d.outletLng.toStringAsFixed(5)}.',
                  ),
                  if (d.note != null && d.note!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('"${d.note}"'),
                  ],
                  if (d.photoIds.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${d.photoIds.length} storefront photo'
                      '${d.photoIds.length == 1 ? '' : 's'} attached.',
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (d.isOpen)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            answering == d.id
                                ? 'Answering this report on save.'
                                : 'Open',
                          ),
                        ),
                        TextButton(
                          key: ValueKey<String>('answer-${d.id}'),
                          onPressed: () => onAnswer(d.id),
                          child: const Text('Answer this'),
                        ),
                        // Adopting the reporting agent's own position is the
                        // common repair, so it is one tap from the report
                        // rather than a hunt through the attempt list.
                        if (_attemptFor(d) != null)
                          TextButton(
                            key: ValueKey<String>('adopt-${d.id}'),
                            onPressed: () =>
                                onUse(_attemptFor(d)!, disputeId: d.id),
                            child: const Text('Use their position'),
                          ),
                      ],
                    )
                  else
                    Text(
                      d.status == 'applied'
                          ? 'Applied by ${d.resolvedByLabel ?? 'a manager'}'
                          : 'Rejected by ${d.resolvedByLabel ?? 'a manager'}',
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// The rejected check-in that matches this report's position, if it is still
  /// in the evidence window. Matched on coordinates because the dispute and
  /// the attempt are two records of one moment.
  CheckInAttemptEvidence? _attemptFor(PinDispute d) {
    for (final a in attempts) {
      if (a.lat == d.lat && a.lng == d.lng) return a;
    }
    return null;
  }
}

/// Who has changed this outlet, and what it was before. An outlet's
/// coordinates decide who can check in where, so moving one is a change to an
/// access boundary and is recorded as such.
class _ChangeLedger extends StatelessWidget {
  const _ChangeLedger({required this.changes});

  final List<OutletChange> changes;

  @override
  Widget build(BuildContext context) {
    if (changes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Change history', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final c in changes)
          Card(
            key: ValueKey<String>('change-${c.id}'),
            child: ListTile(
              title: Text(_describe(c)),
              subtitle: Text('${c.userLabel} · ${_when(c.createdAt)}'),
            ),
          ),
      ],
    );
  }

  String _describe(OutletChange c) {
    final parts = <String>[];
    if (c.after.containsKey('lat')) {
      parts.add(
        'Pin moved from ${_coord(c.before['lat'])}, ${_coord(c.before['lng'])} '
        'to ${_coord(c.after['lat'])}, ${_coord(c.after['lng'])}'
        '${c.pinSource == 'agent_position' ? " (an agent's recorded position)" : ''}',
      );
    }
    if (c.after.containsKey('name')) {
      parts.add('Renamed from "${c.before['name']}" to "${c.after['name']}"');
    }
    if (c.after.containsKey('status')) {
      parts.add('Status ${c.before['status']} → ${c.after['status']}');
    }
    return parts.isEmpty ? 'Changed' : parts.join('. ');
  }

  String _coord(Object? value) =>
      value is num ? value.toDouble().toStringAsFixed(5) : '?';
}

String _metres(double m) =>
    m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '${m.round()} m';

String _when(DateTime at) {
  final local = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
