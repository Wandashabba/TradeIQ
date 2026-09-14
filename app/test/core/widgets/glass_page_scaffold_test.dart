import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_palette.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/core/widgets/glass_page_scaffold.dart';
import 'package:tradeiq_app/core/widgets/lumen_kit.dart';

/// A home screen with one button that pushes a [GlassPageScaffold] — the way
/// the console opens its create and edit forms.
Widget _app(ThemeData theme) => MaterialApp(
  theme: theme,
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const GlassPageScaffold(
              title: Text('New Order'),
              body: Text('form'),
            ),
          ),
        ),
        child: const Text('open'),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(_app(theme));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no theme: the plain Scaffold and AppBar fallback', (
    tester,
  ) async {
    await _open(tester, ThemeData());

    expect(find.text('New Order'), findsOneWidget);
    expect(find.text('form'), findsOneWidget);
    expect(find.byType(LitGround), findsNothing);
    expect(find.byType(GlassBackChip), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('light: lit ground, glass bar and a glass back chip', (
    tester,
  ) async {
    await _open(tester, AppTheme.light());

    expect(find.byType(LitGround), findsOneWidget);
    expect(find.byType(GlassBackChip), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    final bar = tester.widget<AppBar>(find.byType(AppBar));
    expect(bar.backgroundColor, const Color(0x6BFFFFFF));
    expect(find.byType(BackdropFilter), findsWidgets);
  });

  testWidgets('dark: the night ground under a faint glass bar', (tester) async {
    await _open(tester, AppTheme.dark());

    expect(find.byType(LitGround), findsOneWidget);
    expect(find.byType(GlassBackChip), findsOneWidget);
    final bar = tester.widget<AppBar>(find.byType(AppBar));
    expect(bar.backgroundColor, LumenPalette.dark.white(0x6B));
  });

  testWidgets('light: the back chip pops the page', (tester) async {
    await _open(tester, AppTheme.light());

    await tester.tap(find.byType(GlassBackChip));
    await tester.pumpAndSettle();

    expect(find.text('form'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('light: a root page has no back chip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const GlassPageScaffold(title: Text('Root'), body: SizedBox()),
      ),
    );

    expect(find.byType(GlassBackChip), findsNothing);
  });
}
