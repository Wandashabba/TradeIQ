import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/network/human_error.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/audit/data/skus_repository.dart';
import 'package:tradeiq_app/features/audit/data/template_section_repository.dart';
import 'package:tradeiq_app/features/audit/data/visit_progress.dart';
import 'package:tradeiq_app/features/audit/data/visit_review.dart';
import 'package:tradeiq_app/features/audit/data/visits_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/audit_shell_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import '../agent_harness.dart';

/// Everything the visit hub and the three check-in failures need to stand up
/// without a server, a GPS or a disk.

const testOutlet = Outlet(
  id: 'o1',
  name: 'Kasi Corner Spaza',
  code: 'KC-0412',
  lat: -26.2041,
  lng: 28.0473,
);

class FakeOutlets implements OutletsRepository {
  FakeOutlets({this.outlets = const <Outlet>[testOutlet]});

  final List<Outlet> outlets;

  @override
  Future<PaginatedResponse<Outlet>> listOutlets({
    bool mine = false,
    int? limit,
    String? cursor,
  }) async => PaginatedResponse<Outlet>(data: outlets, nextCursor: null);

  @override
  Future<Outlet> createOutlet({
    required String name,
    required String code,
    required String channelType,
    required double lat,
    required double lng,
    required String territoryId,
  }) => throw UnimplementedError();
}

class FakeSkus implements SkusRepository {
  FakeSkus({this.skus = const <Sku>[], this.fail = false});

  final List<Sku> skus;

  /// A product list that will not load. The reachable route to a
  /// can't-confirm section (#389).
  final bool fail;

  @override
  Future<PaginatedResponse<Sku>> listSkus({
    required String outletId,
    int? limit,
    String? cursor,
  }) async {
    if (fail) throw StateError('the product list did not load');
    return PaginatedResponse<Sku>(data: skus, nextCursor: null);
  }
}

/// A check-in with a scripted outcome.
class ScriptedVisits implements VisitsRepository {
  ScriptedVisits(this._result);

  /// A check-in that throws rather than returning a result. The screen used
  /// to await this with no catch, so the failure went to the console and the
  /// agent was left on the locating radar with no error and no way out.
  ScriptedVisits.throwing() : _result = null, _throws = true;

  /// A check-in that never answers, so the screen stays on the locating
  /// radar. The real thing: a GPS fix in a fridge aisle under a tin roof.
  ScriptedVisits.pending() : _result = null, _pends = true;

  final CheckInResult Function()? _result;
  bool _throws = false;
  bool _pends = false;

  String? submittedId;

  /// How many times check-in was asked for. Retry must reset the started flag
  /// or the post-frame call never fires again.
  int calls = 0;

  factory ScriptedVisits.succeeds() =>
      ScriptedVisits(() => CheckInSucceeded('visit-1'));
  /// A failed fence, measured from a real position — so the wrong-pin
  /// report (#386) has evidence to carry.
  factory ScriptedVisits.tooFar([double metres = 180]) => ScriptedVisits(
    () => CheckInGeofenceFailed(metres, lat: -26.2059, lng: 28.0460),
  );
  factory ScriptedVisits.noGps([
    CheckInLocationProblem problem = CheckInLocationProblem.servicesDisabled,
  ]) => ScriptedVisits(() => CheckInLocationUnavailable.because(problem));

  @override
  Future<CheckInResult> checkIn({
    required String outletId,
    required double outletLat,
    required double outletLng,
  }) async {
    calls++;
    if (_throws) throw StateError('local database unavailable');
    if (_pends) return Completer<CheckInResult>().future;
    return _result!();
  }

  /// Every wrong-pin report filed, in order (#386).
  final disputes =
      <({String outletId, double lat, double lng, double distance, String? note})>[];

  /// Makes the next wrong-pin report fail the way a local write can.
  bool disputeFails = false;

  @override
  Future<CheckInResult> checkInDisputingPin({
    required String outletId,
    required double lat,
    required double lng,
    required double distanceMeters,
    String? note,
  }) async {
    disputes.add((
      outletId: outletId,
      lat: lat,
      lng: lng,
      distance: distanceMeters,
      note: note,
    ));
    if (disputeFails) {
      return CheckInFailed(HumanError.of(StateError('disk full')));
    }
    return CheckInOverridden('visit-flagged', distanceMeters: distanceMeters);
  }

  @override
  Future<void> submitVisit(String visitDraftId) async =>
      submittedId = visitDraftId;
}

/// A client with no audit template — the hub as most clients see it.
class NoTemplate implements TemplateSectionRepository {
  NoTemplate({this.throwsOnPin = false});

  /// A pin that fails outright. The second reachable route to a
  /// can't-confirm section (#389).
  final bool throwsOnPin;

  final pinned = <String>[];

  @override
  Future<void> pinForVisit(String visitDraftId) async {
    if (throwsOnPin) throw StateError('could not pin the template');
    pinned.add(visitDraftId);
  }

  @override
  Future<Map<String, Object?>> savedAnswers({
    required String visitDraftId,
    required String templateId,
  }) async => const <String, Object?>{};

