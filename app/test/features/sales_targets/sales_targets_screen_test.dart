import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/sales_targets/data/sales_targets_repository.dart';
import 'package:tradeiq_app/features/sales_targets/presentation/sales_attainment_panel.dart';
import 'package:tradeiq_app/features/sales_targets/presentation/sales_targets_screen.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';

import '../../core/design/amber_golden.dart';
import '../operations_harness.dart';

const SalesAttainmentReport _report = SalesAttainmentReport(
  month: '2026-09',
  timeZone: 'Africa/Johannesburg',
  skus: <SkuAttainment>[
    SkuAttainment(
      skuId: 'cola',
      skuName: 'Cola 2L',
      category: 'Beverages',
      targetId: 't-cola',
      targetUnits: 100,
      actualUnits: 50,
      attainmentPct: 50,
      scoped: <ScopedAttainment>[
        ScopedAttainment(
          targetId: 't-cola-north',
          scope: 'territory',
          territory: SalesTargetRef(id: 'north', name: 'North', code: 'N1'),
          targetUnits: 40,
          actualUnits: 30,
          attainmentPct: 75,
        ),
      ],
    ),
    // No target at all: attainmentPct is null and targetUnits is null. This
    // row is the whole of #396.
    SkuAttainment(
      skuId: 'chips',
      skuName: 'Chips 125g',
      category: 'Snacks',
      actualUnits: 4,
    ),
  ],
  client: AttainmentLevel(
    targets: 1,
    targetUnits: 100,
    actualUnits: 50,
    attainmentPct: 50,
  ),
  territory: AttainmentLevel(
    targets: 1,
    targetUnits: 40,
    actualUnits: 30,
    attainmentPct: 75,
  ),
  // `outlet` is left at its default: no targets at this level at all.
);

const SalesAttainmentReport _noTargets = SalesAttainmentReport(
  month: '2026-09',
  timeZone: 'Africa/Johannesburg',
  skus: <SkuAttainment>[
    SkuAttainment(
      skuId: 'chips',
      skuName: 'Chips 125g',
      category: 'Snacks',
      actualUnits: 4,
    ),
  ],
);

/// A TARGET OF NOUGHT UNITS, which is not the absence of a target.
///
/// The API accepts it (`targetUnits < 0` is all it refuses), this screen's own
/// sheet creates it — a manager delisting a SKU sets it to 0 — and the server
/// then answers `attainmentPct: null`, because the share of nothing is not a
/// number. Every #396 fixture used `targetUnits: null` instead, which is why
/// the panel could assert its way to a red box in debug and a bare em dash in
/// release without a test noticing.
const SalesAttainmentReport _zeroUnitTarget = SalesAttainmentReport(
  month: '2026-09',
  timeZone: 'Africa/Johannesburg',
  skus: <SkuAttainment>[
    SkuAttainment(
      skuId: 'chips',
      skuName: 'Chips 125g',
      category: 'Snacks',
      targetId: 't-chips',
      targetUnits: 0,
      actualUnits: 4,
    ),
  ],
  client: AttainmentLevel(targets: 1, targetUnits: 0, actualUnits: 4),
);

const SalesAttainmentReport _noSkus = SalesAttainmentReport(
  month: '2026-09',
  timeZone: 'Africa/Johannesburg',
  skus: <SkuAttainment>[],
);

const SalesTargetImportResult _preview = SalesTargetImportResult(
  dryRun: true,
  totalRows: 3,
  validRows: 2,
  invalidRows: 1,
  created: 1,
  updated: 1,
  errors: <ImportRowError>[
    ImportRowError(
      row: 3,
      column: 'month',
      message: '"2026-9" is not a month; use YYYY-MM',
    ),
  ],
  rows: <ImportPreviewRow>[
    ImportPreviewRow(
      row: 2,
      skuName: 'Cola 2L',
      month: '2026-09',
      scope: 'client',
      targetUnits: 120,
      action: 'update',
    ),
  ],
);

