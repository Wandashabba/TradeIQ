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
  String? lastPath;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastPath = options.path;
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

  group('CampaignRoi.fromJson', () {
    Map<String, dynamic> body({
      Object? spend = 10000,
      Object? roiPct = 25.5,
      Object? unmeasurable,
    }) => {
      'campaignId': 'c1',
      'outletsTotal': 12,
      'window': {
        'from': '2026-06-01T00:00:00.000Z',
        'to': '2026-07-01T00:00:00.000Z',
      },
      'baselineWindow': {
        'from': '2026-05-02T00:00:00.000Z',
        'to': '2026-06-01T00:00:00.000Z',
      },
      'orderCount': {'attributed': 40, 'baseline': 31},
      'attributedRevenue': 42550.5,
      'baselineRevenue': 30000,
      'incrementalRevenue': 12550.5,
      'spend': spend,
      'roiPct': roiPct,
      'unmeasurable': unmeasurable,
    };

    test('parses every field of a measured return', () {
      final roi = CampaignRoi.fromJson(body());

      expect(roi.campaignId, 'c1');
      expect(roi.outletsTotal, 12);
      expect(roi.window.from, DateTime.utc(2026, 6, 1));
      expect(roi.window.to, DateTime.utc(2026, 7, 1));
      expect(roi.baselineWindow.from, DateTime.utc(2026, 5, 2));
      expect(roi.baselineWindow.to, DateTime.utc(2026, 6, 1));
      expect(roi.baselineWindow.days, 30);
      expect(roi.attributedOrders, 40);
      expect(roi.baselineOrders, 31);
      expect(roi.attributedRevenue, 42550.5);
      expect(roi.baselineRevenue, 30000.0);
      expect(roi.incrementalRevenue, 12550.5);
      expect(roi.spend, 10000.0);
      expect(roi.roiPct, 25.5);
      expect(roi.unmeasurable, isNull);
    });

    test('no budget: roiPct stays null — not zero — with its reason', () {
      final roi = CampaignRoi.fromJson(
        body(spend: null, roiPct: null, unmeasurable: 'no_budget'),
      );

      expect(roi.spend, isNull);
      expect(roi.roiPct, isNull);
      expect(roi.unmeasurable, RoiUnmeasurable.noBudget);
    });

    test('zero budget parses its own reason', () {
      final roi = CampaignRoi.fromJson(
        body(spend: 0, roiPct: null, unmeasurable: 'zero_budget'),
      );

      expect(roi.spend, 0.0);
      expect(roi.roiPct, isNull);
      expect(roi.unmeasurable, RoiUnmeasurable.zeroBudget);
    });

    test('a null roiPct with an unknown or missing reason is still '
        'unmeasurable', () {
      expect(
        CampaignRoi.fromJson(body(roiPct: null, unmeasurable: 'new_reason'))
            .unmeasurable,
        RoiUnmeasurable.unknown,
      );
      expect(
        CampaignRoi.fromJson(body(roiPct: null)).unmeasurable,
        RoiUnmeasurable.unknown,
      );
    });
  });

  group('DioCampaignsRepository.getRoi', () {
    late HttpClientAdapter originalAdapter;

    setUp(() => originalAdapter = dio.httpClientAdapter);
    tearDown(() => dio.httpClientAdapter = originalAdapter);

    test('GETs /campaigns/:id/roi and parses a negative return', () async {
      final adapter = _RecordingAdapter(
        '{"campaignId": "c9", "outletsTotal": 3, '
        '"window": {"from": "2026-06-01T00:00:00.000Z", '
        '"to": "2026-06-08T00:00:00.000Z"}, '
        '"baselineWindow": {"from": "2026-05-25T00:00:00.000Z", '
        '"to": "2026-06-01T00:00:00.000Z"}, '
        '"orderCount": {"attributed": 2, "baseline": 5}, '
        '"attributedRevenue": 1000, "baselineRevenue": 2500, '
        '"incrementalRevenue": -1500, "spend": 500, "roiPct": -400, '
        '"unmeasurable": null}',
      );
      dio.httpClientAdapter = adapter;

      final roi = await DioCampaignsRepository().getRoi('c9');

      expect(adapter.lastPath, '/campaigns/c9/roi');
      expect(roi.campaignId, 'c9');
      expect(roi.baselineWindow.days, 7);
      expect(roi.incrementalRevenue, -1500.0);
      expect(roi.roiPct, -400.0);
      expect(roi.unmeasurable, isNull);
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
