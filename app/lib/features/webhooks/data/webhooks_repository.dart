import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// An admin-facing view of one outbound webhook returned by GET /webhooks.
class Webhook {
  const Webhook({
    required this.id,
    required this.url,
    required this.event,
    required this.active,
  });
  final String id;
  final String url;
  final String event;
  final bool active;

  factory Webhook.fromJson(Map<String, dynamic> json) => Webhook(
        id: json['id'] as String,
        url: json['url'] as String,
        event: json['event'] as String,
        active: json['active'] as bool? ?? true,
      );
}

abstract class WebhooksRepository {
  Future<List<Webhook>> listWebhooks();
  Future<Webhook> createWebhook({
    required String url,
    required String event,
  });
  Future<void> deleteWebhook(String id);
}

class DioWebhooksRepository implements WebhooksRepository {
  @override
  Future<List<Webhook>> listWebhooks() async {
    final response = await dio.get('/webhooks');
    return (response.data as List)
        .map((json) => Webhook.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Webhook> createWebhook({
    required String url,
    required String event,
  }) async {
    final response = await dio.post('/webhooks', data: {
      'url': url,
      'event': event,
    });
    return Webhook.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> deleteWebhook(String id) async {
    await dio.delete('/webhooks/$id');
  }
}

final webhooksRepositoryProvider =
    Provider<WebhooksRepository>((ref) => DioWebhooksRepository());

final webhooksListProvider = FutureProvider<List<Webhook>>((ref) {
  return ref.read(webhooksRepositoryProvider).listWebhooks();
});
