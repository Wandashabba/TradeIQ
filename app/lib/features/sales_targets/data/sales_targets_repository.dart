import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// What the "actual" in every sales-target figure is (#119): units ordered
/// through TradeIQ. It is sell-in, never consumer sell-out — there is no POS
/// feed — so every surface labels it with exactly this.
const sellInLabel = 'Sell-in (orders)';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// `YYYY-MM`, the month format the API speaks.
String salesMonthKey(DateTime month) =>
    '${month.year.toString().padLeft(4, '0')}-'
    '${month.month.toString().padLeft(2, '0')}';

/// "September 2026".
String salesMonthLabel(DateTime month) =>
    '${_monthNames[month.month - 1]} ${month.year}';

double? _optionalDouble(Object? value) => (value as num?)?.toDouble();
int _int(Object? value) => (value as num?)?.toInt() ?? 0;

/// A territory or outlet a target is scoped to.
class SalesTargetRef {
  const SalesTargetRef({
    required this.id,
    required this.name,
    required this.code,
  });

  final String id;
  final String name;
  final String code;

  static SalesTargetRef? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return SalesTargetRef(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
    );
  }
}

/// A territory- or outlet-scoped target and the sell-in measured against it.
class ScopedAttainment {
  const ScopedAttainment({
    required this.targetId,
    required this.scope,
    required this.targetUnits,
    required this.actualUnits,
    this.territory,
    this.outlet,
    this.attainmentPct,
  });

  final String targetId;

  /// `territory` or `outlet`.
  final String scope;
  final SalesTargetRef? territory;
  final SalesTargetRef? outlet;
  final int targetUnits;
  final int actualUnits;
  final double? attainmentPct;

  /// "North (territory)".
  String get scopeLabel =>
      '${territory?.name ?? outlet?.name ?? 'Unknown'} ($scope)';

  factory ScopedAttainment.fromJson(Map<String, dynamic> json) =>
      ScopedAttainment(
        targetId: json['targetId'] as String,
        scope: json['scope'] as String,
        territory: SalesTargetRef.fromJson(json['territory']),
        outlet: SalesTargetRef.fromJson(json['outlet']),
        targetUnits: _int(json['targetUnits']),
        actualUnits: _int(json['actualUnits']),
        attainmentPct: _optionalDouble(json['attainmentPct']),
      );
}

/// One SKU's month: its account-wide target (if any), all its sell-in, and any
/// scoped targets beneath it.
class SkuAttainment {
  const SkuAttainment({
    required this.skuId,
    required this.skuName,
    required this.category,
    required this.actualUnits,
    this.targetId,
    this.targetUnits,
    this.attainmentPct,
    this.scoped = const [],
  });

  final String skuId;
  final String skuName;
  final String category;
  final String? targetId;
  final int? targetUnits;
  final int actualUnits;
  final double? attainmentPct;
  final List<ScopedAttainment> scoped;

  factory SkuAttainment.fromJson(Map<String, dynamic> json) => SkuAttainment(
    skuId: json['skuId'] as String,
    skuName: json['skuName'] as String? ?? '',
    category: json['category'] as String? ?? '',
    targetId: json['targetId'] as String?,
    targetUnits: (json['targetUnits'] as num?)?.toInt(),
    actualUnits: _int(json['actualUnits']),
    attainmentPct: _optionalDouble(json['attainmentPct']),
    scoped: [
      for (final s in (json['scoped'] as List?) ?? const [])
        if (s is Map<String, dynamic>) ScopedAttainment.fromJson(s),
    ],
  );
}

/// Totals for one scope level. Levels are never summed together on the
/// server, because a territory target counts orders an account-wide one does.
class AttainmentLevel {
  const AttainmentLevel({
    required this.targets,
    required this.targetUnits,
    required this.actualUnits,
    this.attainmentPct,
  });

  final int targets;
  final int targetUnits;
  final int actualUnits;
  final double? attainmentPct;