DioException _refusal(int status, String message) {
  final options = RequestOptions(path: '/sales-targets');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: status,
      data: <String, Object?>{'error': message},
    ),
  );
}

class _FakeSalesTargets implements SalesTargetsRepository {
  _FakeSalesTargets({
    this.report = _report,
    this.reportError,
    this.upsertError,
    this.previewError,
    this.deleteError,
  });

  final SalesAttainmentReport report;
  final Object? reportError;
  final Object? upsertError;
  final Object? previewError;
  final Object? deleteError;

  final List<String?> requestedMonths = <String?>[];
  final List<Map<String, Object?>> upserts = <Map<String, Object?>>[];
  final List<String> deleted = <String>[];
  final List<(String, bool)> imports = <(String, bool)>[];

  @override
  Future<SalesAttainmentReport> attainment(String? month) async {
    requestedMonths.add(month);
    if (reportError != null) throw reportError!;
    return report;
  }

  @override
  Future<void> upsert({
    required String skuId,
    required String month,
    required int targetUnits,
    String? territoryId,
    String? outletId,
  }) async {
    if (upsertError != null) throw upsertError!;
    upserts.add(<String, Object?>{
      'skuId': skuId,
      'month': month,
      'targetUnits': targetUnits,
      'territoryId': territoryId,
      'outletId': outletId,
    });
  }

  @override
  Future<void> delete(String id) async {
    if (deleteError != null) throw deleteError!;
    deleted.add(id);
  }

  @override
  Future<SalesTargetImportResult> importCsv(
    String csv, {
    required bool dryRun,
  }) async {
    imports.add((csv, dryRun));
    if (dryRun && previewError != null) throw previewError!;
    return dryRun
        ? _preview
        : const SalesTargetImportResult(
            dryRun: false,
            totalRows: 3,
            validRows: 2,
            invalidRows: 1,
            created: 1,
            updated: 1,
          );
  }
}

/// Stands in for the platform's file chooser, which a widget test has no way
/// to open. Returns [file], or throws [error] if one was given.
class _FakeCsvPicker {
  _FakeCsvPicker({this.file, this.error});

  final PickedCsv? file;
  final Object? error;
  int calls = 0;

  Future<PickedCsv?> call() async {
    calls += 1;
    if (error != null) throw error!;
    return file;
  }
}

const PickedCsv _pickedCsv = PickedCsv(
  name: 'september-targets.csv',
  contents: 'month,sku,targetUnits\n2026-09,Cola 2L,120\n2026-9,Chips 125g,10',
);

Future<_FakeSalesTargets> _pump(
  WidgetTester tester, {
  _FakeSalesTargets? repo,
  _FakeCsvPicker? picker,
  TiqSkin? skin,
  double textScale = 1.0,
  Locale? locale,
  Size size = const Size(360, 720),
}) async {
  final resolved = repo ?? _FakeSalesTargets();
  await pumpOperations(
    tester,
    const SalesTargetsScreen(),
    skin: skin,
    size: size,
    textScale: textScale,
    locale: locale,
    overrides: <Override>[
      salesTargetsRepositoryProvider.overrideWithValue(resolved),
      if (picker != null) csvFilePickerProvider.overrideWithValue(picker.call),
      salesTargetsMonthProvider.overrideWith(
        () => SalesMonthNotifier(DateTime(2026, 9, 17)),
      ),
      outletsRepositoryProvider.overrideWithValue(
        FakeOpsOutletsRepository(
          outlets: <Outlet>[opsOutlet('o1', 'Kasi Corner Spaza')],
        ),
      ),
      territoriesRepositoryProvider.overrideWithValue(
        FakeTerritoriesRepository(
          territories: const <Territory>[
            Territory(id: 'north', name: 'North', code: 'N1'),
          ],
        ),
      ),
    ],
  );
  return resolved;
}

Future<void> _openImport(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('sales-targets-import')));
  await tester.pumpAndSettle();
}

