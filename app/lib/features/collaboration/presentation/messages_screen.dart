import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/manager_scaffold.dart';
import '../data/collaboration_repository.dart';

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
        children: [
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Failed to load messages: $err'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(messagesProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (list) => ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, index) => Card(
                  child: ListTile(title: Text(list[index].body)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey<String>('message-body'),
                    controller: _bodyCtrl,
                    decoration: const InputDecoration(hintText: 'Message the team'),
                  ),
                ),
                IconButton(
                  key: const ValueKey<String>('send-message'),
                  icon: const Icon(Icons.send),
                  onPressed: _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
