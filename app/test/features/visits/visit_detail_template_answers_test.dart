import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/console.dart';
import 'package:tradeiq_app/features/visits/data/visit_detail_repository.dart';
import 'package:tradeiq_app/features/visits/presentation/visit_detail_screen.dart';

// The manager's view of a visit's answers to the client template (#122).
const _schema = {
  'sections': [
    {
      'id': 'promo',
      'title': 'Promo stand',
      'fields': [
        {
          'id': 'standUp',
          'label': 'Is the promo stand up?',
          'type': 'boolean',
          'weight': 5,
          'required': true,
        },
        {
          'id': 'facings',
          'label': 'Promo facings',
          'type': 'number',
          'weight': 5,
          'visibleIf': {'field': 'standUp', 'equals': true},
        },
        {'id': 'comment', 'label': 'Anything else?', 'type': 'text'},
        {
          'id': 'hiddenWhenUp',
          'label': 'Why is it down?',
          'type': 'text',
          'visibleIf': {'field': 'standUp', 'equals': false},
        },
      ],
    },
  ],
};

VisitDetail _visit({List<VisitTemplateAnswers> responses = const []}) =>
    VisitDetail(
      id: 'v1',
      status: 'submitted',
      outlet: const VisitOutletRef(
        id: 'o1',
        name: 'Spar Rosebank',
        code: 'SPR-001',
        channelType: 'supermarket',
      ),
      agent: const VisitAgentRef(id: 'a1', email: 'thandi@acme.test'),
      checkinTs: DateTime.utc(2026, 9, 14, 7),
      submittedAtClient: DateTime.utc(2026, 9, 14, 7, 14),
      geofencePass: true,
      distanceM: 12,
      score: null,
      sections: const [],
      photoTotal: 0,
      photos: const [],
      riskScore: 0,
      signals: const [],
      templateResponses: responses,
    );

const _answers = VisitTemplateAnswers(
  templateId: 'tpl-1',
  templateName: 'Promo Check',
  templateVersion: 2,
  currentVersion: 3,
  schema: _schema,
  answers: {'standUp': true, 'facings': 4, 'retired': 'old answer'},
);

class _Repo implements VisitDetailRepository {
  _Repo(this.detail);
  final VisitDetail detail;

  @override
  Future<VisitDetail> fetch(String visitId) async => detail;
}

Widget _app(VisitDetail detail, ThemeData theme) => ProviderScope(
  overrides: [visitDetailRepositoryProvider.overrideWithValue(_Repo(detail))],
  child: MaterialApp.router(
    theme: theme,
    routerConfig: GoRouter(
      initialLocation: '/visits/v1',
      routes: [
        GoRoute(
          path: '/visits/:id',
          builder: (context, state) =>
              VisitDetailScreen(visitId: state.pathParameters['id']!),
        ),
      ],
    ),
  ),
);

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder _ci(String text) =>
    find.textContaining(RegExp(RegExp.escape(text), caseSensitive: false));

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('night', AppTheme.dark),
  ]) {
    group('$name theme', () {
      testWidgets('shows each answer under the question the template asked', (
        tester,
      ) async {
        _tall(tester);
        await tester.pumpWidget(_app(_visit(responses: [_answers]), theme()));
        await tester.pumpAndSettle();

        final panel = find.byKey(const ValueKey('visit-template-tpl-1'));
        expect(panel, findsOneWidget);
        expect(tester.widget(panel), isA<PanelCard>());
        expect(_ci('Client questions · Promo Check'), findsOneWidget);

        // Labels resolved from the schema, answers in words.
        expect(find.text('Is the promo stand up? (required)'), findsOneWidget);
        expect(find.text('Yes'), findsOneWidget);
        expect(find.text('Promo facings'), findsOneWidget);
        expect(find.text('4'), findsOneWidget);
        expect(find.text('Anything else?'), findsOneWidget);
        expect(find.text('Not answered'), findsOneWidget);
        // A question the agent was never shown is not listed as unanswered.
        expect(find.text('Why is it down?'), findsNothing);
        // An answer to a question the template no longer has is still shown.
        expect(
          find.text('retired (no longer in the template)'),
          findsOneWidget,
        );
        expect(find.text('old answer'), findsOneWidget);

        // Which version the answers belong to, when the template moved on.
        expect(find.textContaining('Answered against v2'), findsOneWidget);
        expect(find.textContaining('template now v3'), findsOneWidget);
      });

      testWidgets(
        'the template’s own score is shown here, apart from the perfect store score',
        (tester) async {
          _tall(tester);
          await tester.pumpWidget(_app(_visit(responses: [_answers]), theme()));
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey('visit-template-score')),
            findsOneWidget,
          );
          expect(_ci('Template score 10 / 10'), findsOneWidget);
          expect(
            find.textContaining('not part of the perfect store score'),
            findsOneWidget,
          );
        },
      );

      testWidgets('no template answers: no panel', (tester) async {
        _tall(tester);
        await tester.pumpWidget(_app(_visit(), theme()));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('visit-template-tpl-1')),
          findsNothing,
        );
        expect(_ci('Client questions'), findsNothing);
      });
    });
  }

  test('parses templateResponses from GET /visits/:id', () {
    final detail = VisitDetail.fromJson({
      'id': 'v1',
      'status': 'submitted',
      'outlet': {
        'id': 'o1',
        'name': 'Spar',
        'code': 'S1',
        'channelType': 'supermarket',
      },
      'agent': {'id': 'a1', 'email': 'a@b.test'},
      'checkinTs': '2026-09-14T07:00:00.000Z',
      'submittedAtClient': null,
      'geofence': {'pass': true, 'distanceM': 3},
      'score': null,
      'sections': <Object>[],
      'photos': {'total': 0, 'items': <Object>[]},
      'fraud': {'riskScore': 0, 'signals': <Object>[]},
      'templateResponses': [
        {
          'templateId': 'tpl-1',
          'templateName': 'Promo Check',
          'templateVersion': 1,
          'currentVersion': 2,
          'schema': _schema,
          'answers': {'standUp': false},
          'recordedAt': '2026-09-14T07:10:00.000Z',
        },
      ],
    });

    final r = detail.templateResponses.single;
    expect(r.templateName, 'Promo Check');
    expect(r.templateVersion, 1);
    expect(r.answeredOlderVersion, isTrue);
    expect(r.answers, {'standUp': false});
    expect(r.recordedAt, DateTime.utc(2026, 9, 14, 7, 10));
  });

  test('a payload without templateResponses parses to none', () {
    final detail = VisitDetail.fromJson({
      'id': 'v1',
      'status': 'in_progress',
      'outlet': {'id': 'o1', 'name': 'Spar', 'code': 'S1'},
      'agent': {'id': 'a1', 'email': 'a@b.test'},
      'checkinTs': '2026-09-14T07:00:00.000Z',
    });
    expect(detail.templateResponses, isEmpty);
  });
}
