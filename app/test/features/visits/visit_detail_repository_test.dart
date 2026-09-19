import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/visits/data/visit_detail_repository.dart';

/// A fake HTTP layer returning one canned status and body, recording the path.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);
  final int status;
  final String body;
  String? path;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    path = options.path;
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

const _fullJson = '''
{
  "id": "v1",
  "status": "submitted",
  "outlet": {"id": "o1", "name": "Spar Rosebank", "code": "SPR-001", "channelType": "supermarket"},
  "agent": {"id": "a1", "email": "thandi@acme.test"},
  "checkinTs": "2026-09-14T07:00:00.000Z",
  "submittedAtClient": "2026-09-14T07:14:30.000Z",
  "geofence": {"pass": true, "distanceM": 44.5},
  "score": {
    "weightedTotal": 55.48, "ratingBand": "red", "target": 85,
    "scoredAt": "2026-09-14T07:15:00.000Z",
    "dimensions": [
      {"key": "availability", "score": 50},
      {"key": "competitive", "score": null}
    ]
  },
  "sections": [
    {"key": "stock", "count": 2, "flagged": 1, "findings": ["1 of 2 SKUs out of stock"], "truncated": false},
    {"key": "visibility", "count": 0, "flagged": 0, "findings": [], "truncated": false}
  ],
  "photos": {"total": 3, "items": [
    {"id": "p1", "section": "visibility", "timestamp": "2026-09-14T07:05:00.000Z", "thumbnailUrl": "/photos/p1/thumbnail"}
  ]},
  "fraud": {"riskScore": 20, "signals": [
    {"code": "geofence_distance", "detail": "Check-in was 44.5m from the outlet", "weight": 20}
  ]}
}
''';

