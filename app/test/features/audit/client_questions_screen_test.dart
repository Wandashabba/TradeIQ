import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/features/audit/data/template_section_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/client_questions_screen.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

// The client-questions section body (#122).
final template = ClientTemplate(
  templateId: 'tpl-1',
  name: 'Promo Check',
  version: 3,
  schemaJson: const {
    'sections': [
      {
        'id': 'promo',
        'title': 'Promo stand',
        'fields': [
          {'id': 'standUp', 'label': 'Is the promo stand up?', 'type': 'boolean'},
          {'id': 'facings', 'label': 'Promo facings', 'type': 'number', 'required': true},
          {'id': 'comment', 'label': 'Anything else?', 'type': 'text'},
        ],
      },
    ],
  },
);

class FakeTemplateSectionRepository implements TemplateSectionRepository {
  FakeTemplateSectionRepository({Map<String, Object?> saved = const {}})
    : saved = Map.of(saved);

  Map<String, Object?> saved;
  final saves = <Map<String, Object?>>[];
  final pinned = <String>[];

  @override
  Future<void> pinForVisit(String visitDraftId) async => pinned.add(visitDraftId);

  @override
  Future<Map<String, Object?>> savedAnswers({
    required String visitDraftId,
    required String templateId,
  }) async => saved;

  @override
  Future<void> saveAnswers({
    required String visitDraftId,
    required ClientTemplate template,
    required Map<String, Object?> answers,
  }) async {
    saves.add(Map.of(answers));
    saved = Map.of(answers);
  }
}

Widget clientQuestionsApp(
  FakeTemplateSectionRepository repo, {
  ThemeData? theme,
  Locale? locale,
}) => ProviderScope(
  overrides: [templateSectionRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(
    theme: theme,
    locale: locale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    localeListResolutionCallback: resolveAppLocale,
    home: Scaffold(
      body: SingleChildScrollView(
        child: ClientQuestionsScreen(visitDraftId: 'v1', template: template),
      ),
    ),
  ),
);

Finder _textCI(String text) =>
    find.textContaining(RegExp('^${RegExp.escape(text)}\$', caseSensitive: false));

void main() {
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('renders the client’s questions under the section label', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(clientQuestionsApp(FakeTemplateSectionRepository()));
    await tester.pumpAndSettle();

    expect(find.text('CLIENT QUESTIONS'), findsOneWidget);
    expect(find.textContaining('Asked on every visit'), findsOneWidget);
    expect(find.text('Is the promo stand up?'), findsOneWidget);
    expect(find.text('Promo facings'), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
    expect(_textCI('1 required question left'), findsOneWidget);
    expect(find.text('Save answers'), findsOneWidget);
  });

  testWidgets('answering and saving hands the answers to the repository', (
    tester,
  ) async {
    tall(tester);
    final repo = FakeTemplateSectionRepository();
    await tester.pumpWidget(clientQuestionsApp(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('field-facings')), '4');
    await tester.pump();
    expect(_textCI('All required questions answered'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('client-questions-save')));
    await tester.pumpAndSettle();

    expect(repo.saves, [
      {'facings': 4},
    ]);
    expect(find.text('Answers saved — queued for sync'), findsOneWidget);
  });

  testWidgets('saving with a required answer missing saves, and marks the gap', (
    tester,
  ) async {
    tall(tester);
    final repo = FakeTemplateSectionRepository();
    await tester.pumpWidget(clientQuestionsApp(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('field-comment')), 'Busy aisle');
    await tester.tap(find.byKey(const ValueKey('client-questions-save')));
    await tester.pumpAndSettle();

    // A partial save is kept — the hub then shows the section partial and the
    // submit stays blocked until the required question is answered.
    expect(repo.saves.single, {'comment': 'Busy aisle'});
    expect(find.text('Answer this before you submit'), findsOneWidget);
  });

  testWidgets('reopening starts from what was saved', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      clientQuestionsApp(
        FakeTemplateSectionRepository(saved: const {'facings': 7, 'standUp': true}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('7'), findsOneWidget);
    final toggle = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('field-standUp')),
    );
    expect(toggle.value, isTrue);
  });

  for (final (name, theme) in [('light', AppTheme.light), ('night', AppTheme.dark)]) {
    testWidgets('$name: questions sit on glass tiles like the other sections', (
      tester,
    ) async {
      tall(tester);
      await tester.pumpWidget(
        clientQuestionsApp(FakeTemplateSectionRepository(), theme: theme()),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT QUESTIONS'), findsOneWidget);
      final tile = tester.widget<GlassPane>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('field-facings')),
              matching: find.byType(GlassPane),
            )
            .first,
      );
      expect(tile.kind, GlassKind.tile);
      expect(tile.blur, isFalse);
      expect(find.text('Save answers'), findsOneWidget);
    });
  }
}
