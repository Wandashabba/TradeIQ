import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
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
/// is chrome, not a verdict.
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

  // The DeltaPill wash family — see delta_pill.dart.
  static const _greenWash = (Color(0xFFE7F5E7), Color(0xFF0B6B0B));
  static const _amberWash = (Color(0xFFFDF3E2), Color(0xFF8A5A00));
  static const _redWash = (Color(0xFFFDEEEE), Color(0xFFA52A2A));

  (String, Color, Color) _resolve(TiqColors colors) {
    if (done) return ('✓ DONE', _greenWash.$1, _greenWash.$2);

    if (now.isAfter(slaDueAt)) {
      final days = now.difference(slaDueAt).inDays; // floors toward zero
      final label = days < 1 ? 'OVERDUE <1d' : 'OVERDUE ${days}d';
      return (label, _redWash.$1, _redWash.$2);
    }

    // Calendar distance, not elapsed hours: "due tomorrow morning" is one day
    // out even when it is 20 hours away.
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(slaDueAt.year, slaDueAt.month, slaDueAt.day);
    final dayDiff = dueDay.difference(today).inDays;

    if (dayDiff == 0) return ('DUE TODAY', _amberWash.$1, _amberWash.$2);
    if (dayDiff < 7) {
      return (
        'DUE ${_weekdays[slaDueAt.weekday - 1]}',
        colors.surface2,
        colors.ink2,
      );
    }
    return (
      'DUE ${slaDueAt.day} ${_months[slaDueAt.month - 1]}',
      colors.surface2,
      colors.ink2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _resolve(context.colors);

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
