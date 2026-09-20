import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated_response.dart';

/// An image attached to a message (#125). Metadata only — the list never
/// carries bytes. Fetch the thumbnail or the full image by [photoId] through
/// the photos repository, which sends the bearer token.
///
/// Images only: attachments ride the existing photo pipeline, not a general
/// file store, so there is no PDF or document variant.
class MessageAttachment {
  const MessageAttachment({required this.photoId, this.position = 0});

  final String photoId;
  final int position;

  factory MessageAttachment.fromJson(Map<String, dynamic> json) =>
      MessageAttachment(
        photoId: json['photoId'] as String,
        position: (json['position'] as num?)?.toInt() ?? 0,
      );
}

/// A single team message returned by GET /messages.
class Message {
  const Message({
    required this.id,
    required this.body,
    this.recipientId,
    this.attachments = const [],
  });
  final String id;
  final String body;
  final String? recipientId;

  /// In the order the sender attached them. Empty for a text-only message.
  final List<MessageAttachment> attachments;

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        body: json['body'] as String,
        recipientId: json['recipientId'] as String?,
        attachments: [
          for (final a in (json['attachments'] as List<dynamic>? ?? const []))
            MessageAttachment.fromJson(a as Map<String, dynamic>),
        ],
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

  /// POST /messages. [attachmentPhotoIds] are ids returned by
  /// `PhotosRepository.uploadMessageAttachment` — at most
  /// [maxMessageAttachments], each uploaded by the caller. [body] may be blank
  /// only when at least one image is attached.
  ///
  /// [clientMessageId] is the idempotency key for this composed message
  /// (#308): generate it once, send the SAME value on every retry of that
  /// message, and a new one for the next message. The server then answers a
  /// retry whose first response was lost with the original message (200)
  /// rather than a duplicate or a 409. The same key with different content is
  /// a 409, so a changed draft needs a new key.
  Future<Message> sendMessage(
    String body, {
    String? recipientId,
    List<String> attachmentPhotoIds = const [],
    String? clientMessageId,
  });
  Future<PaginatedResponse<Announcement>> listAnnouncements();

  /// POST /announcements. The backend gates this on `requireRole('manager',
  /// 'admin')` — the caller must role-gate the affordance too, or a field agent
  /// gets a 403 for a button we showed them.
  Future<Announcement> createAnnouncement({
    required String title,
    required String body,
  });
}

/// The server's cap on images per message (MAX_MESSAGE_ATTACHMENTS).
const maxMessageAttachments = 4;

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
  Future<Message> sendMessage(
    String body, {
    String? recipientId,
    List<String> attachmentPhotoIds = const [],
    String? clientMessageId,
  }) async {
    final data = <String, dynamic>{'body': body};
    if (recipientId != null) data['recipientId'] = recipientId;
    // A body field, not an Idempotency-Key header: the server stores it on the
    // message. 201 (created) and 200 (a replay of an earlier send) both parse
    // as the message.
    if (clientMessageId != null) data['clientMessageId'] = clientMessageId;
    // Omitted rather than sent empty, so a text message's wire shape is
    // exactly what it was before attachments existed.
    if (attachmentPhotoIds.isNotEmpty) {
      data['attachmentPhotoIds'] = attachmentPhotoIds;
    }
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
