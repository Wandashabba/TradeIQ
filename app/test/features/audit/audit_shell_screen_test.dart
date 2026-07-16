import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/features/audit/data/visit_progress.dart';
import 'package:tradeiq_app/features/audit/data/visit_review.dart';
import 'package:tradeiq_app/core/widgets/agent_kit.dart';
import 'package:tradeiq_app/features/audit/data/skus_repository.dart';
import 'package:tradeiq_app/features/audit/data/visits_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/audit_shell_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import '../../helpers/routed_app.dart';

class _FakeOutletsRepository implements OutletsRepository {
  @override
  Future<List<Outlet>> listOutlets() async => const [
        Outlet(id: 'o1', name: 'Test Outlet', code: 'TO-001', lat: -26.2041, lng: 28.0473),
      ];

  @override
  Future<Outlet> createOutlet({
    required String name,
    required String code,
    required String channelType,
    required double lat,
    required double lng,
    required String territoryId,
  }) =>
      throw UnimplementedError();
}

class _FakeSkusRepository implements SkusRepository {
  @override
  Future<List<Sku>> listSkus({required String outletId}) async => const [];
}

class _SucceedingVisitsRepository implements VisitsRepository {
  String? submittedId;

  @override
  Future<CheckInResult> checkIn({
    required String outletId,
    required double outletLat,
    required double outletLng,
  }) async =>
      CheckInSucceeded('visit-1');

  @override
  Future<void> submitVisit(String visitDraftId) async => submittedId = visitDraftId;
}

class _GeofenceFailingVisitsRepository implements VisitsRepository {
  @override
  Future<CheckInResult> checkIn({
    required String outletId,
    required double outletLat,
    required double outletLng,
  }) async =>
      CheckInGeofenceFailed(650);

  @override
  Future<void> submitVisit(String visitDraftId) async {}
}

class _LocationUnavailableVisitsRepository implements VisitsRepository {
  @override
  Future<CheckInResult> checkIn({
    required String outletId,
    required double outletLat,
    required double outletLng,
  }) async =>
      CheckInLocationUnavailable('Location permission denied');

  @override
  Future<void> submitVisit(String visitDraftId) async {}
}

// The S10 scorecard section computes from the local DB on build, so the
// shell tests need a real (in-memory) LocalDb behind the provider.
/// Nothing captured — the state a visit starts in, so submit is blocked.
const _nothingDone = VisitProgress(states: {}, details: {});

/// The four scored sections done — the state that unblocks submit.
const _readyToSubmit = VisitProgress(
  states: {
    AuditSection.stock: SectionState.done,
    AuditSection.visibility: SectionState.done,
    AuditSection.pricing: SectionState.done,
    AuditSection.capability: SectionState.done,
  },
  details: {},
);

List<Override> _overrides(
  VisitsRepository visitsRepository,
  LocalDb db, {
  VisitProgress progress = _nothingDone,
}) =>
    [
      outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
      visitsRepositoryProvider.overrideWithValue(visitsRepository),
      skusRepositoryProvider.overrideWithValue(_FakeSkusRepository()),
      localDbProvider.overrideWithValue(db),
      // Drift's watch() reschedules a zero-duration timer on every tick, so
      // pumpAndSettle never settles against a real stream. Widget tests stub the
      // derived providers; visit_progress_test and sync_status_test cover the
      // real queries against a real database.
      syncStatusProvider.overrideWith((ref) => Stream.value(SyncStatus.empty)),
      visitProgressProvider.overrideWith((ref, arg) => Stream.value(progress)),
      // The submit gate reads the outbox too — same rule, same reason.
      visitReviewProvider.overrideWith(
        (ref, arg) => Stream.value(
          const VisitReview(
            skusCounted: 12,
            outOfStock: 0,
            skusPriced: 12,
            competitors: 0,
            photos: 0,
            willRaise: [],
          ),
        ),
      ),
    ];

Widget _appWith(VisitsRepository visitsRepository, LocalDb db) {
  return routedApp(
    const AuditShellScreen(outletId: 'o1'),
    overrides: _overrides(visitsRepository, db),
  );
}

