import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/webhooks/data/webhooks_repository.dart';

void main() {
  test('Webhook.fromJson parses all fields', () {
    final webhook = Webhook.fromJson(const {
      'id': 'w1',
      'url': 'https://example.com/hook',
      'event': 'visit.submitted',
      'active': false,
    });

    expect(webhook.id, 'w1');
    expect(webhook.url, 'https://example.com/hook');
    expect(webhook.event, 'visit.submitted');
    expect(webhook.active, isFalse);
  });

  test('Webhook.fromJson defaults active to true when missing', () {
    final webhook = Webhook.fromJson(const {
      'id': 'w2',
      'url': 'https://example.com/hook2',
      'event': 'task.closed',
    });

    expect(webhook.active, isTrue);
  });
}
