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

  test('Message.fromJson parses image attachments in order, metadata only', () {
    final message = Message.fromJson(const {
      'id': 'm3',
      'senderId': 's1',
      'recipientId': null,
      'body': '',
      'createdAt': '2026-09-15T10:00:00.000Z',
      'attachments': [
        {
          'photoId': 'p1',
          'position': 0,
          'thumbnailUrl': '/photos/p1/thumbnail',
          'imageUrl': '/photos/p1/image',
        },
        {
          'photoId': 'p2',
          'position': 1,
          'thumbnailUrl': '/photos/p2/thumbnail',
          'imageUrl': '/photos/p2/image',
        },
      ],
    });

    expect(message.attachments.map((a) => a.photoId), ['p1', 'p2']);
    expect(message.attachments.map((a) => a.position), [0, 1]);
  });

  test('Message.fromJson treats a missing attachments array as none', () {
    final message = Message.fromJson(const {'id': 'm4', 'body': 'Text only'});
    expect(message.attachments, isEmpty);
  });

  test('sendMessage POSTs attachmentPhotoIds alongside the body', () async {
    final adapter = _CapturingAdapter(
      '{"id":"m9","body":"Shelf after restock","recipientId":null,'
      '"attachments":[{"photoId":"p1","position":0},'
      '{"photoId":"p2","position":1}]}',
      statusCode: 201,
    );
    final previous = dio.httpClientAdapter;
    dio.httpClientAdapter = adapter;
    addTearDown(() => dio.httpClientAdapter = previous);

    final message = await DioCollaborationRepository().sendMessage(
      'Shelf after restock',
      attachmentPhotoIds: const ['p1', 'p2'],
    );

    expect(adapter.captured!.method, 'POST');
    expect(adapter.captured!.path, '/messages');
    expect(adapter.captured!.data, {
      'body': 'Shelf after restock',
      'attachmentPhotoIds': ['p1', 'p2'],
    });
    expect(message.attachments.map((a) => a.photoId), ['p1', 'p2']);
  });

  test('a text-only sendMessage omits attachmentPhotoIds from the wire', () async {
    final adapter = _CapturingAdapter(
      '{"id":"m10","body":"hi","recipientId":"u2","attachments":[]}',
      statusCode: 201,
    );
    final previous = dio.httpClientAdapter;
    dio.httpClientAdapter = adapter;
    addTearDown(() => dio.httpClientAdapter = previous);

    await DioCollaborationRepository().sendMessage('hi', recipientId: 'u2');

    expect(adapter.captured!.data, {'body': 'hi', 'recipientId': 'u2'});
  });

  test('sendMessage sends clientMessageId, the idempotency key (#308)', () async {
    final adapter = _CapturingAdapter(
      '{"id":"m11","body":"hi","recipientId":null,"attachments":[],'
      '"clientMessageId":"key-1"}',
      statusCode: 201,
    );
    final previous = dio.httpClientAdapter;
    dio.httpClientAdapter = adapter;
    addTearDown(() => dio.httpClientAdapter = previous);

    await DioCollaborationRepository().sendMessage(
      'hi',
      attachmentPhotoIds: const ['p1'],
      clientMessageId: 'key-1',
    );

    expect(adapter.captured!.data, {
      'body': 'hi',
      'attachmentPhotoIds': ['p1'],
      'clientMessageId': 'key-1',
    });
  });

  test('a replayed send (200) parses as the original message (#308)', () async {
    final adapter = _CapturingAdapter(
      '{"id":"m-original","body":"hi","recipientId":null,"attachments":[],'
      '"clientMessageId":"key-1"}',
    );
    final previous = dio.httpClientAdapter;
    dio.httpClientAdapter = adapter;
    addTearDown(() => dio.httpClientAdapter = previous);

    final message = await DioCollaborationRepository().sendMessage(
      'hi',
      clientMessageId: 'key-1',
    );

    expect(message.id, 'm-original');
  });

  test('sendMessage without a key omits clientMessageId from the wire', () async {
    final adapter = _CapturingAdapter(
      '{"id":"m12","body":"hi","recipientId":null,"attachments":[]}',
      statusCode: 201,
    );
    final previous = dio.httpClientAdapter;
    dio.httpClientAdapter = adapter;
    addTearDown(() => dio.httpClientAdapter = previous);

    await DioCollaborationRepository().sendMessage('hi');

    expect(
      (adapter.captured!.data as Map<String, dynamic>).containsKey('clientMessageId'),
      isFalse,
    );
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
