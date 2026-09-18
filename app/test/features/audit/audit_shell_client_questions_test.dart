import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/agent_kit.dart';
import 'package:tradeiq_app/features/audit/data/skus_repository.dart';
import 'package:tradeiq_app/features/audit/data/template_section_repository.dart';
import 'package:tradeiq_app/features/audit/data/visit_progress.dart';
import 'package:tradeiq_app/features/audit/data/visit_review.dart';
import 'package:tradeiq_app/features/audit/data/visits_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/audit_shell_screen.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/client_questions_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import '../../helpers/routed_app.dart';

// The client-questions section on the visit hub (#122): shown only for a
// client with an audit template, gated like the fixed sections.

class _Outlets implements OutletsRepository {
  @override
  Future<PaginatedResponse<Outlet>> listOutlets({
    bool mine = false,
    int? limit,
    String? cursor,
  }) async => const PaginatedResponse(
    data: [
      Outlet(id: 'o1', name: 'Test Outlet', code: 'TO-001', lat: -26.2, lng: 28.04),
    ],
    nextCursor: null,
  );

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

class _Skus implements SkusRepository {
  @override
  Future<PaginatedResponse<Sku>> listSkus({
    required String outletId,
    int? limit,
    String? cursor,
  }) async => const PaginatedResponse(data: [], nextCursor: null);
}

class _Visits implements VisitsRepository {
  @override
  Future<CheckInResult> checkIn({
    required String outletId,
    required double outletLat,
    required double outletLng,
  }) async => CheckInSucceeded('visit-1');

  @override
  Future<void> submitVisit(String visitDraftId) async {}
}

class _Sections implements TemplateSectionRepository {
  final pinned = <String>[];

  @override
  Future<void> pinForVisit(String visitDraftId) async => pinned.add(visitDraftId);

  @override
  Future<Map<String, Object?>> savedAnswers({
    required String visitDraftId,
    required String templateId,
  }) async => const {};

