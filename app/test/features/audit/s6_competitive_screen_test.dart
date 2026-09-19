import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/features/audit/data/competitive_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s6_competitive_screen.dart';

import '../agent_harness.dart';
import 'section_harness.dart';

class _SpyCompetitive implements CompetitiveRepository {
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

List<Override> _overrides(CompetitiveRepository spy) => <Override>[
  competitiveRepositoryProvider.overrideWithValue(spy),
];

const _screen = S6CompetitiveScreen(visitDraftId: 'v1');

Finder _key(String k) => find.byKey(ValueKey<String>(k));

Future<void> _add(WidgetTester tester) =>
    tapInSection(tester, _key('section-add-entry'));

void main() {
  testWidgets('an empty list is a stated outcome, not a blank', (tester) async {
    await pumpSection(
      tester,
      _screen,
      overrides: _overrides(_SpyCompetitive()),
    );
    expect(
      find.text('No competitor on this shelf yet. Add one if you see it.'),
      findsOneWidget,
    );
    expect(find.text('Add competitor'), findsOneWidget);
    await disposeAgentScreen(tester);
  });

  testWidgets('captures a competitor, facings and promoter, and saves them', (
    tester,
  ) async {
    final spy = _SpyCompetitive();
    await pumpSection(tester, _screen, overrides: _overrides(spy));

    await _add(tester);
    await typeInSection(tester, _key('comp-sku-0'), 'Rival Cola 500ml');
    await typeInSection(tester, _key('comp-price-0'), '16.99');
    await typeInSection(tester, _key('comp-posm-0'), 'Wobbler');
    await typeInSection(tester, _key('comp-facings-0'), '3');
    await tapInSection(tester, _key('comp-promoter-0'));
    await saveSection(tester);

    expect(spy.visitDraftId, 'v1');
    final e = spy.entries!.single;
    expect(e.competitorSku, 'Rival Cola 500ml');
    expect(e.competitorPrice, 16.99);
    expect(e.competitorPosmType, 'Wobbler');
    // Facings is what makes share of shelf a real ratio (#93).
    expect(e.facingsCount, 3);
    expect(e.competitorPromoterPresent, isTrue);
    await disposeAgentScreen(tester);
  });

  testWidgets('rows without a competitor name are skipped; a blank facings box '
      'means at least one, never zero', (tester) async {
    final spy = _SpyCompetitive();
    await pumpSection(tester, _screen, overrides: _overrides(spy));

    await _add(tester);
    await _add(tester);
    await typeInSection(tester, _key('comp-sku-1'), 'Rival Crisps');
    await typeInSection(tester, _key('comp-facings-1'), '');
    await saveSection(tester);

    expect(spy.entries!.single.competitorSku, 'Rival Crisps');
    expect(spy.entries!.single.facingsCount, 1);
    await disposeAgentScreen(tester);
  });

  testWidgets('each entry is a row naming itself in mono position, with a '
      'remove that says what it removes', (tester) async {
    final spy = _SpyCompetitive();
    await pumpSection(tester, _screen, overrides: _overrides(spy));

    await _add(tester);
    await _add(tester);
    await typeInSection(tester, _key('comp-sku-0'), 'Rival Cola');
    await scrollAgentTo(tester, _key('entry-0'));
    expect(find.text('Competitor 1 of 2'), findsOneWidget);
    expect(find.text('Rival Cola'), findsWidgets);
    expect(find.text('Not named yet'), findsOneWidget);

    final remove = tester.widget<TorchIconButton>(_key('entry-remove-0'));
    expect(remove.semanticLabel, 'Remove competitor 1 of 2');

    await tapInSection(tester, _key('entry-remove-0'));
    expect(find.text('Competitor 1 of 1'), findsOneWidget);
    await typeInSection(tester, _key('comp-sku-0'), 'Rival Crisps');
    await saveSection(tester);
    expect(spy.entries!.single.competitorSku, 'Rival Crisps');
    await disposeAgentScreen(tester);
  });

  testWidgets('no entry is a card: no fill, no radius, no shadow', (
    tester,
  ) async {
    await pumpSection(
      tester,
      _screen,
      overrides: _overrides(_SpyCompetitive()),
    );
    await _add(tester);
    final decorated = find.ancestor(
      of: _key('comp-sku-0'),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            ((w.decoration! as BoxDecoration).borderRadius != null ||
                (w.decoration! as BoxDecoration).boxShadow != null),
      ),
    );
    expect(decorated, findsNothing);
    await disposeAgentScreen(tester);
  });

  group('the amber census', () {
    for (final skin in agentSkinModes) {
      testWidgets('empty is zero, an added entry arms one — ${skin.name}', (
        tester,
      ) async {
        await pumpSection(
          tester,
          _screen,
          overrides: _overrides(_SpyCompetitive()),
          skin: skin,
        );
        await expectAmber(
          tester,
          skin: skin,
          route: 'competitive',
          phase: 'untouched',
          expected: 0,
        );
        await _add(tester);
        await scrollAgentTo(tester, sectionSave);
        await expectAmber(
          tester,
          skin: skin,
          route: 'competitive',
          phase: 'dirty',
          expected: 1,
        );
        await disposeAgentScreen(tester);
      });
    }
  });
}
