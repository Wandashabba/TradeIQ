import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart' as api_client;
import 'push_config.dart';

/// The kinds of push a user can switch off — the server's categories (#67).
enum NotificationCategory { alerts, tasks, messages, sla }

/// GET/PATCH /push/preferences. Every category defaults to on.
class NotificationPreferences {
  const NotificationPreferences({
    this.alerts = true,
    this.tasks = true,
    this.messages = true,
    this.sla = true,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        alerts: json['alerts'] != false,
        tasks: json['tasks'] != false,
        messages: json['messages'] != false,
        sla: json['sla'] != false,
      );

  final bool alerts;
  final bool tasks;
  final bool messages;
  final bool sla;

  bool operator [](NotificationCategory category) => switch (category) {
    NotificationCategory.alerts => alerts,
    NotificationCategory.tasks => tasks,
    NotificationCategory.messages => messages,
    NotificationCategory.sla => sla,
  };

  NotificationPreferences withValue(
    NotificationCategory category,
    bool enabled,
  ) => NotificationPreferences(
    alerts: category == NotificationCategory.alerts ? enabled : alerts,
    tasks: category == NotificationCategory.tasks ? enabled : tasks,
    messages: category == NotificationCategory.messages ? enabled : messages,
    sla: category == NotificationCategory.sla ? enabled : sla,
  );

  @override
  bool operator ==(Object other) =>
      other is NotificationPreferences &&
      other.alerts == alerts &&
      other.tasks == tasks &&
      other.messages == messages &&
      other.sla == sla;

  @override
  int get hashCode => Object.hash(alerts, tasks, messages, sla);
}

abstract class PushRepository {
  /// POST /push/devices — idempotent register or refresh.
  Future<void> registerDevice({
    required String token,
    required PushPlatform platform,
  });

  /// DELETE /push/devices/:token. [authToken] is the departing session's
  /// bearer token: by the time sign-out calls this, the app has already
  /// dropped it.
  Future<void> unregisterDevice(String token, {required String authToken});

  Future<NotificationPreferences> fetchPreferences();

  Future<NotificationPreferences> updatePreferences(
    Map<NotificationCategory, bool> changes,
  );
}

class DioPushRepository implements PushRepository {
  @override
  Future<void> registerDevice({
    required String token,
    required PushPlatform platform,
  }) async {
    await api_client.dio.post<void>(
      '/push/devices',
      data: {'token': token, 'platform': platform.name},
    );
  }

  @override
  Future<void> unregisterDevice(
    String token, {
    required String authToken,
  }) async {
    await api_client.dio.delete<void>(
      '/push/devices/${Uri.encodeComponent(token)}',
      options: Options(headers: {'Authorization': 'Bearer $authToken'}),
    );
  }

  @override
  Future<NotificationPreferences> fetchPreferences() async {
    final res = await api_client.dio.get<Map<String, dynamic>>(
      '/push/preferences',
    );
    return NotificationPreferences.fromJson(res.data ?? const {});
  }

  @override
  Future<NotificationPreferences> updatePreferences(
    Map<NotificationCategory, bool> changes,
  ) async {
    final res = await api_client.dio.patch<Map<String, dynamic>>(
      '/push/preferences',
      data: {for (final e in changes.entries) e.key.name: e.value},
    );
    return NotificationPreferences.fromJson(res.data ?? const {});
  }
}

final pushRepositoryProvider = Provider<PushRepository>(
  (ref) => DioPushRepository(),
);
