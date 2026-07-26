import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/console.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s1_outlet_info_screen.dart';

const _bothThemes = ['light', 'dark'];

ThemeData _themeFor(String name) =>
    name == 'light' ? AppTheme.light() : AppTheme.dark();

Widget _screen({ThemeData? theme, Key? key, DateTime? ts}) => MaterialApp(
  theme: theme,
  home: Scaffold(
    body: SingleChildScrollView(
      child: S1OutletInfoScreen(key: key, checkinTs: ts),
    ),
  ),
);

void main() {
  testWidgets(
    'renders the read-only check-in confirmation in a console PanelCard on '
    'tokens — both themes',
    (tester) async {
      for (final name in _bothThemes) {
        await tester.pumpWidget(
          _screen(
            theme: _themeFor(name),
            key: ValueKey(name),
            ts: DateTime(2026, 7, 25, 14, 30),
          ),
        );
        await tester.pumpAndSettle();

        // The read-only info sits in the console's only container, never a
        // raw Card.
        expect(find.byType(PanelCard), findsOneWidget, reason: '$name panel');
        expect(find.byType(Card), findsNothing, reason: '$name no Card');

        // Honest wording preserved: this is confirmed at check-in, not agent
        // input.
        expect(
          find.text('Confirmed at check-in'),
          findsOneWidget,
          reason: name,
        );
        expect(find.text('2026-07-25 14:30'), findsOneWidget, reason: name);
        expect(find.text('Passed'), findsOneWidget, reason: name);
      }
    },
  );

  testWidgets('degrades honestly when no check-in timestamp is present', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(theme: _themeFor('dark')));
    await tester.pumpAndSettle();

    expect(find.text('Confirmed at check-in'), findsOneWidget);
    // Never a fabricated timestamp — an absent check-in reads as such.
    expect(find.text('Not recorded'), findsOneWidget);
  });
}
