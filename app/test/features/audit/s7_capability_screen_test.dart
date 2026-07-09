import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/audit/data/capability_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s7_capability_screen.dart';

class _SpyCapabilityRepository implements CapabilityRepository {
  String? visitDraftId;
  CapabilityCapture? capture;

  @override
  Future<void> saveCapability({required String visitDraftId, required CapabilityCapture capture}) async {
    this.visitDraftId = visitDraftId;
    this.capture = capture;
  }
}

void main() {
  testWidgets('captures capability and calls saveCapability on Save', (tester) async {
    final spy = _SpyCapabilityRepository();

    await tester.pumpWidget(ProviderScope(
      overrides: [capabilityRepositoryProvider.overrideWithValue(spy)],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: S7CapabilityScreen(visitDraftId: 'v1')),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('headcount')), '5');
    await tester.tap(find.byKey(const ValueKey('training-productKnowledge')));
    await tester.tap(find.byKey(const ValueKey('training-posSystems')));
    await tester.enterText(find.byKey(const ValueKey('quiz')), '85');
    await tester.pump();

    await tester.ensureVisible(find.text('Save capability'));
    await tester.tap(find.text('Save capability'));
    await tester.pumpAndSettle();

    expect(spy.visitDraftId, 'v1');
    expect(spy.capture!.staffHeadcountConfirmed, 5);
    expect(spy.capture!.repTrainingStatus['productKnowledge'], true);
    expect(spy.capture!.repTrainingStatus['merchandising'], false);
    expect(spy.capture!.repTrainingStatus['posSystems'], true);
    expect(spy.capture!.quizScore, 85);
    expect(find.text('Capability saved — queued for sync'), findsOneWidget);
  });
}