void main() {
  test('parses the full review payload', () async {
    final adapter = _Adapter(200, _fullJson);
    final repo = DioVisitDetailRepository(
      client: Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = adapter,
    );

    final d = await repo.fetch('v1');

    expect(adapter.path, '/visits/v1');
    expect(d.id, 'v1');
    expect(d.isDraft, isFalse);
    expect(d.outlet.name, 'Spar Rosebank');
    expect(d.outlet.code, 'SPR-001');
    expect(d.agent.email, 'thandi@acme.test');
    expect(d.checkinTs, DateTime.utc(2026, 9, 14, 7));
    expect(d.submittedAtClient, DateTime.utc(2026, 9, 14, 7, 14, 30));
    expect(d.dwellMinutes, 14);
    expect(d.geofencePass, isTrue);
    expect(d.distanceM, 44.5);

    expect(d.score!.weightedTotal, 55.48);
    expect(d.score!.ratingBand, 'red');
    expect(d.score!.target, 85);
    expect(d.score!.dimensions.first.score, 50);
    // Not measured stays null, never zero.
    expect(d.score!.dimensions.last.key, 'competitive');
    expect(d.score!.dimensions.last.score, isNull);

    expect(d.sections, hasLength(2));
    expect(d.sections.first.key, 'stock');
    expect(d.sections.first.flagged, 1);
    expect(d.sections.first.findings, ['1 of 2 SKUs out of stock']);

    expect(d.photoTotal, 3);
    expect(d.photos.single.id, 'p1');
    expect(d.photos.single.section, 'visibility');

    expect(d.riskScore, 20);
    expect(d.signals.single.code, 'geofence_distance');
  });

  test('a draft: null submit time, null score, no dwell', () {
    final d = VisitDetail.fromJson(const {
      'id': 'v2',
      'status': 'in_progress',
      'outlet': {'id': 'o1', 'name': 'Spar', 'code': 'S-1', 'channelType': 'x'},
      'agent': {'id': 'a1', 'email': 'a@x.test'},
      'checkinTs': '2026-09-14T07:00:00.000Z',
      'submittedAtClient': null,
      'geofence': {'pass': false, 'distanceM': null},
      'score': null,
      'sections': [],
      'photos': {'total': 0, 'items': []},
      'fraud': {'riskScore': 0, 'signals': []},
    });

    expect(d.isDraft, isTrue);
    expect(d.submittedAtClient, isNull);
    expect(d.dwellMinutes, isNull);
    expect(d.score, isNull);
    expect(d.distanceM, isNull);
    expect(d.geofencePass, isFalse);
    expect(d.photos, isEmpty);
    expect(d.signals, isEmpty);
  });

  test('a wrong-pin claim travels with the visit (#386)', () {
    final d = VisitDetail.fromJson(const {
      'id': 'v4',
      'status': 'in_progress',
      'outlet': {'id': 'o1', 'name': 'Spar', 'code': 'S-1', 'channelType': 'x'},
      'agent': {'id': 'a1', 'email': 'a@x.test'},
      'checkinTs': '2026-09-14T07:00:00.000Z',
      'submittedAtClient': null,
      'geofence': {'pass': false, 'distanceM': 8400},
      'pinDispute': {
        'id': 'd1',
        'lat': -26.2,
        'lng': 28.0,
        'distanceM': 8400,
        'outletLat': -26.1,
        'outletLng': 28.1,
        'note': 'Pinned on the depot',
        'status': 'applied',
        'resolvedByLabel': 'Manager',
        'resolvedAt': '2026-09-14T09:00:00.000Z',
        'createdAt': '2026-09-14T07:00:00.000Z',
      },
      'score': null,
      'sections': [],
      'photos': {'total': 0, 'items': []},
      'fraud': {'riskScore': 30, 'signals': []},
    });

    expect(d.geofencePass, isFalse);
    expect(d.pinDispute, isNotNull);
    expect(d.pinDispute!.distanceM, 8400);
    expect(d.pinDispute!.status, 'applied');
    expect(d.pinDispute!.note, 'Pinned on the depot');
    expect(d.pinDispute!.resolvedByLabel, 'Manager');
  });

  test('no claim, or an older server, is null', () {
    final d = VisitDetail.fromJson(const {
      'id': 'v5',
      'status': 'in_progress',
      'outlet': {'id': 'o1', 'name': 'Spar', 'code': 'S-1', 'channelType': 'x'},
      'agent': {'id': 'a1', 'email': 'a@x.test'},
      'checkinTs': '2026-09-14T07:00:00.000Z',
      'submittedAtClient': null,
      'geofence': {'pass': true, 'distanceM': 3},
      'pinDispute': null,
      'score': null,
      'sections': [],
      'photos': {'total': 0, 'items': []},
      'fraud': {'riskScore': 0, 'signals': []},
    });
    expect(d.pinDispute, isNull);
  });

  test('a submit time before check-in is not a dwell', () {
    final d = VisitDetail.fromJson(const {
      'id': 'v3',
      'status': 'submitted',
      'outlet': {'id': 'o1', 'name': 'Spar', 'code': 'S-1', 'channelType': 'x'},
      'agent': {'id': 'a1', 'email': 'a@x.test'},
      'checkinTs': '2026-09-14T07:00:00.000Z',
      'submittedAtClient': '2026-09-14T06:00:00.000Z',
      'geofence': {'pass': true, 'distanceM': 1},
      'score': null,
      'sections': [],
      'photos': {'total': 0, 'items': []},
      'fraud': {'riskScore': 0, 'signals': []},
    });

    expect(d.dwellMinutes, isNull);
  });

  test('a 404 becomes VisitNotFoundException', () async {
    final repo = DioVisitDetailRepository(
      client: Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = _Adapter(404, '{"error":"Visit not found"}'),
    );

    await expectLater(
      repo.fetch('gone'),
      throwsA(
        isA<VisitNotFoundException>().having((e) => e.visitId, 'id', 'gone'),
      ),
    );
  });

  test('any other failure is rethrown as the DioException', () async {
    final repo = DioVisitDetailRepository(
      client: Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = _Adapter(500, '{"error":"boom"}'),
    );

    await expectLater(repo.fetch('v1'), throwsA(isA<DioException>()));
  });
}
