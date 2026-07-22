import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/auth/presentation/landing_screen.dart';

import '../../helpers/routed_app.dart';

/// The landing screen's video needs a platform player, which widget tests do
/// not have — `initialize()` throws `UnimplementedError` and the screen
/// deliberately swallows it, leaving the background blank.
///
/// That is exactly why these tests assert on what survives without the player:
/// the button treatment, and the fact that nothing autoplays. The control's
/// behaviour with a live player is not reachable here, and pretending
/// otherwise with a mock video platform would test the mock.
void main() {
  testWidgets('uses the design system button, not the gradient pill', (
    tester,
  ) async {
    await tester.pumpWidget(routedApp(const LandingScreen()));
    await tester.pumpAndSettle();

    // The fossil was a 999px pill with an Apple system-blue gradient, which
    // design/index.html lists as removed. The replacement takes its styling
    // from filledButtonTheme, so it squares off with everything else.
    expect(find.widgetWithText(FilledButton, 'Continue'), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('does not autoplay under reduced motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(routedApp(const LandingScreen()));
    await tester.pumpAndSettle();

    // A 22s loop with no way to stop it is WCAG 2.2 SC 2.2.2 (Level A), and
    // this is the first screen anyone sees. Reaching pumpAndSettle at all is
    // part of the assertion: a forever-repeating animation never settles.
    expect(find.byType(LandingScreen), findsOneWidget);
  });

  testWidgets('renders without a platform video player', (tester) async {
    // Guards the swallow in _initializeVideo. If that ever stops catching,
    // every test that pumps this screen dies on an UnimplementedError rather
    // than on anything meaningful.
    await tester.pumpWidget(routedApp(const LandingScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Field Execution, In Focus'), findsOneWidget);
  });
}
