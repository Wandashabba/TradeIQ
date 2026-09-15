import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/camera/photo_capture_service.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_palette.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/features/audit/data/photos_repository.dart';
import 'package:tradeiq_app/features/collaboration/data/collaboration_repository.dart';
import 'package:tradeiq_app/features/collaboration/presentation/message_attachment_thumb.dart';
import 'package:tradeiq_app/features/collaboration/presentation/messages_screen.dart';

import '../../core/theme/tiq_colors_test.dart' show contrastRatio;
import '../../helpers/routed_app.dart';

/// A real, decodable image: the canonical 1×1 transparent PNG.
final _pngBytes = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

const _first = Message(id: 'm1', body: 'Morning standup at 9');
const _second = Message(id: 'm2', body: 'Restock run complete');
const _withImages = Message(
  id: 'm3',
  body: 'Shelf after restock',
  attachments: [
    MessageAttachment(photoId: 'p1', position: 0),
    MessageAttachment(photoId: 'p2', position: 1),
  ],
);
const _imageOnly = Message(
  id: 'm4',
  body: '',
  recipientId: 'u2',
  attachments: [MessageAttachment(photoId: 'p3')],
);

const _announcement = Announcement(
  id: 'a1',
  title: 'Q3 Kickoff',
  body: 'New targets are live',
);

class _FixedSessionController extends SessionController {
  _FixedSessionController(this._initial);
  final SessionState _initial;

  @override
  Future<SessionState> build() async => _initial;
}

class _FakeCollaborationRepository implements CollaborationRepository {
  _FakeCollaborationRepository({this.messages = const [_first, _second]});

  final List<Message> messages;
  String? sentBody;
  List<String>? sentAttachmentIds;
  int sendCalls = 0;

  /// While set, sendMessage throws — the test flips it off to recover.
  bool failSend = false;
  ({String title, String body})? posted;

  @override
  Future<PaginatedResponse<Message>> listMessages() async =>
      PaginatedResponse(data: messages, nextCursor: null);

  @override
  Future<Message> sendMessage(
    String body, {
    String? recipientId,
    List<String> attachmentPhotoIds = const [],
  }) async {
    sendCalls++;
    if (failSend) throw Exception('send failed');
    sentBody = body;
    sentAttachmentIds = attachmentPhotoIds;
    return Message(id: 'm-new', body: body, recipientId: recipientId);
  }

  @override
  Future<PaginatedResponse<Announcement>> listAnnouncements() async =>
      const PaginatedResponse(data: [_announcement], nextCursor: null);

  @override
  Future<Announcement> createAnnouncement({
    required String title,
    required String body,
  }) async {
    posted = (title: title, body: body);
    return Announcement(id: 'a-new', title: title, body: body);
  }
}

class _ThrowingCollaborationRepository implements CollaborationRepository {
  @override
  Future<PaginatedResponse<Message>> listMessages() async => throw Exception('boom');

  @override
  Future<Message> sendMessage(
    String body, {
    String? recipientId,
    List<String> attachmentPhotoIds = const [],
  }) async =>
      throw Exception('boom');

  @override
  Future<PaginatedResponse<Announcement>> listAnnouncements() async => throw Exception('boom');

  @override
  Future<Announcement> createAnnouncement({
    required String title,
    required String body,
  }) async =>
      throw Exception('boom');
}

class _FakePhotosRepository implements PhotosRepository {
  final uploadedDataUrls = <String>[];
  final imageRequests = <String>[];

  /// While set, every upload throws.
  bool failUploads = false;

  @override
  Future<String> uploadMessageAttachment(String dataUrl) async {
    if (failUploads) throw Exception('upload failed');
    uploadedDataUrls.add(dataUrl);
    return 'att-${uploadedDataUrls.length}';
  }

  @override
  Future<Uint8List> thumbnailBytes(String photoId) async => _pngBytes;

  @override
  Future<Uint8List> imageBytes(String photoId) async {
    imageRequests.add(photoId);
    return _pngBytes;
  }

  @override
  Future<List<VisitPhoto>> listPhotos(String visitId) async => const [];

