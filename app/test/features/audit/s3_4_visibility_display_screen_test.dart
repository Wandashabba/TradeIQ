import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/camera/photo_capture_service.dart';
import 'package:tradeiq_app/features/audit/data/photos_repository.dart';
import 'package:tradeiq_app/features/audit/data/visibility_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s3_4_visibility_display_screen.dart';

import '../agent_harness.dart';
import 'section_harness.dart';

class _SpyVisibility implements VisibilityRepository {
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

List<Override> _overrides(
  VisibilityRepository spy, {
  QueuedPhotosRepository? photos,
}) => <Override>[
  visibilityRepositoryProvider.overrideWithValue(spy),
  if (photos != null) queuedPhotosRepositoryProvider.overrideWithValue(photos),
  photoCaptureServiceProvider.overrideWithValue(fakeCapture()),
  scriptedExposure(0.5),
];

const _screen = S3S4VisibilityDisplayScreen(visitDraftId: 'v1');

Finder _key(String k) => find.byKey(ValueKey<String>(k));

void main() {
  testWidgets('captures branding, planogram, facings, cleanliness and '
      'high traffic, and saves them', (tester) async {
    final spy = _SpyVisibility();
    await pumpSection(tester, _screen, overrides: _overrides(spy));

    await tapInSection(tester, _key('branding-poster'));
    await tapInSection(tester, _key('branding-wobbler'));
    await typeInSection(tester, _key('planogram'), '72.5');
    await typeInSection(tester, _key('facings'), '6');
    await typeInSection(tester, _key('cleanliness'), '4');
    await tapInSection(tester, _key('high-traffic'));
    await saveSection(tester);

    expect(spy.visitDraftId, 'v1');
    final c = spy.capture!;
    expect(c.brandingElements, <String, bool>{
      'poster': true,
      'shelfStrip': false,
      'wobbler': true,
    });
    expect(c.planogramCompliancePct, 72.5);
    expect(c.facingsCount, 6);
    expect(c.cleanlinessScore, 4);
    expect(c.highTrafficPass, isTrue);
    expect(
      find.textContaining('Visibility saved — queued for sync'),
      findsOneWidget,
    );
    await disposeAgentScreen(tester);
  });

  testWidgets('an Afrikaans planogram typed with a comma is the percentage', (
    tester,
  ) async {
    final spy = _SpyVisibility();
    await pumpSection(
      tester,
      _screen,
      overrides: _overrides(spy),
      locale: const Locale('af'),
    );
    await typeInSection(tester, _key('planogram'), '72,5');
    await saveSection(tester);
    expect(spy.capture!.planogramCompliancePct, 72.5);
    await disposeAgentScreen(tester);
  });

  testWidgets('the shelf photo is queued under section: visibility — evidence, '
      'never the vision seam', (tester) async {
    final photos = SpyQueuedPhotos();
    await pumpSection(
      tester,
      _screen,
      overrides: _overrides(_SpyVisibility(), photos: photos),
    );
    await takeSectionPhoto(tester);
    await saveSection(tester);
    expect(photos.calls.single['section'], 'visibility');
    expect(photos.calls.single['visitDraftId'], 'v1');
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
          overrides: _overrides(_SpyVisibility()),
          skin: skin,
        );
        await expectAmber(
          tester,
          skin: skin,
          route: 'visibility',
          phase: 'untouched',
          expected: 0,
        );
        await tapInSection(tester, _key('high-traffic'));
        await scrollAgentTo(tester, sectionSave);
        await expectAmber(
          tester,
          skin: skin,
          route: 'visibility',
          phase: 'dirty',
          expected: 1,
        );
        await disposeAgentScreen(tester);
      });
    }
  });
}
