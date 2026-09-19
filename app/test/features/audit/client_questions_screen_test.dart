import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/features/audit/data/template_section_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/client_questions_screen.dart';

import '../agent_harness.dart';
import 'section_harness.dart';

// The client-questions section (#122).
final template = ClientTemplate(
  templateId: 'tpl-1',
  name: 'Promo Check',
  version: 3,
  schemaJson: const <String, Object?>{
    'sections': <Object?>[
      <String, Object?>{
        'id': 'promo',
        'title': 'Promo stand',
        'fields': <Object?>[
          <String, Object?>{
            'id': 'standUp',
            'label': 'Is the promo stand up?',
            'type': 'boolean',
          },
          <String, Object?>{
            'id': 'facings',
            'label': 'Promo facings',
            'type': 'number',
            'required': true,
          },
          <String, Object?>{
            'id': 'comment',
            'label': 'Anything else?',
            'type': 'text',
          },
        ],
      },
    ],
  },
);

class FakeTemplateSectionRepository implements TemplateSectionRepository {
  FakeTemplateSectionRepository({
    Map<String, Object?> saved = const <String, Object?>{},
  }) : saved = Map<String, Object?>.of(saved);

  Map<String, Object?> saved;
  final saves = <Map<String, Object?>>[];
  final pinned = <String>[];

  @override
  Future<void> pinForVisit(String visitDraftId) async =>
      pinned.add(visitDraftId);

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
    saves.add(Map<String, Object?>.of(answers));
    saved = Map<String, Object?>.of(answers);
  }
}

List<Override> _overrides(TemplateSectionRepository repo) => <Override>[
  templateSectionRepositoryProvider.overrideWithValue(repo),
];

final _screen = ClientQuestionsScreen(visitDraftId: 'v1', template: template);

Finder _key(String k) => find.byKey(ValueKey<String>(k));

void main() {
  testWidgets('the client’s questions, under the template’s name and its own '
      'section rule', (tester) async {
    await pumpSection(
      tester,
      _screen,
      overrides: _overrides(FakeTemplateSectionRepository()),
    );
    expect(find.text('Promo Check'), findsOneWidget);
    expect(find.textContaining('Asked on every visit'), findsOneWidget);
    expect(find.text('Promo stand'), findsOneWidget);
    expect(find.text('Is the promo stand up?'), findsOneWidget);
    expect(find.text('Promo facings'), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
    await scrollAgentTo(tester, _key('client-questions-required'));
    expect(find.text('1 required question left'), findsOneWidget);
    await disposeAgentScreen(tester);
  });

  testWidgets('answering and saving hands the answers to the repository', (
    tester,
  ) async {
    final repo = FakeTemplateSectionRepository();
    await pumpSection(tester, _screen, overrides: _overrides(repo));

    await typeInSection(tester, _key('field-facings'), '4');
    await scrollAgentTo(tester, _key('client-questions-required'));
    expect(find.text('All required questions answered'), findsOneWidget);

    await saveSection(tester);
    expect(repo.saves, <Map<String, Object?>>[
      <String, Object?>{'facings': 4},
    ]);
    expect(
      find.textContaining('Answers saved — queued for sync'),
      findsOneWidget,
    );
    await disposeAgentScreen(tester);
  });

  testWidgets(
    'saving with a required answer missing saves, and marks the gap',
    (tester) async {
      final repo = FakeTemplateSectionRepository();
      await pumpSection(tester, _screen, overrides: _overrides(repo));

      await typeInSection(tester, _key('field-comment'), 'Busy aisle');
      await saveSection(tester);

      // A partial save is kept — the hub then shows the section partial and the
      // submit stays blocked until the required question is answered.
      expect(repo.saves.single, <String, Object?>{'comment': 'Busy aisle'});
      await scrollAgentTo(tester, _key('field-facings'));
      expect(find.text('Answer this before you submit'), findsOneWidget);
      await disposeAgentScreen(tester);
    },
  );

  testWidgets('reopening starts from what was saved', (tester) async {
    await pumpSection(
      tester,
      _screen,
      overrides: _overrides(
        FakeTemplateSectionRepository(
          saved: const <String, Object?>{'facings': 7, 'standUp': true},
        ),
      ),
    );
    expect(
      find.descendant(of: _key('field-facings'), matching: find.text('7')),
      findsOneWidget,
    );
    final toggle = tester.widget<TorchToggle>(
      find.descendant(
        of: _key('field-standUp'),
        matching: find.byType(TorchToggle),
      ),
    );
    expect(toggle.value, isTrue);
    await disposeAgentScreen(tester);
  });

  group('the amber census', () {
    for (final skin in agentSkinModes) {
      testWidgets('untouched is zero, armed is one — ${skin.name}', (
        tester,
      ) async {
        await pumpSection(
          tester,
          _screen,
          overrides: _overrides(FakeTemplateSectionRepository()),
          skin: skin,
        );
        await expectAmber(
          tester,
          skin: skin,
          route: 'client questions',
          phase: 'untouched',
          expected: 0,
        );
        await typeInSection(tester, _key('field-facings'), '2');
        await scrollAgentTo(tester, sectionSave);
        await expectAmber(
          tester,
          skin: skin,
          route: 'client questions',
          phase: 'dirty',
          expected: 1,
        );
        await disposeAgentScreen(tester);
      });
    }
  });
}
