import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/api_client.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/campaigns/data/campaigns_repository.dart';

/// A fake HTTP layer that returns a canned body, following the pattern in
/// `test/features/agents/agents_repository_test.dart`.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.body);
  final String body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

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

  group('DioCampaignsRepository.listCampaigns', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = dio.httpClientAdapter;
    });

    tearDown(() {
      dio.httpClientAdapter = originalAdapter;
    });

    test('parses the {data, nextCursor} envelope into a PaginatedResponse',
        () async {
      dio.httpClientAdapter = _RecordingAdapter(
        '{"data": [{"id": "c1", "name": "Summer Push", "status": "active", '
        '"startDate": "2026-06-01", "endDate": "2026-08-31", '
        '"_count": {"outlets": 12}}], '
        '"nextCursor": "cursor-1"}',
      );

      final page = await DioCampaignsRepository().listCampaigns();

      expect(page, isA<PaginatedResponse<Campaign>>());
      expect(page.data, hasLength(1));
      expect(page.data.first.id, 'c1');
      expect(page.nextCursor, 'cursor-1');
    });
  });
}
