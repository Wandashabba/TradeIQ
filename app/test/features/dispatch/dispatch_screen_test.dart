import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/features/dispatch/data/dispatch_repository.dart';
import 'package:tradeiq_app/features/dispatch/presentation/dispatch_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import '../../helpers/routed_app.dart';

const _outlets = [
  Outlet(id: 'o1', name: 'Corner Shop', code: 'CS1', lat: -26.2, lng: 28.0),
  Outlet(id: 'o2', name: 'Main Street', code: 'MS1', lat: -26.1, lng: 28.1),
];

const _result = DispatchResult(
  recommended: DispatchCandidate(
    agentId: 'a1',
    email: 'near@example.com',
    distanceM: 120,
    inTerritory: true,
  ),
  candidates: [
    DispatchCandidate(
      agentId: 'a1',
      email: 'near@example.com',
      distanceM: 120,
      inTerritory: true,
    ),
    DispatchCandidate(
      agentId: 'a2',
      email: 'far@example.com',
      inTerritory: false,
    ),
  ],
);

const _namedResult = DispatchResult(
  recommended: DispatchCandidate(
    agentId: 'a1',
    email: 'near@example.com',
    distanceM: 120,
    inTerritory: true,
    displayName: 'Sipho Ndlovu',
  ),
  candidates: [
    DispatchCandidate(
      agentId: 'a1',
      email: 'near@example.com',
      distanceM: 120,
      inTerritory: true,
      displayName: 'Sipho Ndlovu',
    ),
    DispatchCandidate(
      agentId: 'a2',
      email: 'far@example.com',
      inTerritory: false,
    ),
  ],
);

class _FakeDispatchRepository implements DispatchRepository {
  _FakeDispatchRepository([this.result = _result]);
  final DispatchResult result;

  @override
  Future<DispatchResult> dispatch(String outletId) async => result;
}

Widget _app({ThemeData? theme, DispatchResult result = _result}) => routedApp(
      const DispatchScreen(),
      theme: theme,
      overrides: [
        outletsListProvider.overrideWith((ref) async => _outlets),
        dispatchRepositoryProvider
            .overrideWithValue(_FakeDispatchRepository(result)),
      ],
    );

Future<void> _pickCornerShop(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('outlet-select')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Corner Shop').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('light: candidates are glass tiles in a glass panel', (
    tester,
  ) async {
    await tester.pumpWidget(_app(theme: AppTheme.light()));
    await tester.pumpAndSettle();
    await _pickCornerShop(tester);

    final panes = tester
        .widgetList<GlassPane>(
          find.ancestor(
            of: find.text('near@example.com'),
            matching: find.byType(GlassPane),
          ),
        )
        .toList();
    expect(panes.any((p) => p.kind == GlassKind.tile && !p.blur), isTrue);
    expect(panes.any((p) => p.kind == GlassKind.panel), isTrue);
    // The recommendation is a word, not a highlight.
    expect(find.text('RECOMMENDED'), findsOneWidget);
  });

  for (final theme in [AppTheme.light(), null]) {
    final label = theme == null ? 'dark' : 'light';
    testWidgets('$label: a named candidate is shown by name, keyed by email',
        (tester) async {
      await tester.pumpWidget(_app(theme: theme, result: _namedResult));
      await tester.pumpAndSettle();
      await _pickCornerShop(tester);

      expect(find.text('Sipho Ndlovu'), findsOneWidget);
      expect(find.text('near@example.com'), findsNothing);
      // Keys stay on the email, so nothing keyed on them moves.
      final named = find.byKey(const ValueKey('candidate-near@example.com'));
      expect(named, findsOneWidget);
      expect(
        find.descendant(of: named, matching: find.text('Sipho Ndlovu')),
        findsOneWidget,
      );
      // An unnamed candidate falls back to the email.
      expect(find.text('far@example.com'), findsOneWidget);
      expect(find.text('RECOMMENDED'), findsOneWidget);
    });
  }

  testWidgets('renders the outlet dropdown and Dispatch app bar',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Dispatch'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('outlet-select')), findsOneWidget);
  });
}
