import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/router/torch_page.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';

void main() {
  Widget harness({
    required bool disableAnimations,
    required Widget Function(BuildContext) build,
    TiqSkin? skin,
  }) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Theme(
        data: AppTheme.torchlight(skin ?? TiqSkin.night()),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(builder: build),
        ),
      ),
    );
  }

  Future<void> pumpTransition(
    WidgetTester tester,
    CustomTransitionPage<void> page, {
    required bool disableAnimations,
    TiqSkin? skin,
  }) async {
    await tester.pumpWidget(
      harness(
        disableAnimations: disableAnimations,
        skin: skin,
        build: (context) => page.transitionsBuilder(
          context,
          const AlwaysStoppedAnimation<double>(1),
          const AlwaysStoppedAnimation<double>(0),
          const Text('child'),
        ),
      ),
    );
  }

  test('every kind runs on the declared route token, never a literal', () {
    for (final kind in TorchPageKind.values) {
      final page = torchPage(const Text('x'), kind: kind);
      expect(
        page.transitionDuration,
        TiqMotion.reveal,
        reason: '$kind must use TiqMotion.reveal',
      );
      expect(page.reverseTransitionDuration, TiqMotion.reveal);
    }
  });

  testWidgets('peer is the shared axis, horizontal', (tester) async {
    await pumpTransition(
      tester,
      torchPage(const Text('x')),
      disableAnimations: false,
    );
    final t = tester.widget<SharedAxisTransition>(
      find.byType(SharedAxisTransition),
    );
    expect(t.transitionType, SharedAxisTransitionType.horizontal);
  });

  testWidgets('forward is the shared axis, scaled', (tester) async {
    await pumpTransition(
      tester,
      torchPage(const Text('x'), kind: TorchPageKind.forward),
      disableAnimations: false,
    );
    final t = tester.widget<SharedAxisTransition>(
      find.byType(SharedAxisTransition),
    );
    expect(t.transitionType, SharedAxisTransitionType.scaled);
  });

  testWidgets('arrival is a fade, and never slides', (tester) async {
    await pumpTransition(
      tester,
      torchPage(const Text('x'), kind: TorchPageKind.arrival),
      disableAnimations: false,
    );
    expect(find.byType(SharedAxisTransition), findsNothing);
    expect(find.byType(FadeTransition), findsOneWidget);
  });

  testWidgets('EVERY kind degrades to a cross-fade under reduced motion', (
    tester,
  ) async {
    for (final kind in TorchPageKind.values) {
      await pumpTransition(
        tester,
        torchPage(const Text('x'), kind: kind),
        disableAnimations: true,
      );
      expect(
        find.byType(SharedAxisTransition),
        findsNothing,
        reason: '$kind must not slide or scale under reduced motion',
      );
      expect(find.byType(FadeTransition), findsOneWidget, reason: '$kind');
      // Not a broken state: the incoming page is fully opaque at the end of
      // the animation, not stuck at zero.
      expect(find.text('child'), findsOneWidget, reason: '$kind');
    }
  });

  testWidgets('the fill under a transition is the SKIN ground, in both skins', (
    tester,
  ) async {
    for (final skin in <TiqSkin>[TiqSkin.night(), TiqSkin.day()]) {
      await pumpTransition(
        tester,
        torchPage(const Text('x'), kind: TorchPageKind.peer),
        disableAnimations: false,
        skin: skin,
      );
      final t = tester.widget<SharedAxisTransition>(
        find.byType(SharedAxisTransition),
      );
      expect(
        t.fillColor,
        skin.palette.ground,
        reason:
            'the transition fill reads the skin, not the legacy TiqColors '
            'shim that happens to map plane -> ground today',
      );
    }
  });
}