void main() {
  group('a target that does not exist is not a target of zero (#396)', () {
    testWidgets('a level with no targets renders an em dash and the reason', (
      tester,
    ) async {
      await _pump(tester);

      // The old panel dropped the level out of the grid entirely, so a
      // manager who set no store targets saw two tiles and no reason for the
      // third's absence.
      final stores = tester.widget<StatTile>(
        find.byKey(const ValueKey<String>('attainment-level-Stores')),
      );
      expect(stores.value, isNull);
      expect(
        stores.noDataReason,
        'No target is set at this level, so there is nothing to attain.',
      );
      expect(stores.severity, isNull, reason: 'Absence is not a miss.');
      expect(stores.stateLine, isNull, reason: 'No band word on nothing.');
    });

    testWidgets('a SKU with no target says so in words', (tester) async {
      await _pump(tester);
      await scrollOpsTo(
        tester,
        find.byKey(const ValueKey<String>('sku-chips')),
      );

      final row = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('sku-chips')),
      );
      expect(row.subtitle, contains('no target set'));
      expect(row.severity, SoftRowSeverity.none);
      expect(row.severityLabel, isNull);
      expect(find.text('No target'), findsWidgets);
    });

    testWidgets('a SKU with a target carries its band, and a bar', (
      tester,
    ) async {
      await _pump(tester);

      await scrollOpsTo(tester, find.byKey(const ValueKey<String>('sku-cola')));
      final row = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('sku-cola')),
      );
      // 50% is behind, which is crimson at the solid commitment level plus
      // the word.
      expect(row.severity, SoftRowSeverity.critical);
      expect(row.severityLabel, 'Behind');
    });

    testWidgets('a scoped target names what it applies to', (tester) async {
      await _pump(tester);
      await scrollOpsTo(
        tester,
        find.byKey(const ValueKey<String>('scoped-t-cola-north')),
      );
      final row = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('scoped-t-cola-north')),
      );
      // The old row said "North (territory)" with the wire's own word in
      // brackets; this one is two translated words.
      expect(row.title, 'Cola 2L · North · Territory');
      // 75% is behind, and behind is crimson plus the word.
      expect(row.severity, SoftRowSeverity.critical);
      expect(row.severityLabel, 'Behind');
    });
  });

  group('a target of nought units is not the absence of one', () {
    testWidgets('the panel renders at all, with the reason in words', (
      tester,
    ) async {
      // THE FAILURE, WRITTEN DOWN: "measured" was read off `targets > 0` while
      // the figure came from `attainmentPct`, which the server nulls whenever
      // `targetUnits <= 0`. StatTile was handed a null with no sentence — its
      // own assert in debug, and in release an em dash standing on its own,
      // which is the very law this screen was rewritten to keep.
      await _pump(tester, repo: _FakeSalesTargets(report: _zeroUnitTarget));
      expect(tester.takeException(), isNull);

      final account = tester.widget<StatTile>(
        find.byKey(const ValueKey<String>('attainment-level-Account-wide')),
      );
      expect(account.value, isNull);
      expect(
        account.noDataReason,
        'Every target at this level is 0 units, so there is nothing to '
        'attain.',
      );
      // Not a miss: nothing was asked for, so nothing was missed.
      expect(account.severity, isNull);
      expect(account.stateLine, isNull);
      // The counts still stand — they are how the delisted SKU is found.
      expect(account.subordinates, contains('1 target'));
    });

    testWidgets('the SKU row does not say both things at once', (tester) async {
      await _pump(tester, repo: _FakeSalesTargets(report: _zeroUnitTarget));
      await scrollOpsTo(
        tester,
        find.byKey(const ValueKey<String>('sku-chips')),
      );

      final row = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('sku-chips')),
      );
      // The row printed "target 0 units" over "No target" — a target that is
      // set and not set, in one breath and in one spoken label.
      expect(row.subtitle, contains('target 0 units'));
      expect(row.semanticsLabel, contains('target 0 units'));
      expect(row.semanticsLabel, contains('Target of 0 units'));
      expect(row.semanticsLabel, isNot(contains('. No target')));
      expect(find.text('No target'), findsNothing);
      expect(find.text('Target of 0 units'), findsOneWidget);
      // Still no severity: there is nothing to be behind on.
      expect(row.severity, SoftRowSeverity.none);
      expect(row.severityLabel, isNull);
    });

    testWidgets('an absent target still reads as an absence', (tester) async {
      // The other half of the pair, so the new word cannot swallow the old
      // one: `targetUnits: null` is still "No target".
      await _pump(tester, repo: _FakeSalesTargets(report: _noTargets));
      await scrollOpsTo(
        tester,
        find.byKey(const ValueKey<String>('sku-chips')),
      );
      final row = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('sku-chips')),
      );
      expect(row.subtitle, contains('no target set'));
      expect(row.semanticsLabel, contains('No target'));
      expect(find.text('Target of 0 units'), findsNothing);
    });

    testWidgets('the dashboard panel survives it too', (tester) async {
      await pumpOperations(
        tester,
        const SalesAttainmentPanel(),
        overrides: <Override>[
          salesTargetsRepositoryProvider.overrideWithValue(
            _FakeSalesTargets(report: _zeroUnitTarget),
          ),
        ],
      );
      expect(tester.takeException(), isNull);
      // The zero-unit level says why; the two empty levels beside it keep
      // their own, different reason.
      expect(
        find.text(
          'Every target at this level is 0 units, so there is nothing to '
          'attain.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'No target is set at this level, so there is nothing to '
          'attain.',
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('Afrikaans says it in Afrikaans', (tester) async {
      await _pump(
        tester,
        repo: _FakeSalesTargets(report: _zeroUnitTarget),
        locale: const Locale('af'),
      );
      await scrollOpsTo(
        tester,
        find.byKey(const ValueKey<String>('sku-chips')),
      );
      expect(find.text('Teiken van 0 eenhede'), findsOneWidget);
      expect(find.text('Target of 0 units'), findsNothing);
    });
  });

  group('the month', () {
    testWidgets('names itself in the reader\'s language and steps', (
      tester,
    ) async {
      final repo = await _pump(tester);
      expect(find.text('September 2026'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('sales-month-prev')));
      await tester.pumpAndSettle();
      expect(find.text('August 2026'), findsOneWidget);
      expect(repo.requestedMonths.last, '2026-08');

      await tester.tap(find.byKey(const ValueKey<String>('sales-month-next')));
      await tester.pumpAndSettle();
      expect(repo.requestedMonths.last, '2026-09');
    });

    testWidgets('the step buttons name where they go', (tester) async {
      await _pump(tester);
      final handle = tester.ensureSemantics();
      expect(
        tester
            .getSemantics(
              find.byKey(const ValueKey<String>('sales-month-prev')),
            )
            .label,
        contains('The month before September 2026'),
      );
      handle.dispose();
    });
  });

  group('setting a target', () {
    testWidgets('sends the SKU, month and units', (tester) async {
      final repo = await _pump(tester);

      await scrollOpsTo(
        tester,
        find.byKey(const ValueKey<String>('set-target-cola')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('set-target-cola')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('target-units')),
        '250',
      );
      await tester.pumpAndSettle();
      await scrollOpsSheetTo(
        tester,
        find.byKey(const ValueKey<String>('target-save')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('target-save')));
      await tester.pumpAndSettle();

      expect(repo.upserts, hasLength(1));
      expect(repo.upserts.single['skuId'], 'cola');
      expect(repo.upserts.single['month'], '2026-09');
      expect(repo.upserts.single['targetUnits'], 250);
    });

    testWidgets('editing a territory target keeps its scope', (tester) async {
      final repo = await _pump(tester);
      await scrollOpsTo(
        tester,
        find.byKey(const ValueKey<String>('edit-target-t-cola-north')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('edit-target-t-cola-north')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('target-units')),
        '60',
      );
      await tester.pumpAndSettle();
      await scrollOpsSheetTo(
        tester,
        find.byKey(const ValueKey<String>('target-save')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('target-save')));
      await tester.pumpAndSettle();

      expect(repo.upserts.single['territoryId'], 'north');
      expect(repo.upserts.single['outletId'], isNull);
      expect(repo.upserts.single['targetUnits'], 60);
    });

    testWidgets('a refusal keeps the sheet open with the server\'s reason', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _FakeSalesTargets(
          upsertError: _refusal(404, 'No SKU with id "cola" on this account'),
        ),
      );

      await scrollOpsTo(
        tester,
        find.byKey(const ValueKey<String>('set-target-cola')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('set-target-cola')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('target-units')),
        '250',
      );
      await tester.pumpAndSettle();
      await scrollOpsSheetTo(
        tester,
        find.byKey(const ValueKey<String>('target-save')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('target-save')));
      await tester.pumpAndSettle();

      // A refusal that closes the form has thrown away the thing the manager
      // has to fix.
      expect(find.byKey(const ValueKey<String>('target-save')), findsOneWidget);
      expect(find.textContaining('No SKU with id "cola"'), findsOneWidget);
    });

    testWidgets('a non-numeric target never reaches the server', (
      tester,
    ) async {
      final repo = await _pump(tester);

      await scrollOpsTo(
        tester,
        find.byKey(const ValueKey<String>('set-target-cola')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('set-target-cola')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('target-units')),
        'lots',
      );
      await tester.pumpAndSettle();
      await scrollOpsSheetTo(
        tester,
        find.byKey(const ValueKey<String>('target-save')),
      );

      final save = tester.widget<TorchPrimaryButton>(
        find.byKey(const ValueKey<String>('target-save')),
      );
      expect(save.onPressed, isNull);
      expect(save.blockedReason, isNotNull);
      expect(repo.upserts, isEmpty);
    });
  });

  group('removing a target', () {
    testWidgets('sends the delete', (tester) async {
      final repo = await _pump(tester);
      await scrollOpsTo(
        tester,
        find.byKey(const ValueKey<String>('delete-target-t-cola')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('delete-target-t-cola')),
      );
      await tester.pumpAndSettle();
      expect(repo.deleted, <String>['t-cola']);
    });

    testWidgets('a failure says the target is still set', (tester) async {
      await _pump(
        tester,
        repo: _FakeSalesTargets(deleteError: StateError('no route to host')),
      );
      await scrollOpsTo(
        tester,
        find.byKey(const ValueKey<String>('delete-target-t-cola')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('delete-target-t-cola')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('That target was not removed. It is still set.'),
        findsOneWidget,
      );
      await settleOpsToasts(tester);
    });
  });

  group('the CSV import', () {
    testWidgets('previews with its row errors, then applies', (tester) async {
      final repo = await _pump(tester);
      await _openImport(tester);

      const csv =
          'month,sku,targetUnits\n2026-09,Cola 2L,120\n2026-9,Chips 125g,10';
      await tester.enterText(
        find.byKey(const ValueKey<String>('csv-input')),
        csv,
      );
      await tester.pumpAndSettle();

      // Nothing to apply until a preview has run, and it says why.
      TorchPrimaryButton apply() => tester.widget<TorchPrimaryButton>(
        find.byKey(const ValueKey<String>('csv-apply')),
      );
      await scrollOpsSheetTo(
        tester,
        find.byKey(const ValueKey<String>('csv-apply')),
      );
      expect(apply().onPressed, isNull);
      expect(apply().blockedReason, contains('Preview the file first'));

      await tester.tap(find.byKey(const ValueKey<String>('csv-preview')));
      await tester.pumpAndSettle();

      expect(repo.imports, <(String, bool)>[(csv, true)]);

      // The dry run is a designed state: two figures and a worklist.
      await scrollOpsSheetTo(
        tester,
        find.byKey(const ValueKey<String>('csv-preview-pane')),
      );
      final ready = tester.widget<StatTile>(
        find.byKey(const ValueKey<String>('csv-ready')),
      );
      expect(ready.value, 2);
      final errors = tester.widget<StatTile>(
        find.byKey(const ValueKey<String>('csv-errors')),
      );
      expect(errors.value, 1);
      expect(find.text('Would create 1 and update 1.'), findsOneWidget);
      expect(
        find.text('Row 3 · month: "2026-9" is not a month; use YYYY-MM'),
        findsOneWidget,
      );

      await scrollOpsSheetTo(
        tester,
        find.byKey(const ValueKey<String>('csv-apply')),
      );
      expect(find.text('Apply 2 rows'), findsOneWidget);
      expect(apply().onPressed, isNotNull);

      await tester.tap(find.byKey(const ValueKey<String>('csv-apply')));
      await tester.pumpAndSettle();

      expect(repo.imports, <(String, bool)>[(csv, true), (csv, false)]);
      expect(find.byKey(const ValueKey<String>('csv-input')), findsNothing);
      expect(
        find.text('1 created, 1 updated, 1 rows skipped.'),
        findsOneWidget,
      );
      await settleOpsToasts(tester);
    });

    testWidgets('editing the CSV after a preview requires a fresh one', (
      tester,
    ) async {
      await _pump(tester);
      await _openImport(tester);

      final input = find.byKey(const ValueKey<String>('csv-input'));
      await tester.enterText(input, 'month,sku,targetUnits\n2026-09,Cola 2L,1');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('csv-preview')));
      await tester.pumpAndSettle();

      await tester.enterText(input, 'month,sku,targetUnits\n2026-09,Cola 2L,2');
      await tester.pumpAndSettle();

      await scrollOpsSheetTo(
        tester,
        find.byKey(const ValueKey<String>('csv-apply')),
      );
      // What gets written is always what was shown.
      final apply = tester.widget<TorchPrimaryButton>(
        find.byKey(const ValueKey<String>('csv-apply')),
      );
      expect(apply.onPressed, isNull);
      expect(
        find.byKey(const ValueKey<String>('csv-preview-pane')),
        findsNothing,
      );
    });

    testWidgets('a file-level refusal is shown, and no dry run with it', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _FakeSalesTargets(
          previewError: _refusal(
            400,
            'The header row must include month, sku, targetUnits '
            '(missing: targetUnits)',
          ),
        ),
      );
      await _openImport(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('csv-input')),
        'month,sku\n2026-09,Cola 2L',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('csv-preview')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('csv-file-error')),
        findsOneWidget,
      );
      expect(find.textContaining('missing: targetUnits'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('csv-preview-pane')),
        findsNothing,
      );
    });

    testWidgets('a chosen file previews first, and applies what was shown', (
      tester,
    ) async {
      final picker = _FakeCsvPicker(file: _pickedCsv);
      final repo = await _pump(tester, picker: picker);
      await _openImport(tester);

      // Pasting is still there as the fallback, until a file is chosen.
      expect(find.byKey(const ValueKey<String>('csv-input')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('csv-choose-file')));
      await tester.pumpAndSettle();

      expect(picker.calls, 1);
      expect(find.text('september-targets.csv'), findsOneWidget);
      // While a file is held there is no question about which source uploads.
      expect(find.byKey(const ValueKey<String>('csv-input')), findsNothing);

      await scrollOpsSheetTo(
        tester,
        find.byKey(const ValueKey<String>('csv-preview')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('csv-preview')));
      await tester.pumpAndSettle();
      await scrollOpsSheetTo(
        tester,
        find.byKey(const ValueKey<String>('csv-apply')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('csv-apply')));
      await tester.pumpAndSettle();

      expect(repo.imports, <(String, bool)>[
        (_pickedCsv.contents, true),
        (_pickedCsv.contents, false),
      ]);
      await settleOpsToasts(tester);
    });

    testWidgets('removing the file restores the paste box and the preview', (
      tester,
    ) async {
      final picker = _FakeCsvPicker(file: _pickedCsv);
      await _pump(tester, picker: picker);
      await _openImport(tester);
      await tester.tap(find.byKey(const ValueKey<String>('csv-choose-file')));
      await tester.pumpAndSettle();
      await scrollOpsSheetTo(
        tester,
        find.byKey(const ValueKey<String>('csv-preview')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('csv-preview')));
      await tester.pumpAndSettle();

      await scrollOpsSheetTo(
        tester,
        find.byKey(const ValueKey<String>('csv-clear-file')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('csv-clear-file')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('csv-input')), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('csv-preview-pane')),
        findsNothing,
      );
    });

    testWidgets('cancelling the chooser leaves the pasted CSV alone', (
      tester,
    ) async {
      final picker = _FakeCsvPicker();
      await _pump(tester, picker: picker);
      await _openImport(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('csv-input')),
        'month,sku,targetUnits\n2026-09,Cola 2L,1',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('csv-choose-file')));
      await tester.pumpAndSettle();

      expect(picker.calls, 1);
      expect(find.byKey(const ValueKey<String>('csv-input')), findsOneWidget);
    });

    testWidgets('says why a file could not be taken, and offers paste still', (
      tester,
    ) async {
      final picker = _FakeCsvPicker(
        error: const CsvFileException('That file is larger than 8 MB.'),
      );
      await _pump(tester, picker: picker);
      await _openImport(tester);
      await tester.tap(find.byKey(const ValueKey<String>('csv-choose-file')));
      await tester.pumpAndSettle();

      expect(find.textContaining('larger than 8 MB'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('csv-input')), findsOneWidget);
    });
  });

  group('the states', () {
    testWidgets('no targets at all names the month', (tester) async {
      await _pump(tester, repo: _FakeSalesTargets(report: _noTargets));
      expect(find.text('No targets for September 2026.'), findsOneWidget);
    });

    testWidgets('no SKUs says targets are set per SKU', (tester) async {
      await _pump(tester, repo: _FakeSalesTargets(report: _noSkus));
      expect(find.text('No SKUs on this account.'), findsOneWidget);
    });

    testWidgets('error sanitises and retries', (tester) async {
      await _pump(
        tester,
        repo: _FakeSalesTargets(
          reportError: StateError('SocketException: api.tradeiq.co.za'),
        ),
      );
      expect(find.text('The targets did not load.'), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
    });
  });

  group('the dashboard panel', () {
    testWidgets('sends no month and labels the figure with the one it got', (
      tester,
    ) async {
      final repo = _FakeSalesTargets();
      await pumpOperations(
        tester,
        const SalesAttainmentPanel(),
        overrides: <Override>[
          salesTargetsRepositoryProvider.overrideWithValue(repo),
        ],
      );

      // #339: which month is current is the server's answer, not this
      // device's.
      expect(repo.requestedMonths, <String?>[null]);
      expect(find.textContaining('September 2026'), findsOneWidget);
    });

    testWidgets('says so when no targets are set', (tester) async {
      await pumpOperations(
        tester,
        const SalesAttainmentPanel(),
        overrides: <Override>[
          salesTargetsRepositoryProvider.overrideWithValue(
            _FakeSalesTargets(report: _noTargets),
          ),
        ],
      );
      expect(find.text('No targets for September 2026.'), findsOneWidget);
    });
  });

  group('Afrikaans and 2.0x', () {
    testWidgets('Afrikaans has no English left on it', (tester) async {
      await _pump(tester, locale: const Locale('af'));
      expect(find.text('Verkoopsteikens'), findsWidgets);
      expect(find.text('Teenoor teiken'), findsOneWidget);
      expect(find.text('September 2026'), findsOneWidget);
      expect(find.text('Against target'), findsNothing);
    });

    testWidgets('2.0x does not overflow', (tester) async {
      await _pump(tester, textScale: 2.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Afrikaans at 1.4x does not overflow either', (tester) async {
      await _pump(tester, textScale: 1.4, locale: const Locale('af'));
      expect(tester.takeException(), isNull);
    });
  });

  group('every button is operable by a screen reader', () {
    // The kit shipped a component family that announced itself and did
    // nothing when a screen reader activated it, and `SectionRuleAction` and
    // `PaginationFooter.action` were still shipping that way when this group
    // was migrated. This is the guard, on this screen, per phase — so no
    // local `Semantics(button: true, excludeSemantics: true)` around a bare
    // GestureDetector can bring it back.
    final phases = <String, Future<void> Function(WidgetTester)>{
      'loaded': (t) => _pump(t),
      'no targets': (t) =>
          _pump(t, repo: _FakeSalesTargets(report: _noTargets)),
      'no SKUs': (t) => _pump(t, repo: _FakeSalesTargets(report: _noSkus)),
      'error': (t) => _pump(
        t,
        repo: _FakeSalesTargets(reportError: StateError('no route to host')),
      ),
    };
    for (final phase in phases.entries) {
      testWidgets(phase.key, (tester) async {
        final handle = tester.ensureSemantics();
        await phase.value(tester);
        expectEveryButtonActivatable(tester);
        handle.dispose();
      });
    }
  });

  group('the amber census, every phase in every skin', () {
    for (final skin in <TiqSkin>[
      TiqSkin.night(),
      TiqSkin.day(),
      TiqSkin.veld(),
    ]) {
      final lit = skin.mode == SkinMode.night ? 1 : 0;
      final phases = <String, Future<void> Function(WidgetTester)>{
        'loaded': (t) => _pump(t, skin: skin),
        'no-targets': (t) => _pump(
          t,
          skin: skin,
          repo: _FakeSalesTargets(report: _noTargets),
        ),
        'empty': (t) => _pump(
          t,
          skin: skin,
          repo: _FakeSalesTargets(report: _noSkus),
        ),
        'error': (t) => _pump(
          t,
          skin: skin,
          repo: _FakeSalesTargets(
            reportError: StateError('SocketException: api.tradeiq.co.za'),
          ),
        ),
      };
      for (final phase in phases.entries) {
        testWidgets('${skin.mode.name}, ${phase.key}: $lit', (tester) async {
          await phase.value(tester);
          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            skin,
            route: 'sales-targets',
            phase: phase.key,
          );
          expect(census.objectCount, lit, reason: census.describe());
        });
      }

      // While a sheet is up every amber on the route beneath goes out, so the
      // sheet's own commit is the single lit object — including in Night,
      // where the nav's tab drops to its ink form.
      testWidgets('${skin.mode.name}, beneath the target sheet: 1', (
        tester,
      ) async {
        await _pump(tester, skin: skin);
        await scrollOpsTo(
          tester,
          find.byKey(const ValueKey<String>('set-target-cola')),
        );
        await tester.tap(find.byKey(const ValueKey<String>('set-target-cola')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey<String>('target-units')),
          '250',
        );
        await tester.pumpAndSettle();
        // The commit has to be ON SCREEN to be counted: the census walks the
        // pixels of the composed frame, and a sheet taller than 88% of a
        // 360x720 phone keeps its last control below the fold.
        await scrollOpsSheetTo(
          tester,
          find.byKey(const ValueKey<String>('target-save')),
        );

        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          skin,
          route: 'sales-targets',
          phase: 'target-sheet',
        );
        expect(
          census.objectCount,
          1,
          reason:
              'The sheet owns the frame: the nav tab beneath it is out and '
              'the sheet\'s commit is the one light.\n${census.describe()}',
        );
      });
    }
  });
}
