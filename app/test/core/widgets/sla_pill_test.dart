import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_glass.dart';
import 'package:tradeiq_app/core/theme/lumen_palette.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/sla_pill.dart';

import '../theme/tiq_colors_test.dart' show contrastRatio;

/// Wednesday 2026-07-22, midday. Every case below is phrased relative to this
/// instant — the pill takes `now` as an input precisely so a test can pin it.
final _now = DateTime(2026, 7, 22, 12);

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme,
  home: Scaffold(body: Center(child: child)),
);

/// The wash and text colour as actually rendered, read back from the tree —
/// so a mutated colour in the widget fails here rather than being mirrored
/// by a copied constant.
Future<(Color bg, Color fg)> _pumpAndRead(
  WidgetTester tester,
  SlaPill pill, {
  ThemeData? theme,
}) async {
  await tester.pumpWidget(_wrap(pill, theme: theme));
  final box = tester.widget<Container>(
    find.descendant(of: find.byType(SlaPill), matching: find.byType(Container)),
  );
  final decoration = box.decoration! as BoxDecoration;
  final text = tester.widget<Text>(
    find.descendant(of: find.byType(SlaPill), matching: find.byType(Text)),
  );
  return (decoration.color!, text.style!.color!);
}

void main() {
  group('SlaPill', () {
    testWidgets('overdue by whole days reads "OVERDUE 2d" on the red wash', (
      tester,
    ) async {
      final (bg, fg) = await _pumpAndRead(
        tester,
        SlaPill(
          _now.subtract(const Duration(days: 2, hours: 3)),
          done: false,
          now: _now,
        ),
      );

      expect(find.text('OVERDUE 2d'), findsOneWidget);
      expect(bg, const Color(0xFFFDEEEE));
      expect(fg, const Color(0xFFA52A2A));
    });

    testWidgets('overdue by less than a day reads "OVERDUE <1d" — days floor, '
        'never invented hours', (tester) async {
      final (bg, _) = await _pumpAndRead(
        tester,
        SlaPill(
          _now.subtract(const Duration(hours: 3)),
          done: false,
          now: _now,
        ),
      );

      expect(find.text('OVERDUE <1d'), findsOneWidget);
      expect(bg, const Color(0xFFFDEEEE));
    });

    testWidgets('due later today reads "DUE TODAY" on the amber wash', (
      tester,
    ) async {
      final (bg, fg) = await _pumpAndRead(
        tester,
        SlaPill(
          _now.add(const Duration(hours: 5)), // 17:00 the same day
          done: false,
          now: _now,
        ),
      );

      expect(find.text('DUE TODAY'), findsOneWidget);
      expect(bg, const Color(0xFFFDF3E2));
      expect(fg, const Color(0xFF8A5A00));
    });

    testWidgets('due within the week names the weekday: "DUE FRI"', (
      tester,
    ) async {
      final (bg, fg) = await _pumpAndRead(
        tester,
        // Wednesday + 2 days = Friday 2026-07-24.
        SlaPill(_now.add(const Duration(days: 2)), done: false, now: _now),
      );

      expect(find.text('DUE FRI'), findsOneWidget);
      // Muted = theme tokens (dark fallback here): surface2 under ink2.
      expect(bg, TiqColors.dark.surface2);
      expect(fg, TiqColors.dark.ink2);
    });

    testWidgets('six days out is still a weekday; seven switches to the date', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SlaPill(_now.add(const Duration(days: 6)), done: false, now: _now),
        ),
      );
      expect(find.text('DUE TUE'), findsOneWidget); // 2026-07-28

      await tester.pumpWidget(
        _wrap(
          SlaPill(_now.add(const Duration(days: 7)), done: false, now: _now),
        ),
      );
      expect(find.text('DUE 29 JUL'), findsOneWidget);
    });

    testWidgets('a week or more out reads day + month: "DUE 12 AUG"', (
      tester,
    ) async {
      final (bg, fg) = await _pumpAndRead(
        tester,
        SlaPill(DateTime(2026, 8, 12, 9), done: false, now: _now),
      );

      expect(find.text('DUE 12 AUG'), findsOneWidget);
      expect(bg, TiqColors.dark.surface2);
      expect(fg, TiqColors.dark.ink2);
    });

    // The backend sends slaDueAt as UTC ISO and TaskItem.fromJson keeps it
    // UTC; `now` is the screen's local clock. Instant comparisons are
    // zone-safe, but calendar labels must be phrased in the MANAGER's day —
    // both fixtures below build the due instant from local wall-clock time
    // and convert, so the expectation holds in every zone once the pill
    // normalises, while a pill reading raw UTC calendar fields mislabels in
    // any zone ahead of UTC.
    testWidgets('a UTC due instant just after local midnight is "DUE TODAY", '
        'not yesterday\'s weekday', (tester) async {
      // Thursday 2026-07-23, 00:30 local; due 45 minutes later. In UTC+2
      // that instant is 22:15Z WEDNESDAY — a pill reading UTC calendar
      // fields computes dayDiff -1 and mutedly names yesterday, understating
      // a deadline that is under an hour away.
      final localNow = DateTime(2026, 7, 23, 0, 30);
      final dueUtc = localNow.add(const Duration(minutes: 45)).toUtc();

      final (bg, _) = await _pumpAndRead(
        tester,
        SlaPill(dueUtc, done: false, now: localNow),
      );

      expect(find.text('DUE TODAY'), findsOneWidget);
      expect(bg, const Color(0xFFFDF3E2));
    });

    testWidgets('a late-evening UTC instant due TOMORROW local names the '
        'local weekday, not "DUE TODAY"', (tester) async {
      // Wednesday 2026-07-22, 20:00 local; due 01:00 Thursday local — in
      // UTC+2 that is 23:00Z still on Wednesday. UTC calendar fields would
      // claim "DUE TODAY"; the manager's calendar says Thursday.
      final localNow = DateTime(2026, 7, 22, 20);
      final dueUtc = DateTime(2026, 7, 23, 1).toUtc();

      await tester.pumpWidget(
        _wrap(SlaPill(dueUtc, done: false, now: localNow)),
      );

      expect(find.text('DUE THU'), findsOneWidget);
      expect(find.text('DUE TODAY'), findsNothing);
    });

    testWidgets('done reads "✓ DONE" on the green wash', (tester) async {
      final (bg, fg) = await _pumpAndRead(
        tester,
        SlaPill(_now.add(const Duration(days: 3)), done: true, now: _now),
      );

      expect(find.text('✓ DONE'), findsOneWidget);
      expect(bg, const Color(0xFFE7F5E7));
      expect(fg, const Color(0xFF0B6B0B));
    });

    testWidgets('done wins over overdue — a closed task is never "OVERDUE"', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SlaPill(
            _now.subtract(const Duration(days: 5)),
            done: true,
            now: _now,
          ),
        ),
      );

      expect(find.text('✓ DONE'), findsOneWidget);
      expect(find.textContaining('OVERDUE'), findsNothing);
    });

    testWidgets('the wash is a fully rounded pill with 10–11px w700 text', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(SlaPill(_now, done: false, now: _now)));

      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(SlaPill),
          matching: find.byType(Container),
        ),
      );
      expect(
        (box.decoration! as BoxDecoration).borderRadius,
        BorderRadius.circular(999),
      );

      final text = tester.widget<Text>(
        find.descendant(of: find.byType(SlaPill), matching: find.byType(Text)),
      );
      expect(text.style?.fontWeight, FontWeight.w700);
      expect(text.style?.fontSize, inInclusiveRange(10, 11));
    });

    // Every wash/text pair must clear WCAG AA 4.5:1 for its 10–11px text —
    // measured off the rendered widget, in both themes for the token-driven
    // muted pair (the fixed status washes are theme-invariant by design).
    for (final (name, theme) in [
      ('dark', ThemeData(extensions: const [TiqColors.dark])),
      ('light', ThemeData(extensions: const [TiqColors.light])),
    ]) {
      testWidgets('every state clears 4.5:1 over its wash ($name theme)', (
        tester,
      ) async {
        final states = <String, SlaPill>{
          'overdue': SlaPill(
            _now.subtract(const Duration(days: 2)),
            done: false,
            now: _now,
          ),
          'due today': SlaPill(
            _now.add(const Duration(hours: 5)),
            done: false,
            now: _now,
          ),
          'due this week': SlaPill(
            _now.add(const Duration(days: 2)),
            done: false,
            now: _now,
          ),
          'due later': SlaPill(DateTime(2026, 8, 12), done: false, now: _now),
          'done': SlaPill(_now, done: true, now: _now),
        };

        for (final entry in states.entries) {
          final (bg, fg) = await _pumpAndRead(
            tester,
            entry.value,
            theme: theme,
          );
          final ratio = contrastRatio(fg, bg);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '${entry.key} ($name) is $ratio:1 over its wash — pill text '
                'is 10–11px, so AA demands 4.5:1.',
          );
        }
      });
    }
  });

  group('SlaPill in Lumen Glass (light)', () {
    testWidgets('each verdict takes its Lumen status swatch, composited opaque', (
      tester,
    ) async {
      for (final (name, pill, status) in [
        (
          'overdue',
          SlaPill(
            _now.subtract(const Duration(days: 2)),
            done: false,
            now: _now,
          ),
          LumenStatus.crit,
        ),
        (
          'due today',
          SlaPill(_now.add(const Duration(hours: 5)), done: false, now: _now),
          LumenStatus.warn,
        ),
        ('done', SlaPill(_now, done: true, now: _now), LumenStatus.good),
      ]) {
        final (bg, fg) = await _pumpAndRead(
          tester,
          pill,
          theme: AppTheme.light(),
        );
        final sw = status.swatchOf(TiqColors.light);
        expect(
          bg,
          Color.alphaBlend(sw.tint, TiqColors.light.surface1),
          reason: name,
        );
        expect(fg, sw.ink, reason: name);
      }
    });

    testWidgets('"due later" stays chrome: a white-rimmed chip under muted ink', (
      tester,
    ) async {
      final (bg, fg) = await _pumpAndRead(
        tester,
        SlaPill(DateTime(2026, 8, 12, 9), done: false, now: _now),
        theme: AppTheme.light(),
      );

      expect(find.text('DUE 12 AUG'), findsOneWidget);
      expect(bg, TiqColors.light.surface2);
      expect(fg, LumenPalette.light.inkMuted);
      final box = tester.widget<Container>(
        find.descendant(of: find.byType(SlaPill), matching: find.byType(Container)),
      );
      final deco = box.decoration! as BoxDecoration;
      expect((deco.border! as Border).top.color, LumenPalette.light.pillRim);
      expect(deco.borderRadius, BorderRadius.circular(LumenGlass.radiusChip));
    });

    testWidgets('the verdict is still spelled out, in mono figures', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SlaPill(
            _now.subtract(const Duration(days: 2, hours: 3)),
            done: false,
            now: _now,
          ),
          theme: AppTheme.light(),
        ),
      );

      final text = tester.widget<Text>(find.text('OVERDUE 2d'));
      expect(text.style?.fontFamily, LumenGlass.mono);
      expect(text.style?.fontWeight, FontWeight.w700);
      expect(text.style?.fontSize, inInclusiveRange(10, 11));
    });
  });

  group('SlaPill.calendarDayDiff', () {
    // Why no live DST probe: the Dart VM reads the process timezone once at
    // startup and `flutter test` offers no per-test TZ control, so a
    // spring-forward repro (Europe/Paris 2026-03-29, where subtracting LOCAL
    // midnights yields a 23h day and `inDays` floors it to 0 — "DUE TODAY" a
    // day early) cannot be forced from inside this suite. Instead the helper
    // is pinned as a pure function: it reconstructs both days at UTC
    // midnight, where every day is exactly 24h BY CONSTRUCTION, so the
    // 23h/25h-day failure mode cannot exist in any zone.
    test('one minute across midnight is one day', () {
      expect(
        SlaPill.calendarDayDiff(
          DateTime(2026, 3, 28, 23, 59),
          DateTime(2026, 3, 29, 0, 1),
        ),
        1,
      );
    });

    test('the European spring-forward pair is exactly one day, never zero', () {
      // 2026-03-29 is the CET→CEST switch: local midnights there are 23h
      // apart. The UTC reconstruction must still count one calendar day.
      expect(
        SlaPill.calendarDayDiff(
          DateTime(2026, 3, 28, 12),
          DateTime(2026, 3, 29, 12),
        ),
        1,
      );
      expect(
        SlaPill.calendarDayDiff(
          DateTime(2026, 3, 22, 12),
          DateTime(2026, 3, 29, 0, 30),
        ),
        7,
      );
    });

    test('same day is zero regardless of hours apart', () {
      expect(
        SlaPill.calendarDayDiff(
          DateTime(2026, 7, 22, 0, 1),
          DateTime(2026, 7, 22, 23, 59),
        ),
        0,
      );
    });

    test('month and year boundaries count plain calendar days', () {
      expect(
        SlaPill.calendarDayDiff(DateTime(2026, 7, 31), DateTime(2026, 8, 1)),
        1,
      );
      expect(
        SlaPill.calendarDayDiff(
          DateTime(2026, 12, 31, 23),
          DateTime(2027, 1, 1, 1),
        ),
        1,
      );
      expect(
        SlaPill.calendarDayDiff(DateTime(2026, 2, 1), DateTime(2026, 3, 1)),
        28,
      );
    });
  });
}