  @override
  Future<PhotoUploadResult> uploadPhoto({
    required String visitId,
    required String section,
    required String dataUrl,
    required Map<String, dynamic> gpsTag,
    required String timestamp,
  }) async =>
      throw UnimplementedError();
}

/// The picker seam: returns a real PNG from either source, recording which.
class _FakeGateway implements ImagePickerGateway {
  final sources = <ImageSource>[];

  @override
  Future<XFile?> pick({
    required ImageSource source,
    required double maxWidth,
    required int imageQuality,
  }) async {
    sources.add(source);
    return XFile.fromData(_pngBytes, name: 'shot.png', mimeType: 'image/png');
  }
}

Widget _app(
  CollaborationRepository repo, {
  String role = 'manager',
  ThemeData? theme,
  _FakePhotosRepository? photos,
  _FakeGateway? gateway,
}) => routedApp(
      const MessagesScreen(),
      theme: theme,
      overrides: [
        collaborationRepositoryProvider.overrideWithValue(repo),
        photosRepositoryProvider.overrideWithValue(
          photos ?? _FakePhotosRepository(),
        ),
        photoCaptureServiceProvider.overrideWithValue(
          PhotoCaptureService(gateway: gateway ?? _FakeGateway()),
        ),
        sessionControllerProvider.overrideWith(
          () => _FixedSessionController(SessionState(role: role)),
        ),
      ],
    );

/// The screen opens on Messages; announcements live behind the segment.
Future<void> _openAnnouncements(WidgetTester tester) async {
  await tester.tap(find.text('Announcements'));
  await tester.pumpAndSettle();
}

/// Attach button -> source sheet -> pick. Library by default.
Future<void> _attachPhoto(
  WidgetTester tester, {
  String source = 'attach-gallery',
}) async {
  await tester.tap(find.byKey(const ValueKey<String>('attach-photo')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey<String>(source)));
  await tester.pumpAndSettle();
}

Finder _pending(int i) => find.byKey(ValueKey('pending-attachment-$i'));

/// True when some DecoratedBox above [of] paints a rim in [color] — the glass
/// frame around a photo.
bool _hasRim(WidgetTester tester, Finder of, Color color) => tester
    .widgetList<DecoratedBox>(
      find.ancestor(of: of, matching: find.byType(DecoratedBox)),
    )
    .any((box) {
      final decoration = box.decoration;
      return decoration is BoxDecoration &&
          decoration.border is Border &&
          (decoration.border! as Border).top.color == color;
    });

