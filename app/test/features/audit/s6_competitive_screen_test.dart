import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/audit/data/competitive_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s6_competitive_screen.dart';

class _SpyCompetitiveRepository implements CompetitiveRepository {
  String? visitDraftId;
  List<CompetitiveEntry>? entries;

  @override
  Future<void> saveCompetitive({
    required String visitDraftId,
    required List<CompetitiveEntry> entries,
  }) async {
    this.visitDraftId = visitDraftId;
    this.entries = entries;
  }
}

void main() {
  testWidgets('captures competitor entries and calls saveCompetitive on Save', (
    tester,
  ) async {
    final spy = _SpyCompetitiveRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [competitiveRepositoryProvider.overrideWithValue(spy)],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: S6CompetitiveScreen(visitDraftId: 'v1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add competitor'));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('comp-sku-0')),
      'Rival Cola 500ml',
    );
    await tester.enterText(find.byKey(const ValueKey('comp-price-0')), '12.50');
    await tester.enterText(find.byKey(const ValueKey('comp-posm-0')), 'poster');
    await tester.ensureVisible(find.byKey(const ValueKey('comp-promoter-0')));
    await tester.tap(find.byKey(const ValueKey('comp-promoter-0')));
    await tester.pump();

    await tester.ensureVisible(find.text('Save competitive'));
    await tester.tap(find.text('Save competitive'));
    await tester.pumpAndSettle();

    expect(spy.visitDraftId, 'v1');
    expect(spy.entries, hasLength(1));
    expect(spy.entries!.first.competitorSku, 'Rival Cola 500ml');
    expect(spy.entries!.first.competitorPrice, 12.50);
    expect(spy.entries!.first.competitorPosmType, 'poster');
    expect(spy.entries!.first.competitorPromoterPresent, true);
    // Facings defaults to 1 — never 0, which would erase the competitor from the
    // share-of-shelf denominator entirely (#93).
    expect(spy.entries!.first.facingsCount, 1);
    expect(
      find.text('Competitive intel saved — queued for sync'),
      findsOneWidget,
    );
  });

  testWidgets('skips rows without a competitor SKU name on Save', (
    tester,
  ) async {
    final spy = _SpyCompetitiveRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [competitiveRepositoryProvider.overrideWithValue(spy)],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: S6CompetitiveScreen(visitDraftId: 'v1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add competitor'));
    await tester.pump();

    await tester.ensureVisible(find.text('Save competitive'));
    await tester.tap(find.text('Save competitive'));
    await tester.pumpAndSettle();

    expect(spy.visitDraftId, 'v1');
    expect(spy.entries, isEmpty);
  });

  testWidgets('captures competitor facings, so share of shelf is a real ratio', (
    tester,
  ) async {
    final spy = _SpyCompetitiveRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [competitiveRepositoryProvider.overrideWithValue(spy)],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: S6CompetitiveScreen(visitDraftId: 'v1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add competitor'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('comp-sku-0')),
      'Rival Cola 500ml',
    );
    await tester.enterText(find.byKey(const ValueKey('comp-facings-0')), '18');
    await tester.tap(find.text('Save competitive'));
    await tester.pumpAndSettle();

    // Without this, share of shelf counted each captured ROW as one facing — a
    // competitor holding a whole shelf counted the same as one holding a can.
    expect(spy.entries!.first.facingsCount, 18);
  });
}