  @override
  Future<void> saveAnswers({
    required String visitDraftId,
    required ClientTemplate template,
    required Map<String, Object?> answers,
  }) async {}
}

ClientTemplate _template({bool required = true}) => ClientTemplate(
  templateId: 'tpl-1',
  name: 'Promo Check',
  version: 3,
  schemaJson: {
    'sections': [
      {
        'id': 'promo',
        'title': 'Promo stand',
        'fields': [
          {'id': 'facings', 'label': 'Promo facings', 'type': 'number', 'required': required},
        ],
      },
    ],
  },
);

const _fixedDone = {
  AuditSection.stock: CaptureState.done,
  AuditSection.visibility: CaptureState.done,
  AuditSection.pricing: CaptureState.done,
  AuditSection.capability: CaptureState.done,
};

VisitProgress _progress({
  TemplateSectionProgress? template,
  Map<AuditSection, CaptureState> states = _fixedDone,
}) => VisitProgress(states: states, details: const {}, template: template);

Widget _hub(
  VisitProgress progress, {
  _Sections? sections,
  ThemeData? theme,
  Locale? locale,
}) {
  final db = LocalDb(NativeDatabase.memory());
  addTearDown(db.close);
  final overrides = <Override>[
    outletsRepositoryProvider.overrideWithValue(_Outlets()),
    visitsRepositoryProvider.overrideWithValue(_Visits()),
    skusRepositoryProvider.overrideWithValue(_Skus()),
    templateSectionRepositoryProvider.overrideWithValue(sections ?? _Sections()),
    localDbProvider.overrideWithValue(db),
    syncStatusProvider.overrideWith((ref) => Stream.value(SyncStatus.empty)),
    visitProgressProvider.overrideWith((ref, arg) => Stream.value(progress)),
    visitReviewProvider.overrideWith(
      (ref, arg) => Stream.value(
        const VisitReview(
          skusCounted: 0,
          outOfStock: 0,
          skusPriced: 0,
          competitors: 0,
          photos: 0,
          willRaise: [],
        ),
      ),
    ),
  ];
  return routedApp(
    const AuditShellScreen(outletId: 'o1'),
    overrides: overrides,
    theme: theme,
    locale: locale,
  );
}

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

AgentButton _submit(WidgetTester tester) =>
    tester.widget<AgentButton>(find.byKey(const ValueKey('submit-visit')));

List<String> _sectionKeys(WidgetTester tester) => tester
    .widgetList<InkWell>(find.byType(InkWell))
    .map((w) => w.key)
    .whereType<ValueKey<String>>()
    .map((k) => k.value)
    .where((v) => v.startsWith('section-'))
    .toList();

void main() {
  for (final (name, theme) in [('light', AppTheme.light), ('night', AppTheme.dark)]) {
    group('$name theme', () {
      testWidgets('no template: the hub is exactly the fixed audit', (tester) async {
        _tall(tester);
        await tester.pumpWidget(_hub(_progress(), theme: theme()));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('section-clientQuestions')), findsNothing);
        expect(find.textContaining('Client questions'), findsNothing);
        expect(_sectionKeys(tester), [
          for (final s in AuditSection.values) 'section-${s.name}',
        ]);
        expect(_submit(tester).onPressed, isNotNull);
      });

      testWidgets('a template adds its section before the score, named by the client', (
        tester,
      ) async {
        _tall(tester);
        await tester.pumpWidget(
          _hub(
            _progress(template: TemplateSectionProgress.of(_template(), null)),
            theme: theme(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('section-clientQuestions')), findsOneWidget);
        expect(find.text('Promo Check'), findsOneWidget);
        expect(find.text('Client questions · Not started'), findsOneWidget);
        final keys = _sectionKeys(tester);
        expect(keys.last, 'section-score');
        expect(keys[keys.length - 2], 'section-clientQuestions');
        // The 7 fixed captures + the client's section.
        expect(find.text('/8'), findsOneWidget);
      });

      testWidgets('unanswered required client questions block the submit, by name', (
        tester,
      ) async {
        _tall(tester);
        await tester.pumpWidget(
          _hub(
            _progress(template: TemplateSectionProgress.of(_template(), const {})),
            theme: theme(),
          ),
        );
        await tester.pumpAndSettle();

        expect(_submit(tester).onPressed, isNull);
        expect(find.text('Finish Promo Check to submit'), findsOneWidget);
      });

      testWidgets('answered required questions unblock the submit', (tester) async {
        _tall(tester);
        await tester.pumpWidget(
          _hub(
            _progress(
              template: TemplateSectionProgress.of(_template(), const {'facings': 3}),
            ),
            theme: theme(),
          ),
        );
        await tester.pumpAndSettle();

        expect(_submit(tester).onPressed, isNotNull);
        expect(find.text('Client questions · 1 of 1 answered'), findsOneWidget);
      });

      testWidgets('optional client questions never block', (tester) async {
        _tall(tester);
        await tester.pumpWidget(
          _hub(
            _progress(
              template: TemplateSectionProgress.of(_template(required: false), null),
            ),
            theme: theme(),
          ),
        );
        await tester.pumpAndSettle();

        expect(_submit(tester).onPressed, isNotNull);
        expect(find.text('Client questions · Optional'), findsOneWidget);
      });
    });
  }

  testWidgets('the fixed sections still block with the template answered', (tester) async {
    _tall(tester);
    await tester.pumpWidget(
      _hub(
        _progress(
          states: const {},
          template: TemplateSectionProgress.of(_template(), const {'facings': 3}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_submit(tester).onPressed, isNull);
    expect(find.textContaining('Promo Check to submit'), findsNothing);
  });

  testWidgets('check-in pins the client template to the visit', (tester) async {
    final sections = _Sections();
    await tester.pumpWidget(_hub(_progress(), sections: sections));
    await tester.pumpAndSettle();

    expect(sections.pinned, ['visit-1']);
  });

  testWidgets('tapping the section opens the client’s questions full screen', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(
      _hub(
        _progress(template: TemplateSectionProgress.of(_template(), null)),
        theme: AppTheme.light(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('section-clientQuestions')));
    await tester.pumpAndSettle();

    expect(find.byType(ClientQuestionsScreen), findsOneWidget);
    expect(find.text('Promo facings'), findsOneWidget);
    expect(find.text('Save answers'), findsOneWidget);
  });

  testWidgets('Afrikaans: the section’s own words translate, its name does not', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(
      _hub(
        _progress(template: TemplateSectionProgress.of(_template(), const {})),
        locale: const Locale('af'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Promo Check'), findsOneWidget);
    expect(find.text('Kliëntvrae · 0 van 1 beantwoord'), findsOneWidget);
    expect(find.text('Voltooi Promo Check om in te dien'), findsOneWidget);
  });
}
