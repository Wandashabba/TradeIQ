import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated_response.dart';

/// A campaign returned by GET /campaigns.
class Campaign {
  const Campaign({
    required this.id,
    required this.name,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.outletCount,
    this.objective,
    this.budget,
  });
  final String id;
  final String name;
  final String status;
  final String startDate;
  final String endDate;
  final int outletCount;
  final String? objective;
  final double? budget;

  factory Campaign.fromJson(Map<String, dynamic> json) => Campaign(
    id: json['id'] as String,
    name: json['name'] as String,
    status: json['status'] as String,
    startDate: json['startDate'] as String,
    endDate: json['endDate'] as String,
    outletCount:
        (json['_count'] as Map<String, dynamic>?)?['outlets'] as int? ?? 0,
    objective: json['objective'] as String?,
    budget: (json['budget'] as num?)?.toDouble(),
  );
}

/// The compliance rollup returned by GET /campaigns/:id/compliance.
class CampaignCompliance {
  const CampaignCompliance({
    required this.outletsTotal,
    required this.outletsVisited,
    required this.visitCoverageRate,
    required this.avgPlanogramCompliancePct,
    required this.avgAbsPriceDeviationPct,
    required this.promoComplianceRate,
  });
  final double outletsTotal;
  final double outletsVisited;
  final double visitCoverageRate;
  final double avgPlanogramCompliancePct;
  final double avgAbsPriceDeviationPct;
  final double promoComplianceRate;

  factory CampaignCompliance.fromJson(Map<String, dynamic> json) =>
      CampaignCompliance(
        outletsTotal: (json['outletsTotal'] as num?)?.toDouble() ?? 0,
        outletsVisited: (json['outletsVisited'] as num?)?.toDouble() ?? 0,
        visitCoverageRate: (json['visitCoverageRate'] as num?)?.toDouble() ?? 0,
        avgPlanogramCompliancePct:
            (json['avgPlanogramCompliancePct'] as num?)?.toDouble() ?? 0,
        avgAbsPriceDeviationPct:
            (json['avgAbsPriceDeviationPct'] as num?)?.toDouble() ?? 0,
        promoComplianceRate:
            (json['promoComplianceRate'] as num?)?.toDouble() ?? 0,
      );
}

/// Why a campaign's return has no percentage. Mirrors the backend's
/// `unmeasurable` reason on GET /campaigns/:id/roi.
enum RoiUnmeasurable {
  /// No budget recorded — there is no spend to return on.
  noBudget,

  /// A budget of exactly zero — a division by zero, not a measurement.
  zeroBudget,

  /// A reason this client does not recognise yet. Still unmeasurable.
  unknown;

  static RoiUnmeasurable? fromJson(Object? raw) => switch (raw) {
    null => null,
    'no_budget' => RoiUnmeasurable.noBudget,
    'zero_budget' => RoiUnmeasurable.zeroBudget,
    _ => RoiUnmeasurable.unknown,
  };
}

/// A `{from, to}` date window on the ROI response.
class RoiWindow {
  const RoiWindow({required this.from, required this.to});
  final DateTime from;
  final DateTime to;

  /// Whole days covered, rounded — the length the baseline is matched to.
  int get days => (to.difference(from).inHours / 24).round();

  factory RoiWindow.fromJson(Map<String, dynamic> json) => RoiWindow(
    from: DateTime.parse(json['from'] as String),
    to: DateTime.parse(json['to'] as String),
  );
}

/// The return returned by GET /campaigns/:id/roi: incremental SELL-IN against
/// spend.
///
/// [attributedRevenue] is what outlets ordered from the client during the
/// campaign — sell-in, not sell-through. It is not consumer sales and must not
/// be labelled as such. An order carries one campaign, so when campaigns
/// overlap each order counts toward one of them only.
class CampaignRoi {
  const CampaignRoi({
    required this.campaignId,
    required this.outletsTotal,
    required this.window,
    required this.baselineWindow,
    required this.attributedOrders,
    required this.baselineOrders,
    required this.attributedRevenue,
    required this.baselineRevenue,
    required this.incrementalRevenue,
    required this.spend,
    required this.roiPct,
    required this.unmeasurable,
  });

  final String campaignId;
  final int outletsTotal;
  final RoiWindow window;

  /// The equal-length window immediately before the campaign.
  final RoiWindow baselineWindow;
  final int attributedOrders;
  final int baselineOrders;
  final double attributedRevenue;
  final double baselineRevenue;

  /// attributed − baseline; negative when the campaign period sold in less.
  final double incrementalRevenue;

  /// The campaign budget. Null when none is recorded.
  final double? spend;

