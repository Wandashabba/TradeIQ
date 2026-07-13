import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../data/collaboration_repository.dart';

/// The team channel. A worklist above, a composer pinned below it — the
/// composer is the one thing on the page that is always reachable, because
/// reading the thread and answering it are the same task.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final _bodyCtrl = TextEditingController();

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty) return;
    await ref.read(collaborationRepositoryProvider).sendMessage(body);
    if (mounted) {
      _bodyCtrl.clear();
      ref.invalidate(messagesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider);

    return ManagerScaffold(
      title: 'Messages',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AsyncSection<List<Message>>(
                  value: messages,
                  label: 'messages',
                  onRetry: () => ref.invalidate(messagesProvider),
                  builder: (list) => _MessageList(messages: list),
                ),
              ],
            ),
          ),
          _Composer(controller: _bodyCtrl, onSend: _send),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.messages});

  final List<Message> messages;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      title:
          '${messages.length} ${messages.length == 1 ? 'message' : 'messages'}',
      subtitle: 'Everything the team can see',
      padded: false,
      child: messages.isEmpty
          ? const EmptyState(
              message: 'No messages yet',
              hint: 'Anything you send below reaches the whole team.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [for (final m in messages) _MessageRow(message: m)],
            ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final direct = message.recipientId != null;

    return WorklistRow(
      key: ValueKey('message-${message.id}'),
      title: message.body,
      // The id is machine-facing — a manager quoting a message in a bug report
      // wants the thing the system knows it by.
      meta: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CodeToken(message.id),
          if (direct) ...[
            const SizedBox(width: 6),
            const Text('·'),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'To ${message.recipientId}',
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
      // A message has no severity, so it carries one hue and one hue only.
      level: StatusLevel.neutral,
      statusLabel: direct ? 'Direct' : 'Broadcast',
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey<String>('message-body'),
              controller: controller,
              style: const TextStyle(fontSize: 13, color: AppColors.ink1),
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: 'Message the team',
                isDense: true,
                filled: true,
                fillColor: AppColors.surface2,
                hintStyle: TextStyle(fontSize: 13, color: AppColors.ink3),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            key: const ValueKey<String>('send-message'),
            icon: const Icon(Icons.send, size: 18),
            color: AppColors.ink1,
            tooltip: 'Send',
            onPressed: onSend,
          ),
        ],
      ),
    );
  }
}
