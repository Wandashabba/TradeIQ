import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/camera/photo_capture_service.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/theme/torchlight/agent_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/features/audit/data/photos_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/audit_shell_screen.dart';
import 'package:tradeiq_app/features/audit/presentation/pin_dispute_view.dart';

import '../../core/design/amber_golden.dart';
import '../agent_harness.dart';
import 'visit_harness.dart';

/// "THE PIN IS WRONG" (#386), from the agent's side.
///
/// An outlet pinned to the depot car park measures 8.4 km from the agent
/// standing inside it, forever. The override that lets that visit happen is an
/// override on the anti-fraud control, so what these tests hold it to is that
/// it is VISIBLE: it carries the failed check-in's own evidence, it never
/// reports a pass, and the hub keeps saying so with flags the agent cannot
/// clear.

class _QueuedPhotos implements QueuedPhotosRepository {
  final queued =
      <({String visitDraftId, String section, String dataUrl, String? source})>[];

  @override
  Future<void> queuePhoto({
    required String visitDraftId,
    required String section,
    required String dataUrl,
    Map<String, dynamic> gpsTag = const <String, dynamic>{},
    DateTime? capturedAt,
    String? source,
  }) async => queued.add((
    visitDraftId: visitDraftId,
    section: section,
    dataUrl: dataUrl,
    source: source,
  ));
}

final _storefront = CapturedPhoto(
  dataUrl: 'data:image/jpeg;base64,AAAA',
  byteLength: 4,
  capturedAt: DateTime.utc(2026, 9, 19, 8, 30),
  source: PhotoSource.camera,
  gpsTag: const <String, dynamic>{'lat': -26.2059, 'lng': 28.046},
);

Future<void> _pumpTooFar(
  WidgetTester tester, {
  required ScriptedVisits visits,
  _QueuedPhotos? photos,
  CapturedPhoto? photo,
  SkinMode skin = SkinMode.night,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
}) => pumpVisit(
  tester,
  visits: visits,
  skin: skin,
  textScale: textScale,
  locale: locale,
  extraOverrides: <Override>[
    queuedPhotosRepositoryProvider.overrideWithValue(photos ?? _QueuedPhotos()),
    storefrontPhotoPickerProvider.overrideWithValue((context) async => photo),
  ],
);