void main() {
  testWidgets('light: the segment rides a pill and the composer is a glass bar',
      (tester) async {
    await tester.pumpWidget(
      _app(_FakeCollaborationRepository(), theme: AppTheme.light()),
    );
    await tester.pumpAndSettle();

    final selected = find.descendant(
      of: find.byKey(const ValueKey('tab-_Feed.messages')),
      matching: find.byType(GlassPane),
    );
    expect(tester.widget<GlassPane>(selected).kind, GlassKind.pill);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tab-_Feed.announcements')),
        matching: find.byType(GlassPane),
      ),
      findsNothing,
    );

    final composer = tester.widgetList<GlassPane>(
      find.ancestor(
        of: find.byKey(const ValueKey<String>('message-body')),
        matching: find.byType(GlassPane),
      ),
    );
    expect(composer.any((p) => p.kind == GlassKind.bar), isTrue);

    // The field stays opaque, so its words and hint measure true on glass.
    const t = TiqColors.light;
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('message-body')),
    );
    expect(field.decoration!.fillColor, t.surface2);
    expect(contrastRatio(t.ink3, t.surface2), greaterThanOrEqualTo(4.5));
    expect(contrastRatio(t.ink1, t.surface2), greaterThanOrEqualTo(4.5));

    final row = tester.widgetList<GlassPane>(
      find.ancestor(
        of: find.text('Morning standup at 9'),
        matching: find.byType(GlassPane),
      ),
    );
    expect(row.any((p) => p.kind == GlassKind.tile && !p.blur), isTrue);
  });

  testWidgets('renders message bodies once loaded', (tester) async {
    await tester.pumpWidget(_app(_FakeCollaborationRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Morning standup at 9'), findsOneWidget);
    expect(find.text('Restock run complete'), findsOneWidget);
  });

  testWidgets('sending a message calls sendMessage with the entered body',
      (tester) async {
    final repo = _FakeCollaborationRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('message-body')),
      'hello team',
    );
    await tester.tap(find.byKey(const ValueKey<String>('send-message')));
    await tester.pumpAndSettle();

    expect(repo.sentBody, 'hello team');
    // A text message sends no attachments.
    expect(repo.sentAttachmentIds, isEmpty);
  });

  testWidgets('shows an error message when the list fails to load',
      (tester) async {
    await tester.pumpWidget(_app(_ThrowingCollaborationRepository()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load messages'), findsOneWidget);
  });

  group('composer attachments (#125)', () {
    testWidgets('attaching from the library or the camera adds removable '
        'pending thumbnails', (tester) async {
      final gateway = _FakeGateway();
      await tester.pumpWidget(
        _app(_FakeCollaborationRepository(), gateway: gateway),
      );
      await tester.pumpAndSettle();

      expect(_pending(0), findsNothing);

      await _attachPhoto(tester);
      await _attachPhoto(tester, source: 'attach-camera');

      expect(gateway.sources, [ImageSource.gallery, ImageSource.camera]);
      expect(_pending(0), findsOneWidget);
      expect(_pending(1), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('pending-attachment-remove-0')),
      );
      await tester.pumpAndSettle();

      expect(_pending(0), findsOneWidget);
      expect(_pending(1), findsNothing);
    });

    testWidgets('dismissing the source sheet adds nothing', (tester) async {
      final gateway = _FakeGateway();
      await tester.pumpWidget(
        _app(_FakeCollaborationRepository(), gateway: gateway),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('attach-photo')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5)); // the scrim
      await tester.pumpAndSettle();

      expect(gateway.sources, isEmpty);
      expect(_pending(0), findsNothing);
    });

    testWidgets('send uploads each pending photo, sends their ids in order, '
        'then clears the draft', (tester) async {
      final repo = _FakeCollaborationRepository();
      final photos = _FakePhotosRepository();
      await tester.pumpWidget(_app(repo, photos: photos));
      await tester.pumpAndSettle();

      await _attachPhoto(tester);
      await _attachPhoto(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('message-body')),
        'Shelf after restock',
      );
      await tester.tap(find.byKey(const ValueKey<String>('send-message')));
      await tester.pumpAndSettle();

      expect(photos.uploadedDataUrls, hasLength(2));
      expect(photos.uploadedDataUrls.first, startsWith('data:image/png;base64,'));
      expect(repo.sentBody, 'Shelf after restock');
      expect(repo.sentAttachmentIds, ['att-1', 'att-2']);
      expect(_pending(0), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey<String>('message-body')))
            .controller!
            .text,
        isEmpty,
      );
    });

    testWidgets('a photo alone is a sendable message', (tester) async {
      final repo = _FakeCollaborationRepository();
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      await _attachPhoto(tester);
      await tester.tap(find.byKey(const ValueKey<String>('send-message')));
      await tester.pumpAndSettle();

      expect(repo.sentBody, '');
      expect(repo.sentAttachmentIds, ['att-1']);
    });

    testWidgets('an upload failure says so, sends nothing, and keeps the '
        'draft', (tester) async {
      final repo = _FakeCollaborationRepository();
      final photos = _FakePhotosRepository()..failUploads = true;
      await tester.pumpWidget(_app(repo, photos: photos));
      await tester.pumpAndSettle();

      await _attachPhoto(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('message-body')),
        'Look at this',
      );
      await tester.tap(find.byKey(const ValueKey<String>('send-message')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('composer-error')), findsOneWidget);
      expect(find.textContaining('failed to upload'), findsOneWidget);
      expect(find.textContaining('Your draft is kept'), findsOneWidget);
      expect(repo.sendCalls, 0);
      expect(_pending(0), findsOneWidget);
      expect(find.text('Look at this'), findsOneWidget);

      // Recovery: the same draft goes out once the upload works.
      photos.failUploads = false;
      await tester.tap(find.byKey(const ValueKey<String>('send-message')));
      await tester.pumpAndSettle();

      expect(repo.sentBody, 'Look at this');
      expect(repo.sentAttachmentIds, ['att-1']);
      expect(find.byKey(const ValueKey('composer-error')), findsNothing);
    });

    testWidgets('a send failure keeps the draft, and the retry does not '
        're-upload photos that already made it', (tester) async {
      final repo = _FakeCollaborationRepository()..failSend = true;
      final photos = _FakePhotosRepository();
      await tester.pumpWidget(_app(repo, photos: photos));
      await tester.pumpAndSettle();

      await _attachPhoto(tester);
      await tester.tap(find.byKey(const ValueKey<String>('send-message')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Message not sent'), findsOneWidget);
      expect(_pending(0), findsOneWidget);
      expect(photos.uploadedDataUrls, hasLength(1));

      repo.failSend = false;
      await tester.tap(find.byKey(const ValueKey<String>('send-message')));
      await tester.pumpAndSettle();

      expect(photos.uploadedDataUrls, hasLength(1));
      expect(repo.sentAttachmentIds, ['att-1']);
      expect(_pending(0), findsNothing);
    });

    testWidgets('the attach button disables at the 4-photo cap',
        (tester) async {
      await tester.pumpWidget(_app(_FakeCollaborationRepository()));
      await tester.pumpAndSettle();

      for (var i = 0; i < maxMessageAttachments; i++) {
        await _attachPhoto(tester);
      }

      expect(_pending(3), findsOneWidget);
      final attach = tester.widget<IconButton>(
        find.byKey(const ValueKey<String>('attach-photo')),
      );
      expect(attach.onPressed, isNull);
    });
  });

  group('thread attachments (#125)', () {
    testWidgets('a message shows its images as thumbnails inside its own tile',
        (tester) async {
      await tester.pumpWidget(
        _app(
          _FakeCollaborationRepository(messages: const [_withImages]),
          theme: AppTheme.light(),
        ),
      );
      await tester.pumpAndSettle();

      final thumbs = find.descendant(
        of: find.byKey(const ValueKey('message-m3')),
        matching: find.byType(MessageAttachmentThumb),
      );
      expect(thumbs, findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('message-attachment-image-p1')),
        findsOneWidget,
      );
      expect(find.text('Shelf after restock'), findsOneWidget);
    });

    testWidgets('tapping a thumbnail opens that photo full size, and Close '
        'dismisses it', (tester) async {
      final photos = _FakePhotosRepository();
      await tester.pumpWidget(
        _app(
          _FakeCollaborationRepository(messages: const [_withImages]),
          photos: photos,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('message-attachment-p2')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('attachment-dialog')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('attachment-dialog-image')),
        findsOneWidget,
      );
      expect(photos.imageRequests, ['p2']);

      await tester.tap(find.byKey(const ValueKey('attachment-dialog-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('attachment-dialog')), findsNothing);
    });

    testWidgets('an image-only message is headed "Photo" rather than blank',
        (tester) async {
      await tester.pumpWidget(
        _app(_FakeCollaborationRepository(messages: const [_imageOnly])),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('message-m4')),
          matching: find.text('Photo'),
        ),
        findsOneWidget,
      );
    });
  });

  for (final (name, theme, palette) in [
    ('light', AppTheme.light(), LumenPalette.light),
    ('dark', AppTheme.dark(), LumenPalette.dark),
  ]) {
    testWidgets('$name: pending and thread photos are framed by the glass rim '
        'inside glass panes', (tester) async {
      await tester.pumpWidget(
        _app(
          _FakeCollaborationRepository(messages: const [_withImages]),
          theme: theme,
        ),
      );
      await tester.pumpAndSettle();
      await _attachPhoto(tester);

      // The pending photo lives in the composer's glass bar, rimmed.
      final bar = tester.widgetList<GlassPane>(
        find.ancestor(of: _pending(0), matching: find.byType(GlassPane)),
      );
      expect(bar.any((p) => p.kind == GlassKind.bar), isTrue);
      expect(_hasRim(tester, _pending(0), palette.tileRim), isTrue);

      // The thread photo sits in the message's no-blur tile, rimmed.
      final threadImage = find.byKey(
        const ValueKey('message-attachment-image-p1'),
      );
      final tile = tester.widgetList<GlassPane>(
        find.ancestor(of: threadImage, matching: find.byType(GlassPane)),
      );
      expect(tile.any((p) => p.kind == GlassKind.tile && !p.blur), isTrue);
      expect(_hasRim(tester, threadImage, palette.tileRim), isTrue);

      // The attach affordance uses the palette's accent ink, not a literal.
      final attach = tester.widget<IconButton>(
        find.byKey(const ValueKey<String>('attach-photo')),
      );
      expect(attach.color, palette.accentInk);
    });
  }

  testWidgets('the announcements segment lists announcement titles',
      (tester) async {
    await tester.pumpWidget(_app(_FakeCollaborationRepository()));
    await tester.pumpAndSettle();

    // Messages is the default feed, so the announcement is not on screen yet.
    expect(find.text('Q3 Kickoff'), findsNothing);

    await _openAnnouncements(tester);

    expect(find.text('Q3 Kickoff'), findsOneWidget);
    expect(find.text('New targets are live'), findsOneWidget);
    // The conversation composer belongs to Messages, not to the broadcast feed.
    expect(find.byKey(const ValueKey<String>('message-body')), findsNothing);
    expect(find.byKey(const ValueKey<String>('attach-photo')), findsNothing);
  });

  testWidgets('shows an error message when announcements fail to load',
      (tester) async {
    await tester.pumpWidget(_app(_ThrowingCollaborationRepository()));
    await tester.pumpAndSettle();

    await _openAnnouncements(tester);

    expect(find.textContaining('Failed to load announcements'), findsOneWidget);
  });

  testWidgets('a manager can post an announcement with a title and body',
      (tester) async {
    final repo = _FakeCollaborationRepository();
    await tester.pumpWidget(_app(repo, role: 'manager'));
    await tester.pumpAndSettle();

    await _openAnnouncements(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('announcement-create-fab')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('announcement-title')),
      'Price change',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('announcement-body')),
      'New list price from Monday',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('post-announcement')));
    await tester.pumpAndSettle();

    expect(repo.posted?.title, 'Price change');
    expect(repo.posted?.body, 'New list price from Monday');
  });

  testWidgets('an admin also gets the compose affordance', (tester) async {
    await tester.pumpWidget(
      _app(_FakeCollaborationRepository(), role: 'admin'),
    );
    await tester.pumpAndSettle();
    await _openAnnouncements(tester);

    expect(
      find.byKey(const ValueKey<String>('announcement-create-fab')),
      findsOneWidget,
    );
  });

  testWidgets('a field agent reads announcements but cannot post one',
      (tester) async {
    await tester.pumpWidget(
      _app(_FakeCollaborationRepository(), role: 'field_agent'),
    );
    await tester.pumpAndSettle();
    await _openAnnouncements(tester);

    // POST /announcements is manager/admin only — no button we cannot honour.
    expect(
      find.byKey(const ValueKey<String>('announcement-create-fab')),
      findsNothing,
    );
    expect(find.text('Q3 Kickoff'), findsOneWidget);
  });

  testWidgets('Post stays disabled until both title and body are filled',
      (tester) async {
    final repo = _FakeCollaborationRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await _openAnnouncements(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('announcement-create-fab')),
    );
    await tester.pumpAndSettle();

    final post = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('post-announcement')),
    );
    expect(post.onPressed, isNull);

    // A title alone is not enough — the endpoint requires both.
    await tester.enterText(
      find.byKey(const ValueKey<String>('announcement-title')),
      'Title only',
    );
    await tester.pump();

    final stillDisabled = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('post-announcement')),
    );
    expect(stillDisabled.onPressed, isNull);
    expect(repo.posted, isNull);
  });
}
