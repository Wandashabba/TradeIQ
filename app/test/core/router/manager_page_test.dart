import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/router/manager_page.dart';

void main() {
  Widget harness({
    required bool disableAnimations,
    required Widget Function(BuildContext) build,
  }) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(builder: build),
      ),
    );
  }

  testWidgets('managerPage builds a SharedAxisTransition when motion is on', (
    tester,
  ) async {
    final page = managerPage(const Text('x'));
    expect(page, isA<CustomTransitionPage<void>>());
    final ctp = page;
    await tester.pumpWidget(
      harness(
        disableAnimations: false,
        build: (context) => ctp.transitionsBuilder(
          context,
          const AlwaysStoppedAnimation(1),
          const AlwaysStoppedAnimation(0),
          const Text('child'),
        ),
      ),
    );
    expect(find.byType(SharedAxisTransition), findsOneWidget);
  });

  testWidgets('managerPage falls back to a fade under reduced motion', (
    tester,
  ) async {
    final page = managerPage(const Text('x'));
    await tester.pumpWidget(
      harness(
        disableAnimations: true,
        build: (context) => page.transitionsBuilder(
          context,
          const AlwaysStoppedAnimation(1),
          const AlwaysStoppedAnimation(0),
          const Text('child'),
        ),
      ),
    );
    expect(find.byType(SharedAxisTransition), findsNothing);
    expect(find.byType(FadeTransition), findsOneWidget);
  });
}
