import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/theme/tiq_geometry.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../data/collaboration_repository.dart';

/// The team channel. Two feeds live here, and a segmented control switches
/// between them rather than stacking them:
///
/// * **Messages** are a conversation — the page ends in a composer that is
///   always reachable, because reading the thread and answering it are the same
///   task.
/// * **Announcements** are a broadcast — read-only for most of the team, and
///   written by a manager through a deliberate title+body form, not a one-line
///   composer.
///
/// Stacking the two would leave the message composer pinned under a list of
/// announcements, where "Message the team" is the wrong thing to offer. The
/// segment lets each feed own its compose affordance instead.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

enum _Feed { messages, announcements }

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final _bodyCtrl = TextEditingController();
  _Feed _feed = _Feed.messages;

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

  Future<void> _compose() async {
    final draft = await showDialog<({String title, String body})>(
      context: context,
      builder: (context) => const _AnnouncementDialog(),
    );
    if (draft == null) return;
    await ref
        .read(collaborationRepositoryProvider)
        .createAnnouncement(title: draft.title, body: draft.body);
    if (mounted) ref.invalidate(announcementsListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(sessionControllerProvider).value?.role;
    // POST /announcements is requireRole('manager', 'admin') — the compose
    // affordance follows the endpoint exactly, so nobody is offered a button
    // that would come back 403.
    final canAnnounce = role == 'manager' || role == 'admin';
    final onAnnouncements = _feed == _Feed.announcements;

    return ManagerScaffold(
      title: 'Messages',
      floatingActionButton: onAnnouncements && canAnnounce
          ? FloatingActionButton(
              key: const ValueKey<String>('announcement-create-fab'),
              tooltip: 'New announcement',
              onPressed: _compose,
              child: const Icon(Icons.campaign_outlined),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FilterRow(
                  children: [
                    const SectionLabel('View'),
                    _Segmented<_Feed>(
                      segments: const [
                        (label: 'Messages', value: _Feed.messages),
                        (label: 'Announcements', value: _Feed.announcements),
                      ],
                      selected: _feed,
                      onChanged: (f) => setState(() => _feed = f),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (onAnnouncements)
                  AsyncSection<List<Announcement>>(
                    value: ref.watch(announcementsListProvider),
                    label: 'announcements',
                    onRetry: () => ref.invalidate(announcementsListProvider),
                    builder: (list) => _AnnouncementList(
                      announcements: list,
                      canAnnounce: canAnnounce,
                    ),
                  )
                else
                  AsyncSection<List<Message>>(
                    value: ref.watch(messagesProvider),
                    label: 'messages',
                    onRetry: () => ref.invalidate(messagesProvider),
                    builder: (list) => _MessageList(messages: list),
                  ),
              ],
            ),
          ),
          // The composer belongs to the conversation, not to the broadcast.
          if (!onAnnouncements) _Composer(controller: _bodyCtrl, onSend: _send),
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

class _AnnouncementList extends StatelessWidget {
  const _AnnouncementList({
    required this.announcements,
    required this.canAnnounce,
  });

  final List<Announcement> announcements;
  final bool canAnnounce;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      title: '${announcements.length} '
          '${announcements.length == 1 ? 'announcement' : 'announcements'}',
      subtitle: 'Broadcast to the whole client',
      padded: false,
      child: announcements.isEmpty
          ? EmptyState(
              message: 'No announcements yet',
              // The hint tells you what to do only if you are allowed to do it.
              hint: canAnnounce
                  ? 'Post one and every user on this client sees it.'
                  : 'Your managers post here when something affects everyone.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final a in announcements)
                  _AnnouncementRow(announcement: a),
              ],
            ),
    );
  }
}

class _AnnouncementRow extends StatelessWidget {
  const _AnnouncementRow({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    return WorklistRow(
      key: ValueKey('announcement-${announcement.id}'),
      // The title is the headline; the body is what it actually says.
      title: announcement.title,
      meta: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CodeToken(announcement.id),
          const SizedBox(width: 6),
          const Text('·'),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              announcement.body,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      // An announcement has no severity — it is a notice, not an incident.
      level: StatusLevel.neutral,
      statusLabel: 'Announcement',
    );
  }
}

/// Title *and* body, because the endpoint requires both and rejects a blank
/// either way. Post stays disabled until both are non-empty, so the 400 is
/// unreachable from the UI.
class _AnnouncementDialog extends StatefulWidget {
  const _AnnouncementDialog();

  @override
  State<_AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<_AnnouncementDialog> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _post() {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) return;
    Navigator.of(context).pop((title: title, body: body));
  }

  @override
  Widget build(BuildContext context) {
    final ready = _titleCtrl.text.trim().isNotEmpty &&
        _bodyCtrl.text.trim().isNotEmpty;

    final c = context.colors;
    return AlertDialog(
      backgroundColor: c.surface1,
      title: const Text('New announcement', style: TextStyle(fontSize: 15)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey<String>('announcement-title'),
            controller: _titleCtrl,
            autofocus: true,
            style: TextStyle(fontSize: 13, color: c.ink1),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Title',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('announcement-body'),
            controller: _bodyCtrl,
            maxLines: 4,
            style: TextStyle(fontSize: 13, color: c.ink1),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Body',
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey<String>('post-announcement'),
          onPressed: ready ? _post : null,
          child: const Text('Post'),
        ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: c.surface1,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey<String>('message-body'),
              controller: controller,
              style: TextStyle(fontSize: 13, color: c.ink1),
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Message the team',
                isDense: true,
                filled: true,
                fillColor: c.surface2,
                hintStyle: TextStyle(fontSize: 13, color: c.ink3),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            key: const ValueKey<String>('send-message'),
            icon: const Icon(Icons.send, size: 18),
            color: c.ink1,
            tooltip: 'Send',
            onPressed: onSend,
          ),
        ],
      ),
    );
  }
}

/// The console's segmented switch, as used by Alerts and Tasks.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<({String label, T value})> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: c.lineStrong),
        borderRadius: BorderRadius.circular(TiqGeometry.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < segments.length; i++)
            InkWell(
              key: ValueKey('tab-${segments[i].value}'),
              onTap: () => onChanged(segments[i].value),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: segments[i].value == selected
                      ? c.surface3
                      : Colors.transparent,
                  border: Border(
                    right: BorderSide(
                      color: i == segments.length - 1
                          ? Colors.transparent
                          : c.lineStrong,
                    ),
                  ),
                ),
                child: Text(
                  segments[i].label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: segments[i].value == selected
                        ? c.ink1
                        : c.ink2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
