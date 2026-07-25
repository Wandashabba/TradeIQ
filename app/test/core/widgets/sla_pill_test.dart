import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
