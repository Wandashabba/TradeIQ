import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/features/sales_targets/data/sales_targets_repository.dart';
import 'package:tradeiq_app/features/sales_targets/presentation/sales_attainment_panel.dart';
import 'package:tradeiq_app/features/sales_targets/presentation/sales_targets_screen.dart';

import '../../helpers/routed_app.dart';

const _report = SalesAttainmentReport(
  month: '2026-09',
  timeZone: 'Africa/Johannesburg',
  skus: [
    SkuAttainment(
      skuId: 'cola',
      skuName: 'Cola 2L',
      category: 'Beverages',
      targetId: 't-cola',
      targetUnits: 100,
      actualUnits: 50,
      attainmentPct: 50,
      scoped: [
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
);

const _preview = SalesTargetImportResult(
  dryRun: true,
  totalRows: 3,
  validRows: 2,
  invalidRows: 1,
  created: 1,
  updated: 1,
  errors: [
    ImportRowError(
      row: 3,
      column: 'month',
      message: '"2026-9" is not a month; use YYYY-MM',
    ),
  ],
  rows: [
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
    response: Response(
      requestOptions: options,
      statusCode: status,
      data: {'error': message},
    ),
  );
}

class _FakeSalesTargetsRepository implements SalesTargetsRepository {
  _FakeSalesTargetsRepository({
    this.report = _report,
    this.upsertError,
    this.previewError,
  });

  final SalesAttainmentReport report;
  final Object? upsertError;
  final Object? previewError;

  final requestedMonths = <String?>[];
  final upserts = <Map<String, Object?>>[];
  final deleted = <String>[];
  final imports = <(String, bool)>[];

  @override
  Future<SalesAttainmentReport> attainment(String? month) async {
    requestedMonths.add(month);
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
    upserts.add({
      'skuId': skuId,
      'month': month,
      'targetUnits': targetUnits,
      'territoryId': territoryId,
      'outletId': outletId,
    });
  }

  @override
  Future<void> delete(String id) async => deleted.add(id);

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

class _ThrowingSalesTargetsRepository extends _FakeSalesTargetsRepository {
  @override
  Future<SalesAttainmentReport> attainment(String? month) async =>
      throw Exception('boom');
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

const _pickedCsv = PickedCsv(
  name: 'september-targets.csv',
  contents: 'month,sku,targetUnits\n2026-09,Cola 2L,120\n2026-9,Chips 125g,10',
);

Widget _app(
  SalesTargetsRepository repo, {
  ThemeData? theme,
  _FakeCsvPicker? picker,
}) => routedApp(
  const SalesTargetsScreen(),
  theme: theme,
  overrides: [
    salesTargetsRepositoryProvider.overrideWithValue(repo),
    if (picker != null) csvFilePickerProvider.overrideWithValue(picker.call),
    salesTargetsMonthProvider.overrideWith(
      () => SalesMonthNotifier(DateTime(2026, 9, 17)),
    ),
  ],
);

/// Opens the CSV dialog from the screen's toolbar.
Future<void> _openImport(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('sales-targets-import')));
  await tester.pumpAndSettle();
}

Future<void> _pumpTall(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(1400, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows sell-in vs target per SKU, scope and level', (
    tester,
  ) async {
    final repo = _FakeSalesTargetsRepository();
    await _pumpTall(tester, _app(repo));

    expect(repo.requestedMonths, ['2026-09']);
    expect(find.text('September 2026'), findsOneWidget);
    // Labelled as sell-in from orders, never as consumer sales.
    expect(find.text('Sell-in (orders) vs target'), findsOneWidget);
    expect(find.text('Cola 2L'), findsOneWidget);
    expect(find.text('Sell-in 50 · target 100 units'), findsOneWidget);
    expect(find.text('Cola 2L · North (territory)'), findsOneWidget);
    expect(find.text('75%'), findsWidgets);
    // A SKU with sell-in but no target is shown, as having no target.
    expect(find.text('Chips 125g'), findsOneWidget);
    expect(find.text('Sell-in 4 · target — units'), findsOneWidget);
    // Status chips set their label in capitals, so match without case.
    expect(
      find.textContaining(RegExp('^no target\$', caseSensitive: false)),
      findsOneWidget,
    );
    // Level figures: account-wide and territories, none for outlets.
    expect(find.text('50 of 100 units · 1 target'), findsOneWidget);
    expect(find.text('30 of 40 units · 1 target'), findsOneWidget);
    // Keys, not the word: "Outlets" is also a nav destination on the rail.
    expect(
      find.byKey(const ValueKey<String>('attainment-level-Account-wide')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('attainment-level-Territories')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('attainment-level-Outlets')),
      findsNothing,
    );
  });

  testWidgets('steps between months', (tester) async {
    final repo = _FakeSalesTargetsRepository();
    await _pumpTall(tester, _app(repo));

    await tester.tap(find.byKey(const ValueKey<String>('sales-month-next')));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('sales-month-prev')));
    await tester.tap(find.byKey(const ValueKey<String>('sales-month-prev')));
    await tester.pumpAndSettle();
    expect(find.text('August 2026'), findsOneWidget);
    expect(repo.requestedMonths, ['2026-09', '2026-10', '2026-08']);
  });

  testWidgets('shows an error state with a retry when loading fails', (
    tester,
  ) async {
    await _pumpTall(tester, _app(_ThrowingSalesTargetsRepository()));

    expect(find.textContaining('Failed to load sales targets'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    // Nothing to target without the SKU list, so no add button.
    expect(
      find.byKey(const ValueKey<String>('sales-target-add')),
      findsNothing,
    );
  });

  testWidgets('sets a target on a SKU for the picked month', (tester) async {
    final repo = _FakeSalesTargetsRepository();
    await _pumpTall(tester, _app(repo));

    await tester.tap(find.byKey(const ValueKey<String>('set-target-chips')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('target-units')),
      '25',
    );
    await tester.tap(find.byKey(const ValueKey<String>('target-save')));
    await tester.pumpAndSettle();

    expect(repo.upserts, [
      {
        'skuId': 'chips',
        'month': '2026-09',
        'targetUnits': 25,
        'territoryId': null,
        'outletId': null,
      },
    ]);
    expect(find.byKey(const ValueKey<String>('target-save')), findsNothing);
  });

  testWidgets('editing a territory target keeps its scope', (tester) async {
    final repo = _FakeSalesTargetsRepository();
    await _pumpTall(tester, _app(repo));

    await tester.tap(
      find.byKey(const ValueKey<String>('edit-target-t-cola-north')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Edit sales target'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey<String>('target-units')),
      '45',
    );
    await tester.tap(find.byKey(const ValueKey<String>('target-save')));
    await tester.pumpAndSettle();

    expect(repo.upserts.single, {
      'skuId': 'cola',
      'month': '2026-09',
      'targetUnits': 45,
      'territoryId': 'north',
      'outletId': null,
    });
  });

  testWidgets('keeps the dialog open with the reason when a save is refused', (
    tester,
  ) async {
    final repo = _FakeSalesTargetsRepository(
      upsertError: _refusal(404, 'SKU not found'),
    );
    await _pumpTall(tester, _app(repo));

    await tester.tap(find.byKey(const ValueKey<String>('set-target-chips')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('target-units')),
      '25',
    );
    await tester.tap(find.byKey(const ValueKey<String>('target-save')));
    await tester.pumpAndSettle();

    expect(find.text('SKU not found'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('target-save')), findsOneWidget);
  });

  testWidgets('refuses a non-numeric target before calling the server', (
    tester,
  ) async {
    final repo = _FakeSalesTargetsRepository();
    await _pumpTall(tester, _app(repo));

    await tester.tap(find.byKey(const ValueKey<String>('set-target-chips')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('target-units')),
      'lots',
    );
    await tester.tap(find.byKey(const ValueKey<String>('target-save')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a whole number of units'), findsOneWidget);
    expect(repo.upserts, isEmpty);
  });

  testWidgets('removes a target', (tester) async {
    final repo = _FakeSalesTargetsRepository();
    await _pumpTall(tester, _app(repo));

    await tester.tap(
      find.byKey(const ValueKey<String>('delete-target-t-cola')),
    );
    await tester.pumpAndSettle();

    expect(repo.deleted, ['t-cola']);
  });

  testWidgets('previews a CSV with its row errors, then applies it', (
    tester,
  ) async {
    final repo = _FakeSalesTargetsRepository();
    await _pumpTall(tester, _app(repo));

    await tester.tap(
      find.byKey(const ValueKey<String>('sales-targets-import')),
    );
    await tester.pumpAndSettle();

    const csv =
        'month,sku,targetUnits\n2026-09,Cola 2L,120\n2026-9,Chips 125g,10';
    await tester.enterText(
      find.byKey(const ValueKey<String>('csv-input')),
      csv,
    );
    await tester.pump();

    // Nothing to apply until a preview has run.
    FilledButton apply() => tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('csv-apply')),
    );
    expect(apply().onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey<String>('csv-preview')));
    await tester.pumpAndSettle();

    expect(repo.imports, [(csv, true)]);
    expect(
      find.text('2 ready · 1 with errors · would create 1, update 1'),
      findsOneWidget,
    );
    expect(
      find.text('Row 3 · month: "2026-9" is not a month; use YYYY-MM'),
      findsOneWidget,
    );
    expect(find.text('Apply 2 rows'), findsOneWidget);
    expect(apply().onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey<String>('csv-apply')));
    await tester.pumpAndSettle();

    expect(repo.imports, [(csv, true), (csv, false)]);
    expect(find.byKey(const ValueKey<String>('csv-input')), findsNothing);
    expect(
      find.text('Targets saved: 1 created, 1 updated · 1 rows skipped'),
      findsOneWidget,
    );
  });

  testWidgets('editing the CSV after a preview requires a fresh preview', (
    tester,
  ) async {
    final repo = _FakeSalesTargetsRepository();
    await _pumpTall(tester, _app(repo));

    await tester.tap(
      find.byKey(const ValueKey<String>('sales-targets-import')),
    );
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey<String>('csv-input'));
    await tester.enterText(input, 'month,sku,targetUnits\n2026-09,Cola 2L,1');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('csv-preview')));
    await tester.pumpAndSettle();

    await tester.enterText(input, 'month,sku,targetUnits\n2026-09,Cola 2L,2');
    await tester.pump();

    final apply = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('csv-apply')),
    );
    expect(apply.onPressed, isNull);
  });

  testWidgets('shows a file-level CSV refusal in the dialog', (tester) async {
    final repo = _FakeSalesTargetsRepository(
      previewError: _refusal(
        400,
        'The header row must include month, sku, targetUnits (missing: targetUnits)',
      ),
    );
    await _pumpTall(tester, _app(repo));

    await tester.tap(
      find.byKey(const ValueKey<String>('sales-targets-import')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('csv-input')),
      'month,sku\n2026-09,Cola 2L',
    );
    await tester.pump();
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

  testWidgets('light: level figures and the CSV preview are glass tiles', (
    tester,
  ) async {
    await _pumpTall(
      tester,
      _app(_FakeSalesTargetsRepository(), theme: AppTheme.light()),
    );

    final level = tester.widget<GlassPane>(
      find.byKey(const ValueKey<String>('attainment-level-Account-wide')),
    );
    expect(level.kind, GlassKind.tile);
    expect(level.blur, isFalse);
  });

  testWidgets('uploads a chosen file: previews first, applies what was shown', (
    tester,
  ) async {
    final repo = _FakeSalesTargetsRepository();
    final picker = _FakeCsvPicker(file: _pickedCsv);
    await _pumpTall(tester, _app(repo, picker: picker));
    await _openImport(tester);

    // Pasting is still there as the fallback, until a file is chosen.
    expect(find.byKey(const ValueKey<String>('csv-input')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('csv-choose-file')));
    await tester.pumpAndSettle();

    expect(picker.calls, 1);
    expect(find.text('september-targets.csv'), findsOneWidget);
    // The paste box goes away: only one of the two can be about to upload.
    expect(find.byKey(const ValueKey<String>('csv-input')), findsNothing);

    FilledButton apply() => tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('csv-apply')),
    );
    expect(apply().onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey<String>('csv-preview')));
    await tester.pumpAndSettle();

    expect(repo.imports, [(_pickedCsv.contents, true)]);
    expect(
      find.text('2 ready · 1 with errors · would create 1, update 1'),
      findsOneWidget,
    );
    expect(
      find.text('Row 3 · month: "2026-9" is not a month; use YYYY-MM'),
      findsOneWidget,
    );
    expect(apply().onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey<String>('csv-apply')));
    await tester.pumpAndSettle();

    // Applied exactly the text that was previewed — the file is never re-read
    // between the preview and the apply.
    expect(repo.imports, [
      (_pickedCsv.contents, true),
      (_pickedCsv.contents, false),
    ]);
    expect(
      find.text('Targets saved: 1 created, 1 updated · 1 rows skipped'),
      findsOneWidget,
    );
  });

  testWidgets(
    'removing the file restores the paste box and retires the preview',
    (tester) async {
      final repo = _FakeSalesTargetsRepository();
      await _pumpTall(
        tester,
        _app(repo, picker: _FakeCsvPicker(file: _pickedCsv)),
      );
      await _openImport(tester);
      await tester.tap(find.byKey(const ValueKey<String>('csv-choose-file')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('csv-preview')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('csv-clear-file')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('csv-input')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('csv-file-name')), findsNothing);
      // Nothing can be applied any more: what was shown is no longer the source.
      final apply = tester.widget<FilledButton>(
        find.byKey(const ValueKey<String>('csv-apply')),
      );
      expect(apply.onPressed, isNull);
      expect(repo.imports, [(_pickedCsv.contents, true)]);
    },
  );

  testWidgets('cancelling the chooser leaves the pasted CSV alone', (
    tester,
  ) async {
    final repo = _FakeSalesTargetsRepository();
    final picker = _FakeCsvPicker();
    await _pumpTall(tester, _app(repo, picker: picker));
    await _openImport(tester);
    await tester.enterText(
      find.byKey(const ValueKey<String>('csv-input')),
      'month,sku,targetUnits\n2026-09,Cola 2L,1',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey<String>('csv-choose-file')));
    await tester.pumpAndSettle();

    expect(picker.calls, 1);
    expect(find.byKey(const ValueKey<String>('csv-input')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('csv-file-name')), findsNothing);
    expect(repo.imports, isEmpty);
  });

  testWidgets('says why a file could not be taken, and offers paste still', (
    tester,
  ) async {
    await _pumpTall(
      tester,
      _app(
        _FakeSalesTargetsRepository(),
        picker: _FakeCsvPicker(
          error: const CsvFileException(
            'That file is too large to be a list of targets. '
            'Choose a CSV under 8 MB.',
          ),
        ),
      ),
    );
    await _openImport(tester);
    await tester.tap(find.byKey(const ValueKey<String>('csv-choose-file')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('csv-file-error')),
      findsOneWidget,
    );
    expect(find.textContaining('under 8 MB'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('csv-input')), findsOneWidget);
  });

  group('dashboard panel', () {
    Widget panel(SalesTargetsRepository repo) => routedApp(
      const SingleChildScrollView(child: SalesAttainmentPanel()),
      overrides: [salesTargetsRepositoryProvider.overrideWithValue(repo)],
    );

    testWidgets('sends no month and labels the figure with the one it got', (
      tester,
    ) async {
      final repo = _FakeSalesTargetsRepository();
      await _pumpTall(tester, panel(repo));

      // Which month "now" is belongs to the account's timezone, so the panel
      // asks for no month and names the one the server answered for (#339).
      expect(repo.requestedMonths, [null]);
      expect(find.text('Sell-in vs target'), findsOneWidget);
      expect(
        find.textContaining('Sell-in (orders) · September 2026'),
        findsOneWidget,
      );
      expect(find.text('50%'), findsOneWidget);
      // Both levels are under 80%: account-wide 50% and territories 75%.
      expect(
        find.textContaining(RegExp('^behind\$', caseSensitive: false)),
        findsNWidgets(2),
      );
      expect(find.text('75%'), findsOneWidget);
    });

    testWidgets('says so when no targets are set', (tester) async {
      await _pumpTall(
        tester,
        panel(
          _FakeSalesTargetsRepository(
            report: const SalesAttainmentReport(
              month: '2026-09',
              timeZone: 'UTC',
              skus: [],
            ),
          ),
        ),
      );

      expect(find.text('No sales targets for September 2026'), findsOneWidget);
    });
  });

  test('attainment formatting and levels', () {
    expect(formatAttainment(null), '—');
    expect(formatAttainment(50), '50%');
    expect(formatAttainment(33.33), '33.3%');
    expect(attainmentLevel(null).name, 'neutral');
    expect(attainmentLevel(100).name, 'good');
    expect(attainmentLevel(85).name, 'warning');
    expect(attainmentLevel(40).name, 'critical');
    expect(salesMonthKey(DateTime(2026, 13)), '2027-01');
    // The dashboard only learns its month from the wire, so the key has to
    // read back as a label — and anything that is not a key is left alone.
    expect(salesMonthLabelFromKey('2026-09'), 'September 2026');
    expect(salesMonthLabelFromKey('2026-13'), '2026-13');
    expect(salesMonthLabelFromKey(''), '');
  });
}
