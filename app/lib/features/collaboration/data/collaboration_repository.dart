import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated_response.dart';

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
  Future<PaginatedResponse<Message>> listMessages();
  Future<Message> sendMessage(String body, {String? recipientId});
  Future<PaginatedResponse<Announcement>> listAnnouncements();

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
  Future<PaginatedResponse<Message>> listMessages() async {
    final response = await dio.get('/messages');
    return PaginatedResponse<Message>.fromJson(
      response.data as Map<String, dynamic>,
      (e) => Message.fromJson(e as Map<String, dynamic>),
    );
  }

  @override
  Future<Message> sendMessage(String body, {String? recipientId}) async {
    final data = <String, dynamic>{'body': body};
    if (recipientId != null) data['recipientId'] = recipientId;
    final response = await dio.post('/messages', data: data);
    return Message.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<PaginatedResponse<Announcement>> listAnnouncements() async {
    final response = await dio.get('/announcements');
    return PaginatedResponse<Announcement>.fromJson(
      response.data as Map<String, dynamic>,
      (e) => Announcement.fromJson(e as Map<String, dynamic>),
    );
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

// Both providers expose the FIRST PAGE as a plain list: the messages/
// announcements panel wants the most recent items, not the whole history,
// and "load more" UI is deliberately out of scope for the pagination sweep
// (see the spec). `nextCursor` is available on the repository for any screen
// that later needs to page; these providers intentionally drop it.
final messagesProvider = FutureProvider<List<Message>>((ref) async {
  final page = await ref.read(collaborationRepositoryProvider).listMessages();
  return page.data;
});

final announcementsListProvider = FutureProvider<List<Announcement>>((ref) async {
  final page = await ref.read(collaborationRepositoryProvider).listAnnouncements();
  return page.data;
});
