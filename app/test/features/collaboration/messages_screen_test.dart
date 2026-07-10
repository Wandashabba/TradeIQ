import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/collaboration/data/collaboration_repository.dart';
import 'package:tradeiq_app/features/collaboration/presentation/messages_screen.dart';

const _first = Message(id: 'm1', body: 'Morning standup at 9');
const _second = Message(id: 'm2', body: 'Restock run complete');

class _FakeCollaborationRepository implements CollaborationRepository {
  String? sentBody;

  @override
  Future<List<Message>> listMessages() async => const [_first, _second];

  @override
  Future<Message> sendMessage(String body, {String? recipientId}) async {
    sentBody = body;
    return Message(id: 'm-new', body: body, recipientId: recipientId);
  }

  @override
  Future<List<Announcement>> listAnnouncements() async => const [];
}

class _ThrowingCollaborationRepository implements CollaborationRepository {
  @override
  Future<List<Message>> listMessages() async => throw Exception('boom');

  @override
  Future<Message> sendMessage(String body, {String? recipientId}) async =>
      throw Exception('boom');

  @override
  Future<List<Announcement>> listAnnouncements() async => throw Exception('boom');
}

Widget _app(CollaborationRepository repo) => ProviderScope(
      overrides: [
        collaborationRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: MessagesScreen()),
    );

void main() {
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
}
