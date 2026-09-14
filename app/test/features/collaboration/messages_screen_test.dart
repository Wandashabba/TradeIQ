import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/features/collaboration/data/collaboration_repository.dart';
import 'package:tradeiq_app/features/collaboration/presentation/messages_screen.dart';

import '../../core/theme/tiq_colors_test.dart' show contrastRatio;
import '../../helpers/routed_app.dart';

const _first = Message(id: 'm1', body: 'Morning standup at 9');
const _second = Message(id: 'm2', body: 'Restock run complete');

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
  String? sentBody;
  ({String title, String body})? posted;

  @override
  Future<PaginatedResponse<Message>> listMessages() async =>
      const PaginatedResponse(data: [_first, _second], nextCursor: null);

  @override
  Future<Message> sendMessage(String body, {String? recipientId}) async {
    sentBody = body;
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
  Future<Message> sendMessage(String body, {String? recipientId}) async =>
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

Widget _app(
  CollaborationRepository repo, {
  String role = 'manager',
  ThemeData? theme,
}) => routedApp(
      const MessagesScreen(),
      theme: theme,
      overrides: [
        collaborationRepositoryProvider.overrideWithValue(repo),
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
  });

  testWidgets('shows an error message when the list fails to load',
      (tester) async {
    await tester.pumpWidget(_app(_ThrowingCollaborationRepository()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load messages'), findsOneWidget);
  });

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
