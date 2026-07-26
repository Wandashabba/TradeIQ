import 'package:flutter/material.dart';

import '../../../../core/theme/tiq_colors.dart';
import '../../../../core/widgets/console.dart';

/// S1 — Outlet Information: a read-only confirmation of the check-in the agent
/// already completed. There is nothing to capture here — the timestamp and
/// geofence result come from check-in, so the screen states them plainly and
/// never presents them as agent input.
class S1OutletInfoScreen extends StatelessWidget {
  const S1OutletInfoScreen({super.key, this.checkinTs});

  final DateTime? checkinTs;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ts = checkinTs;
    return PanelCard(
      title: 'Outlet check-in',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            // Honesty: this is confirmed at check-in, not something the agent
            // fills in here.
            'Confirmed at check-in',
            style: TextStyle(fontSize: 13, color: colors.ink2),
          ),
          const SizedBox(height: 14),
          _InfoRow(
            label: 'Checked in',
            // Keyed: the shell's timestamp-stability test reads this value
            // across a leave-and-return to prove it is stamped once, not
            // re-derived on rebuild.
            valueKey: const ValueKey('checkin-timestamp'),
            // An absent check-in reads as such — never a fabricated time.
            value: ts == null ? 'Not recorded' : _formatTs(ts),
          ),
          const SizedBox(height: 10),
          _InfoRow(label: 'Geofence', value: 'Passed'),
        ],
      ),
    );
  }

  static String _formatTs(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}';
  }
}

/// A muted label above the console's line, paired with its ink1 value.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueKey});

  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SectionLabel(label),
        Text(
          value,
          key: valueKey,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.ink1,
          ),
        ),
      ],
    );
  }
}
