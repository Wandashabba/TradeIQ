import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/camera/photo_capture_service.dart';
import '../../../core/network/human_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../../audit/data/photos_repository.dart';
import '../data/collaboration_repository.dart';
import 'message_attachment_thumb.dart';

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

/// A photo picked for the draft but not yet sent (#125).
///
/// Uploaded at SEND time, not at pick time, so an abandoned draft leaves
/// nothing on the server. Once an upload succeeds its [photoId] is kept: if
/// the send then fails, retrying does not upload the same photo twice.
class _PendingAttachment {
  _PendingAttachment(this.dataUrl) : bytes = _decode(dataUrl);

  final String dataUrl;

  /// Decoded once for the preview, not on every rebuild.
  final Uint8List? bytes;
  String? photoId;

  static Uint8List? _decode(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    if (comma == -1) return null;
    try {
      return base64Decode(dataUrl.substring(comma + 1));
    } on FormatException {
      return null;
    }
  }
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final _bodyCtrl = TextEditingController();
  _Feed _feed = _Feed.messages;

  final _pending = <_PendingAttachment>[];
  bool _sending = false;
  String? _composerError;

  static const _uuid = Uuid();

  /// The idempotency key of the draft being sent (#308). Minted when Send is
  /// first pressed, kept across retries so a send whose response was lost is
  /// answered with the original message instead of a duplicate or a 409, and
  /// cleared once the send succeeds.
  String? _clientMessageId;

  /// What [_clientMessageId] was minted for: the body and the exact pending
  /// photos. If the sender edits either after a failed send, it is a different
  /// message — the server 409s a key reused for different content — so it
  /// gets a fresh key.
  ({String body, List<_PendingAttachment> photos})? _keyedDraft;

  bool _draftUnchangedSinceKeyed(String body) {
    final keyed = _keyedDraft;
    if (_clientMessageId == null || keyed == null || keyed.body != body) {
      return false;
    }
    if (keyed.photos.length != _pending.length) return false;
    for (var i = 0; i < _pending.length; i++) {
      if (!identical(keyed.photos[i], _pending[i])) return false;
    }
    return true;
  }

  String _keyFor(String body) {
    if (!_draftUnchangedSinceKeyed(body)) {
      _clientMessageId = _uuid.v4();
      _keyedDraft = (body: body, photos: List.of(_pending));
    }
    return _clientMessageId!;
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  /// Pick or take a photo through the same [PhotoCaptureService] the audit
  /// flow uses — downscaled, encoded, and size-checked before it is ever sent.
  Future<void> _attach() async {
    if (_pending.length >= maxMessageAttachments || _sending) return;
    final source = await showModalBottomSheet<PhotoSource>(
      context: context,
      backgroundColor: context.colors.surface1,
      builder: (_) => const _AttachSourceSheet(),
    );
    if (source == null || !mounted) return;
    try {
      final photo = await ref.read(photoCaptureServiceProvider).capture(source);
      // A cancelled picker is a normal outcome — the draft stays as it was.
      if (photo == null || !mounted) return;
      setState(() {
        _pending.add(_PendingAttachment(photo.dataUrl));
        _composerError = null;
      });
    } on PhotoTooLargeException catch (e) {
      if (mounted) setState(() => _composerError = e.toString());
    } catch (_) {
      // Denied camera permission lands here. Say so rather than doing nothing.
      if (mounted) {
        setState(
          () => _composerError =
              'Could not add a photo. Check camera and photo permissions.',
        );
      }
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _pending.removeAt(index);
      _composerError = null;
    });
  }

  Future<void> _send() async {
    final body = _bodyCtrl.text.trim();
    if (_sending || (body.isEmpty && _pending.isEmpty)) return;
    setState(() {
      _sending = true;
      _composerError = null;
    });
    final clientMessageId = _keyFor(body);

    // Upload whatever has not made it yet. On failure nothing is sent, and the
    // draft — words and photos — stays exactly where the sender left it.
    final photos = ref.read(photosRepositoryProvider);
    for (final attachment in _pending) {
      if (attachment.photoId != null) continue;
      try {
        attachment.photoId = await photos.uploadMessageAttachment(
          attachment.dataUrl,
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _sending = false;
          _composerError =
              'A photo failed to upload, so nothing was sent. '
              '${humanErrorMessage(e)} Your draft is kept.';
        });
        return;
      }
    }

