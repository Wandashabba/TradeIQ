import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/audit/data/template_section_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/client_questions_screen.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

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
          {'id': 'facings', 'label': 'Promo facings', 'type': 'number', 'required': true},
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

Widget _app(Locale locale) => ProviderScope(
  overrides: [templateSectionRepositoryProvider.overrideWithValue(_Repo())],
  child: MaterialApp(
    locale: locale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    localeListResolutionCallback: resolveAppLocale,
    home: Scaffold(
      body: SingleChildScrollView(
        child: ClientQuestionsScreen(visitDraftId: 'v1', template: _template),
      ),
    ),
  ),
);

void main() {
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('the client-questions section renders in Afrikaans', (tester) async {
    tall(tester);
    await tester.pumpWidget(_app(const Locale('af')));
    await tester.pumpAndSettle();

    expect(find.text('KLIËNTVRAE'), findsOneWidget);
    expect(
      find.text(
        'Word by elke besoek gevra. '
        'Beantwoord die verpligte vrae om in te dien.',
      ),
      findsOneWidget,
    );
    expect(find.text('Verpligtend'), findsOneWidget);
    expect(find.text('NOG 1 VERPLIGTE VRAAG'), findsOneWidget);
    expect(find.text('Stoor antwoorde'), findsOneWidget);
    expect(
      find.text('Fotovrae kan nog nie in die app beantwoord word nie'),
      findsOneWidget,
    );
    // Client-authored content is not translated.
    expect(find.text('Promo facings'), findsOneWidget);
    expect(find.text('Save answers'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('client-questions-save')));
    await tester.pumpAndSettle();
    expect(find.text('Antwoorde gestoor — wag om gestuur te word'), findsOneWidget);
    expect(find.text('Beantwoord dit voor jy indien'), findsOneWidget);
  });

  testWidgets('an unsupported locale falls back to English', (tester) async {
    tall(tester);
    await tester.pumpWidget(_app(const Locale('zu')));
    await tester.pumpAndSettle();

    expect(find.text('CLIENT QUESTIONS'), findsOneWidget);
    expect(find.text('Save answers'), findsOneWidget);
    expect(find.text('1 REQUIRED QUESTION LEFT'), findsOneWidget);
  });
}
