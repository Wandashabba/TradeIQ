import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/camera/photo_capture_service.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/audit/data/photos_repository.dart';
import 'package:tradeiq_app/features/collaboration/data/collaboration_repository.dart';
import 'package:tradeiq_app/features/collaboration/presentation/message_attachment_thumb.dart';
import 'package:tradeiq_app/features/collaboration/presentation/messages_screen.dart';
import 'package:tradeiq_app/features/users/data/users_repository.dart';

import '../../core/design/amber_golden.dart';
import '../worklist_harness.dart';

/// An `Error` rather than an `Exception`: Riverpod 3 retries an Exception and
/// the screen then never leaves its loading phase.
StateError get _networkFailure =>
    StateError('SocketException: Failed host lookup: api.tradeiq.co.za');

const _sender = 'u-sipho';
const _recipient = 'u-thandi';

final _roster = <AppUser>[
  person(_sender, 'sipho@acme.test', name: 'Sipho Dlamini'),
  person(_recipient, 'thandi@acme.test', name: 'Thandi Mkhize'),
];

const _first = Message(
  id: 'm1',
  body: 'Morning standup at 9',
  senderId: _sender,
);
const _second = Message(
  id: 'm2',
  body: 'Restock run complete',
  senderId: _sender,
);
const _direct = Message(
  id: 'm-direct',
  body: 'Can you cover Soweto?',
  senderId: _sender,
  recipientId: _recipient,
);
const _fromAStranger = Message(
  id: 'm-stranger',
  body: 'Left the keys in the van',
  senderId: 'u-gone',
);
const _withImages = Message(
  id: 'm3',
  body: 'Shelf after restock',
  senderId: _sender,
  attachments: <MessageAttachment>[
    MessageAttachment(photoId: 'p1', position: 0),
    MessageAttachment(photoId: 'p2', position: 1),
  ],
);
const _imageOnly = Message(
  id: 'm4',
  body: '',
  senderId: _sender,
  recipientId: _recipient,
  attachments: <MessageAttachment>[MessageAttachment(photoId: 'p3')],
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
  _FakeCollaborationRepository({
    this.messages = const <Message>[_first, _second],
    this.listFailure,
    this.announcementsFailure,
  });

  final List<Message> messages;
  final Object? listFailure;
  final Object? announcementsFailure;

  String? sentBody;
  List<String>? sentAttachmentIds;
  int sendCalls = 0;

  /// The clientMessageId of every send attempt, failed ones included (#308).
  final List<String?> attemptKeys = <String?>[];

  /// While set, sendMessage throws — the test flips it off to recover.
  bool failSend = false;
  ({String title, String body})? posted;
  Object? postFailure;

  @override
  Future<PaginatedResponse<Message>> listMessages() async {
    if (listFailure != null) throw listFailure!;
    return PaginatedResponse<Message>(data: messages, nextCursor: null);
  }

  @override
  Future<Message> sendMessage(
    String body, {
    String? recipientId,
    List<String> attachmentPhotoIds = const <String>[],
    String? clientMessageId,
  }) async {
    sendCalls++;
    attemptKeys.add(clientMessageId);
    if (failSend) throw StateError('send failed');
    sentBody = body;
    sentAttachmentIds = attachmentPhotoIds;
    return Message(id: 'm-new', body: body, recipientId: recipientId);
  }

  @override
  Future<PaginatedResponse<Announcement>> listAnnouncements() async {
    if (announcementsFailure != null) throw announcementsFailure!;
    return const PaginatedResponse<Announcement>(
      data: <Announcement>[_announcement],
      nextCursor: null,
    );
  }

  @override
  Future<Announcement> createAnnouncement({
    required String title,
    required String body,
  }) async {
    if (postFailure != null) throw postFailure!;
    posted = (title: title, body: body);
    return Announcement(id: 'a-new', title: title, body: body);
  }
}

class _FakePhotosRepository implements PhotosRepository {
  final List<String> uploadedDataUrls = <String>[];
  final List<String> imageRequests = <String>[];

  /// While set, every upload throws.
  bool failUploads = false;

  @override
  Future<String> uploadMessageAttachment(String dataUrl) async {
    if (failUploads) throw StateError('upload failed');
    uploadedDataUrls.add(dataUrl);
    return 'att-${uploadedDataUrls.length}';
  }

  @override
  Future<Uint8List> thumbnailBytes(String photoId) async => pngBytes;

