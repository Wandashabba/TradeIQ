import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/api_client.dart';
import 'package:tradeiq_app/features/trends/data/trends_repository.dart';

/// Records the request and answers with a canned JSON body.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.body);
  final String body;
  RequestOptions? last;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

const _benchmarkBody = '''
{
  "metric": "perfectStore",
  "interval": "week",
  "unit": "percent",
  "target": null,
  "client": {
    "average": 40,
    "count": 5,
    "points": [
      {"period": "2026-03-02T00:00:00.000Z", "value": 25, "count": 4},
      {"period": "2026-03-09T00:00:00.000Z", "value": 100, "count": 1}
    ]
  },
  "unassigned": {"count": 1},
  "territories": [
    {
      "territoryId": "t-north", "territoryName": "North", "territoryCode": "tb-north",
      "average": 66.67, "count": 3,
      "points": [{"period": "2026-03-02T00:00:00.000Z", "value": 50, "count": 2}],
      "rank": 1, "deltaFromClient": 26.67, "position": "above"
    },
    {
      "territoryId": "t-south", "territoryName": "South", "territoryCode": "tb-south",
      "average": 0, "count": 1, "points": [],
      "rank": 2, "deltaFromClient": -40, "position": "below"
    },
    {
      "territoryId": "t-empty", "territoryName": "Empty", "territoryCode": "tb-empty",
      "average": null, "count": 0, "points": [],
      "rank": null, "deltaFromClient": null, "position": null
    }
  ]
}
''';

void main() {
  test('TrendPoint.fromJson parses period and coerces value to double', () {
    final point = TrendPoint.fromJson(const {
      'period': '2026-W27',
      'value': 42,
      'count': 5,
    });

    expect(point.period, '2026-W27');
    expect(point.value, 42.0);
    expect(point.value, isA<double>());
    expect(point.count, 5);
  });

  test('parsing the points list yields the right length and values', () {
    final payload = <String, dynamic>{
      'interval': 'week',
      'points': [
        {'period': '2026-W26', 'value': 10.5, 'count': 3},
        {'period': '2026-W27', 'value': 12, 'count': 4},
      ],
    };

    final points = (payload['points'] as List)
        .map((json) => TrendPoint.fromJson(json as Map<String, dynamic>))
        .toList();

    expect(points.length, 2);
    expect(points[0].period, '2026-W26');
    expect(points[0].value, 10.5);
    expect(points[1].period, '2026-W27');
    expect(points[1].value, 12.0);
  });

  group('benchmark', () {
    late HttpClientAdapter originalAdapter;

    setUp(() => originalAdapter = dio.httpClientAdapter);
    tearDown(() => dio.httpClientAdapter = originalAdapter);

    test('sends the metric with the shared query and parses the report',
        () async {
      final adapter = _RecordingAdapter(_benchmarkBody);
      dio.httpClientAdapter = adapter;

      final report = await DioTrendsRepository().benchmark(
        BenchmarkMetric.perfectStore,
        TrendQuery(
          interval: TrendInterval.day,
          from: DateTime.utc(2026, 3, 1),
        ),
      );

      expect(adapter.last!.path, '/trends/benchmark');
      expect(adapter.last!.queryParameters, {
        'interval': 'day',
        'from': '2026-03-01T00:00:00.000Z',
        'metric': 'perfectStore',
      });

      expect(report.metric, BenchmarkMetric.perfectStore);
      expect(report.isPercent, isTrue);
      expect(report.suffix, '%');
      expect(report.target, isNull);
      expect(report.unassignedCount, 1);
      expect(report.client.average, 40.0);
      expect(report.client.count, 5);
      expect(report.client.points.map((p) => p.count), [4, 1]);

      final [north, south, empty] = report.territories;
      expect(north.territoryId, 't-north');
      expect(north.territoryCode, 'tb-north');
      expect(north.average, 66.67);
      expect(north.rank, 1);
      expect(north.deltaFromClient, 26.67);
      expect(north.position, BenchmarkPosition.above);

      // A measured zero stays a zero …
      expect(south.average, 0.0);
      expect(south.count, 1);
      expect(south.position, BenchmarkPosition.below);

      // … and "nothing measured" stays null, never coerced to 0.
      expect(empty.average, isNull);
      expect(empty.count, 0);
      expect(empty.rank, isNull);
      expect(empty.deltaFromClient, isNull);
      expect(empty.position, isNull);
      expect(empty.points, isEmpty);
    });
  });

  test('scorecard reports carry the target and no percent suffix', () {
    final report = TerritoryBenchmarkReport.fromJson(const {
      'metric': 'scorecards',
      'unit': 'score',
      'target': {'value': 75, 'label': 'Green threshold'},
      'client': {'average': 64, 'count': 5, 'points': []},
      'unassigned': {'count': 0},
      'territories': [],
    });

    expect(report.metric, BenchmarkMetric.scorecards);
    expect(report.isPercent, isFalse);
    expect(report.suffix, '');
    expect(report.target, 75.0);
    expect(report.targetLabel, 'Green threshold');
    expect(report.territories, isEmpty);
  });

  test('sample counts read as words, singular and plural', () {
    expect(BenchmarkMetric.scorecards.samples(1), '1 scorecard');
    expect(BenchmarkMetric.perfectStore.samples(3), '3 scorecards');
    expect(BenchmarkMetric.availability.samples(1), '1 stock line');
    expect(BenchmarkMetric.shareOfShelf.samples(2), '2 visits with facings');
  });
}
