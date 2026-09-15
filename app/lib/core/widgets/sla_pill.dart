import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/lumen_glass.dart';
import '../theme/lumen_palette.dart';
import '../theme/status_pill_colors.dart';
import '../theme/tiq_colors.dart';

/// The SLA verdict as a pill — `OVERDUE 2d`, `DUE TODAY`, `DUE FRI`,
/// `DUE 12 AUG`, `✓ DONE`.
///
/// Words always: the wash sets the temperature, but the verdict is spelled
/// out, so the pill still reads in greyscale and to a screen reader. Overdue
/// is measured in floored days — `OVERDUE <1d` for anything under a day —
/// because a fake-precise `3h` would imply the console knows when the fix
/// crew reads it.
///
/// The status washes reuse [DeltaPill]'s fixed palette family (red / amber /
/// green) — a verdict is the same verdict in both themes, and each pair is
/// self-contained ≥4.5:1 (pinned in sla_pill_test.dart). Only the muted
/// "due later" state rides on theme tokens (surface2 under ink2), because it
/// is chrome, not a verdict. Lumen Glass swaps the washes for its own status
/// swatches, composited opaque so each pair still clears AA on its own.
///
/// `now` is an input, never a clock read — the screen takes `DateTime.now()`
/// once per build and threads it, so tests can pin time.
class SlaPill extends StatelessWidget {
  const SlaPill(
    this.slaDueAt, {
    super.key,
    required this.done,
    required this.now,
  });

  final DateTime slaDueAt;

  /// A closed task is done regardless of the clock — done wins over overdue.
  final bool done;

  final DateTime now;

  static const _weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', //
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  // The fixed status wash family — single-sourced, see status_pill_colors.dart.
  static const _greenWash = statusPillGood;
  static const _amberWash = statusPillWarn;
  static const _redWash = statusPillBad;

  /// Whole calendar days from [from]'s day to [to]'s day.
  ///
  /// Both days are reconstructed at UTC midnight before subtracting: local
  /// midnights are 23h or 25h apart across a DST transition, and
  /// `Duration.inDays` floors a 23h day to 0 — which would label a
  /// tomorrow-due task "DUE TODAY" on every European spring-forward. In UTC
  /// every day is exactly 24h by construction, so the diff is exact in any
  /// zone. Inputs must already be local projections; only their calendar
  /// fields are read.
  @visibleForTesting
  static int calendarDayDiff(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  (String, Color, Color) _resolve(TiqColors colors) {
    if (done) return ('✓ DONE', _greenWash.bg, _greenWash.fg);

    if (now.isAfter(slaDueAt)) {
      final days = now.difference(slaDueAt).inDays; // floors toward zero
      final label = days < 1 ? 'OVERDUE <1d' : 'OVERDUE ${days}d';
      return (label, _redWash.bg, _redWash.fg);
    }

    // Instant comparisons above are zone-safe; calendar fields are NOT. The
    // backend sends slaDueAt as UTC and TaskItem keeps it UTC, while `now`
    // is the manager's local clock — so every calendar read below must come
    // from the LOCAL projection of the due instant, or a deadline just past
    // local midnight gets labelled with yesterday's weekday.
    final due = slaDueAt.toLocal();

    // Calendar distance, not elapsed hours: "due tomorrow morning" is one day
    // out even when it is 20 hours away.
    final dayDiff = calendarDayDiff(now, due);

    if (dayDiff == 0) return ('DUE TODAY', _amberWash.bg, _amberWash.fg);
    if (dayDiff < 7) {
      return (
        'DUE ${_weekdays[due.weekday - 1]}',
        colors.surface2,
        colors.ink2,
      );
    }
    return (
      'DUE ${due.day} ${_months[due.month - 1]}',
      colors.surface2,
      colors.ink2,
    );
  }

  /// Glass: each verdict maps to its Lumen status; the muted "due later"
  /// states stay chrome (a white-rimmed surface2 chip under inkMuted).
  LumenStatus? _status(String label) {
    if (done) return LumenStatus.good;
    if (label.startsWith('OVERDUE')) return LumenStatus.crit;
    if (label == 'DUE TODAY') return LumenStatus.warn;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (label, bg, fg) = _resolve(colors);

    if (colors.glass) {
      final sw = _status(label)?.swatchOf(colors);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          // Opaque composite, so the ink clears AA over any pane.
          color: sw == null
              ? colors.surface2
              : Color.alphaBlend(sw.tint, colors.surface1),
          border: Border.all(color: sw?.rim ?? context.lumen.pillRim),
          borderRadius: BorderRadius.circular(LumenGlass.radiusChip),
        ),
        child: Text(
          label,
          style: LumenGlass.figure(
            size: 10.5,
            color: sw?.ink ?? context.lumen.inkMuted,
            weight: FontWeight.w700,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: fg,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