  /// Null — never zero — when the return cannot be measured; see
  /// [unmeasurable].
  final double? roiPct;
  final RoiUnmeasurable? unmeasurable;

  factory CampaignRoi.fromJson(Map<String, dynamic> json) {
    final orders = json['orderCount'] as Map<String, dynamic>? ?? const {};
    return CampaignRoi(
      campaignId: json['campaignId'] as String,
      outletsTotal: (json['outletsTotal'] as num?)?.toInt() ?? 0,
      window: RoiWindow.fromJson(json['window'] as Map<String, dynamic>),
      baselineWindow: RoiWindow.fromJson(
        json['baselineWindow'] as Map<String, dynamic>,
      ),
      attributedOrders: (orders['attributed'] as num?)?.toInt() ?? 0,
      baselineOrders: (orders['baseline'] as num?)?.toInt() ?? 0,
      attributedRevenue: (json['attributedRevenue'] as num?)?.toDouble() ?? 0,
      baselineRevenue: (json['baselineRevenue'] as num?)?.toDouble() ?? 0,
      incrementalRevenue: (json['incrementalRevenue'] as num?)?.toDouble() ?? 0,
      spend: (json['spend'] as num?)?.toDouble(),
      roiPct: (json['roiPct'] as num?)?.toDouble(),
      // A null percentage with no reason is still unmeasurable: never let it
      // fall through to a figure.
      unmeasurable:
          RoiUnmeasurable.fromJson(json['unmeasurable']) ??
          (json['roiPct'] == null ? RoiUnmeasurable.unknown : null),
    );
  }
}

abstract class CampaignsRepository {
  Future<PaginatedResponse<Campaign>> listCampaigns();
  Future<CampaignCompliance> getCompliance(String id);

  /// GET /campaigns/:id/roi — manager/admin.
  Future<CampaignRoi> getRoi(String id);

  /// POST /campaigns. Dates are ISO strings; [outletIds] seeds the initial
  /// outlet assignment. Requires a manager/admin session.
  Future<Campaign> createCampaign({
    required String name,
    required String startDate,
    required String endDate,
    String? objective,
    double? budget,
    List<String>? outletIds,
  });

  /// PATCH /campaigns/:id. Only name/objective/budget/status are editable —
  /// the backend does not accept date or outlet changes on update.
  Future<Campaign> updateCampaign(
    String id, {
    String? name,
    String? objective,
    double? budget,
    String? status,
  });
}

class DioCampaignsRepository implements CampaignsRepository {
  @override
  Future<PaginatedResponse<Campaign>> listCampaigns() async {
    final response = await dio.get('/campaigns');
    return PaginatedResponse<Campaign>.fromJson(
      response.data as Map<String, dynamic>,
      (e) => Campaign.fromJson(e as Map<String, dynamic>),
    );
  }

  @override
  Future<CampaignCompliance> getCompliance(String id) async {
    final response = await dio.get('/campaigns/$id/compliance');
    return CampaignCompliance.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<CampaignRoi> getRoi(String id) async {
    final response = await dio.get('/campaigns/$id/roi');
    return CampaignRoi.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Campaign> createCampaign({
    required String name,
    required String startDate,
    required String endDate,
    String? objective,
    double? budget,
    List<String>? outletIds,
  }) async {
    final response = await dio.post(
      '/campaigns',
      data: {
        'name': name,
        'startDate': startDate,
        'endDate': endDate,
        'objective': ?objective,
        'budget': ?budget,
        if (outletIds != null && outletIds.isNotEmpty) 'outletIds': outletIds,
      },
    );
    return Campaign.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Campaign> updateCampaign(
    String id, {
    String? name,
    String? objective,
    double? budget,
    String? status,
  }) async {
    final response = await dio.patch(
      '/campaigns/$id',
      data: {
        'name': ?name,
        'objective': ?objective,
        'budget': ?budget,
        'status': ?status,
      },
    );
    return Campaign.fromJson(response.data as Map<String, dynamic>);
  }
}

final campaignsRepositoryProvider = Provider<CampaignsRepository>(
  (ref) => DioCampaignsRepository(),
);

// The provider exposes the FIRST PAGE as a plain list: the campaigns screen
// wants the current campaigns, not the whole history, and "load more" UI is
// deliberately out of scope for the pagination sweep (see the spec).
// `nextCursor` is available on the repository for any screen that later needs
// to page; this provider intentionally drops it.
final campaignsListProvider = FutureProvider<List<Campaign>>((ref) async {
  final page = await ref.read(campaignsRepositoryProvider).listCampaigns();
  return page.data;
});