  static const empty = AttainmentLevel(
    targets: 0,
    targetUnits: 0,
    actualUnits: 0,
  );

  factory AttainmentLevel.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return empty;
    return AttainmentLevel(
      targets: _int(json['targets']),
      targetUnits: _int(json['targetUnits']),
      actualUnits: _int(json['actualUnits']),
      attainmentPct: _optionalDouble(json['attainmentPct']),
    );
  }
}

/// GET /sales-targets/attainment.
class SalesAttainmentReport {
  const SalesAttainmentReport({
    required this.month,
    required this.timeZone,
    required this.skus,
    this.metricLabel = sellInLabel,
    this.client = AttainmentLevel.empty,
    this.territory = AttainmentLevel.empty,
    this.outlet = AttainmentLevel.empty,
    this.truncated = false,
  });

  final String month;
  final String timeZone;
  final String metricLabel;
  final List<SkuAttainment> skus;
  final AttainmentLevel client;
  final AttainmentLevel territory;
  final AttainmentLevel outlet;
  final bool truncated;

  bool get hasTargets =>
      client.targets + territory.targets + outlet.targets > 0;

  factory SalesAttainmentReport.fromJson(Map<String, dynamic> json) {
    final summary = (json['summary'] as Map<String, dynamic>?) ?? const {};
    return SalesAttainmentReport(
      month: json['month'] as String? ?? '',
      timeZone: json['timeZone'] as String? ?? '',
      metricLabel: json['metricLabel'] as String? ?? sellInLabel,
      skus: [
        for (final s in (json['skus'] as List?) ?? const [])
          if (s is Map<String, dynamic>) SkuAttainment.fromJson(s),
      ],
      client: AttainmentLevel.fromJson(summary['client']),
      territory: AttainmentLevel.fromJson(summary['territory']),
      outlet: AttainmentLevel.fromJson(summary['outlet']),
      truncated: json['truncated'] as bool? ?? false,
    );
  }
}

/// One problem with one CSV row.
class ImportRowError {
  const ImportRowError({required this.row, required this.message, this.column});

  final int row;
  final String? column;
  final String message;

  factory ImportRowError.fromJson(Map<String, dynamic> json) => ImportRowError(
    row: _int(json['row']),
    column: json['column'] as String?,
    message: json['message'] as String? ?? '',
  );
}

/// A valid CSV row, as it is (or would be) written.
class ImportPreviewRow {
  const ImportPreviewRow({
    required this.row,
    required this.skuName,
    required this.month,
    required this.scope,
    required this.targetUnits,
    required this.action,
    this.territoryCode,
    this.outletCode,
  });

  final int row;
  final String skuName;
  final String month;
  final String scope;
  final String? territoryCode;
  final String? outletCode;
  final int targetUnits;

  /// `create` or `update`.
  final String action;

  factory ImportPreviewRow.fromJson(Map<String, dynamic> json) =>
      ImportPreviewRow(
        row: _int(json['row']),
        skuName: json['skuName'] as String? ?? '',
        month: json['month'] as String? ?? '',
        scope: json['scope'] as String? ?? 'client',
        territoryCode: json['territoryCode'] as String?,
        outletCode: json['outletCode'] as String?,
        targetUnits: _int(json['targetUnits']),
        action: json['action'] as String? ?? 'create',
      );
}

/// POST /sales-targets/import.
class SalesTargetImportResult {
  const SalesTargetImportResult({
    required this.dryRun,
    required this.totalRows,
    required this.validRows,
    required this.invalidRows,
    required this.created,
    required this.updated,
    this.errors = const [],
    this.rows = const [],
  });

  final bool dryRun;
  final int totalRows;
  final int validRows;
  final int invalidRows;
  final List<ImportRowError> errors;
  final List<ImportPreviewRow> rows;
  final int created;
  final int updated;

