import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/features/audit/data/template_section_repository.dart';
import 'package:tradeiq_app/features/audit/data/visit_progress.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/client_questions_screen.dart';

import '../agent_harness.dart';
import 'visit_harness.dart';

// The client-questions section on the visit hub (#122): shown only for a
// client with an audit template, gated exactly like a fixed section, and —
// new here — rendered as **can't confirm** rather than vanishing when its
// template could not be pinned (#389).

ClientTemplate _template({bool required = true}) => ClientTemplate(
  templateId: 'tpl-1',
  name: 'Promo Check',
  version: 3,
  schemaJson: <String, Object?>{
    'sections': <Object?>[
      <String, Object?>{
        'id': 'promo',
        'title': 'Promo stand',
        'fields': <Object?>[
          <String, Object?>{
            'id': 'facings',
            'label': 'Promo facings',
            'type': 'number',
            'required': required,
          },
        ],
      },
    ],
  },
);

const _fixedDone = <AuditSection, CaptureState>{
  AuditSection.stock: CaptureState.done,
  AuditSection.visibility: CaptureState.done,
  AuditSection.pricing: CaptureState.done,
  AuditSection.capability: CaptureState.done,
};

VisitProgress _progress({
  TemplateSectionProgress? template,
  Map<AuditSection, CaptureState> states = _fixedDone,
}) => VisitProgress(
  states: states,
  details: const <AuditSection, String>{},
  template: template,
);

TorchPrimaryButton _submit(WidgetTester tester) => tester
    .widget<TorchPrimaryButton>(
      find.byKey(const ValueKey<String>('submit-visit')),
    );

/// Every section row on the hub, in order. `SoftRow` takes **no `Material`
/// ancestor** — no ripple, no elevation, no `InkWell` — so the rows are found
/// by their own type rather than by the ink the old hub was built from.
List<String> _sectionKeys(WidgetTester tester) => tester
    .widgetList<SoftRow>(find.byType(SoftRow))
    .map((w) => w.key)
    .whereType<ValueKey<String>>()
    .map((k) => k.value)
    .where((v) => v.startsWith('section-'))
    .toList();

void main() {
  for (final skin in <SkinMode>[SkinMode.night, SkinMode.day, SkinMode.veld]) {
    group('${skin.name}', () {
      testWidgets('no template: the hub is exactly the fixed audit', (
        tester,
      ) async {
        await pumpVisit(
          tester,
          visits: ScriptedVisits.succeeds(),
          progress: _progress(),
          skin: skin,
        );
        await scrollAgentTo(
          tester,
          find.byKey(const ValueKey<String>('section-score')),
        );

        expect(
          find.byKey(const ValueKey<String>('section-clientQuestions')),
          findsNothing,
        );
        expect(
          _sectionKeys(tester),
          <String>[for (final s in AuditSection.values) 'section-${s.name}'],
        );
        expect(_submit(tester).onPressed, isNotNull);
      });

      testWidgets('a template adds its section before the score', (
        tester,
      ) async {
        await pumpVisit(
          tester,
          visits: ScriptedVisits.succeeds(),
          progress: _progress(
            template: TemplateSectionProgress.of(_template(), null),
          ),
          skin: skin,
        );
        final row = find.byKey(
          const ValueKey<String>('section-clientQuestions'),
        );
        await scrollAgentTo(tester, row);

        expect(row, findsOneWidget);
        // Named by the CLIENT, not by us.
        expect(find.text('Promo Check'), findsOneWidget);
        // Last is always the score: it is the result of the others.
        expect(_sectionKeys(tester).last, 'section-score');
        expect(
          _sectionKeys(tester)[_sectionKeys(tester).length - 2],
          'section-clientQuestions',
        );
      });
    });
  }

  testWidgets('unanswered required client questions block the submit, by name', (
    tester,
  ) async {
    await pumpVisit(
      tester,
      visits: ScriptedVisits.succeeds(),
      progress: _progress(
        template: TemplateSectionProgress.of(_template(), null),
      ),
    );
    final button = _submit(tester);
    expect(button.onPressed, isNull);
    // By the client's own name for it — "the section" would be useless in a
    // shop with the manager waiting.
    expect(button.blockedReason!.contains('Promo Check'), isTrue);
  });

  testWidgets('answered required questions unblock the submit', (tester) async {
    await pumpVisit(
      tester,
      visits: ScriptedVisits.succeeds(),
      progress: _progress(
        template: TemplateSectionProgress.of(_template(), <String, Object?>{
          'facings': 4,
        }),
      ),
    );
    expect(_submit(tester).onPressed, isNotNull);
  });

  testWidgets('optional client questions never block', (tester) async {
    await pumpVisit(
      tester,
      visits: ScriptedVisits.succeeds(),
      progress: _progress(
        template: TemplateSectionProgress.of(_template(required: false), null),
      ),
    );
    expect(_submit(tester).onPressed, isNotNull);
  });

  testWidgets('the fixed sections still block with the template answered', (
    tester,
  ) async {
    await pumpVisit(
      tester,
      visits: ScriptedVisits.succeeds(),
      progress: _progress(
        states: const <AuditSection, CaptureState>{
          AuditSection.stock: CaptureState.done,
        },
        template: TemplateSectionProgress.of(_template(), <String, Object?>{
          'facings': 4,
        }),
      ),
    );
    final button = _submit(tester);
    expect(button.onPressed, isNull);
    expect(button.blockedReason!.contains('Visibility & display'), isTrue);
  });

  testWidgets('check-in pins the client template to the visit', (tester) async {
    final sections = NoTemplate();
    await pumpVisit(
      tester,
      visits: ScriptedVisits.succeeds(),
      progress: _progress(),
      templates: sections,
    );
    expect(sections.pinned, <String>['visit-1']);
  });

  testWidgets('tapping the section opens the client’s questions full screen', (
    tester,
  ) async {
    await pumpVisit(
      tester,
      visits: ScriptedVisits.succeeds(),
      progress: _progress(
        template: TemplateSectionProgress.of(_template(), null),
      ),
    );
    final row = find.byKey(const ValueKey<String>('section-clientQuestions'));
    await scrollAgentTo(tester, row);
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(find.byType(ClientQuestionsScreen), findsOneWidget);
  });

  testWidgets('Afrikaans: the section’s own words translate, its name does not', (
    tester,
  ) async {
    await pumpVisit(
      tester,
      visits: ScriptedVisits.succeeds(),
      progress: _progress(
        template: TemplateSectionProgress.of(_template(), null),
      ),
      locale: const Locale('af'),
    );
    await scrollAgentTo(
      tester,
      find.byKey(const ValueKey<String>('section-clientQuestions')),
    );
    // The client named their own template; we do not translate it.
    expect(find.text('Promo Check'), findsOneWidget);
    // Our own words around it are Afrikaans.
    expect(find.textContaining('Enige volgorde'), findsOneWidget);
  });
}
