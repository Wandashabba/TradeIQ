import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/audit/data/capability_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s7_capability_screen.dart';

import '../agent_harness.dart';
import 'section_harness.dart';

class _SpyCapability implements CapabilityRepository {
  String? visitDraftId;
  CapabilityCapture? capture;

  @override
  Future<void> saveCapability({
    required String visitDraftId,
    required CapabilityCapture capture,
  }) async {
    this.visitDraftId = visitDraftId;
    this.capture = capture;
  }
}

List<Override> _overrides(CapabilityRepository spy) => <Override>[
  capabilityRepositoryProvider.overrideWithValue(spy),
];

const _screen = S7CapabilityScreen(visitDraftId: 'v1');

Finder _key(String k) => find.byKey(ValueKey<String>(k));

void main() {
  testWidgets('captures headcount, training and quiz, and saves them', (
    tester,
  ) async {
    final spy = _SpyCapability();
    await pumpSection(tester, _screen, overrides: _overrides(spy));

    await typeInSection(tester, _key('headcount'), '5');
    await tapInSection(tester, _key('training-productKnowledge'));
    await tapInSection(tester, _key('training-posSystems'));
    await typeInSection(tester, _key('quiz'), '80');
    await saveSection(tester);

    expect(spy.visitDraftId, 'v1');
    expect(spy.capture!.staffHeadcountConfirmed, 5);
    expect(spy.capture!.repTrainingStatus, <String, bool>{
      'productKnowledge': true,
      'merchandising': false,
      'posSystems': true,
    });
    expect(spy.capture!.quizScore, 80);
    expect(
      find.textContaining('Capability saved — queued for sync'),
      findsOneWidget,
    );
    await disposeAgentScreen(tester);
  });

  testWidgets('the Save is a ghost until something changes, and after', (
    tester,
  ) async {
    await pumpSection(tester, _screen, overrides: _overrides(_SpyCapability()));
    await scrollAgentTo(tester, sectionSave);
    await expectAmber(
      tester,
      skin: SkinMode.night,
      route: 'capability',
      phase: 'untouched',
      expected: 0,
    );
    await typeInSection(tester, _key('headcount'), '3');
    await scrollAgentTo(tester, sectionSave);
    await expectAmber(
      tester,
      skin: SkinMode.night,
      route: 'capability',
      phase: 'dirty',
      expected: 1,
    );
    await saveSection(tester);
    await expectAmber(
      tester,
      skin: SkinMode.night,
      route: 'capability',
      phase: 'saved',
      expected: 0,
    );
    await disposeAgentScreen(tester);
  });

  group('the amber census', () {
    for (final skin in agentSkinModes) {
      testWidgets('untouched is zero, armed is one — ${skin.name}', (
        tester,
      ) async {
        await pumpSection(
          tester,
          _screen,
          overrides: _overrides(_SpyCapability()),
          skin: skin,
        );
        await expectAmber(
          tester,
          skin: skin,
          route: 'capability',
          phase: 'untouched',
          expected: 0,
        );
        await tapInSection(tester, _key('training-merchandising'));
        await scrollAgentTo(tester, sectionSave);
        await expectAmber(
          tester,
          skin: skin,
          route: 'capability',
          phase: 'dirty',
          expected: 1,
        );
        await disposeAgentScreen(tester);
      });
    }
  });
}
