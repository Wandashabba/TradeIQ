import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/api_client.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/collaboration/data/collaboration_repository.dart';

/// Captures the outbound request instead of hitting the network, so a test can
/// assert the wire contract (path, method, field names) the backend expects.
class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter(this.responseBody, {this.statusCode = 200});

  final String responseBody;
  final int statusCode;
  RequestOptions? captured;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured = options;
    return ResponseBody.fromString(
      responseBody,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('Message.fromJson parses all fields including recipientId', () {
    final message = Message.fromJson(const {
      'id': 'm1',
      'senderId': 's1',
      'recipientId': 'r1',
      'body': 'Hello team',
      'createdAt': '2026-07-09T10:00:00.000Z',
    });

    expect(message.id, 'm1');
    expect(message.body, 'Hello team');
    expect(message.recipientId, 'r1');
  });

  test('Message.fromJson allows a null recipientId', () {
    final message = Message.fromJson(const {
      'id': 'm2',
      'senderId': 's2',
      'body': 'Broadcast',
      'createdAt': '2026-07-09T10:00:00.000Z',
    });

    expect(message.id, 'm2');
    expect(message.body, 'Broadcast');
    expect(message.recipientId, isNull);
  });

  test('Announcement.fromJson parses all fields', () {
    final announcement = Announcement.fromJson(const {
      'id': 'a1',
      'title': 'Q3 Kickoff',
      'body': 'New targets are live',
      'createdAt': '2026-07-09T10:00:00.000Z',
    });

    expect(announcement.id, 'a1');
    expect(announcement.title, 'Q3 Kickoff');
    expect(announcement.body, 'New targets are live');
  });

  test('createAnnouncement POSTs title and body to /announcements', () async {
    final adapter = _CapturingAdapter(
      '{"id":"a9","clientId":"c1","authorId":"u1","title":"Price change",'
      '"body":"New list price from Monday",'
      '"createdAt":"2026-07-09T10:00:00.000Z"}',
      statusCode: 201,
    );
    final previous = dio.httpClientAdapter;
    dio.httpClientAdapter = adapter;
    addTearDown(() => dio.httpClientAdapter = previous);

    final announcement = await DioCollaborationRepository().createAnnouncement(
      title: 'Price change',
      body: 'New list price from Monday',
    );

    expect(adapter.captured!.method, 'POST');
    expect(adapter.captured!.path, '/announcements');
    // The route reads exactly `title` and `body` off the JSON body and 400s on
    // a blank either way — no other field is sent or accepted.
    expect(adapter.captured!.data, {
      'title': 'Price change',
      'body': 'New list price from Monday',
    });
    expect(announcement.id, 'a9');
  });

  test('listAnnouncements GETs /announcements and parses the {data, nextCursor} envelope', () async {
    final adapter = _CapturingAdapter(
      '{"data": [{"id":"a1","title":"Q3 Kickoff","body":"New targets are live",'
      '"createdAt":"2026-07-09T10:00:00.000Z"}], "nextCursor": null}',
    );
    final previous = dio.httpClientAdapter;
    dio.httpClientAdapter = adapter;
    addTearDown(() => dio.httpClientAdapter = previous);

    final page = await DioCollaborationRepository().listAnnouncements();

    expect(adapter.captured!.method, 'GET');
    expect(adapter.captured!.path, '/announcements');
    expect(page, isA<PaginatedResponse<Announcement>>());
    expect(page.data.single.title, 'Q3 Kickoff');
    expect(page.nextCursor, isNull);
  });

  test('listMessages GETs /messages and parses the {data, nextCursor} envelope', () async {
    final adapter = _CapturingAdapter(
      '{"data": [{"id":"m1","senderId":"s1","recipientId":null,'
      '"body":"Hello team","createdAt":"2026-07-09T10:00:00.000Z"}], '
      '"nextCursor": "cursor-1"}',
    );
    final previous = dio.httpClientAdapter;
    dio.httpClientAdapter = adapter;
    addTearDown(() => dio.httpClientAdapter = previous);

    final page = await DioCollaborationRepository().listMessages();

    expect(adapter.captured!.method, 'GET');
    expect(adapter.captured!.path, '/messages');
    expect(page, isA<PaginatedResponse<Message>>());
    expect(page.data.single.id, 'm1');
    expect(page.nextCursor, 'cursor-1');
  });
}
