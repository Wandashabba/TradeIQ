import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/features/audit/data/risks_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s8_risks_screen.dart';

import '../agent_harness.dart';
import 'section_harness.dart';

class _SpyRisks implements RisksRepository {
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

List<Override> _overrides(RisksRepository spy) => <Override>[
  risksRepositoryProvider.overrideWithValue(spy),
];

const _screen = S8RisksScreen(visitDraftId: 'v1');

Finder _key(String k) => find.byKey(ValueKey<String>(k));

Future<void> _add(WidgetTester tester) =>
    tapInSection(tester, _key('section-add-entry'));

Future<void> _severity(WidgetTester tester, int i, String word) => tapInSection(
  tester,
  find.descendant(of: _key('risk-severity-$i'), matching: find.text(word)),
);

void main() {
  testWidgets('captures a risk with its severity and note, and saves it', (
    tester,
  ) async {
    final spy = _SpyRisks();
    await pumpSection(tester, _screen, overrides: _overrides(spy));

    await _add(tester);
    await typeInSection(tester, _key('risk-type-0'), 'Expired stock');
    await _severity(tester, 0, 'Critical');
    await typeInSection(tester, _key('risk-note-0'), 'Two cases on the floor');
    await saveSection(tester);

    expect(spy.visitDraftId, 'v1');
    final e = spy.entries!.single;
    expect(e.flagType, 'Expired stock');
    expect(e.severity, 'critical');
    expect(e.note, 'Two cases on the floor');
    await disposeAgentScreen(tester);
  });

  testWidgets('rows without a flag type are skipped; severity defaults to '
      'normal', (tester) async {
    final spy = _SpyRisks();
    await pumpSection(tester, _screen, overrides: _overrides(spy));
    await _add(tester);
    await _add(tester);
    await typeInSection(tester, _key('risk-type-1'), 'Broken fridge');
    await saveSection(tester);
    expect(spy.entries!.single.flagType, 'Broken fridge');
    expect(spy.entries!.single.severity, 'normal');
    await disposeAgentScreen(tester);
  });

  testWidgets('a serious risk says so in words and a silhouette, and says '
      'saving raises a task — never the hue alone', (tester) async {
    await pumpSection(tester, _screen, overrides: _overrides(_SpyRisks()));
    await _add(tester);
    expect(_key('risk-severity-note-0'), findsNothing);

    await _severity(tester, 0, 'High');
    final chip = tester.widget<StatusChip>(_key('risk-severity-note-0'));
    expect(chip.level, StatusLevel.watch);
    expect(chip.label, 'High risk — saving it raises a follow-up task');

    await _severity(tester, 0, 'Critical');
    expect(
      tester.widget<StatusChip>(_key('risk-severity-note-0')).level,
      StatusLevel.critical,
    );
    await disposeAgentScreen(tester);
  });

  testWidgets('the remove control names the risk it removes', (tester) async {
    await pumpSection(tester, _screen, overrides: _overrides(_SpyRisks()));
    await _add(tester);
    expect(find.text('Risk 1 of 1'), findsOneWidget);
    expect(
      tester.widget<TorchIconButton>(_key('entry-remove-0')).semanticLabel,
      'Remove risk 1 of 1',
    );
    await disposeAgentScreen(tester);
  });

  group('the amber census', () {
    for (final skin in agentSkinModes) {
      testWidgets('empty is zero; a critical risk with an armed Save is one — '
          '${skin.name}', (tester) async {
        await pumpSection(
          tester,
          _screen,
          overrides: _overrides(_SpyRisks()),
          skin: skin,
        );
        await expectAmber(
          tester,
          skin: skin,
          route: 'risks',
          phase: 'untouched',
          expected: 0,
        );
        await _add(tester);
        await _severity(tester, 0, 'Critical');
        await scrollAgentTo(tester, sectionSave);
        await expectAmber(
          tester,
          skin: skin,
          route: 'risks',
          phase: 'dirty, critical',
          expected: 1,
        );
        await disposeAgentScreen(tester);
      });
    }
  });
}
