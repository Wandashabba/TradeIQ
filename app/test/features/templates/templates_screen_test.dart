import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/templates/data/templates_repository.dart';
import 'package:tradeiq_app/features/templates/presentation/templates_screen.dart';

import '../../core/design/amber_golden.dart';
import '../worklist_harness.dart';
import 'templates_harness.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required FakeTemplatesRepository repo,
    TiqSkin? skin,
    double textScale = 1.0,
  }) => pumpWorklist(
    tester,
    const TemplatesScreen(),
    skin: skin,
    textScale: textScale,
    overrides: <Override>[templatesRepositoryProvider.overrideWithValue(repo)],
  );

  group('the list', () {
    testWidgets('names every template, its version and its state', (
      tester,
    ) async {
      await pump(tester, repo: FakeTemplatesRepository());

      expect(find.text('Grocery Audit'), findsOneWidget);
      expect(find.text('v2 · retail'), findsOneWidget);
      // Paused is a word, never a shade.
      await scrollWorklistTo(tester, find.text('Pharmacy Audit'));
      expect(find.text('Paused'), findsOneWidget);
    });

    testWidgets('an empty list is a stated result', (tester) async {
      await pump(
        tester,
        repo: FakeTemplatesRepository(templates: <AuditTemplate>[]),
      );

      expect(find.text('No templates yet.'), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets('a failure is sanitised and offers one retry', (tester) async {
      await pump(
        tester,
        repo: FakeTemplatesRepository(listFailure: templatesNetworkFailure),
      );

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('templates-retry')),
        findsOneWidget,
      );
    });
  });

  group('which one is in use', () {
    testWidgets('is said once, at the top, in words', (tester) async {
      await pump(tester, repo: FakeTemplatesRepository(selectedId: 'tpl-1'));

      expect(find.text('“Grocery Audit” (v2)'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('templates-in-audits')),
        findsOneWidget,
      );
    });

    testWidgets('none in use says so rather than showing nothing', (
      tester,
    ) async {
      await pump(tester, repo: FakeTemplatesRepository());

      expect(find.text('No template is used in audits.'), findsOneWidget);
      // Nothing to stop using, so nothing is offered.
      expect(
        find.byKey(const ValueKey<String>('templates-stop-using')),
        findsNothing,
      );
    });

    testWidgets('Use in audits selects, and only an active row offers it', (
      tester,
    ) async {
      final repo = FakeTemplatesRepository();
      await pump(tester, repo: repo);

      // Paused: it cannot be put in front of agents.
      expect(
        find.byKey(const ValueKey<String>('template-use-tpl-2')),
        findsNothing,
      );

      final use = find.byKey(const ValueKey<String>('template-use-tpl-1'));
      await scrollWorklistTo(tester, use);
      await tester.tap(use);
      await tester.pumpAndSettle();

      expect(repo.selections, <String?>['tpl-1']);
      await settleToasts(tester);
    });

    testWidgets('Stop using clears it', (tester) async {
      final repo = FakeTemplatesRepository(selectedId: 'tpl-1');
      await pump(tester, repo: repo);

      final stop = find.byKey(const ValueKey<String>('templates-stop-using'));
      await scrollWorklistTo(tester, stop);
      await tester.tap(stop);
      await tester.pumpAndSettle();

      expect(repo.selections, <String?>[null]);
      await settleToasts(tester);
    });

    testWidgets('a refused change says so and nothing silently moves', (
      tester,
    ) async {
      final repo = FakeTemplatesRepository(
        selectFailure: templatesNetworkFailure,
      );
      await pump(tester, repo: repo);

      final use = find.byKey(const ValueKey<String>('template-use-tpl-1'));
      await scrollWorklistTo(tester, use);
      await tester.tap(use);
      await tester.pumpAndSettle();

      expect(find.byType(TorchToast), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      expect(repo.selectedId, isNull);
      await settleToasts(tester);
    });
  });

  testWidgets('a row opens its preview', (tester) async {
    await pump(tester, repo: FakeTemplatesRepository());

    await tester.tap(find.text('Grocery Audit'));
    await tester.pumpAndSettle();

    expect(find.text('stub:/audit-templates/tpl-1/preview'), findsOneWidget);
  });

  group('the amber census', () {
    testWidgets('Night paints exactly one lit object: the nav tab', (
      tester,
    ) async {
      await pump(tester, repo: FakeTemplatesRepository(selectedId: 'tpl-1'));

      final census = await amberCensus(tester);
      expectWithinAmberBudget(
        census,
        TiqSkin.night(),
        route: 'audit-templates',
        phase: 'loaded',
      );
      expect(
        census.objectCount,
        1,
        reason:
            '"Use in audits" is a row verb, not the screen\'s commit action: '
            'a list of templates is not a screen about one of '
            'them.\n${census.describe()}',
      );
    });

    testWidgets('Night, empty, still exactly the nav tab', (tester) async {
      await pump(
        tester,
        repo: FakeTemplatesRepository(templates: <AuditTemplate>[]),
      );
      final census = await amberCensus(tester);
      expect(census.objectCount, 1, reason: census.describe());
    });

    testWidgets('Night, error, still exactly the nav tab', (tester) async {
      await pump(
        tester,
        repo: FakeTemplatesRepository(listFailure: templatesNetworkFailure),
      );
      final census = await amberCensus(tester);
      expect(census.objectCount, 1, reason: census.describe());
    });

    for (final skin in <TiqSkin>[TiqSkin.day(), TiqSkin.veld()]) {
      for (final phase in const <String>['loaded', 'empty', 'error']) {
        testWidgets('${skin.mode.name}, $phase, paints no amber at all', (
          tester,
        ) async {
          await pump(
            tester,
            skin: skin,
            repo: FakeTemplatesRepository(
              templates: phase == 'empty'
                  ? <AuditTemplate>[]
                  : templateFixtures,
              listFailure: phase == 'error' ? templatesNetworkFailure : null,
            ),
          );

          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            skin,
            route: 'audit-templates',
            phase: phase,
          );
          expect(census.objectCount, 0, reason: census.describe());
        });
      }
    }
  });

  testWidgets('2.0x: the rows survive and nothing overflows', (tester) async {
    await pump(tester, repo: FakeTemplatesRepository(), textScale: 2.0);

    await scrollWorklistTo(tester, find.text('Grocery Audit'));
    expect(find.text('Grocery Audit'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