Future<void> _tapKey(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey<String>(key));
  await scrollAgentTo(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _openReport(WidgetTester tester) =>
    _tapKey(tester, 'pin-is-wrong');

TorchScope _scope(WidgetTester tester) =>
    TorchScope.maybeOf(tester.element(find.byType(TorchShell)))!;

void main() {
  group('the action on the too-far screen', () {
    testWidgets('is offered, quietly, under the distance', (tester) async {
      await _pumpTooFar(tester, visits: ScriptedVisits.tooFar(180));
      expect(
        find.byKey(const ValueKey<String>('pin-is-wrong'), skipOffstage: false),
        findsOneWidget,
      );
      // Retry is still the primary: walking closer is still the right answer
      // most of the time, and the report must not compete with it.
      expect(
        _scope(tester).allocation.isLit(AuditShellScreen.retryClaimId),
        isTrue,
      );
      expect(
        _scope(tester).allocation.isLit(AuditShellScreen.pinDisputeClaimId),
        isFalse,
      );
    });

    testWidgets('is offered at the depot distance #386 was filed about', (
      tester,
    ) async {
      await _pumpTooFar(tester, visits: ScriptedVisits.tooFar(8400));
      expect(
        find.byKey(const ValueKey<String>('pin-is-wrong'), skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('beyond the server cap it names who can fix it instead', (
      tester,
    ) async {
      // A claim the server will refuse would queue a visit that never syncs,
      // and the agent's whole visit with it.
      await _pumpTooFar(tester, visits: ScriptedVisits.tooFar(31000));
      expect(
        find.byKey(const ValueKey<String>('pin-is-wrong'), skipOffstage: false),
        findsNothing,
      );
      expect(
        find.text(
          'This is too far to report the pin from here. Ask your manager to '
          'correct this store.',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    });
  });

  group('the report', () {
    testWidgets('says what it overrides before the agent commits', (
      tester,
    ) async {
      await _pumpTooFar(tester, visits: ScriptedVisits.tooFar(180));
      await _openReport(tester);

      expect(find.text('Report the pin and start the visit'), findsOneWidget);
      // The evidence it carries without the agent adding anything.
      final evidence = find.byKey(
        const ValueKey<String>('pin-dispute-evidence'),
      );
      expect(evidence, findsOneWidget);
      expect(
        find.descendant(of: evidence, matching: find.byType(FigureSlot)),
        findsOneWidget,
      );
      expect(
        find.text(
          'Where you are standing, as your phone recorded it',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      // And, in words, that this is flagged and not theirs to clear.
      expect(
        find.textContaining('stays flagged', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.textContaining('cannot clear the flag', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('going back returns to the distance, having filed nothing', (
      tester,
    ) async {
      final visits = ScriptedVisits.tooFar(180);
      await _pumpTooFar(tester, visits: visits);
      await _openReport(tester);
      await _tapKey(tester, 'pin-dispute-back');

      expect(find.text('You’re too far away'), findsOneWidget);
      expect(visits.disputes, isEmpty);
    });

    testWidgets(
      'filing carries the failed check-in position and distance, and the note',
      (tester) async {
        final visits = ScriptedVisits.tooFar(8400);
        await _pumpTooFar(tester, visits: visits);
        await _openReport(tester);

        final note = find.byKey(const ValueKey<String>('pin-dispute-note'));
        await scrollAgentTo(tester, note);
        await tester.enterText(
          find.descendant(of: note, matching: find.byType(EditableText)),
          'Pinned on the depot',
        );
        await _tapKey(tester, 'pin-dispute-submit');

        expect(visits.disputes, hasLength(1));
        final filed = visits.disputes.single;
        // The failure's own measurement — not a second fix taken at the
        // moment of filing, which could be anywhere by then.
        expect(filed.outletId, 'o1');
        expect(filed.lat, -26.2059);
        expect(filed.lng, 28.0460);
        expect(filed.distance, 8400);
        expect(filed.note, 'Pinned on the depot');
      },
    );

    testWidgets('lands on the hub with two flags that say so', (tester) async {
      await _pumpTooFar(tester, visits: ScriptedVisits.tooFar(180));
      await _openReport(tester);
      await _tapKey(tester, 'pin-dispute-submit');

      // The hub, not a success screen that forgets how it got here.
      expect(
        find.byKey(const ValueKey<String>('visit-progress')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('flag-out-of-fence')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('flag-pin-reported')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Out of fence', findRichText: true),
        findsWidgets,
      );
      expect(find.textContaining('180 m', findRichText: true), findsWidgets);
    });

    testWidgets('the flags are neutral members, never the severity one', (
      tester,
    ) async {
      await _pumpTooFar(tester, visits: ScriptedVisits.tooFar(180));
      await _openReport(tester);
      await _tapKey(tester, 'pin-dispute-submit');

      final kinds = tester
          .widgetList<FlagChip>(find.byType(FlagChip))
          .map((c) => c.kind)
          .toList();
      expect(kinds, <FlagKind>[FlagKind.outOfFence, FlagKind.forReview]);
      expect(kinds, isNot(contains(FlagKind.sentBack)));
    });

    testWidgets('a flag opens a sheet that says what the manager sees', (
      tester,
    ) async {
      await _pumpTooFar(tester, visits: ScriptedVisits.tooFar(180));
      await _openReport(tester);
      await _tapKey(tester, 'pin-dispute-submit');

      await tester.tap(find.byKey(const ValueKey<String>('flag-out-of-fence')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('visit-flag-sheet-body')),
        findsOneWidget,
      );
      expect(
        find.textContaining('the flag stays until they do'),
        findsOneWidget,
      );
    });

    testWidgets('a storefront photo is queued against the new visit', (
      tester,
    ) async {
      final photos = _QueuedPhotos();
      await _pumpTooFar(
        tester,
        visits: ScriptedVisits.tooFar(180),
        photos: photos,
        photo: _storefront,
      );
      await _openReport(tester);
      await _tapKey(tester, 'pin-dispute-photo');
      expect(
        find.byKey(
          const ValueKey<String>('pin-dispute-photo-added'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(
        find.text('Your photo of the storefront', skipOffstage: false),
        findsOneWidget,
      );
      await _tapKey(tester, 'pin-dispute-submit');

      expect(photos.queued, hasLength(1));
      expect(photos.queued.single.visitDraftId, 'visit-flagged');
      expect(photos.queued.single.section, 'pin_dispute');
      expect(photos.queued.single.dataUrl, _storefront.dataUrl);
      // WHERE the picture came from travels with it. Without this the server
      // cannot tell a photo of the shop from a screenshot picked at home —
      // a gallery image is stamped with the time it was PICKED and the
      // position at that moment, which agree with the claim perfectly and
      // say nothing about the shop.
      expect(photos.queued.single.source, 'camera');
    });

    testWidgets('no photo queues nothing — it is optional', (tester) async {
      final photos = _QueuedPhotos();
      await _pumpTooFar(
        tester,
        visits: ScriptedVisits.tooFar(180),
        photos: photos,
      );
      await _openReport(tester);
      await _tapKey(tester, 'pin-dispute-submit');
      expect(photos.queued, isEmpty);
      expect(
        find.byKey(const ValueKey<String>('flag-out-of-fence')),
        findsOneWidget,
      );
    });

    testWidgets('a failure stays on the report and says why', (tester) async {
      final visits = ScriptedVisits.tooFar(180)..disputeFails = true;
      await _pumpTooFar(tester, visits: visits);
      await _openReport(tester);
      await _tapKey(tester, 'pin-dispute-submit');

      final error = find.byKey(const ValueKey<String>('pin-dispute-error'));
      await scrollAgentTo(tester, error);
      expect(error, findsOneWidget);
      expect(find.byType(FlagChip), findsNothing);
      // Still on the report, with what the agent typed — not thrown back to
      // the distance to start again.
      expect(find.byType(PinDisputeView), findsOneWidget);
    });

    testWidgets('an ordinary check-in carries no flags', (tester) async {
      await pumpVisit(tester, visits: ScriptedVisits.succeeds());
      expect(find.byType(FlagChip), findsNothing);
    });
  });

  group('the amber census', () {
    for (final skin in agentSkinModes) {
      testWidgets('the report is exactly one — ${skin.name}', (tester) async {
        await _pumpTooFar(
          tester,
          visits: ScriptedVisits.tooFar(180),
          skin: skin,
        );
        await _openReport(tester);
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          agentSkinFor(skin),
          route: 'check-in / pin is wrong',
          phase: 'pin-dispute',
        );
        expect(census.objectCount, 1, reason: census.describe());
      });

      testWidgets('a flagged, blocked hub emits nothing — ${skin.name}', (
        tester,
      ) async {
        // The flags are labels, and amber is not a label.
        await _pumpTooFar(
          tester,
          visits: ScriptedVisits.tooFar(180),
          skin: skin,
        );
        await _openReport(tester);
        await _tapKey(tester, 'pin-dispute-submit');
        final census = await amberCensus(tester);
        expect(census.objectCount, 0, reason: census.describe());
      });
    }

    testWidgets('the report declares its primary, and nothing else', (
      tester,
    ) async {
      await _pumpTooFar(tester, visits: ScriptedVisits.tooFar(180));
      await _openReport(tester);
      final allocation = _scope(tester).allocation;
      expect(allocation.isLit(AuditShellScreen.pinDisputeClaimId), isTrue);
      expect(allocation.isLit(AuditShellScreen.retryClaimId), isFalse);
    });
  });

  group('2.0× text', () {
    testWidgets('the report lays out in Afrikaans at 2.0×', (tester) async {
      await _pumpTooFar(
        tester,
        visits: ScriptedVisits.tooFar(180),
        textScale: 2.0,
        locale: const Locale('af'),
      );
      await _openReport(tester);
      expect(tester.takeException(), isNull);
      expect(
        find.text(
          'Meld die speld aan en begin die besoek',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      await scrollAgentTo(
        tester,
        find.byKey(const ValueKey<String>('pin-dispute-photo')),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the flagged hub header lays out at 2.0×', (tester) async {
      // English at 2.0×. Afrikaans at 2.0× overflows the BLOCKED hub by 37dp
      // with no flags at all — the thumb zone's blocker note naming four
      // sections is taller than a 360×640 viewport leaves it — which is a
      // TorchShell problem that predates this change and is reported, not
      // papered over here. The flags live in the header, which scrolls.
      await _pumpTooFar(
        tester,
        visits: ScriptedVisits.tooFar(180),
        textScale: 2.0,
      );
      await _openReport(tester);
      await _tapKey(tester, 'pin-dispute-submit');
      expect(tester.takeException(), isNull);
      // At 2.0× the thumb zone takes most of a 360×640 phone and the header
      // scrolls with the body, by design — so the flag is scrolled to, and
      // must lay out without overflow on the way.
      final flag = find.byKey(const ValueKey<String>('flag-out-of-fence'));
      await scrollAgentTo(tester, flag);
      expect(tester.takeException(), isNull);
      expect(flag, findsOneWidget);
    });

    testWidgets('the flags speak Afrikaans', (tester) async {
      await _pumpTooFar(
        tester,
        visits: ScriptedVisits.tooFar(180),
        locale: const Locale('af'),
      );
      await _openReport(tester);
      await _tapKey(tester, 'pin-dispute-submit');
      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('Buite heining', findRichText: true),
        findsWidgets,
      );
      expect(
        find.textContaining('Speld aangemeld', findRichText: true),
        findsWidgets,
      );
    });
  });
}
