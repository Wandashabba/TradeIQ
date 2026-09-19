import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/section_rule.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/alerts/presentation/alert_rules_screen.dart';

import '../../core/design/amber_golden.dart';
import '../worklist_harness.dart';

AlertRule _rule({
  String id = 'r1',
  String name = 'Out of stock alert',
  String metric = 'out_of_stock',
  String severity = 'critical',
  bool active = true,
  double? threshold,
}) => AlertRule(
  id: id,
  name: name,
  metric: metric,
  severity: severity,
  active: active,
  threshold: threshold,
);

Future<FakeAlertRulesRepository> _pump(
  WidgetTester tester, {
  List<AlertRule> rules = const <AlertRule>[],
  Object? failure,
  TiqSkin? skin,
  double textScale = 1.0,
}) async {
  final repository = FakeAlertRulesRepository(rules: rules, failure: failure);
  await pumpWorklist(
    tester,
    const AlertRulesScreen(),
    skin: skin,
    textScale: textScale,
    overrides: <Override>[
      alertRulesRepositoryProvider.overrideWithValue(repository),
    ],
  );
  return repository;
}

void main() {
  group('the list', () {
    testWidgets('active and off are two sections, and both always render', (
      tester,
    ) async {
      await _pump(
        tester,
        rules: <AlertRule>[
          _rule(),
          _rule(id: 'r2', name: 'Price drift', metric: 'price_deviation',
              active: false),
        ],
      );

      await scrollWorklistTo(tester, find.byType(SectionRule).first);
      final rules = tester
          .widgetList<SectionRule>(find.byType(SectionRule))
          .toList();
      expect(rules.map((r) => r.name).toList(), <String>['Active', 'Off']);
      expect(rules.first.count, 1);
      expect(rules.last.count, 1);
    });

    testWidgets('a section with nothing in it still says so', (tester) async {
      await _pump(tester, rules: <AlertRule>[_rule()]);

      await scrollWorklistTo(tester, find.text('Nothing is switched off.'));
      expect(find.text('Nothing is switched off.'), findsOneWidget);
    });

    testWidgets('the condition is a sentence and the metric wears mono', (
      tester,
    ) async {
      await _pump(tester, rules: <AlertRule>[_rule(threshold: 50)]);

      await scrollWorklistTo(tester, find.text('out_of_stock'));
      final skin = TiqSkin.night();
      final metric = tester.widget<Text>(find.text('out_of_stock'));
      expect(metric.style!.fontFamily, skin.text.monoIdent.family);
      expect(
        find.text('Fires when a product is found out of stock on a visit.'),
        findsOneWidget,
      );
    });

    testWidgets('severity is a mark and a word, never the row colour', (
      tester,
    ) async {
      await _pump(tester, rules: <AlertRule>[_rule(severity: 'warning')]);

      await scrollWorklistTo(tester, find.text('Watch'));
      expect(find.text('Watch'), findsOneWidget);
      final row = tester.widget<SoftRow>(find.byType(SoftRow).first);
      // The row itself carries no severity bar: a configured severity is a
      // fact about future alerts, not a verdict about this row.
      expect(row.severity, SoftRowSeverity.none);
    });

    testWidgets('no threshold says whose default it is, never a null', (
      tester,
    ) async {
      await _pump(tester, rules: <AlertRule>[_rule()]);

      await scrollWorklistTo(tester, find.text('the server’s own threshold'));
      expect(find.text('the server’s own threshold'), findsOneWidget);
    });

    testWidgets('a threshold is a figure, and 60 is never 60.0', (
      tester,
    ) async {
      await _pump(tester, rules: <AlertRule>[_rule(threshold: 60)]);

      await scrollWorklistTo(tester, find.text('60'));
      expect(find.text('60'), findsOneWidget);
      expect(find.text('60.0'), findsNothing);
    });

    testWidgets('a second active rule on a metric is called out', (
      tester,
    ) async {
      await _pump(
        tester,
        rules: <AlertRule>[
          _rule(id: 'new'),
          _rule(id: 'old', name: 'Older out of stock'),
        ],
      );

      await scrollWorklistTo(
        tester,
        find.text('· shadowed by a newer active rule'),
      );
      expect(find.text('· shadowed by a newer active rule'), findsOneWidget);
    });

    testWidgets('the metric rail narrows the list', (tester) async {
      await _pump(
        tester,
        rules: <AlertRule>[
          _rule(),
          _rule(id: 'r2', name: 'Price drift', metric: 'price_deviation'),
        ],
      );

      await scrollRailTo(
        tester,
        find.byKey(const ValueKey<String>('filter-metric-price_deviation')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('filter-metric-price_deviation')),
      );
      await tester.pumpAndSettle();

      await scrollWorklistTo(tester, find.byType(SoftRow).first);
      expect(find.byType(SoftRow), findsOneWidget);
      expect(find.text('Price drift'), findsOneWidget);
    });
  });

  group('turning a rule on and off', () {
    testWidgets('off patches active: false with its id', (tester) async {
      final repository = await _pump(tester, rules: <AlertRule>[_rule()]);

      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('toggle-r1')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('toggle-r1')));
      await tester.pumpAndSettle();

      expect(repository.updatedId, 'r1');
      expect(repository.updatedActive, isFalse);
    });

    testWidgets('on patches active: true', (tester) async {
      final repository = await _pump(
        tester,
        rules: <AlertRule>[_rule(active: false)],
      );

      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('toggle-r1')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('toggle-r1')));
      await tester.pumpAndSettle();

      expect(repository.updatedActive, isTrue);
    });

    testWidgets('the state is a word and a glyph, not a fill alone', (
      tester,
    ) async {
      await _pump(tester, rules: <AlertRule>[_rule()]);

      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('toggle-r1')),
      );
      // The toggled-on icon button is an Abyssal block plus the word ON, and
      // its label names where the press GOES, not where it is.
      expect(find.text('On'), findsOneWidget);
      final button = tester.widget<TorchIconButton>(
        find.byKey(const ValueKey<String>('toggle-r1')),
      );
      expect(button.toggledOn, isTrue);
      expect(button.stateWord, 'On');
      expect(button.semanticLabel, 'Turn Out of stock alert off');
    });
  });

  group('the form sheet', () {
    testWidgets('creating sends the name, metric, severity and threshold', (
      tester,
    ) async {
      final repository = await _pump(tester, rules: <AlertRule>[_rule()]);

      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('add-rule')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('add-rule')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('new-rule-name')),
        'Price band breach',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(TorchSheet),
          matching: find.text('Price deviation'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(TorchSheet),
          matching: find.text('Warning'),
        ),
      );
      await tester.pumpAndSettle();
      await scrollSheetTo(
        tester,
        find.byKey(const ValueKey<String>('rule-threshold')),
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('rule-threshold')),
        '12',
      );
      await scrollSheetTo(
        tester,
        find.byKey(const ValueKey<String>('create-rule')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('create-rule')));
      await tester.pumpAndSettle();

      expect(repository.createdName, 'Price band breach');
      expect(repository.createdMetric, 'price_deviation');
      expect(repository.createdSeverity, 'warning');
      expect(repository.createdThreshold, 12);
    });

    testWidgets('a rule cannot be created without a name', (tester) async {
      final repository = await _pump(tester);

      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('add-rule')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('add-rule')));
      await tester.pumpAndSettle();
      await scrollSheetTo(
        tester,
        find.byKey(const ValueKey<String>('create-rule')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('create-rule')));
      await tester.pumpAndSettle();

      expect(repository.createCount, 0);
      await scrollSheetTo(tester, find.text('A rule needs a name.'));
      expect(find.text('A rule needs a name.'), findsOneWidget);
    });

    testWidgets('the numeric trough refuses letters at the keyboard', (
      tester,
    ) async {
      await _pump(tester);

      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('add-rule')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('add-rule')));
      await tester.pumpAndSettle();
      await scrollSheetTo(
        tester,
        find.byKey(const ValueKey<String>('rule-threshold')),
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('rule-threshold')),
        'abc',
      );
      await tester.pumpAndSettle();

      // Digits, a true minus and both separators, and nothing else: the
      // locale decides how a value is written back, never what a thumb may
      // type. A threshold that was never a number never reaches the request.
      expect(find.text('abc'), findsNothing);
    });

    testWidgets('a threshold that will not parse is refused before the '
        'request', (tester) async {
      final repository = await _pump(tester);

      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('add-rule')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('add-rule')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('new-rule-name')),
        'Anything',
      );
      await scrollSheetTo(
        tester,
        find.byKey(const ValueKey<String>('rule-threshold')),
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('rule-threshold')),
        '1.2.3',
      );
      await scrollSheetTo(
        tester,
        find.byKey(const ValueKey<String>('create-rule')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('create-rule')));
      await tester.pumpAndSettle();

      expect(repository.createCount, 0);
      await scrollSheetTo(tester, find.text('A threshold is a number.'));
      expect(find.text('A threshold is a number.'), findsOneWidget);
    });

    testWidgets('the row opens the editor, which patches severity and '
        'threshold', (tester) async {
      final repository = await _pump(
        tester,
        rules: <AlertRule>[_rule(threshold: 50)],
      );

      await scrollWorklistTo(tester, find.byType(SoftRow).first);
      await tester.tap(find.byType(SoftRow).first);
      await tester.pumpAndSettle();

      expect(find.byType(TorchSheet), findsOneWidget);
      // There is no name field on an edit: the API cannot rename a rule.
      expect(find.byKey(const ValueKey<String>('new-rule-name')), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey<String>('rule-threshold')),
        '40',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(TorchSheet),
          matching: find.text('Normal'),
        ),
      );
      await tester.pumpAndSettle();
      await scrollSheetTo(
        tester,
        find.byKey(const ValueKey<String>('save-rule')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('save-rule')));
      await tester.pumpAndSettle();

      expect(repository.updatedId, 'r1');
      expect(repository.updatedThreshold, 40);
      expect(repository.updatedSeverity, 'normal');
      // Severity always goes, so the PATCH is never an empty body.
      expect(repository.updatedActive, isNull);
    });
  });

  group('the settled states', () {
    testWidgets('nothing configured is a designed state', (tester) async {
      await _pump(tester);

      expect(find.text('No rules yet.'), findsOneWidget);
      expect(
        find.text('Alerts only exist because a rule says so.'),
        findsOneWidget,
      );
    });

    testWidgets('a failure is sanitised and offers one retry', (tester) async {
      await _pump(
        tester,
        failure: StateError('SocketException: api.tradeiq.co.za'),
      );

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      expect(find.byKey(const ValueKey<String>('rules-retry')), findsOneWidget);
    });
  });

  group('the amber census', () {
    testWidgets('Night paints exactly one lit object: the nav tab', (
      tester,
    ) async {
      await _pump(
        tester,
        rules: <AlertRule>[_rule(), _rule(id: 'r2', active: false)],
      );

      final census = await amberCensus(tester);
      expectWithinAmberBudget(
        census,
        TiqSkin.night(),
        route: 'alert-rules',
        phase: 'loaded',
      );
      expect(
        census.objectCount,
        1,
        reason:
            'A configuration list has nothing happening in it, so it '
            'nominates nothing.\n${census.describe()}',
      );
    });

    testWidgets('Night, empty, still paints exactly the nav tab', (
      tester,
    ) async {
      await _pump(tester);
      final census = await amberCensus(tester);
      expect(census.objectCount, 1, reason: census.describe());
    });

    testWidgets('the form sheet spends one on its commit', (tester) async {
      await _pump(tester, rules: <AlertRule>[_rule()]);

      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('add-rule')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('add-rule')));
      await tester.pumpAndSettle();
      // The commit is at the foot of a form that outgrows the sheet's
      // ceiling, and a light nobody can see is not a light.
      await scrollSheetTo(
        tester,
        find.byKey(const ValueKey<String>('create-rule')),
      );

      final census = await amberCensus(tester);
      expectWithinAmberBudget(
        census,
        TiqSkin.night(),
        route: 'alert-rules/form',
        phase: 'sheet',
      );
      expect(
        census.objectCount,
        1,
        reason:
            'The commit is armed from the start — a create form can always be '
            'submitted and answered — and the nav tab beneath has gone '
            'out.\n${census.describe()}',
      );
    });

    for (final skin in <TiqSkin>[TiqSkin.day(), TiqSkin.veld()]) {
      testWidgets('${skin.mode.name} paints no amber at all', (tester) async {
        await _pump(tester, skin: skin, rules: <AlertRule>[_rule()]);

        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          skin,
          route: 'alert-rules',
          phase: 'loaded',
        );
        expect(census.objectCount, 0, reason: census.describe());
      });
    }
  });

  testWidgets('2.0x text: the structure survives and nothing overflows', (
    tester,
  ) async {
    await _pump(
      tester,
      textScale: 2.0,
      rules: <AlertRule>[
        _rule(threshold: 50),
        _rule(id: 'r2', name: 'Price drift', metric: 'price_deviation',
            active: false),
      ],
    );

    expect(tester.takeException(), isNull);
    await scrollWorklistTo(tester, find.byType(SoftRow).first);
    expect(find.byType(SoftRow), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
