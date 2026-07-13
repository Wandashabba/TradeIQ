import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/campaigns/data/campaigns_repository.dart';
import 'package:tradeiq_app/features/campaigns/presentation/campaigns_screen.dart';

import '../../helpers/routed_app.dart';

const _campaignA = Campaign(
  id: 'c1',
  name: 'Summer Push',
  status: 'active',
  startDate: '2026-06-01',
  endDate: '2026-08-31',
  outletCount: 12,
  objective: 'visibility',
  budget: 15000,
);

const _campaignB = Campaign(
  id: 'c2',
  name: 'Winter Push',
  status: 'draft',
  startDate: '2026-01-01',
  endDate: '2026-03-31',
  outletCount: 0,
);

const _compliance = CampaignCompliance(
  outletsTotal: 12,
  outletsVisited: 9,
  visitCoverageRate: 75,
  avgPlanogramCompliancePct: 88.5,
  avgAbsPriceDeviationPct: 3.2,
  promoComplianceRate: 91,
);

class _FakeCampaignsRepository implements CampaignsRepository {
  @override
  Future<List<Campaign>> listCampaigns() async => const [_campaignA, _campaignB];

  @override
  Future<CampaignCompliance> getCompliance(String id) async => _compliance;

  @override
  Future<Campaign> createCampaign({
    required String name,
    required String startDate,
    required String endDate,
    String? objective,
    double? budget,
    List<String>? outletIds,
  }) async =>
      _campaignA;

  @override
  Future<Campaign> updateCampaign(
    String id, {
    String? name,
    String? objective,
    double? budget,
    String? status,
  }) async =>
      _campaignA;
}

class _ThrowingCampaignsRepository implements CampaignsRepository {
  @override
  Future<List<Campaign>> listCampaigns() async => throw Exception('boom');

  @override
  Future<CampaignCompliance> getCompliance(String id) async =>
      throw Exception('boom');

  @override
  Future<Campaign> createCampaign({
    required String name,
    required String startDate,
    required String endDate,
    String? objective,
    double? budget,
    List<String>? outletIds,
  }) async =>
      throw Exception('boom');

  @override
  Future<Campaign> updateCampaign(
    String id, {
    String? name,
    String? objective,
    double? budget,
    String? status,
  }) async =>
      throw Exception('boom');
}

Widget _app(CampaignsRepository repo) => routedApp(
      const CampaignsScreen(),
      overrides: [
        campaignsRepositoryProvider.overrideWithValue(repo),
      ],
    );

void main() {
  testWidgets('renders campaign names once loaded', (tester) async {
    await tester.pumpWidget(_app(_FakeCampaignsRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Summer Push'), findsOneWidget);
    expect(find.text('Winter Push'), findsOneWidget);
  });

  testWidgets('tapping a campaign shows its compliance rollup',
      (tester) async {
    await tester.pumpWidget(_app(_FakeCampaignsRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('campaign-c1')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('compliance-c1')),
      findsOneWidget,
    );
  });

  testWidgets('shows an error message when loading fails', (tester) async {
    await tester.pumpWidget(_app(_ThrowingCampaignsRepository()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Failed to load campaigns'),
      findsOneWidget,
    );
  });
}