  factory SalesTargetImportResult.fromJson(Map<String, dynamic> json) =>
      SalesTargetImportResult(
        dryRun: json['dryRun'] as bool? ?? false,
        totalRows: _int(json['totalRows']),
        validRows: _int(json['validRows']),
        invalidRows: _int(json['invalidRows']),
        created: _int(json['created']),
        updated: _int(json['updated']),
        errors: [
          for (final e in (json['errors'] as List?) ?? const [])
            if (e is Map<String, dynamic>) ImportRowError.fromJson(e),
        ],
        rows: [
          for (final r in (json['rows'] as List?) ?? const [])
            if (r is Map<String, dynamic>) ImportPreviewRow.fromJson(r),
        ],
      );
}

abstract class SalesTargetsRepository {
  /// GET /sales-targets/attainment?month=YYYY-MM
  Future<SalesAttainmentReport> attainment(String month);

  /// PUT /sales-targets — creates the target for this SKU, month and scope,
  /// or replaces its units. At most one of [territoryId] / [outletId].
  Future<void> upsert({
    required String skuId,
    required String month,
    required int targetUnits,
    String? territoryId,
    String? outletId,
  });

  /// DELETE /sales-targets/:id
  Future<void> delete(String id);

  /// POST /sales-targets/import — [dryRun] validates and previews only.
  Future<SalesTargetImportResult> importCsv(String csv, {required bool dryRun});
}

class DioSalesTargetsRepository implements SalesTargetsRepository {
  @override
  Future<SalesAttainmentReport> attainment(String month) async {
    final response = await dio.get(
      '/sales-targets/attainment',
      queryParameters: {'month': month},
    );
    return SalesAttainmentReport.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<void> upsert({
    required String skuId,
    required String month,
    required int targetUnits,
    String? territoryId,
    String? outletId,
  }) async {
    await dio.put(
      '/sales-targets',
      data: {
        'skuId': skuId,
        'month': month,
        'targetUnits': targetUnits,
        'territoryId': territoryId,
        'outletId': outletId,
      },
    );
  }

  @override
  Future<void> delete(String id) async {
    await dio.delete('/sales-targets/$id');
  }

  @override
  Future<SalesTargetImportResult> importCsv(
    String csv, {
    required bool dryRun,
  }) async {
    final response = await dio.post(
      '/sales-targets/import',
      data: {'csv': csv, 'dryRun': dryRun},
    );
    return SalesTargetImportResult.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}

final salesTargetsRepositoryProvider = Provider<SalesTargetsRepository>(
  (ref) => DioSalesTargetsRepository(),
);

/// The month the Sales targets screen is looking at, as the first of that
/// month. Starts on the current month; [initial] exists for tests.
class SalesMonthNotifier extends Notifier<DateTime> {
  SalesMonthNotifier([this.initial]);

  final DateTime? initial;

  @override
  DateTime build() {
    final start = initial ?? DateTime.now();
    return DateTime(start.year, start.month);
  }

  void previous() => state = DateTime(state.year, state.month - 1);

  void next() => state = DateTime(state.year, state.month + 1);
}

final salesTargetsMonthProvider =
    NotifierProvider<SalesMonthNotifier, DateTime>(SalesMonthNotifier.new);

/// The picked month's actual-vs-target report.
final salesAttainmentProvider = FutureProvider<SalesAttainmentReport>((ref) {
  final month = ref.watch(salesTargetsMonthProvider);
  return ref
      .read(salesTargetsRepositoryProvider)
      .attainment(salesMonthKey(month));
});

/// The dashboard's figure: always this month, whatever month the Sales
/// targets screen was last left on.
///
/// "This month" is the device's calendar month; the server still counts the
/// month's days in the account's timezone, so only the first or last hours of
/// a month can disagree about which month that is.
final currentMonthAttainmentProvider = FutureProvider<SalesAttainmentReport>((
  ref,
) {
  return ref
      .read(salesTargetsRepositoryProvider)
      .attainment(salesMonthKey(DateTime.now()));
});
