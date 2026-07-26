import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/features/audit/data/visit_progress.dart';
import 'package:tradeiq_app/features/audit/data/visit_review.dart';
import 'package:tradeiq_app/core/widgets/agent_kit.dart';
import 'package:tradeiq_app/core/widgets/agent_motion.dart';
import 'package:tradeiq_app/features/audit/data/skus_repository.dart';
import 'package:tradeiq_app/features/audit/data/visits_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/audit_shell_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import '../../core/theme/tiq_colors_test.dart' show contrastRatio;
import '../../helpers/routed_app.dart';

class _FakeOutletsRepository implements OutletsRepository {
  @override
  Future<List<Outlet>> listOutlets({bool mine = false}) async => const [
    Outlet(
      id: 'o1',
      name: 'Test Outlet',
      code: 'TO-001',
      lat: -26.2041,
      lng: 28.0473,
    ),
  ];

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
  }) async => CheckInSucceeded('visit-1');

  @override
  Future<void> submitVisit(String visitDraftId) async =>
      submittedId = visitDraftId;
}

class _GeofenceFailingVisitsRepository implements VisitsRepository {
  @override
  Future<CheckInResult> checkIn({
    required String outletId,
    required double outletLat,
    required double outletLng,
  }) async => CheckInGeofenceFailed(650);

  @override
  Future<void> submitVisit(String visitDraftId) async {}
}

