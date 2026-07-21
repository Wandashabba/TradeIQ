import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/audit/data/visibility_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s3_4_visibility_display_screen.dart';

class _SpyVisibilityRepository implements VisibilityRepository {
  String? visitDraftId;
  VisibilityCapture? capture;

  @override
  Future<void> saveVisibility({
    required String visitDraftId,
    required VisibilityCapture capture,
  }) async {
    this.visitDraftId = visitDraftId;
    this.capture = capture;
  }
}

void main() {
  testWidgets('captures visibility and calls saveVisibility on Save', (
    tester,
  ) async {
    final spy = _SpyVisibilityRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [visibilityRepositoryProvider.overrideWithValue(spy)],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: S3S4VisibilityDisplayScreen(visitDraftId: 'v1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('branding-poster')));
    await tester.enterText(find.byKey(const ValueKey('planogram')), '82.5');
    await tester.enterText(find.byKey(const ValueKey('facings')), '12');
    await tester.enterText(find.byKey(const ValueKey('cleanliness')), '90');
    await tester.ensureVisible(find.byKey(const ValueKey('high-traffic')));
    await tester.tap(find.byKey(const ValueKey('high-traffic')));
    await tester.pump();

    await tester.ensureVisible(find.text('Save visibility'));
    await tester.tap(find.text('Save visibility'));
    await tester.pumpAndSettle();

    expect(spy.visitDraftId, 'v1');
    expect(spy.capture!.planogramCompliancePct, 82.5);
    expect(spy.capture!.facingsCount, 12);
    expect(spy.capture!.cleanlinessScore, 90);
    expect(spy.capture!.highTrafficPass, true);
    expect(spy.capture!.brandingElements['poster'], true);
    expect(find.text('Visibility saved — queued for sync'), findsOneWidget);
  });
}
