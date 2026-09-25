import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';

import 'visit_harness.dart';

/// THE MANAGER'S VIEW OF A VISIT'S ANSWERS to the client's audit template
/// (#122): each answer under the question the template asked, the version the
/// answers belong to, and the template's own score kept apart from the
/// perfect-store one.

const Map<String, dynamic> _schema = <String, dynamic>{
  'sections': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'promo',
      'title': 'Promo stand',
      'fields': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'standUp',
          'label': 'Is the promo stand up?',
          'type': 'boolean',
          'weight': 5,
          'required': true,
        },
        <String, dynamic>{
          'id': 'facings',
          'label': 'Promo facings',
          'type': 'number',
          'weight': 5,
          'visibleIf': <String, dynamic>{'field': 'standUp', 'equals': true},
        },
        <String, dynamic>{
          'id': 'comment',
          'label': 'Anything else?',
          'type': 'text',
        },
        <String, dynamic>{
          'id': 'hiddenWhenUp',
          'label': 'Why is it down?',
          'type': 'text',
          'visibleIf': <String, dynamic>{'field': 'standUp', 'equals': false},
        },
      ],
    },
  ],
};

const VisitTemplateAnswers _answers = VisitTemplateAnswers(
  templateId: 'tpl-1',
  templateName: 'Promo Check',
  templateVersion: 2,
  currentVersion: 3,
  schema: _schema,
  answers: <String, dynamic>{
    'standUp': true,
    'facings': 4,
    'retired': 'old answer',
  },
);

Finder _rowFor(String field) =>
    find.byKey(ValueKey<String>('visit-template-answer-$field'));

