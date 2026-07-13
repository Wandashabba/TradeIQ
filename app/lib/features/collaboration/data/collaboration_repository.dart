import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// A single team message returned by GET /messages.
class Message {
  const Message({
    required this.id,
    required this.body,
    this.recipientId,
  });
  final String id;
  final String body;
  final String? recipientId;

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        body: json['body'] as String,
        recipientId: json['recipientId'] as String?,
      );
}

/// A broadcast announcement returned by GET /announcements.
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
  });
  final String id;
  final String title;
  final String body;

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
      );
}

abstract class CollaborationRepository {
  Future<List<Message>> listMessages();
  Future<Message> sendMessage(String body, {String? recipientId});
  Future<List<Announcement>> listAnnouncements();

  /// POST /announcements. The backend gates this on `requireRole('manager',
  /// 'admin')` — the caller must role-gate the affordance too, or a field agent
  /// gets a 403 for a button we showed them.
  Future<Announcement> createAnnouncement({
    required String title,
    required String body,
  });
}

class DioCollaborationRepository implements CollaborationRepository {
  @override
  Future<List<Message>> listMessages() async {
    final response = await dio.get('/messages');
    return (response.data as List)
        .map((json) => Message.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Message> sendMessage(String body, {String? recipientId}) async {
    final data = <String, dynamic>{'body': body};
    if (recipientId != null) data['recipientId'] = recipientId;
    final response = await dio.post('/messages', data: data);
    return Message.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<Announcement>> listAnnouncements() async {
    final response = await dio.get('/announcements');
    return (response.data as List)
        .map((json) => Announcement.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Announcement> createAnnouncement({
    required String title,
    required String body,
  }) async {
    final response = await dio.post(
      '/announcements',
      data: <String, dynamic>{'title': title, 'body': body},
    );
    return Announcement.fromJson(response.data as Map<String, dynamic>);
  }
}

final collaborationRepositoryProvider =
    Provider<CollaborationRepository>((ref) => DioCollaborationRepository());

final messagesProvider = FutureProvider<List<Message>>((ref) {
  return ref.read(collaborationRepositoryProvider).listMessages();
});

final announcementsListProvider = FutureProvider<List<Announcement>>((ref) {
  return ref.read(collaborationRepositoryProvider).listAnnouncements();
});
