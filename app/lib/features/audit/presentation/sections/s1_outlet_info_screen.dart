import 'package:flutter/material.dart';

import '../../../../core/theme/lumen_glass.dart';
import '../../../../core/theme/lumen_palette.dart';
import '../../../../core/theme/tiq_colors.dart';
import '../../../../core/widgets/console.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/lumen_kit.dart';
import '../../../../l10n/l10n.dart';

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
    final l10n = context.l10n;
    final ts = checkinTs;
    if (colors.glass) return _GlassCheckin(ts: ts);
    return PanelCard(
      title: l10n.s1Title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            // Honesty: this is confirmed at check-in, not something the agent
            // fills in here.
            l10n.s1ConfirmedAtCheckin,
            style: TextStyle(fontSize: 13, color: colors.ink2),
          ),
          const SizedBox(height: 14),
          _InfoRow(
            label: l10n.s1CheckedIn,
            // Keyed: the shell's timestamp-stability test reads this value
            // across a leave-and-return to prove it is stamped once, not
            // re-derived on rebuild.
            valueKey: const ValueKey('checkin-timestamp'),
            // An absent check-in reads as such — never a fabricated time.
            value: ts == null ? l10n.s1NotRecorded : _formatTs(ts),
          ),
          const SizedBox(height: 10),
          _InfoRow(label: l10n.s1Geofence, value: l10n.s1Passed),
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

/// The check-in in Lumen Glass: one tile, the time as a mono figure, and the
/// geofence as a ✓ in its status tile beside the word — never colour alone.
class _GlassCheckin extends StatelessWidget {
  const _GlassCheckin({required this.ts});

  final DateTime? ts;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lumen = context.lumen;
    final l10n = context.l10n;
    final good = LumenStatus.good.swatchOf(colors);
    final ts = this.ts;
    return GlassPane(
      kind: GlassKind.tile,
      blur: false,
      radius: LumenGlass.radiusCard,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Kicker(l10n.s1Title, color: lumen.kicker),
          const SizedBox(height: 6),
          // Honesty: this is confirmed at check-in, not agent input.
          Text(
            l10n.s1ConfirmedAtCheckin,
            style: TextStyle(fontSize: 13, color: lumen.inkMuted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: SectionLabel(l10n.s1CheckedIn)),
              Text(
                // An absent check-in reads as such — never a fabricated time.
                ts == null
                    ? l10n.s1NotRecorded
                    : S1OutletInfoScreen._formatTs(ts),
                key: const ValueKey('checkin-timestamp'),
                style: ts == null
                    ? TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: lumen.inkMuted,
                      )
                    : LumenGlass.figure(size: 13.5, color: lumen.ink),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: SectionLabel(l10n.s1Geofence)),
              const StatusTile(
                status: LumenStatus.good,
                glyph: '✓',
                size: 22,
                radius: 7,
                fontSize: 11,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.s1Passed,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: good.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