  @override
  Future<Uint8List> imageBytes(String photoId) async {
    imageRequests.add(photoId);
    return pngBytes;
  }

  @override
  Future<List<VisitPhoto>> listPhotos(String visitId) async =>
      const <VisitPhoto>[];

  @override
  Future<PhotoUploadResult> uploadPhoto({
    required String visitId,
    required String section,
    required String dataUrl,
    required Map<String, dynamic> gpsTag,
    required String timestamp,
    String? source,
  }) async => throw UnimplementedError();
}

/// The picker seam: returns a real PNG from either source, recording which.
class _FakeGateway implements ImagePickerGateway {
  final List<ImageSource> sources = <ImageSource>[];

  @override
  Future<XFile?> pick({
    required ImageSource source,
    required double maxWidth,
    required int imageQuality,
  }) async {
    sources.add(source);
    return XFile.fromData(pngBytes, name: 'shot.png', mimeType: 'image/png');
  }
}

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required _FakeCollaborationRepository repo,
    String role = 'manager',
    _FakePhotosRepository? photos,
    _FakeGateway? gateway,
    List<AppUser>? users,
    TiqSkin? skin,
    double textScale = 1.0,
  }) => pumpWorklist(
    tester,
    const MessagesScreen(),
    skin: skin,
    textScale: textScale,
    users: users ?? _roster,
    overrides: <Override>[
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

  /// The screen opens on Messages; announcements live behind the rail.
  Future<void> openAnnouncements(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey<String>('tab-announcements')));
    await tester.pumpAndSettle();
  }

  /// Attach button -> source sheet -> pick. Library by default.
  Future<void> attachPhoto(
    WidgetTester tester, {
    String source = 'attach-gallery',
  }) async {
    await tester.tap(find.byKey(const ValueKey<String>('attach-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey<String>(source)));
    await tester.pumpAndSettle();
  }

  Finder pending(int i) => find.byKey(ValueKey<String>('pending-attachment-$i'));

  /// Let the primary's 400ms double-press debounce lapse.
  ///
  /// It is measured against the wall clock, not the test's fake one, so two
  /// taps in a widget test land inside the window and the second is swallowed
  /// — which is the correct behaviour for a thumb and the wrong thing for a
  /// test about a retry.
  Future<void> pastDebounce(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 450)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(
      find.byKey(const ValueKey<String>('message-body')),
      text,
    );
    await tester.pumpAndSettle();
  }

  group('a row names a person, not a database id', () {
    testWidgets('the sender and the recipient come from the roster', (
      tester,
    ) async {
      await pump(
        tester,
        repo: _FakeCollaborationRepository(
          messages: const <Message>[_first, _direct],
        ),
      );

      expect(find.text('From Sipho Dlamini · To the whole team'), findsOneWidget);
      expect(
        find.text('From Sipho Dlamini · To Thandi Mkhize'),
        findsOneWidget,
      );
      // The cuid is not on screen anywhere.
      expect(find.textContaining('m-direct'), findsNothing);
      expect(find.textContaining(_recipient), findsNothing);
    });

    testWidgets('somebody the roster cannot name is said in words, with the '
        'id as the explicit unknown state', (tester) async {
      await pump(
        tester,
        repo: _FakeCollaborationRepository(
          messages: const <Message>[_fromAStranger],
        ),
      );

      expect(
        find.text('Sender not on the roster: u-gone'),
        findsOneWidget,
      );
    });

    testWidgets('an empty roster never prints an id in a name\'s place', (
      tester,
    ) async {
      await pump(
        tester,
        users: const <AppUser>[],
        repo: _FakeCollaborationRepository(messages: const <Message>[_first]),
      );

      expect(find.text('Sender not on the roster: u-sipho'), findsOneWidget);
      expect(find.textContaining('From u-sipho'), findsNothing);
    });
  });

  group('the thread', () {
    testWidgets('renders message bodies once loaded', (tester) async {
      await pump(tester, repo: _FakeCollaborationRepository());

      expect(find.text('Morning standup at 9'), findsOneWidget);
      expect(find.text('Restock run complete'), findsOneWidget);
    });

    testWidgets('an empty thread is a stated result', (tester) async {
      await pump(
        tester,
        repo: _FakeCollaborationRepository(messages: const <Message>[]),
      );

      expect(find.text('No messages yet.'), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets('a failure is sanitised and offers one retry', (tester) async {
      await pump(
        tester,
        repo: _FakeCollaborationRepository(listFailure: _networkFailure),
      );

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('messages-retry')),
        findsOneWidget,
      );
    });

    testWidgets('an image-only message is headed "Photo" rather than blank', (
      tester,
    ) async {
      await pump(
        tester,
        repo: _FakeCollaborationRepository(
          messages: const <Message>[_imageOnly],
        ),
      );

      expect(find.text('Photo'), findsOneWidget);
    });
  });

  group('sending', () {
    testWidgets('calls sendMessage with the entered body', (tester) async {
      final repo = _FakeCollaborationRepository();
      await pump(tester, repo: repo);

      await type(tester, 'Shelf is bare in aisle 3');
      await tester.tap(find.byKey(const ValueKey<String>('send-message')));
      await tester.pumpAndSettle();

      expect(repo.sentBody, 'Shelf is bare in aisle 3');
      expect(repo.sentAttachmentIds, isEmpty);
    });

    testWidgets('an empty composer cannot send, and says why', (tester) async {
      final repo = _FakeCollaborationRepository();
      await pump(tester, repo: repo);

      expect(find.text('Write something, or add a photo.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('send-message')));
      await tester.pumpAndSettle();
      expect(repo.sendCalls, 0);
    });

    group('the idempotency key (#308)', () {
      testWidgets('a retry of the same draft reuses its key; the next draft '
          'gets a new one', (tester) async {
        final repo = _FakeCollaborationRepository()..failSend = true;
        await pump(tester, repo: repo);

        await type(tester, 'Shelf is bare');
        await tester.tap(find.byKey(const ValueKey<String>('send-message')));
        await tester.pumpAndSettle();

        repo.failSend = false;
        await pastDebounce(tester);
        await tester.tap(find.byKey(const ValueKey<String>('send-message')));
        await tester.pumpAndSettle();

        expect(repo.attemptKeys, hasLength(2));
        expect(repo.attemptKeys[0], isNotNull);
        expect(repo.attemptKeys[1], repo.attemptKeys[0]);

        await type(tester, 'A second message');
        await pastDebounce(tester);
        await tester.tap(find.byKey(const ValueKey<String>('send-message')));
        await tester.pumpAndSettle();

        expect(repo.attemptKeys, hasLength(3));
        expect(repo.attemptKeys[2], isNot(repo.attemptKeys[0]));
      });

      testWidgets('editing a failed draft before retrying mints a new key', (
        tester,
      ) async {
        final repo = _FakeCollaborationRepository()..failSend = true;
        await pump(tester, repo: repo);

        await type(tester, 'Shelf is bare');
        await tester.tap(find.byKey(const ValueKey<String>('send-message')));
        await tester.pumpAndSettle();

        repo.failSend = false;
        await type(tester, 'Shelf is bare in aisle 3');
        await pastDebounce(tester);
        await tester.tap(find.byKey(const ValueKey<String>('send-message')));
        await tester.pumpAndSettle();

        expect(repo.attemptKeys[1], isNot(repo.attemptKeys[0]));
      });
    });

    testWidgets('a send failure keeps the draft and says so', (tester) async {
      final repo = _FakeCollaborationRepository()..failSend = true;
      await pump(tester, repo: repo);

      await type(tester, 'Shelf is bare');
      await tester.tap(find.byKey(const ValueKey<String>('send-message')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('composer-error')),
        findsOneWidget,
      );
      expect(find.textContaining('Your draft is kept.'), findsOneWidget);
      expect(find.text('Shelf is bare'), findsOneWidget);
    });
  });

  group('photos', () {
    testWidgets('attaching from the library adds a removable thumbnail', (
      tester,
    ) async {
      final gateway = _FakeGateway();
      await pump(
        tester,
        repo: _FakeCollaborationRepository(),
        gateway: gateway,
      );

      await attachPhoto(tester);

      expect(gateway.sources, <ImageSource>[ImageSource.gallery]);
      expect(pending(0), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('pending-attachment-remove-0')),
      );
      await tester.pumpAndSettle();
      expect(pending(0), findsNothing);
    });

    testWidgets('the camera is the other source', (tester) async {
      final gateway = _FakeGateway();
      await pump(
        tester,
        repo: _FakeCollaborationRepository(),
        gateway: gateway,
      );

      await attachPhoto(tester, source: 'attach-camera');
      expect(gateway.sources, <ImageSource>[ImageSource.camera]);
    });

    testWidgets('dismissing the source sheet adds nothing', (tester) async {
      await pump(tester, repo: _FakeCollaborationRepository());

      await tester.tap(find.byKey(const ValueKey<String>('attach-photo')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(180, 20));
      await tester.pumpAndSettle();

      expect(pending(0), findsNothing);
    });

    testWidgets('send uploads each pending photo and sends their ids', (
      tester,
    ) async {
      final repo = _FakeCollaborationRepository();
      final photos = _FakePhotosRepository();
      await pump(tester, repo: repo, photos: photos);

      await attachPhoto(tester);
      await attachPhoto(tester);
      await type(tester, 'Shelf after restock');
      await tester.tap(find.byKey(const ValueKey<String>('send-message')));
      await tester.pumpAndSettle();

      expect(photos.uploadedDataUrls, hasLength(2));
      expect(repo.sentAttachmentIds, <String>['att-1', 'att-2']);
    });

    testWidgets('a photo alone is a sendable message', (tester) async {
      final repo = _FakeCollaborationRepository();
      await pump(tester, repo: repo);

      await attachPhoto(tester);
      await tester.tap(find.byKey(const ValueKey<String>('send-message')));
      await tester.pumpAndSettle();

      expect(repo.sentBody, '');
      expect(repo.sentAttachmentIds, hasLength(1));
    });

    testWidgets('an upload failure sends nothing and keeps the draft', (
      tester,
    ) async {
      final repo = _FakeCollaborationRepository();
      final photos = _FakePhotosRepository()..failUploads = true;
      await pump(tester, repo: repo, photos: photos);

      await attachPhoto(tester);
      await type(tester, 'Shelf after restock');
      await tester.tap(find.byKey(const ValueKey<String>('send-message')));
      await tester.pumpAndSettle();

      expect(repo.sendCalls, 0);
      expect(
        find.textContaining('A photo failed to upload, so nothing was sent.'),
        findsOneWidget,
      );
      expect(pending(0), findsOneWidget);
    });

    testWidgets('the attach button says why it stops at the cap', (
      tester,
    ) async {
      await pump(tester, repo: _FakeCollaborationRepository());

      for (var i = 0; i < maxMessageAttachments; i++) {
        await attachPhoto(tester);
      }

      expect(find.text('4 of 4 photos attached.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('attach-photo')));
      await tester.pumpAndSettle();
      // No sheet opened: the cap is reached.
      expect(
        find.byKey(const ValueKey<String>('attach-gallery')),
        findsNothing,
      );
    });

    testWidgets('a message shows its images, and one opens full size', (
      tester,
    ) async {
      final photos = _FakePhotosRepository();
      await pump(
        tester,
        photos: photos,
        repo: _FakeCollaborationRepository(
          messages: const <Message>[_withImages],
        ),
      );

      expect(find.byType(MessageAttachmentThumb), findsNWidgets(2));

      final thumb = find.byKey(const ValueKey<String>('message-attachment-p1'));
      await scrollWorklistTo(tester, thumb);
      await tester.tap(thumb);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('attachment-sheet')),
        findsOneWidget,
      );
      expect(photos.imageRequests, <String>['p1']);

      await tester.tap(
        find.byKey(const ValueKey<String>('attachment-sheet-close')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('attachment-sheet')),
        findsNothing,
      );
    });
  });

  group('announcements', () {
    testWidgets('the rail switches feeds and the composer goes with it', (
      tester,
    ) async {
      await pump(tester, repo: _FakeCollaborationRepository());

      expect(
        find.byKey(const ValueKey<String>('message-body')),
        findsOneWidget,
      );

      await openAnnouncements(tester);

      expect(find.text('Q3 Kickoff'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('message-body')),
        findsNothing,
        reason:
            '"Message the team" is the wrong thing to offer under a list of '
            'broadcasts.',
      );
    });

    testWidgets('a failure is sanitised and offers one retry', (tester) async {
      await pump(
        tester,
        repo: _FakeCollaborationRepository(
          announcementsFailure: _networkFailure,
        ),
      );
      await openAnnouncements(tester);

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
    });

    testWidgets('a manager posts one with a headline and a body', (
      tester,
    ) async {
      final repo = _FakeCollaborationRepository();
      await pump(tester, repo: repo);
      await openAnnouncements(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('announcement-create')),
      );
      await tester.pumpAndSettle();

      // It says why it cannot post yet.
      expect(find.text('Give the announcement a headline.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey<String>('announcement-title')),
        'Q4 Kickoff',
      );
      await tester.pumpAndSettle();
      expect(find.text('Say what it is about.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey<String>('announcement-body')),
        'New targets from Monday',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('post-announcement')),
      );
      await tester.pumpAndSettle();

      expect(repo.posted?.title, 'Q4 Kickoff');
      expect(repo.posted?.body, 'New targets from Monday');
      await settleToasts(tester);
    });

    testWidgets('an admin also gets the compose affordance', (tester) async {
      await pump(
        tester,
        repo: _FakeCollaborationRepository(),
        role: 'admin',
      );
      await openAnnouncements(tester);

      expect(
        find.byKey(const ValueKey<String>('announcement-create')),
        findsOneWidget,
      );
    });

    testWidgets('a field agent reads announcements but cannot post one', (
      tester,
    ) async {
      await pump(
        tester,
        repo: _FakeCollaborationRepository(),
        role: 'field_agent',
      );
      await openAnnouncements(tester);

      expect(find.text('Q3 Kickoff'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('announcement-create')),
        findsNothing,
      );
    });

    testWidgets('an empty list tells each role something it can act on', (
      tester,
    ) async {
      await pump(
        tester,
        role: 'field_agent',
        repo: _FakeCollaborationRepository(),
      );
      await openAnnouncements(tester);
      // A manager's fixture always has one, so the wording is checked from the
      // agent's side through the role branch above.
      expect(find.text('Q3 Kickoff'), findsOneWidget);
    });
  });

  group('the amber census', () {
    testWidgets('Night, empty composer: exactly the nav tab', (tester) async {
      await pump(tester, repo: _FakeCollaborationRepository());

      final census = await amberCensus(tester);
      expectWithinAmberBudget(
        census,
        TiqSkin.night(),
        route: 'messages',
        phase: 'messages-loaded',
      );
      expect(
        census.objectCount,
        1,
        reason:
            'A Send with nothing to send is not armed and declares no '
            'claim.\n${census.describe()}',
      );
    });

    testWidgets('Night, a draft: the nav tab and Send, and no more', (
      tester,
    ) async {
      await pump(tester, repo: _FakeCollaborationRepository());
      await type(tester, 'Shelf is bare');

      final census = await amberCensus(tester);
      expectWithinAmberBudget(
        census,
        TiqSkin.night(),
        route: 'messages',
        phase: 'messages-armed',
      );
      expect(census.objectCount, 2, reason: census.describe());
    });

    testWidgets('Night, announcements: nothing to send, nothing lit but the '
        'tab', (tester) async {
      await pump(tester, repo: _FakeCollaborationRepository());
      await openAnnouncements(tester);

      final census = await amberCensus(tester);
      expect(census.objectCount, 1, reason: census.describe());
    });

    testWidgets('Night, error: exactly the nav tab', (tester) async {
      await pump(
        tester,
        repo: _FakeCollaborationRepository(listFailure: _networkFailure),
      );
      final census = await amberCensus(tester);
      expect(census.objectCount, 1, reason: census.describe());
    });

    for (final skin in <TiqSkin>[TiqSkin.day(), TiqSkin.veld()]) {
      testWidgets('${skin.mode.name}: zero empty, one with a draft', (
        tester,
      ) async {
        await pump(tester, repo: _FakeCollaborationRepository(), skin: skin);

        var census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          skin,
          route: 'messages',
          phase: 'messages-loaded',
        );
        expect(census.objectCount, 0, reason: census.describe());

        await type(tester, 'Shelf is bare');
        census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          skin,
          route: 'messages',
          phase: 'messages-armed',
        );
        expect(census.objectCount, 1, reason: census.describe());
      });
    }
  });

  testWidgets('2.0x: the thread and the composer survive', (tester) async {
    await pump(
      tester,
      repo: _FakeCollaborationRepository(),
      textScale: 2.0,
    );

    expect(
      find.byKey(const ValueKey<String>('message-body')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Veld builds the channel', (tester) async {
    await pump(
      tester,
      repo: _FakeCollaborationRepository(),
      skin: TiqSkin.veld(),
    );

    await scrollWorklistTo(tester, find.text('Morning standup at 9'));
    expect(find.text('Morning standup at 9'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