LocalDb _testDb() {
  final db = LocalDb(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

/// The hub plus the two places a submit can land: the outcome (on confirm) and
/// the picker (on back out).
GoRouter _submitRouter() => GoRouter(
      initialLocation: '/audit/o1',
      routes: [
        GoRoute(
          path: '/audit',
          builder: (context, state) => const Text('Outlet Picker'),
        ),
        GoRoute(
          path: '/audit/:outletId',
          builder: (context, state) => const AuditShellScreen(outletId: 'o1'),
        ),
        GoRoute(
          path: '/audit/:outletId/done',
          builder: (context, state) => const Text('Outcome'),
        ),
      ],
    );

void main() {
  testWidgets('shows the audit as a named checklist after a successful check-in', (tester) async {
    await tester.pumpWidget(_appWith(_SucceedingVisitsRepository(), _testDb()));
    await tester.pumpAndSettle();

    // The old shell was a Material Stepper built with
    // `Step(title: SizedBox.shrink())` — nine sections with NO titles. An agent
    // could not see which section they were on, what was done, or what was left.
    expect(find.text('Outlet info'), findsOneWidget);
    expect(find.text('Stock & availability'), findsOneWidget);
    expect(find.text('Score'), findsOneWidget);
    expect(find.byKey(const ValueKey('visit-progress')), findsOneWidget);
  });

  testWidgets('submit is blocked until the required sections are done, and says which', (tester) async {
    await tester.pumpWidget(_appWith(_SucceedingVisitsRepository(), _testDb()));
    await tester.pumpAndSettle();

    // Submitting without them lands a visit with a scorecard dimension at zero,
    // marking the store down for work the agent never did.
    final button = tester.widget<AgentButton>(
      find.byKey(const ValueKey('submit-visit')),
    );
    expect(button.onPressed, isNull);
    expect(find.textContaining('to submit'), findsWidgets);
  });

  testWidgets('shows a blocking error when the check-in fails the geofence', (tester) async {
    await tester.pumpWidget(_appWith(_GeofenceFailingVisitsRepository(), _testDb()));
    await tester.pumpAndSettle();

    // The measured distance against the threshold — not a bare "too far".
    expect(find.textContaining('650'), findsOneWidget);
    expect(find.text('Stock & availability'), findsNothing);
  });

  testWidgets('shows a retry action when location is unavailable', (tester) async {
    await tester.pumpWidget(_appWith(_LocationUnavailableVisitsRepository(), _testDb()));
    await tester.pumpAndSettle();

    expect(find.text('Location permission denied'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('tapping logout clears the session', (tester) async {
    await tester.pumpWidget(_appWith(_SucceedingVisitsRepository(), _testDb()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pump();

    final context = tester.element(find.byType(AuditShellScreen));
    final container = ProviderScope.containerOf(context);
    expect(container.read(sessionControllerProvider).value?.role, isNull);
  });

  testWidgets('submit opens the gate first — it does not submit on one tap', (tester) async {
    final repo = _SucceedingVisitsRepository();

    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(repo, _testDb(), progress: _readyToSubmit),
      child: MaterialApp.router(routerConfig: _submitRouter()),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Submit visit'));
    await tester.tap(find.byKey(const ValueKey('submit-visit')));
    await tester.pumpAndSettle();

    // Submitting is irreversible and it raises tasks against a real shop. The
    // hub button opens the review; it does not fire the submission.
    expect(repo.submittedId, isNull);
    expect(find.textContaining('cannot change it'), findsOneWidget);
  });

  testWidgets('confirming at the gate submits and ends on the outcome', (tester) async {
    final repo = _SucceedingVisitsRepository();

    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(repo, _testDb(), progress: _readyToSubmit),
      child: MaterialApp.router(routerConfig: _submitRouter()),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Submit visit'));
    await tester.tap(find.byKey(const ValueKey('submit-visit')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('confirm-submit')));
    await tester.pumpAndSettle();

    expect(repo.submittedId, 'visit-1');
    // The visit ends on its score, not back at a list of outlets.
    expect(find.text('Outcome'), findsOneWidget);
  });

  testWidgets('the check-in timestamp does not drift when you leave a section and come back', (tester) async {
    await tester.pumpWidget(_appWith(_SucceedingVisitsRepository(), _testDb()));
    await tester.pumpAndSettle();

    // The check-in time is evidence: it is half of the dwell measurement the
    // fraud engine reasons over. It must be stamped once, at check-in, and never
    // re-derived on a rebuild.
    await tester.tap(find.byKey(const ValueKey('section-outletInfo')));
    await tester.pumpAndSettle();

    // Opening a section pushes it full-screen — one thing at a time.
    expect(find.text('S1 Outlet Information'), findsOneWidget);

    final first = tester
        .widget<Text>(find.textContaining('Checked in at').first)
        .data;

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('section-outletInfo')));
    await tester.pumpAndSettle();

    final second = tester
        .widget<Text>(find.textContaining('Checked in at').first)
        .data;

    expect(second, first);
  });
}
