import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/campaigns/data/campaigns_repository.dart';

void main() {
  group('Campaign.fromJson', () {
    test('parses fields incl. _count.outlets and budget', () {
      final campaign = Campaign.fromJson(const {
        'id': 'c1',
        'name': 'Summer Push',
        'objective': 'visibility',
        'startDate': '2026-06-01',
        'endDate': '2026-08-31',
        'budget': 15000,
        'status': 'active',
        '_count': {'outlets': 12},
      });

      expect(campaign.id, 'c1');
      expect(campaign.name, 'Summer Push');
      expect(campaign.objective, 'visibility');
      expect(campaign.startDate, '2026-06-01');
      expect(campaign.endDate, '2026-08-31');
      expect(campaign.budget, 15000.0);
      expect(campaign.status, 'active');
      expect(campaign.outletCount, 12);
    });

    test('defaults outletCount to 0 and budget to null when absent', () {
      final campaign = Campaign.fromJson(const {
        'id': 'c2',
        'name': 'Winter Push',
        'startDate': '2026-01-01',
        'endDate': '2026-03-31',
        'status': 'draft',
      });

      expect(campaign.objective, isNull);
      expect(campaign.budget, isNull);
      expect(campaign.outletCount, 0);
    });
  });

  group('CampaignCompliance.fromJson', () {
    test('parses all metrics as doubles', () {
      final compliance = CampaignCompliance.fromJson(const {
        'outletsTotal': 20,
        'outletsVisited': 15,
        'visitCoverageRate': 75.0,
        'avgPlanogramCompliancePct': 88.5,
        'avgAbsPriceDeviationPct': 3.2,
        'promoComplianceRate': 91.0,
      });

      expect(compliance.outletsTotal, 20.0);
      expect(compliance.outletsVisited, 15.0);
      expect(compliance.visitCoverageRate, 75.0);
      expect(compliance.avgPlanogramCompliancePct, 88.5);
      expect(compliance.avgAbsPriceDeviationPct, 3.2);
      expect(compliance.promoComplianceRate, 91.0);
    });

    test('defaults missing metrics to 0', () {
      final compliance = CampaignCompliance.fromJson(const {});

      expect(compliance.outletsTotal, 0.0);
      expect(compliance.outletsVisited, 0.0);
      expect(compliance.visitCoverageRate, 0.0);
      expect(compliance.avgPlanogramCompliancePct, 0.0);
      expect(compliance.avgAbsPriceDeviationPct, 0.0);
      expect(compliance.promoComplianceRate, 0.0);
    });
  });
}
