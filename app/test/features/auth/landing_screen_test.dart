import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_glass.dart';
import 'package:tradeiq_app/core/theme/lumen_palette.dart';
import 'package:tradeiq_app/core/widgets/dimmed_aisle_backdrop.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/features/auth/presentation/landing_screen.dart';

import '../../helpers/routed_app.dart';

/// The landing screen is now the splash (2026-07-24 premium-ui redesign): no
/// Continue button, no pause toggle — it auto-advances at max(5s, restore)
/// with tap-anywhere as the skip. The old tests asserted the Continue button,
/// the WCAG pause control, and the indefinite loop's behaviour; that contract
/// was removed BY DESIGN, so those assertions are replaced, not weakened.
/// The full navigation race is covered by splash_flow_test.dart, which pumps
/// the real router; these tests cover what the screen renders on its own.
///
/// The splash's video still needs a platform player, which widget tests do
/// not have — `initialize()` throws `UnimplementedError` and the screen
/// deliberately swallows it, leaving the gradient-fallback backdrop.
void main() {
  testWidgets('renders the wordmark, with the old Continue button gone', (
    tester,
  ) async {
    await tester.pumpWidget(routedApp(const LandingScreen()));
    await tester.pumpAndSettle();

    // Text.rich('TRADE' + 'IQ') → plain text 'TRADEIQ'.
    expect(find.text('TRADEIQ'), findsOneWidget);
    // The splash advances by itself; a Continue button would be a lie.
    expect(find.widgetWithText(FilledButton, 'Continue'), findsNothing);
  });

  testWidgets('does not navigate within the first 100ms', (tester) async {
    // routedApp registers no '/login' route, so any premature context.go
    // would surface as an exception here — silence is the assertion.
    await tester.pumpWidget(routedApp(const LandingScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.byType(LandingScreen), findsOneWidget);
  });

  testWidgets('reduced motion renders the wordmark statically', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(routedApp(const LandingScreen()));
    // A single pump, no settle: the fade-up must be zero-duration, so the
    // wordmark is already at full opacity on the first frame.
    await tester.pump();

    expect(find.text('TRADEIQ'), findsOneWidget);
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('TRADEIQ'), matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, 1);
  });

  testWidgets('renders without a platform video player', (tester) async {
    // Guards the swallow in _initializeVideo. If that ever stops catching,
    // every test that pumps this screen dies on an UnimplementedError rather
    // than on anything meaningful.
    await tester.pumpWidget(routedApp(const LandingScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('TRADEIQ'), findsOneWidget);
  });

  testWidgets('light: the splash is the lit ground, the wordmark in ink', (
    tester,
  ) async {
    await tester.pumpWidget(
      routedApp(const LandingScreen(), theme: AppTheme.light()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LitGround), findsOneWidget);
    expect(find.byType(DimmedAisleBackdrop), findsNothing);
    final wordmark = tester.widget<Text>(find.text('TRADEIQ'));
    expect(wordmark.style?.color, LumenGlass.ink);
  });

  testWidgets(
    'dark: the splash is the night ground, the wordmark in night ink',
    (tester) async {
      await tester.pumpWidget(
        routedApp(const LandingScreen(), theme: AppTheme.dark()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LitGround), findsOneWidget);
      expect(find.byType(DimmedAisleBackdrop), findsNothing);
      final wordmark = tester.widget<Text>(find.text('TRADEIQ'));
      expect(wordmark.style?.color, LumenPalette.dark.ink);
    },
  );
}