    try {
      await ref
          .read(collaborationRepositoryProvider)
          .sendMessage(
            body,
            attachmentPhotoIds: [for (final a in _pending) a.photoId!],
            clientMessageId: clientMessageId,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _composerError =
            'Message not sent. ${humanErrorMessage(e)} Your draft is kept.';
      });
      return;
    }

    if (!mounted) return;
    _bodyCtrl.clear();
    setState(() {
      _pending.clear();
      _sending = false;
      // Sent: the next message is a new one and gets its own key.
      _clientMessageId = null;
      _keyedDraft = null;
    });
    ref.invalidate(messagesProvider);
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
          if (!onAnnouncements)
            _Composer(
              controller: _bodyCtrl,
              onSend: _send,
              onAttach: _attach,
              onRemove: _removeAttachment,
              pending: _pending,
              sending: _sending,
              error: _composerError,
            ),
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
    final images = message.attachments;
    // An image can be the whole message; the row still needs a headline.
    final title = message.body.trim().isNotEmpty
        ? message.body
        : images.length == 1
        ? 'Photo'
        : '${images.length} photos';

    final metaLine = Row(
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
    );

    return WorklistRow(
      key: ValueKey('message-${message.id}'),
      title: title,
      // The id is machine-facing — a manager quoting a message in a bug report
      // wants the thing the system knows it by. The images sit under it, inside
      // the same tile, so they read as part of this message and no other.
      meta: images.isEmpty
          ? metaLine
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                metaLine,
                const SizedBox(height: 8),
                Wrap(
                  key: ValueKey('message-attachments-${message.id}'),
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final a in images)
                      MessageAttachmentThumb(photoId: a.photoId),
                  ],
                ),
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
    final colors = context.colors;
    final ready = _titleCtrl.text.trim().isNotEmpty &&
        _bodyCtrl.text.trim().isNotEmpty;

    return AlertDialog(
      backgroundColor: colors.surface1,
      title: const Text('New announcement', style: TextStyle(fontSize: 15)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey<String>('announcement-title'),
            controller: _titleCtrl,
            autofocus: true,
            style: TextStyle(fontSize: 13, color: colors.ink1),
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
            style: TextStyle(fontSize: 13, color: colors.ink1),
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

/// Camera or library — the same two sources the guided audit capture offers.
class _AttachSourceSheet extends StatelessWidget {
  const _AttachSourceSheet();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget option(Key key, IconData icon, String label, PhotoSource source) =>
        ListTile(
          key: key,
          leading: Icon(icon, color: colors.ink2),
          title: Text(
            label,
            style: TextStyle(fontSize: 14, color: colors.ink1),
          ),
          onTap: () => Navigator.of(context).pop(source),
        );
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          option(
            const ValueKey<String>('attach-camera'),
            Icons.photo_camera_outlined,
            'Take photo',
            PhotoSource.camera,
          ),
          option(
            const ValueKey<String>('attach-gallery'),
            Icons.photo_library_outlined,
            'Choose from library',
            PhotoSource.gallery,
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.onAttach,
    required this.onRemove,
    required this.pending,
    required this.sending,
    required this.error,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final ValueChanged<int> onRemove;
  final List<_PendingAttachment> pending;
  final bool sending;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final iconInk = colors.glass ? context.lumen.accentInk : colors.ink1;
    final canAttach = !sending && pending.length < maxMessageAttachments;

    final field = Expanded(
      child: TextField(
        key: const ValueKey<String>('message-body'),
        controller: controller,
        style: TextStyle(fontSize: 13, color: colors.ink1),
        onSubmitted: (_) => onSend(),
        decoration: InputDecoration(
          hintText: 'Message the team',
          isDense: true,
          filled: true,
          // Opaque in both themes: the words and hint measure true however
          // the thread scrolls beneath a glass bar.
          fillColor: colors.surface2,
          hintStyle: TextStyle(fontSize: 13, color: colors.ink3),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
      ),
    );
    final attach = IconButton(
      key: const ValueKey<String>('attach-photo'),
      icon: const Icon(Icons.add_a_photo_outlined, size: 18),
      color: iconInk,
      tooltip: canAttach
          ? 'Attach photo'
          : 'Up to $maxMessageAttachments photos per message',
      onPressed: canAttach ? onAttach : null,
    );
    final send = IconButton(
      key: const ValueKey<String>('send-message'),
      icon: sending
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: iconInk),
            )
          : const Icon(Icons.send, size: 18),
      color: iconInk,
      tooltip: 'Send',
      onPressed: sending ? null : onSend,
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pending.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SingleChildScrollView(
              key: const ValueKey<String>('pending-attachments'),
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < pending.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _PendingThumb(
                        index: i,
                        attachment: pending[i],
                        onRemove: sending ? null : () => onRemove(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StatusChip(label: 'Not sent', level: StatusLevel.critical),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error!,
                    key: const ValueKey<String>('composer-error'),
                    style: TextStyle(fontSize: 11.5, color: colors.ink2),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [attach, const SizedBox(width: 2), field, const SizedBox(width: 8), send],
        ),
      ],
    );

    // Glass: the composer floats as a bar over the thread, not a ruled footer.
    if (colors.glass) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: GlassPane(
          kind: GlassKind.bar,
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
          child: content,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: content,
    );
  }
}

/// A picked photo waiting in the draft: what will be sent, and a way to take it
/// back out before it is.
class _PendingThumb extends StatelessWidget {
  const _PendingThumb({
    required this.index,
    required this.attachment,
    required this.onRemove,
  });

  static const double size = 56;

  final int index;
  final _PendingAttachment attachment;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(
      colors.glass ? LumenGlass.radiusControl - 4 : AppColors.radiusControl,
    );
    final broken = Container(
      width: size,
      height: size,
      color: colors.surface2,
      alignment: Alignment.center,
      child: Icon(Icons.broken_image_outlined, size: 18, color: colors.ink3),
    );
    final bytes = attachment.bytes;

    Widget photo = ClipRRect(
      borderRadius: radius,
      child: bytes == null
          ? broken
          : Image.memory(
              bytes,
              key: ValueKey('pending-attachment-$index'),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => broken,
            ),
    );
    if (colors.glass) {
      // Glass frames the photo — a rim over its edge — and never tints it.
      photo = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: context.lumen.tileRim),
        ),
        child: photo,
      );
    }

    return Semantics(
      label: 'Photo ${index + 1} ready to send',
      image: true,
      child: SizedBox(
        width: size + 8,
        height: size + 8,
        child: Stack(
          children: [
            Positioned(left: 0, bottom: 0, child: photo),
            Positioned(
              right: 0,
              top: 0,
              child: Material(
                color: colors.surface1,
                shape: CircleBorder(side: BorderSide(color: colors.line)),
                child: InkWell(
                  key: ValueKey('pending-attachment-remove-$index'),
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: Tooltip(
                    message: 'Remove photo',
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Icon(Icons.close, size: 14, color: colors.ink1),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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

  /// Glass: a bar track with the selected segment lifted onto a bright pill —
  /// the dashboard filter bar's idiom. Both states share one padding (a
  /// pane's rim paints over its edge, it adds no size), so a tap never
  /// shifts the row.
  Widget _glass() {
    const pad = EdgeInsets.symmetric(horizontal: 11, vertical: 5);
    const inner = LumenGlass.radiusControl - 3;
    return GlassPane(
      kind: GlassKind.bar,
      radius: LumenGlass.radiusControl,
      blur: false,
      shadow: false,
      specular: false,
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in segments)
            InkWell(
              key: ValueKey('tab-${s.value}'),
              onTap: () => onChanged(s.value),
              borderRadius: BorderRadius.circular(inner),
              child: s.value == selected
                  ? GlassPane(
                      kind: GlassKind.pill,
                      radius: inner,
                      padding: pad,
                      child: _GlassSegmentLabel(s.label, selected: true),
                    )
                  : Padding(
                      padding: pad,
                      child: _GlassSegmentLabel(s.label, selected: false),
                    ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (colors.glass) return _glass();
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colors.lineStrong),
        borderRadius: BorderRadius.circular(AppColors.radiusControl),
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
                      ? colors.surface3
                      : Colors.transparent,
                  border: Border(
                    right: BorderSide(
                      color: i == segments.length - 1
                          ? Colors.transparent
                          : colors.lineStrong,
                    ),
                  ),
                ),
                child: Text(
                  segments[i].label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: segments[i].value == selected
                        ? colors.ink1
                        : colors.ink2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A glass segment's words: ink when selected, the muted ink otherwise — both
/// clear 4.5:1 on the bar, and the lifted pill carries the state as well.
class _GlassSegmentLabel extends StatelessWidget {
  const _GlassSegmentLabel(this.label, {required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: selected ? context.lumen.ink : context.lumen.inkMuted,
    ),
  );
}
