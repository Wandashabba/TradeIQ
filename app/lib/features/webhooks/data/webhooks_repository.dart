import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated_response.dart';

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
  Future<PaginatedResponse<Webhook>> listWebhooks();
  Future<Webhook> createWebhook({
    required String url,
    required String event,
  });
  Future<void> deleteWebhook(String id);

  /// PATCH /webhooks/:id — activate or deactivate a webhook without deleting it.
  Future<Webhook> setActive(String id, bool active);
}

class DioWebhooksRepository implements WebhooksRepository {
  @override
  Future<PaginatedResponse<Webhook>> listWebhooks() async {
    final response = await dio.get('/webhooks');
    return PaginatedResponse<Webhook>.fromJson(
      response.data as Map<String, dynamic>,
      (e) => Webhook.fromJson(e as Map<String, dynamic>),
    );
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

  @override
  Future<Webhook> setActive(String id, bool active) async {
    final response = await dio.patch('/webhooks/$id', data: {'active': active});
    return Webhook.fromJson(response.data as Map<String, dynamic>);
  }
}

final webhooksRepositoryProvider =
    Provider<WebhooksRepository>((ref) => DioWebhooksRepository());

// The provider exposes the FIRST PAGE as a plain list: the webhooks screen
// wants the current webhooks, not the whole history, and "load more" UI is
// deliberately out of scope for the pagination sweep (see the spec).
// `nextCursor` is available on the repository for any screen that later needs
// to page; this provider intentionally drops it.
final webhooksListProvider = FutureProvider<List<Webhook>>((ref) async {
  final page = await ref.read(webhooksRepositoryProvider).listWebhooks();
  return page.data;
});
