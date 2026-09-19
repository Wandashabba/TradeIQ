import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/audit/data/template_section_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/client_questions_screen.dart';

import '../features/agent_harness.dart';
import '../features/audit/section_harness.dart';

// The client-questions section (#122) in Afrikaans. The section's own words
// are translated; the client-authored questions are shown as written.
final _template = ClientTemplate(
  templateId: 'tpl-1',
  name: 'Promo Check',
  version: 1,
  schemaJson: const {
    'sections': [
      {
        'id': 'promo',
        'title': 'Promo stand',
        'fields': [
          {
            'id': 'facings',
            'label': 'Promo facings',
            'type': 'number',
            'required': true,
          },
          {'id': 'photo', 'label': 'Stand photo', 'type': 'photo'},
        ],
      },
    ],
  },
);

class _Repo implements TemplateSectionRepository {
  @override
  Future<void> pinForVisit(String visitDraftId) async {}

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

void main() {
  Future<void> pump(WidgetTester tester, Locale locale) => pumpSection(
    tester,
    ClientQuestionsScreen(visitDraftId: 'v1', template: _template),
    overrides: <Override>[
      templateSectionRepositoryProvider.overrideWithValue(_Repo()),
    ],
    locale: locale,
    size: const Size(360, 1400),
  );

  testWidgets('the client-questions section renders in Afrikaans', (
    tester,
  ) async {
    await pump(tester, const Locale('af'));

    // The template's name is the client's and is not translated; the section's
    // own words are.
    expect(find.text('Promo Check'), findsOneWidget);
    expect(find.text('Stoor soos jy gaan'), findsOneWidget);
    expect(
      find.text(
        'Word by elke besoek gevra. '
        'Beantwoord die verpligte vrae om in te dien.',
      ),
      findsOneWidget,
    );
    expect(find.text('Verpligtend'), findsOneWidget);
    expect(find.text('Nog 1 verpligte vraag'), findsOneWidget);
    expect(find.text('Stoor'), findsOneWidget);
    expect(
      find.text('Fotovrae kan nog nie in die app beantwoord word nie'),
      findsOneWidget,
    );
    // Client-authored content is not translated.
    expect(find.text('Promo facings'), findsOneWidget);
    expect(find.text('Save'), findsNothing);

    await saveSection(tester);
    expect(
      find.textContaining('Antwoorde gestoor — wag om gestuur te word'),
      findsOneWidget,
    );
    expect(find.text('Beantwoord dit voor jy indien'), findsOneWidget);
    await disposeAgentScreen(tester);
  });

  testWidgets('an unsupported locale falls back to English', (tester) async {
    await pump(tester, const Locale('zu'));
    expect(find.text('Saves as you go'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('1 required question left'), findsOneWidget);
    await disposeAgentScreen(tester);
  });
}
