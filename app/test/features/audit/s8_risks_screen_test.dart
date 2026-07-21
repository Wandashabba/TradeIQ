import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/audit/data/risks_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s8_risks_screen.dart';

class _SpyRisksRepository implements RisksRepository {
  String? visitDraftId;
  List<RiskEntry>? entries;

  @override
  Future<void> saveRisks({
    required String visitDraftId,
    required List<RiskEntry> entries,
  }) async {
    this.visitDraftId = visitDraftId;
    this.entries = entries;
  }
}

void main() {
  testWidgets('captures risk entries and calls saveRisks on Save', (
    tester,
  ) async {
    final spy = _SpyRisksRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [risksRepositoryProvider.overrideWithValue(spy)],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: S8RisksScreen(visitDraftId: 'v1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Flag a risk'));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('risk-type-0')),
      'expiredStock',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('risk-severity-0')));
    await tester.tap(find.byKey(const ValueKey('risk-severity-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('critical').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('risk-note-0')),
      'Two cases past date',
    );
    await tester.pump();

    await tester.ensureVisible(find.text('Save risks'));
    await tester.tap(find.text('Save risks'));
    await tester.pumpAndSettle();

    expect(spy.visitDraftId, 'v1');
    expect(spy.entries, hasLength(1));
    expect(spy.entries!.first.flagType, 'expiredStock');
    expect(spy.entries!.first.severity, 'critical');
    expect(spy.entries!.first.note, 'Two cases past date');
    expect(
      find.text(
        'Risks saved — queued for sync; follow-up tasks will be auto-created',
      ),
      findsOneWidget,
    );
  });

  testWidgets('skips rows without a flag type on Save', (tester) async {
    final spy = _SpyRisksRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [risksRepositoryProvider.overrideWithValue(spy)],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: S8RisksScreen(visitDraftId: 'v1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Flag a risk'));
    await tester.pump();

    await tester.ensureVisible(find.text('Save risks'));
    await tester.tap(find.text('Save risks'));
    await tester.pumpAndSettle();

    expect(spy.visitDraftId, 'v1');
    expect(spy.entries, isEmpty);
  });
}
