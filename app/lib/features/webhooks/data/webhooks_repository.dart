import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated_response.dart';

/// The events the backend emits — `WEBHOOK_EVENTS` in webhooks.service.ts, in
/// its order. The API still accepts any event name; one not on this list simply
/// never fires, so the create form offers these as the hint.
const webhookEvents = <String>[
  'visit.submitted',
  'alert.raised',
  'order.created',
  // A report schedule ran (#66): carries the run and a link to its CSV.
  'report.generated',
];

/// Whether a webhook is actually receiving (#100), as the backend derives it.
enum WebhookHealth {
  /// Nothing has failed since the last success (or it has never fired).
  healthy,

  /// The latest delivery failed and is waiting on a retry.
  failing,

  /// A delivery gave up after every retry since the last success.
  unhealthy;

  static WebhookHealth parse(String? raw) => switch (raw) {
    'failing' => WebhookHealth.failing,
    'unhealthy' => WebhookHealth.unhealthy,
    _ => WebhookHealth.healthy,
  };
}

/// Where one delivery stands (#100).
enum DeliveryStatus {
  pending,
  succeeded,
  failedRetrying,
  gaveUp;

  static DeliveryStatus? parse(String? raw) => switch (raw) {
    'pending' => DeliveryStatus.pending,
    'succeeded' => DeliveryStatus.succeeded,
    'failed_retrying' => DeliveryStatus.failedRetrying,
    'gave_up' => DeliveryStatus.gaveUp,
    _ => null,
  };

  /// A failed delivery can be sent again by hand.
  bool get redeliverable =>
      this == DeliveryStatus.failedRetrying || this == DeliveryStatus.gaveUp;
}

DateTime? _date(Object? raw) =>
    raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

/// An admin-facing view of one outbound webhook returned by GET /webhooks.
class Webhook {
  const Webhook({
    required this.id,
    required this.url,
    required this.event,
    required this.active,
    this.health = WebhookHealth.healthy,
    this.consecutiveFailures = 0,
    this.lastDeliveryStatus,
    this.lastDeliveryAt,
  });
  final String id;
  final String url;
  final String event;
  final bool active;
  final WebhookHealth health;

  /// Deliveries that gave up since the last successful one.
  final int consecutiveFailures;
  final DeliveryStatus? lastDeliveryStatus;
  final DateTime? lastDeliveryAt;

  factory Webhook.fromJson(Map<String, dynamic> json) => Webhook(
    id: json['id'] as String,
    url: json['url'] as String,
    event: json['event'] as String,
    active: json['active'] as bool? ?? true,
    health: WebhookHealth.parse(json['health'] as String?),
    consecutiveFailures: json['consecutiveFailures'] as int? ?? 0,
    lastDeliveryStatus: DeliveryStatus.parse(
      json['lastDeliveryStatus'] as String?,
    ),
    lastDeliveryAt: _date(json['lastDeliveryAt']),
  );
}

/// One event delivered (or being delivered) to one webhook, from
/// GET /webhooks/:id/deliveries.
class WebhookDelivery {
  const WebhookDelivery({
    required this.id,
    required this.event,
    required this.status,
    required this.attempts,
    required this.createdAt,
    this.lastStatusCode,
    this.lastError,
    this.nextAttemptAt,
    this.lastAttemptAt,
    this.deliveredAt,
  });

  final String id;
  final String event;
  final DeliveryStatus status;
  final int attempts;
  final DateTime createdAt;
  final int? lastStatusCode;
  final String? lastError;
  final DateTime? nextAttemptAt;
  final DateTime? lastAttemptAt;
  final DateTime? deliveredAt;

  factory WebhookDelivery.fromJson(Map<String, dynamic> json) =>
      WebhookDelivery(
        id: json['id'] as String,
        event: json['event'] as String,
        // An unknown future status reads as queued rather than crashing.
        status:
            DeliveryStatus.parse(json['status'] as String?) ??
            DeliveryStatus.pending,
        attempts: json['attempts'] as int? ?? 0,
        createdAt: _date(json['createdAt']) ?? DateTime.now(),
        lastStatusCode: json['lastStatusCode'] as int?,
        lastError: json['lastError'] as String?,
        nextAttemptAt: _date(json['nextAttemptAt']),
        lastAttemptAt: _date(json['lastAttemptAt']),
        deliveredAt: _date(json['deliveredAt']),
      );
}

abstract class WebhooksRepository {
  Future<PaginatedResponse<Webhook>> listWebhooks();
  Future<Webhook> createWebhook({required String url, required String event});
  Future<void> deleteWebhook(String id);

  /// PATCH /webhooks/:id — activate or deactivate a webhook without deleting it.
  Future<Webhook> setActive(String id, bool active);

  /// GET /webhooks/:id/deliveries — the most recent deliveries, newest first.
  Future<List<WebhookDelivery>> listDeliveries(String webhookId, {int limit});

  /// POST /webhook-deliveries/:id/redeliver — send a failed delivery again now.
  Future<WebhookDelivery> redeliver(String deliveryId);
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
    final response = await dio.post(
      '/webhooks',
      data: {'url': url, 'event': event},
    );
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

  @override
  Future<List<WebhookDelivery>> listDeliveries(
    String webhookId, {
    int limit = 10,
  }) async {
    final response = await dio.get(
      '/webhooks/$webhookId/deliveries',
      queryParameters: {'limit': limit},
    );
    return PaginatedResponse<WebhookDelivery>.fromJson(
      response.data as Map<String, dynamic>,
      (e) => WebhookDelivery.fromJson(e as Map<String, dynamic>),
    ).data;
  }

  @override
  Future<WebhookDelivery> redeliver(String deliveryId) async {
    final response = await dio.post(
      '/webhook-deliveries/$deliveryId/redeliver',
    );
    return WebhookDelivery.fromJson(response.data as Map<String, dynamic>);
  }
}

final webhooksRepositoryProvider = Provider<WebhooksRepository>(
  (ref) => DioWebhooksRepository(),
);

// The provider exposes the FIRST PAGE as a plain list: the webhooks screen
// wants the current webhooks, not the whole history, and "load more" UI is
// deliberately out of scope for the pagination sweep (see the spec).
// `nextCursor` is available on the repository for any screen that later needs
// to page; this provider intentionally drops it.
final webhooksListProvider = FutureProvider<List<Webhook>>((ref) async {
  final page = await ref.read(webhooksRepositoryProvider).listWebhooks();
  return page.data;
});

/// The recent deliveries for one webhook — fetched only when its row is opened.
final webhookDeliveriesProvider =
    FutureProvider.family<List<WebhookDelivery>, String>((ref, webhookId) {
      return ref.read(webhooksRepositoryProvider).listDeliveries(webhookId);
    });
