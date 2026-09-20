import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/dimmed_aisle_backdrop.dart';
import 'package:tradeiq_app/features/auth/presentation/landing_screen.dart';

import 'entry_harness.dart';

/// The splash on Torchlight.
///
/// It is still the splash the premium-ui redesign made it: no Continue button,
/// no pause toggle, auto-advancing at max(5s, restore) with tap-anywhere as
/// the skip. The full navigation race is covered by `splash_flow_test.dart`,
/// which pumps the real router; these cover what the screen renders on its
/// own.
///
/// The video needs a platform player, which widget tests do not have —
/// `initialize()` throws `UnimplementedError` and the screen swallows it,
/// leaving the backdrop's gradient fallback.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    SkinMode skin = SkinMode.night,
    double textScale = 1.0,
    Locale locale = const Locale('en'),
    bool disableAnimations = true,
  }) => pumpEntryScreen(
    tester,
    const LandingScreen(),
    path: '/',
    textScale: textScale,
    locale: locale,
    disableAnimations: disableAnimations,
    settle: false,
    overrides: entryBaseOverrides(db: entryTestDb(), skin: skin),
  );

  testWidgets('renders the wordmark, with the old Continue button gone', (
    tester,
  ) async {
    await pump(tester);

    // Text.rich('TRADE' + 'IQ') → plain text 'TRADEIQ'.
    expect(find.text('TRADEIQ'), findsOneWidget);
    // The splash advances by itself; a Continue button would be a lie.
    expect(find.textContaining('Continue'), findsNothing);
  });

  testWidgets('does not navigate within the first 100ms', (tester) async {
    // The harness registers no '/login' route, so any premature context.go
    // would surface as an exception here — silence is the assertion.
    await pump(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.byType(LandingScreen), findsOneWidget);
  });

  testWidgets('renders without a platform video player', (tester) async {
    // Guards the swallow in _initializeVideo. If that ever stops catching,
    // every test that pumps this screen dies on an UnimplementedError rather
    // than on anything meaningful.
    await pump(tester);
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.text('TRADEIQ'), findsOneWidget);
  });

  testWidgets('under the motion budget the wordmark arrives at rest', (
    tester,
  ) async {
    await pump(tester);
    // A single pump, no settle: the fade-up must be zero-duration, so the
    // wordmark is already at full opacity on the first frame.
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('TRADEIQ'), matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, 1);
  });

  group('the footage is Night\'s ground, and Night\'s only', () {
    testWidgets('Night shows the dimmed aisle', (tester) async {
      await pump(tester, skin: SkinMode.night);
      expect(find.byType(DimmedAisleBackdrop), findsOneWidget);
    });

    for (final skin in <SkinMode>[SkinMode.day, SkinMode.veld]) {
      testWidgets('${skin.name} is paper — no footage at all', (tester) async {
        await pump(tester, skin: skin);
        expect(
          find.byType(DimmedAisleBackdrop),
          findsNothing,
          reason:
              'unify §4: Veld renders no images, and a near-black video under '
              'a white ground is a different screen rather than a lighter '
              'version of the same one',
        );
        expect(find.text('TRADEIQ'), findsOneWidget);
      });
    }
  });

  testWidgets('declares no amber at all, in any skin', (tester) async {
    for (final skin in entrySkinModes) {
      await pump(tester, skin: skin);
      final scope = tester.widget<TorchScope>(find.byType(TorchScope));
      expect(scope.phase, 'holding');
      expect(
        scope.allocation.granted,
        isEmpty,
        reason:
            '${skin.name}: a splash is the one screen with nothing to commit',
      );
    }
  });

  testWidgets('2.0× Afrikaans still fits', (tester) async {
    await pump(tester, textScale: 2.0, locale: const Locale('af'));
    expect(tester.takeException(), isNull);
    expect(find.text('TRADEIQ'), findsOneWidget);
  });
}