  @override
  Future<void> saveAnswers({
    required String visitDraftId,
    required ClientTemplate template,
    required Map<String, Object?> answers,
  }) async {}
}

/// Nothing captured — the state a visit starts in, so submit is blocked.
const nothingDone = VisitProgress(
  states: <AuditSection, CaptureState>{},
  details: <AuditSection, String>{},
);

/// The four scored sections done — the state that unblocks the submit.
const readyToSubmit = VisitProgress(
  states: <AuditSection, CaptureState>{
    AuditSection.stock: CaptureState.done,
    AuditSection.visibility: CaptureState.done,
    AuditSection.pricing: CaptureState.done,
    AuditSection.capability: CaptureState.done,
  },
  details: <AuditSection, String>{},
);

/// Ready but for one required section the app could not establish.
const cantConfirmStock = VisitProgress(
  states: <AuditSection, CaptureState>{
    AuditSection.stock: CaptureState.cantConfirm,
    AuditSection.visibility: CaptureState.done,
    AuditSection.pricing: CaptureState.done,
    AuditSection.capability: CaptureState.done,
  },
  details: <AuditSection, String>{},
  cantConfirm: <AuditSection, CantConfirmReason>{
    AuditSection.stock: CantConfirmReason.productListUnavailable,
  },
);

/// Pump the visit route.
///
/// [progress] null means "use the real provider", which is what the
/// can't-confirm tests want: they drive the state through the real derivation
/// from a failing repository rather than by handing the screen a record.
Future<void> pumpVisit(
  WidgetTester tester, {
  required VisitsRepository visits,
  VisitProgress? progress = nothingDone,
  TemplateSectionRepository? templates,
  SkusRepository? skus,
  List<Outlet> outlets = const <Outlet>[testOutlet],
  SkinMode skin = SkinMode.night,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
  SyncStatus sync = SyncStatus.empty,
  bool progressThrows = false,
  bool settle = true,
  List<Override> extraOverrides = const <Override>[],
}) async {
  final db = agentTestDb();
  await pumpAgentScreen(
    tester,
    const AuditShellScreen(outletId: 'o1'),
    path: '/audit/o1',
    overrides: <Override>[
      ...agentBaseOverrides(db: db, skin: skin, sync: sync),
      outletsRepositoryProvider.overrideWithValue(FakeOutlets(outlets: outlets)),
      visitsRepositoryProvider.overrideWithValue(visits),
      skusRepositoryProvider.overrideWithValue(skus ?? FakeSkus()),
      templateSectionRepositoryProvider.overrideWithValue(
        templates ?? NoTemplate(),
      ),
      // Drift's `watch()` reschedules a zero-duration timer on every tick, so
      // `pumpAndSettle` NEVER settles against a real stream — the test hangs
      // with no output, which is how this was found twice. A test that is
      // about the DERIVATION passes `progress: null` and must also pass
      // `settle: false`; [pumpVisitLive] does both.
      if (progressThrows)
        visitProgressProvider.overrideWith(
          (ref, arg) => Stream<VisitProgress>.error(StateError('no read')),
        )
      else if (progress != null)
        visitProgressProvider.overrideWith(
          (ref, arg) => Stream<VisitProgress>.value(progress),
        ),
      visitReviewProvider.overrideWith(
        (ref, arg) => Stream<VisitReview>.value(
          const VisitReview(
            skusCounted: 12,
            outOfStock: 0,
            skusPriced: 12,
            competitors: 0,
            photos: 0,
            willRaise: <RaisedTask>[],
          ),
        ),
      ),
      ...extraOverrides,
    ],
    textScale: textScale,
    locale: locale,
    settle: settle,
    extraRoutes: <GoRoute>[
      GoRoute(path: '/today', builder: (c, s) => const Text('Today')),
      GoRoute(path: '/audit', builder: (c, s) => const Text('Outlet picker')),
      GoRoute(
        path: '/audit/:outletId/done',
        builder: (c, s) => const Text('Outcome'),
      ),
      GoRoute(path: '/my-work', builder: (c, s) => const Text('My work')),
    ],
  );
}

/// Pump the visit route against the **real** `visitProgressProvider`.
///
/// The derivation is the thing under test — a failing product list becoming a
/// can't-confirm section, a failed template pin becoming a row — so it cannot
/// be stubbed. Drift's `watch()` reschedules a zero-duration timer forever, so
/// this never calls `pumpAndSettle`: it pumps a fixed number of frames, which
/// is enough for the post-frame check-in, the pin and the first stream event.
///
/// A test that uses this must end with `await disposeAgentScreen(tester)` —
/// cancelling the query stream schedules one last zero-duration timer, and
/// flutter_test's own teardown pump does not elapse the clock far enough to
/// run it. See [disposeAgentScreen].
Future<void> pumpVisitLive(
  WidgetTester tester, {
  required VisitsRepository visits,
  TemplateSectionRepository? templates,
  SkusRepository? skus,
  SkinMode skin = SkinMode.night,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
}) async {
  await pumpVisit(
    tester,
    visits: visits,
    progress: null,
    templates: templates,
    skus: skus,
    skin: skin,
    textScale: textScale,
    locale: locale,
    settle: false,
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}