void main() {
  for (final skin in <TiqSkin>[TiqSkin.night(), TiqSkin.day()]) {
    group(skin.mode.name, () {
      testWidgets('each answer sits under the question the template asked', (
        tester,
      ) async {
        await pumpVisit(
          tester,
          skin: skin,
          detail: submittedVisit(
            templateResponses: const <VisitTemplateAnswers>[_answers],
          ),
        );

        expect(
          find.byKey(const ValueKey<String>('visit-template-tpl-1')),
          findsOneWidget,
        );
        expect(find.text('Client questions · Promo Check'), findsOneWidget);

        // Labels resolved from the schema, answers in words.
        final standUp = tester.widget<SoftRow>(_rowFor('standUp'));
        expect(standUp.title, 'Is the promo stand up? (required)');
        expect(standUp.semanticsLabel, contains('Yes'));

        final facings = tester.widget<SoftRow>(_rowFor('facings'));
        expect(facings.title, 'Promo facings');
        expect(facings.semanticsLabel, contains('4'));

        final comment = tester.widget<SoftRow>(_rowFor('comment'));
        expect(comment.semanticsLabel, contains('Not answered'));

        // A question the agent was never shown is not listed as unanswered.
        expect(_rowFor('hiddenWhenUp'), findsNothing);

        // An answer to a question the template no longer has is still shown:
        // it is still something the agent recorded.
        final orphan = tester.widget<SoftRow>(_rowFor('retired'));
        expect(orphan.title, 'retired (no longer in the template)');
        expect(orphan.semanticsLabel, contains('old answer'));
      });

      testWidgets('says which version the answers belong to', (tester) async {
        await pumpVisit(
          tester,
          skin: skin,
          detail: submittedVisit(
            templateResponses: const <VisitTemplateAnswers>[_answers],
          ),
        );

        expect(find.textContaining('Answered against v2'), findsOneWidget);
        expect(find.textContaining('the template is now v3'), findsOneWidget);
      });

      testWidgets(
        "the template's own score is shown here, apart from the perfect store "
        'score',
        (tester) async {
          await pumpVisit(
            tester,
            skin: skin,
            detail: submittedVisit(
              templateResponses: const <VisitTemplateAnswers>[_answers],
            ),
          );

          expect(
            find.byKey(const ValueKey<String>('visit-template-score')),
            findsOneWidget,
          );
          expect(find.text('Template score 10 of 10'), findsOneWidget);
          expect(
            find.textContaining('not part of the perfect store score'),
            findsOneWidget,
          );
        },
      );

      testWidgets('no template answers: no section at all', (tester) async {
        await pumpVisit(tester, skin: skin, detail: submittedVisit());

        expect(
          find.byKey(const ValueKey<String>('visit-template-tpl-1')),
          findsNothing,
        );
        expect(find.textContaining('Client questions'), findsNothing);
      });

      testWidgets('a template with nothing filled in says so', (tester) async {
        await pumpVisit(
          tester,
          skin: skin,
          detail: submittedVisit(
            templateResponses: const <VisitTemplateAnswers>[
              VisitTemplateAnswers(
                templateId: 'tpl-1',
                templateName: 'Promo Check',
                templateVersion: 1,
                currentVersion: 1,
                schema: <String, dynamic>{'sections': <Object>[]},
                answers: <String, dynamic>{},
              ),
            ],
          ),
        );

        expect(find.text('No answers were recorded'), findsOneWidget);
      });
    });
  }

  testWidgets('the answers read in Afrikaans', (tester) async {
    await pumpVisit(
      tester,
      locale: const Locale('af'),
      detail: submittedVisit(
        templateResponses: const <VisitTemplateAnswers>[_answers],
      ),
    );

    expect(find.text('Kliëntvrae · Promo Check'), findsOneWidget);
    expect(find.textContaining('Beantwoord teen v2'), findsOneWidget);
    final standUp = tester.widget<SoftRow>(_rowFor('standUp'));
    expect(standUp.title, contains('(verpligtend)'));
    expect(standUp.semanticsLabel, contains('Ja'));
    expect(find.text('Client questions · Promo Check'), findsNothing);
  });

  test('parses templateResponses from GET /visits/:id', () {
    final detail = VisitDetail.fromJson(<String, dynamic>{
      'id': 'v1',
      'status': 'submitted',
      'outlet': <String, dynamic>{
        'id': 'o1',
        'name': 'Spar',
        'code': 'S1',
        'channelType': 'supermarket',
      },
      'agent': <String, dynamic>{'id': 'a1', 'email': 'a@b.test'},
      'checkinTs': '2026-09-14T07:00:00.000Z',
      'submittedAtClient': null,
      'geofence': <String, dynamic>{'pass': true, 'distanceM': 3},
      'score': null,
      'sections': <Object>[],
      'photos': <String, dynamic>{'total': 0, 'items': <Object>[]},
      'fraud': <String, dynamic>{'riskScore': 0, 'signals': <Object>[]},
      'templateResponses': <Map<String, dynamic>>[
        <String, dynamic>{
          'templateId': 'tpl-1',
          'templateName': 'Promo Check',
          'templateVersion': 1,
          'currentVersion': 2,
          'schema': _schema,
          'answers': <String, dynamic>{'standUp': false},
          'recordedAt': '2026-09-14T07:10:00.000Z',
        },
      ],
    });

    final r = detail.templateResponses.single;
    expect(r.templateName, 'Promo Check');
    expect(r.templateVersion, 1);
    expect(r.answeredOlderVersion, isTrue);
    expect(r.answers, <String, dynamic>{'standUp': false});
    expect(r.recordedAt, DateTime.utc(2026, 9, 14, 7, 10));
  });

  test('a payload without templateResponses parses to none', () {
    final detail = VisitDetail.fromJson(<String, dynamic>{
      'id': 'v1',
      'status': 'in_progress',
      'outlet': <String, dynamic>{'id': 'o1', 'name': 'Spar', 'code': 'S1'},
      'agent': <String, dynamic>{'id': 'a1', 'email': 'a@b.test'},
      'checkinTs': '2026-09-14T07:00:00.000Z',
    });
    expect(detail.templateResponses, isEmpty);
  });
}
