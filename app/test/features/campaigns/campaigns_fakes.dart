import 'dart:async';

import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/campaigns/data/campaigns_repository.dart';

/// Shared fixtures for the campaign screen tests.
///
/// Every failure is an `Error` and not a bare `Exception`, deliberately:
/// Riverpod 3's `defaultRetry` returns null for an `Error` and an exponential
/// backoff for anything else, so a fixture that throws `Exception('boom')`
/// makes the provider retry ten times over ~12 seconds and a widget test never
/// reaches the error branch at all.
StateError offline() => StateError('SocketException: api.tradeiq.co.za');

const campaignA = Campaign(
  id: 'c1',
  name: 'Summer Push',
  status: 'active',
  startDate: '2026-06-01',
  endDate: '2026-08-31',
  outletCount: 12,
  objective: 'visibility',
  budget: 15000,
);

const campaignB = Campaign(
  id: 'c2',
  name: 'Winter Push',
  status: 'draft',
  startDate: '2026-01-01',
  endDate: '2026-03-31',
  outletCount: 0,
);

const _defaultCompliance = CampaignCompliance(
  outletsTotal: 12,
  outletsVisited: 9,
  visitCoverageRate: 75,
  avgPlanogramCompliancePct: 88.5,
  avgAbsPriceDeviationPct: 3.2,
  promoComplianceRate: 91,
);

/// A campaign that launched and has not been visited yet.
///
/// This is what the server actually sends for one: `pct()` returns 0 on a zero
/// denominator and `mean()` returns 0 on an empty array
/// (`backend/src/lib/kpiMath.ts`), and `campaigns.service.ts` builds the
/// visibility and pricing row sets out of the visits — so four rates that were
/// computed over nothing arrive as four zeroes, indistinguishable on the wire
/// from a campaign where every store was audited and every planogram failed.
const unvisitedCompliance = CampaignCompliance(
  outletsTotal: 12,
  outletsVisited: 0,
  visitCoverageRate: 0,
  avgPlanogramCompliancePct: 0,
  avgAbsPriceDeviationPct: 0,
  promoComplianceRate: 0,
);

/// A campaign with no outlets at all: visit coverage is a division by zero.
const noOutletCompliance = CampaignCompliance(
  outletsTotal: 0,
  outletsVisited: 0,
  visitCoverageRate: 0,
  avgPlanogramCompliancePct: 0,
  avgAbsPriceDeviationPct: 0,
  promoComplianceRate: 0,
);

CampaignRoi roiOf({
  double attributed = 42550.5,
  double baseline = 30000,
  double? spend = 10000,
  double? roiPct = 25.5,
  String? unmeasurable,
}) => CampaignRoi.fromJson(<String, dynamic>{
  'campaignId': 'c1',
  'outletsTotal': 12,
  'window': <String, dynamic>{
    'from': '2026-06-01T00:00:00.000Z',
    'to': '2026-07-01T00:00:00.000Z',
  },
  'baselineWindow': <String, dynamic>{
    'from': '2026-05-02T00:00:00.000Z',
    'to': '2026-06-01T00:00:00.000Z',
  },
  'orderCount': <String, dynamic>{'attributed': 40, 'baseline': 31},
  'attributedRevenue': attributed,
  'baselineRevenue': baseline,
  'incrementalRevenue': attributed - baseline,
  'spend': spend,
  'roiPct': roiPct,
  'unmeasurable': unmeasurable,
});

class FakeCampaignsRepository implements CampaignsRepository {
  FakeCampaignsRepository({
    this.campaigns = const <Campaign>[campaignA, campaignB],
    CampaignRoi? roi,
    CampaignCompliance? compliance,
    this.listFailure,
    this.listPending = false,
    this.complianceFailure,
    this.compliancePending = false,
    this.roiFailure,
    this.roiPending = false,
    this.saveFailure,
    this.savePending = false,
  }) : roi = roi ?? roiOf(),
       compliance = compliance ?? _defaultCompliance;

  final List<Campaign> campaigns;
  final CampaignRoi roi;
  final CampaignCompliance compliance;
  final Object? listFailure;
  final bool listPending;
  final Object? complianceFailure;
  final bool compliancePending;
  final Object? roiFailure;
  final bool roiPending;
  final Object? saveFailure;
  final bool savePending;

  final List<String> calls = <String>[];
  Map<String, Object?>? created;
  Map<String, Object?>? updated;

  @override
  Future<PaginatedResponse<Campaign>> listCampaigns() async {
    if (listFailure != null) throw listFailure!;
    if (listPending) return Completer<PaginatedResponse<Campaign>>().future;
    return PaginatedResponse<Campaign>(data: campaigns, nextCursor: null);
  }

  @override
  Future<CampaignCompliance> getCompliance(String id) async {
    calls.add('compliance:$id');
    if (complianceFailure != null) throw complianceFailure!;
    if (compliancePending) return Completer<CampaignCompliance>().future;
    return compliance;
  }

  @override
  Future<CampaignRoi> getRoi(String id) async {
    calls.add('roi:$id');
    if (roiFailure != null) throw roiFailure!;
    if (roiPending) return Completer<CampaignRoi>().future;
    return roi;
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
    created = <String, Object?>{
      'name': name,
      'startDate': startDate,
      'endDate': endDate,
      'objective': objective,
      'budget': budget,
      'outletIds': outletIds,
    };
    calls.add('create');
    if (saveFailure != null) throw saveFailure!;
    if (savePending) return Completer<Campaign>().future;
    return campaignA;
  }

  @override
  Future<Campaign> updateCampaign(
    String id, {
    String? name,
    String? objective,
    double? budget,
    String? status,
  }) async {
    updated = <String, Object?>{
      'id': id,
      'name': name,
      'objective': objective,
      'budget': budget,
      'status': status,
    };
    calls.add('update:$id');
    if (saveFailure != null) throw saveFailure!;
    if (savePending) return Completer<Campaign>().future;
    return campaignA;
  }
}