class _LocationUnavailableVisitsRepository implements VisitsRepository {
  @override
  Future<CheckInResult> checkIn({
    required String outletId,
    required double outletLat,
    required double outletLng,
  }) async => CheckInLocationUnavailable('Location permission denied');

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
}) => [
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

Widget _appWith(
  VisitsRepository visitsRepository,
  LocalDb db, {
  VisitProgress progress = _nothingDone,
  ThemeData? theme,
}) {
  return routedApp(
    const AuditShellScreen(outletId: 'o1'),
    overrides: _overrides(visitsRepository, db, progress: progress),
    theme: theme,
  );
}

/// Both themes, each with the palette its assertions read against.
const _bothThemes = [('light', TiqColors.light), ('dark', TiqColors.dark)];

ThemeData _themeFor(String name) =>
    name == 'light' ? AppTheme.light() : AppTheme.dark();

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
  testWidgets('shows the audit as a named checklist after a successful check-in', (
    tester,
  ) async {
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

  testWidgets(
    'submit is blocked until the required sections are done, and says which',
    (tester) async {
      await tester.pumpWidget(
        _appWith(_SucceedingVisitsRepository(), _testDb()),
      );
      await tester.pumpAndSettle();

      // Submitting without them lands a visit with a scorecard dimension at zero,
      // marking the store down for work the agent never did.
      final button = tester.widget<AgentButton>(
        find.byKey(const ValueKey('submit-visit')),
      );
      expect(button.onPressed, isNull);
      expect(find.textContaining('to submit'), findsWidgets);
    },
  );

  testWidgets('shows a blocking error when the check-in fails the geofence', (
    tester,
  ) async {
    await tester.pumpWidget(
      _appWith(_GeofenceFailingVisitsRepository(), _testDb()),
    );
    await tester.pumpAndSettle();

    // The measured distance against the threshold — not a bare "too far".
    expect(find.textContaining('650'), findsOneWidget);
    expect(find.text('Stock & availability'), findsNothing);
  });

  testWidgets('shows a retry action when location is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _appWith(_LocationUnavailableVisitsRepository(), _testDb()),
    );
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

  testWidgets('submit opens the gate first — it does not submit on one tap', (
    tester,
  ) async {
    final repo = _SucceedingVisitsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(repo, _testDb(), progress: _readyToSubmit),
        child: MaterialApp.router(routerConfig: _submitRouter()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Submit visit'));
    await tester.tap(find.byKey(const ValueKey('submit-visit')));
    await tester.pumpAndSettle();

    // Submitting is irreversible and it raises tasks against a real shop. The
    // hub button opens the review; it does not fire the submission.
    expect(repo.submittedId, isNull);
    expect(find.textContaining('cannot change it'), findsOneWidget);
  });

  testWidgets('confirming at the gate submits and ends on the outcome', (
    tester,
  ) async {
    final repo = _SucceedingVisitsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(repo, _testDb(), progress: _readyToSubmit),
        child: MaterialApp.router(routerConfig: _submitRouter()),
      ),
    );
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

  testWidgets(
    'the check-in timestamp does not drift when you leave a section and come back',
    (tester) async {
      await tester.pumpWidget(
        _appWith(_SucceedingVisitsRepository(), _testDb()),
      );
      await tester.pumpAndSettle();

      // The check-in time is evidence: it is half of the dwell measurement the
      // fraud engine reasons over. It must be stamped once, at check-in, and never
      // re-derived on a rebuild.
      await tester.tap(find.byKey(const ValueKey('section-outletInfo')));
      await tester.pumpAndSettle();

      // Opening a section pushes it full-screen — one thing at a time.
      expect(find.text('Confirmed at check-in'), findsOneWidget);

      final first = tester
          .widget<Text>(find.byKey(const ValueKey('checkin-timestamp')))
          .data;

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('section-outletInfo')));
      await tester.pumpAndSettle();

      final second = tester
          .widget<Text>(find.byKey(const ValueKey('checkin-timestamp')))
          .data;

      expect(second, first);
    },
  );

  // ── Premium restyle (sub5b1 Task 2) ─────────────────────────────────────

  // The wash/text of the pill carrying [text], read off the RENDERED tree — so
  // AA is measured on what actually paints. A self-tint regression (critText→
  // crit, or flattening the wash) collapses this ratio and fails the assert on
  // its own merits, rather than being caught only by a token-equality check.
  (Color bg, Color fg) pillColours(WidgetTester tester, Finder text) {
    final container = find
        .ancestor(
          of: text,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).color != null,
          ),
        )
        .first;
    final bg =
        (tester.widget<Container>(container).decoration! as BoxDecoration)
            .color!;
    final fg = tester.widget<Text>(text).style!.color!;
    return (bg, fg);
  }

  testWidgets(
    'the progress panel is a glass hero with a big count and status pill',
    (tester) async {
      for (final (name, palette) in _bothThemes) {
        await tester.pumpWidget(
          _appWith(
            _SucceedingVisitsRepository(),
            _testDb(),
            progress: _readyToSubmit,
            theme: _themeFor(name),
          ),
        );
        await tester.pumpAndSettle();

        // Glass hero: the console's washed-panel recipe — a heroWash→surface1
        // gradient under a heroBorder hairline, not a flat surface1 card.
        final hero = tester.widget<Container>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('visit-progress')),
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is Container &&
                      w.decoration is BoxDecoration &&
                      (w.decoration! as BoxDecoration).gradient != null,
                ),
              )
              .first,
        );
        final deco = hero.decoration! as BoxDecoration;
        final grad = deco.gradient! as LinearGradient;
        expect(grad.colors, [
          palette.heroWash,
          palette.surface1,
        ], reason: '$name hero gradient');
        expect(
          (deco.border! as Border).top.color,
          palette.heroBorder,
          reason: '$name hero border',
        );

        // The count is the biggest thing in the panel — 30–32px ink1.
        final count = tester.widget<AnimatedCount>(find.byType(AnimatedCount));
        expect(count.value, 4, reason: '$name four sections done');
        expect(
          count.style.fontSize,
          inInclusiveRange(30, 32),
          reason: '$name count size',
        );
        expect(count.style.color, palette.ink1, reason: '$name count colour');

        // Unblocked → a good-wash status pill carrying the WORDS. AA is
        // measured on the RENDERED pair, so a self-tint regression fails here
        // on its own, not only via the token-equality check below.
        final (readyBg, readyFg) = pillColours(
          tester,
          find.text('Ready to submit'),
        );
        expect(readyFg, palette.good, reason: '$name ready pill text');
        // Pin the wash itself: flattening the bg (keeping green text) must fail
        // a test, so the ready state stays visibly distinct from the neutral
        // chip — good-on-surface2 would still clear AA and hide the loss.
        expect(
          readyBg,
          Color.alphaBlend(
            palette.good.withValues(alpha: 0.12),
            palette.surface1,
          ),
          reason: '$name ready pill wash',
        );
        expect(
          readyBg,
          isNot(palette.surface2),
          reason: '$name ready wash differs from the neutral chip',
        );
        expect(
          contrastRatio(readyFg, readyBg),
          greaterThanOrEqualTo(4.5),
          reason: '$name ready pill AA (rendered pair)',
        );
      }
    },
  );

  testWidgets('a blocked visit says how many sections are still required', (
    tester,
  ) async {
    for (final (name, palette) in _bothThemes) {
      await tester.pumpWidget(
        _appWith(
          _SucceedingVisitsRepository(),
          _testDb(),
          theme: _themeFor(name),
        ),
      );
      await tester.pumpAndSettle();

      // The four scored sections are required; none are done in the default
      // state, so the pill counts them in words — never colour alone.
      final pill = tester.widget<Text>(find.text('4 still required'));
      expect(pill.style!.color, palette.ink3, reason: '$name blocked pill');
    }
  });

  testWidgets('the checked-in arrival keeps the "In store" honesty subtitle', (
    tester,
  ) async {
    for (final (name, _) in _bothThemes) {
      await tester.pumpWidget(
        _appWith(
          _SucceedingVisitsRepository(),
          _testDb(),
          theme: _themeFor(name),
        ),
      );
      await tester.pumpAndSettle();

      // Check-in success stays visible two ways: the dwell subtitle, and the
      // hub itself being legible (a section is on screen). Neither is removed.
      expect(
        find.textContaining('In store'),
        findsOneWidget,
        reason: '$name dwell subtitle',
      );
      expect(
        find.text('Stock & availability'),
        findsOneWidget,
        reason: '$name hub visible',
      );
    }
  });

  testWidgets(
    'section rows carry a state mark + word, and REQUIRED pills clear AA',
    (tester) async {
      for (final (name, palette) in _bothThemes) {
        await tester.pumpWidget(
          _appWith(
            _SucceedingVisitsRepository(),
            _testDb(),
            theme: _themeFor(name),
          ),
        );
        await tester.pumpAndSettle();

        // The row is a console row: the section name in words, plus a status
        // line ("Not started") — the state never rides on colour alone.
        expect(find.byKey(const ValueKey('section-stock')), findsOneWidget);
        expect(find.text('Stock & availability'), findsOneWidget);
        expect(find.text('Not started'), findsWidgets);

        // The REQUIRED-to-submit pill carries the words in critText on a crit
        // wash. AA measured on the rendered pair, so a critText→crit mutation
        // (raw crit fails AA in dark) fails this assert directly.
        final (reqBg, reqFg) = pillColours(
          tester,
          find.text('REQUIRED TO SUBMIT').first,
        );
        expect(reqFg, palette.critText, reason: '$name required pill text');
        expect(
          contrastRatio(reqFg, reqBg),
          greaterThanOrEqualTo(4.5),
          reason: '$name required pill AA (rendered pair)',
        );
      }
    },
  );

  testWidgets(
    'the too-far screen keeps the distance + fraud note, theme-aware',
    (tester) async {
      for (final (name, palette) in _bothThemes) {
        await tester.pumpWidget(
          _appWith(
            _GeofenceFailingVisitsRepository(),
            _testDb(),
            theme: _themeFor(name),
          ),
        );
        await tester.pumpAndSettle();

        // The measured distance against the threshold, and the fraud-signal
        // note, are both honesty signals that must survive the restyle.
        expect(find.byKey(const ValueKey('checkin-distance')), findsOneWidget);
        expect(
          find.textContaining('650 m away'),
          findsOneWidget,
          reason: '$name distance copy',
        );
        expect(
          find.textContaining('fraud signal'),
          findsOneWidget,
          reason: '$name fraud note',
        );

        // The distance pill reads in critText on a crit wash — AA measured on
        // the rendered pair, so a critText→crit mutation fails here directly.
        final (distBg, distFg) = pillColours(
          tester,
          find.textContaining('650 m away'),
        );
        expect(distFg, palette.critText, reason: '$name distance text');
        expect(
          contrastRatio(distFg, distBg),
          greaterThanOrEqualTo(4.5),
          reason: '$name distance pill AA (rendered pair)',
        );
      }
    },
  );

  test('no non-geometry AppColors. remain in the hub source', () {
    // Geometry (radii) stays on AppColors; every colour must read from the
    // ambient theme via context.colors, so both themes render.
    final src = File(
      'lib/features/audit/presentation/audit_shell_screen.dart',
    ).readAsStringSync();
    final offenders = RegExp(
      r'AppColors\.(?!radiusPanel|radiusControl)\w+',
    ).allMatches(src).map((m) => m.group(0)).toSet().toList();
    expect(offenders, isEmpty, reason: 'use context.colors for: $offenders');
  });
}
