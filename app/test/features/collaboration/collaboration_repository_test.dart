import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/collaboration/data/collaboration_repository.dart';

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
}
