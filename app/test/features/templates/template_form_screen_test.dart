import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/templates/data/templates_repository.dart';
import 'package:tradeiq_app/features/templates/presentation/template_form_screen.dart';

import '../../core/design/amber_golden.dart';
import '../reports/reports_harness.dart' show PushedHost;
import '../worklist_harness.dart';
import 'templates_harness.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required FakeTemplatesRepository repo,
    TiqSkin? skin,
    double textScale = 1.0,
  }) async {
    await pumpWorklist(
      tester,
      const PushedHost(child: TemplateFormScreen(templateId: 'tpl-1')),
      skin: skin,
      textScale: textScale,
      overrides: <Override>[
        templatesRepositoryProvider.overrideWithValue(repo),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('walks the template one section at a time', (tester) async {
    await pump(tester, repo: FakeTemplatesRepository());

    expect(find.text('Grocery Audit'), findsOneWidget);
    expect(find.text('Section 1 of 2'), findsWidgets);
    expect(find.text('On shelf?'), findsOneWidget);
    expect(find.text('Shelf zone'), findsNothing);

    await tester.tap(find.text('Next section'));
    await tester.pumpAndSettle();

    expect(find.text('Section 2 of 2'), findsWidgets);
    expect(find.text('Shelf zone'), findsOneWidget);
    expect(find.text('On shelf?'), findsNothing);

    await tester.tap(find.text('Back a section'));
    await tester.pumpAndSettle();
    expect(find.text('On shelf?'), findsOneWidget);
  });

  testWidgets('a conditional field appears once its trigger is answered', (
    tester,
  ) async {
    await pump(tester, repo: FakeTemplatesRepository());

    expect(find.text('Facing count'), findsNothing);

    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();

    expect(find.text('Facing count'), findsOneWidget);
  });

  testWidgets('a yes/no question is a choice row, so unanswered and "no" are '
      'different facts', (tester) async {
    await pump(tester, repo: FakeTemplatesRepository());

    // Nothing selected is a state, and it says so.
    expect(find.text('Not answered yet.'), findsWidgets);

    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();

    // Answering "no" does NOT reveal the conditional field, because the answer
    // is no — which a switch rendering off could never have distinguished from
    // nobody having touched it.
    expect(find.text('Facing count'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('field-clear-onShelf')),
      findsOneWidget,
    );
  });

  testWidgets('an answer survives walking back to it', (tester) async {
    await pump(tester, repo: FakeTemplatesRepository());

    await tester.tap(find.text('Next section'));
    await tester.pumpAndSettle();
    await scrollWorklistTo(
      tester,
      find.byKey(const ValueKey<String>('field-note')),
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('field-note')),
      'Back wall empty',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Back a section'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next section'));
    await tester.pumpAndSettle();

    await scrollWorklistTo(tester, find.text('Back wall empty'));
    expect(find.text('Back wall empty'), findsOneWidget);
  });

  testWidgets('a photo question says it cannot be answered, and never blocks',
      (tester) async {
    await pump(tester, repo: FakeTemplatesRepository());

    await tester.tap(find.text('Next section'));
    await tester.pumpAndSettle();

    await scrollWorklistTo(
      tester,
      find.byKey(const ValueKey<String>('field-shelfPhoto')),
    );
    expect(find.text('Cannot be answered yet'), findsOneWidget);
    // The last section's commit is still armed.
    expect(find.text('Finish preview'), findsOneWidget);
  });

  testWidgets('finishing says nothing was saved', (tester) async {
    await pump(tester, repo: FakeTemplatesRepository());

    await tester.tap(find.text('Next section'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish preview'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('template-preview-done')),
      findsOneWidget,
    );
    expect(find.textContaining('Nothing was saved'), findsOneWidget);
  });

  testWidgets('a template with no sections says so', (tester) async {
    await pump(
      tester,
      repo: FakeTemplatesRepository(detailSchema: const <String, dynamic>{}),
    );

    expect(
      find.byKey(const ValueKey<String>('template-no-sections')),
      findsOneWidget,
    );
    expect(find.text('Next section'), findsNothing);
    expect(find.text('Finish preview'), findsNothing);
  });

  testWidgets('a failed load is sanitised and offers one retry', (
    tester,
  ) async {
    await pump(
      tester,
      repo: FakeTemplatesRepository(detailFailure: templatesNetworkFailure),
    );

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('template-retry')),
      findsOneWidget,
    );
  });

  group('the amber census', () {
    testWidgets('Night: exactly the commit, and nothing else', (tester) async {
      await pump(tester, repo: FakeTemplatesRepository());

      final census = await amberCensus(tester);
      expectWithinAmberBudget(
        census,
        TiqSkin.night(),
        route: 'audit-templates/preview',
        phase: 'section-1',
      );
      expect(census.objectCount, 1, reason: census.describe());
    });

    testWidgets('Night, no sections: nothing to commit, nothing lit', (
      tester,
    ) async {
      await pump(
        tester,
        repo: FakeTemplatesRepository(detailSchema: const <String, dynamic>{}),
      );
      final census = await amberCensus(tester);
      expect(census.objectCount, 0, reason: census.describe());
    });

    testWidgets('Night, error: nothing lit', (tester) async {
      await pump(
        tester,
        repo: FakeTemplatesRepository(detailFailure: templatesNetworkFailure),
      );
      final census = await amberCensus(tester);
      expect(census.objectCount, 0, reason: census.describe());
    });

    for (final skin in <TiqSkin>[TiqSkin.day(), TiqSkin.veld()]) {
      testWidgets('${skin.mode.name}: exactly the commit', (tester) async {
        await pump(tester, repo: FakeTemplatesRepository(), skin: skin);

        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          skin,
          route: 'audit-templates/preview',
          phase: 'section-1',
        );
        expect(census.objectCount, 1, reason: census.describe());
      });
    }
  });

  testWidgets('2.0x: the form survives and nothing overflows', (tester) async {
    await pump(tester, repo: FakeTemplatesRepository(), textScale: 2.0);

    expect(find.text('On shelf?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
