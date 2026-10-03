import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/camera/photo_capture_service.dart';
import '../../../core/design/torch_scope.dart';
import '../../../core/network/paginated_response.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_desk.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/console_record.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../../audit/data/photos_repository.dart';
import '../../users/data/users_repository.dart';
import '../data/collaboration_repository.dart';
import 'message_attachment_thumb.dart';

/// THE TEAM CHANNEL — two feeds, one rail, one composer.
///
/// * **Messages** are a conversation, so the route ends in a composer that is
///   always reachable: reading the thread and answering it are one task.
/// * **Announcements** are a broadcast — read-only for most of the team, and
///   written by a manager through a deliberate title-and-body sheet rather
///   than a one-line composer.
///
/// Stacking the two would leave "Message the team" pinned under a list of
/// announcements. The rail lets each feed own its compose affordance instead.
///
/// ## A row names a person
///
/// The old row printed `cmf3k9…` as the message's meta and "To cmf3k9…" beside
/// it. A cuid is not a person. The roster names the sender and the recipient,
/// and where it cannot — a deleted account, a roster that has not loaded — the
/// row says so **in words** and shows the id in the identifier face as the
/// explicit unknown state, which is the one place an id belongs (unify §1.15).
/// The id is still reachable: a long press copies it.
///
/// ## Amber, counted, with and without the keyboard
///
/// Night's budget is two either way, and the composer is why the rule about
/// the keyboard exists. With the keyboard down: the nav's active tab is slot 1
/// and Send is slot 2. With it up the nav does not render, and the grant it was
/// holding pays for the focused field's rule — so a focused composer plus a lit
/// Send is exactly two, not three. Day lights Send alone, and **zero**
/// when the draft is empty: a Send with nothing to send is not armed.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

enum _Feed { messages, announcements }

/// The id the composer's Send claims under.
const String messageSendClaimId = 'send-message';

/// A photo picked for the draft but not yet sent (#125).
///
/// Uploaded at SEND time, not at pick time, so an abandoned draft leaves
/// nothing on the server. Once an upload succeeds its [photoId] is kept: if
/// the send then fails, retrying does not upload the same photo twice.
class PendingAttachment {
  PendingAttachment(this.dataUrl) : bytes = _decode(dataUrl);

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
  final _body = TextEditingController();
  _Feed _feed = _Feed.messages;

  final List<PendingAttachment> _pending = <PendingAttachment>[];
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
  ({String body, List<PendingAttachment> photos})? _keyedDraft;

  @override
  void initState() {
    super.initState();
    _body.addListener(_draftChanged);
  }

  void _draftChanged() {
    // The Send claim follows the draft, so an empty composer paints no amber.
    if (mounted) setState(() {});
  }

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
      _keyedDraft = (body: body, photos: List<PendingAttachment>.of(_pending));
    }
    return _clientMessageId!;
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  bool get _hasDraft =>
      _body.text.trim().isNotEmpty || _pending.isNotEmpty;

  /// Pick or take a photo through the same [PhotoCaptureService] the audit
  /// flow uses — downscaled, encoded, and size-checked before it is ever sent.
  Future<void> _attach() async {
    if (_pending.length >= maxMessageAttachments || _sending) return;
    final source = await showTorchSheet<PhotoSource>(
      context,
      builder: (_) => const _AttachSourceSheet(),
    );
    if (source == null || !mounted) return;
    try {
      final photo = await ref.read(photoCaptureServiceProvider).capture(source);
      // A cancelled picker is a normal outcome — the draft stays as it was.
      if (photo == null || !mounted) return;
      setState(() {
        _pending.add(PendingAttachment(photo.dataUrl));
        _composerError = null;
      });
    } on PhotoTooLargeException catch (e) {
      if (mounted) setState(() => _composerError = e.toString());
    } catch (_) {
      // Denied camera permission lands here. Say so rather than doing nothing.
      if (mounted) {
        setState(() => _composerError = context.l10n.composerPhotoFailed);
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
    final l10n = context.l10n;
    final body = _body.text.trim();
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
          _composerError = l10n.composerUploadFailed(
            TorchErrorMessage.sanitise(e).body,
          );
        });
        return;
      }
    }

    try {
      await ref
          .read(collaborationRepositoryProvider)
          .sendMessage(
            body,
            attachmentPhotoIds: <String>[
              for (final a in _pending) a.photoId!,
            ],
            clientMessageId: clientMessageId,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _composerError = l10n.composerSendFailed(
          TorchErrorMessage.sanitise(e).body,
        );
      });
      return;
    }

    if (!mounted) return;
    _body.clear();
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
    final l10n = context.l10n;
    final draft = await showTorchSheet<({String title, String body})>(
      context,
      builder: (_) => const _AnnouncementSheet(),
    );
    if (draft == null || !mounted) return;
    try {
      await ref
          .read(collaborationRepositoryProvider)
          .createAnnouncement(title: draft.title, body: draft.body);
      if (!mounted) return;
      ref.invalidate(announcementsListProvider);
      showTorchToast(
        context,
        message: l10n.announcementPosted,
        kind: ToastKind.success,
      );
    } catch (error) {
      if (!mounted) return;
      showTorchToast(
        context,
        message: l10n.announcementPostFailed(
          TorchErrorMessage.sanitise(error).body,
        ),
        kind: ToastKind.failure,
      );
    }
  }

  void _refresh() {
    ref.invalidate(messagesProvider);
    ref.invalidate(announcementsListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final role = ref.watch(sessionControllerProvider).value?.role;
    // POST /announcements is requireRole('manager', 'admin') — the compose
    // affordance follows the endpoint exactly, so nobody is offered a button
    // that would come back 403.
    final canAnnounce = role == 'manager' || role == 'admin';
    final onAnnouncements = _feed == _Feed.announcements;
    final gutter = context.skin.space.gutter;
    final armed = _hasDraft && !_sending;

    final messages = ref.watch(messagesProvider);
    final announcements = ref.watch(announcementsListProvider);
    final feed = onAnnouncements ? announcements : messages;

    // WHICH FEED, as one object handed to both arms. The phone bleeds it out
    // to the window's gutter; the list pane supplies its own, so the pane is
    // given the identical rail un-bled.
    final feedRail = TorchFilterRail(
      semanticsLabel: l10n.messagesWhichFeed,
      chips: <Widget>[
        TorchFilterChip(
          key: const ValueKey<String>('tab-messages'),
          label: l10n.messagesTitle,
          // The tab's count is what is loaded, which is what the feed
          // below it shows — the footer is where "there are more" is
          // said, in words, rather than in a number that would then be
          // a different number from the list.
          count: messages.value == null
              ? null
              : messages.value!.data.length + _olderMessages.length,
          countLoading: messages.isLoading,
          selected: !onAnnouncements,
          onSelected: () => setState(() => _feed = _Feed.messages),
        ),
        TorchFilterChip(
          key: const ValueKey<String>('tab-announcements'),
          label: l10n.messagesFeedAnnouncements,
          count: announcements.value == null
              ? null
              : announcements.value!.data.length + _olderAnnouncements.length,
          countLoading: announcements.isLoading,
          selected: onAnnouncements,
          onSelected: () => setState(() => _feed = _Feed.announcements),
        ),
      ],
    );

    final compose = Align(
      alignment: AlignmentDirectional.centerStart,
      child: TorchSecondaryButton(
        key: const ValueKey<String>('announcement-create'),
        label: l10n.announcementNew,
        onPressed: _compose,
      ),
    );

    return ConsoleFrame(
      phase: onAnnouncements
          ? 'announcements-${_phaseOf(announcements)}'
          : 'messages-${_phaseOf(messages)}',
      // ── WHAT THE DESK GETS, AND THE ONE THING IT DROPS ──────────────────
      //
      // Null while a feed is loading and after it failed — a skeleton and an
      // error are not records — and non-null on every phase that has an
      // answer, **including an empty feed**: with no records the detail pane
      // already has words for that ("Nothing to read yet."), which is the same
      // arrangement `alerts_screen.dart` ships.
      //
      // Which feed is in `filters`, because it is this screen's rail and it
      // names and counts both slices — so the section markers are **not** in
      // `lead`, by the argument Alerts makes for dropping its own.
      //
      // ## THE DESK CURRENTLY DROPS THE TEAM COMPOSER, and that is a gap
      //
      // `band:` below is the composer, and `ConsoleFrame` passes `band` to the
      // phone arm only: `ConsoleDeskBody` takes a header, an ask bar, records
      // and children, and has **no slot for a pinned region of the screen's
      // own**. The composer is therefore absent above 1212dp, which means a
      // manager on a desktop can read the thread and cannot answer it — the
      // one capability this route exists for.
      //
      // It is left where it is rather than smuggled into `lead` or into a
      // record's pane. `lead` draws *above* the list, and a composer at the
      // top of the feed is not the composer; the detail pane is one message at
      // rest, and a composer there would post to the feed from a card about
      // somebody else's message. The honest fix is a `band`/composer slot on
      // `ConsoleDeskRecords` that lands at the foot of the LIST pane, which is
      // where the phone's band sits relative to its list — and that is a
      // change to the shared desk contract rather than to this screen, so it
      // is named here instead of invented.
      desk: switch (feed) {
        AsyncLoading<Object?>() || AsyncError<Object?>() => null,
        _ => onAnnouncements
            ? _announcementsDesk(
                announcements.value,
                filters: feedRail,
                compose: canAnnounce ? compose : null,
              )
            : _messagesDesk(messages.value, filters: feedRail),
      },
      claims: <TorchClaim>[
        if (!onAnnouncements && armed)
          TorchPrimaryButton.claim(messageSendClaimId),
      ],
      header: TorchAppHeader(
        title: l10n.messagesTitle,
        facts: <String>[l10n.messagesFact],
        trailing: TorchIconButton(
          key: const ValueKey<String>('messages-refresh'),
          icon: Icons.refresh,
          semanticLabel: l10n.messagesRefresh,
          onPressed: _refresh,
        ),
      ),
      // The composer belongs to the conversation, not to the broadcast.
      band: onAnnouncements
          ? null
          : _Composer(
              controller: _body,
              pending: _pending,
              sending: _sending,
              armed: armed,
              error: _composerError,
              onSend: _send,
              onAttach: _attach,
              onRemove: _removeAttachment,
            ),
      children: <Widget>[
        // THE SAME RAIL AND THE SAME BUTTON THE PANES HOLD, and the same
        // instances. Only one arm of `ConsoleFrame` is ever mounted.
        TorchBleed(child: feedRail),
        const SizedBox(height: TiqSpace.s6),

        if (onAnnouncements && canAnnounce) ...<Widget>[
          compose,
          const SizedBox(height: TiqSpace.s6),
        ],

        ...switch (feed) {
          AsyncLoading<Object?>() => <Widget>[
            Skeleton(
              label: onAnnouncements
                  ? l10n.announcementsSkeleton
                  : l10n.messagesSkeleton,
              child: const SkeletonRows(count: 4, rowHeight: 80),
            ),
          ],
          AsyncError<Object?>(:final error) => <Widget>[
            TorchErrorRegion(
              name: onAnnouncements
                  ? l10n.announcementsSkeleton
                  : l10n.messagesSkeleton,
              child: ErrorState(
                message: TorchErrorMessage.sanitise(error),
                action: TorchSecondaryButton(
                  key: const ValueKey<String>('messages-retry'),
                  label: l10n.torchTryAgain,
                  onPressed: _refresh,
                ),
              ),
            ),
          ],
          _ => onAnnouncements
              ? _announcements(
                  announcements.value,
                  canAnnounce: canAnnounce,
                  gutter: gutter,
                )
              : _messages(messages.value, gutter),
        },
      ],
    );
  }

  static String _phaseOf(AsyncValue<Object?> value) => switch (value) {
    AsyncLoading<Object?>() => 'loading',
    AsyncError<Object?>() => 'error',
    _ => 'loaded',
  };

  /// Pages two and on for each feed. Page one stays in its provider so a sent
  /// message still refreshes the list.
  final List<Message> _olderMessages = <Message>[];
  final List<Announcement> _olderAnnouncements = <Announcement>[];
  String? _messagesCursor;
  String? _announcementsCursor;
  bool _messagesCursorRead = false;
  bool _announcementsCursorRead = false;
  bool _feedLoading = false;
  bool _feedFailed = false;

  Future<void> _loadOlder(Future<void> Function() fetch) async {
    setState(() {
      _feedLoading = true;
      _feedFailed = false;
    });
    try {
      await fetch();
      if (!mounted) return;
      setState(() => _feedLoading = false);
    } on Object {
      if (!mounted) return;
      // What is on screen stays. A failed *next* page is not a failed feed.
      setState(() {
        _feedLoading = false;
        _feedFailed = true;
      });
    }
  }

  /// The footer under a feed that was cut, and the way on.
  ///
  /// The count beside each section marker was the length of page one, so a
  /// manager read the size of a page as the size of the feed. On a feed of
  /// direct messages that is the worst version of this defect in the app: the
  /// thing that goes missing is somebody asking you for something.
  ///
  /// Never a fabricated total — the server returns a cursor, not a count.
  List<Widget> _feedFooter({
    required String? next,
    required String summary,
    required String action,
    required ValueKey<String> key,
    required VoidCallback onPressed,
  }) {
    final bar = _feedFooterBar(
      next: next,
      summary: summary,
      action: action,
      key: key,
      onPressed: onPressed,
    );
    if (bar == null) return const <Widget>[];
    return <Widget>[const SizedBox(height: TiqSpace.s4), bar];
  }

  /// The footer itself, with no gap above it.
  ///
  /// Split out of [_feedFooter] for the desk, whose `footer:` slot supplies
  /// the gap: the pane puts a `blockGap` above whatever it is given, so the
  /// `s4` the phone spends here would be spent twice. Same summary, same
  /// failure line, same "Show older" button on the same handler — one object
  /// with two framings rather than two footers that have to agree.
  Widget? _feedFooterBar({
    required String? next,
    required String summary,
    required String action,
    required ValueKey<String> key,
    required VoidCallback onPressed,
    ValueKey<String>? footerKey,
  }) {
    if (next == null && !_feedFailed) return null;
    return PaginationFooter(
      key: footerKey,
      summary: summary,
      narrowLine: _feedFailed ? context.l10n.feedMoreFailed : null,
      action: next == null
          ? null
          : TorchTertiaryButton(
              key: key,
              label: action,
              busy: _feedLoading,
              onPressed: _feedLoading ? null : onPressed,
            ),
    );
  }

  List<Widget> _messages(PaginatedResponse<Message>? page, double gutter) {
    final l10n = context.l10n;
    final directory = ref.watch(userDirectoryProvider);
    final messages = <Message>[...?page?.data, ..._olderMessages];
    // Page one's cursor until something older has been loaded, then the last
    // page's. The read flag separates "not asked yet" from "the server sent
    // none" — the same unknown-versus-zero distinction the figures make.
    final next = _messagesCursorRead ? _messagesCursor : page?.nextCursor;
    return <Widget>[
      SectionRule(
        l10n.messagesTitle,
        count: messages.isEmpty ? null : messages.length,
      ),
      const SizedBox(height: TiqSpace.s5),
      if (messages.isEmpty)
        EmptyState(
          scope: EmptyScope.inPanel,
          headline: l10n.messagesEmptyHeadline,
          body: l10n.messagesEmptyBody,
        )
      else
        TorchBleed(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var i = 0; i < messages.length; i++)
                _MessageRow(
                  key: ValueKey<String>('message-${messages[i].id}'),
                  message: messages[i],
                  directory: directory,
                  last: i == messages.length - 1,
                ),
            ],
          ),
        ),
      ..._feedFooter(
        next: next,
        summary: l10n.messagesShowing(messages.length),
        action: l10n.messagesShowOlder,
        key: const ValueKey<String>('messages-older'),
        onPressed: () => _loadOlder(() async {
          final older = await ref
              .read(collaborationRepositoryProvider)
              .listMessages(cursor: next);
          _olderMessages.addAll(older.data);
          _messagesCursor = older.nextCursor;
          _messagesCursorRead = true;
        }),
      ),
    ];
  }

  /// The messages feed, as records.
  ///
  /// The same list the phone arm builds — page one plus whatever "Show older"
  /// has added — the same `_MessageRow` keyed the same way, and the same
  /// footer on the same handler. The rows need no tap suppressed because they
  /// have never had one; **they keep their long press**, so the message id is
  /// as reachable on the desk as it is on a phone and for the same gesture.
  ConsoleDeskRecords _messagesDesk(
    PaginatedResponse<Message>? page, {
    required Widget filters,
  }) {
    final l10n = context.l10n;
    final directory = ref.watch(userDirectoryProvider);
    final messages = <Message>[...?page?.data, ..._olderMessages];
    final next = _messagesCursorRead ? _messagesCursor : page?.nextCursor;

    return ConsoleDeskRecords(
      filters: filters,
      footer: _feedFooterBar(
        next: next,
        summary: l10n.messagesShowing(messages.length),
        action: l10n.messagesShowOlder,
        key: const ValueKey<String>('messages-older-desk'),
        footerKey: const ValueKey<String>('messages-footer-desk'),
        onPressed: () => _loadOlder(() async {
          final older = await ref
              .read(collaborationRepositoryProvider)
              .listMessages(cursor: next);
          _olderMessages.addAll(older.data);
          _messagesCursor = older.nextCursor;
          _messagesCursorRead = true;
        }),
      ),
      records: <ConsoleDeskRecord>[
        for (var i = 0; i < messages.length; i++)
          ConsoleDeskRecord(
            id: messages[i].id,
            row: (context, selected) => _MessageRow(
              key: ValueKey<String>('message-${messages[i].id}'),
              message: messages[i],
              directory: directory,
              last: i == messages.length - 1,
            ),
            detail: (context) =>
                _MessageDetail(message: messages[i], directory: directory),
          ),
      ],
    );
  }

  /// The announcements feed, as records.
  ///
  /// [compose] is null for everybody POST /announcements would answer 403 —
  /// the same condition the phone arm checks — and it goes in `lead` because
  /// there is nowhere else: `ConsoleDeskRecords` has `lead`, `filters`,
  /// `records` and `footer`, and `filters` is already the feed rail. **So on
  /// the desk "New announcement" sits above the two feed chips rather than
  /// below them**, which is a worse place for it; the alternative was a
  /// desktop on which an announcement cannot be posted at all, and that is
  /// worse than a button one block too high.
  ConsoleDeskRecords _announcementsDesk(
    PaginatedResponse<Announcement>? page, {
    required Widget filters,
    required Widget? compose,
  }) {
    final l10n = context.l10n;
    final announcements = <Announcement>[
      ...?page?.data,
      ..._olderAnnouncements,
    ];
    final next = _announcementsCursorRead
        ? _announcementsCursor
        : page?.nextCursor;

    return ConsoleDeskRecords(
      lead: <Widget>[
        if (compose != null) ...<Widget>[
          compose,
          const SizedBox(height: TiqSpace.s6),
        ],
      ],
      filters: filters,
      footer: _feedFooterBar(
        next: next,
        summary: l10n.announcementsShowing(announcements.length),
        action: l10n.announcementsShowOlder,
        key: const ValueKey<String>('announcements-older-desk'),
        footerKey: const ValueKey<String>('announcements-footer-desk'),
        onPressed: () => _loadOlder(() async {
          final older = await ref
              .read(collaborationRepositoryProvider)
              .listAnnouncements(cursor: next);
          _olderAnnouncements.addAll(older.data);
          _announcementsCursor = older.nextCursor;
          _announcementsCursorRead = true;
        }),
      ),
      records: <ConsoleDeskRecord>[
        for (var i = 0; i < announcements.length; i++)
          ConsoleDeskRecord(
            id: announcements[i].id,
            row: (context, selected) => _AnnouncementRow(
              key: ValueKey<String>('announcement-${announcements[i].id}'),
              announcement: announcements[i],
              last: i == announcements.length - 1,
            ),
            detail: (context) =>
                _AnnouncementDetail(announcement: announcements[i]),
          ),
      ],
    );
  }

  List<Widget> _announcements(
    PaginatedResponse<Announcement>? page, {
    required bool canAnnounce,
    required double gutter,
  }) {
    final l10n = context.l10n;
    final announcements = <Announcement>[
      ...?page?.data,
      ..._olderAnnouncements,
    ];
    final next = _announcementsCursorRead
        ? _announcementsCursor
        : page?.nextCursor;
    return <Widget>[
      SectionRule(
        l10n.messagesFeedAnnouncements,
        count: announcements.isEmpty ? null : announcements.length,
      ),
      const SizedBox(height: TiqSpace.s5),
      if (announcements.isEmpty)
        EmptyState(
          scope: EmptyScope.inPanel,
          headline: l10n.announcementsEmptyHeadline,
          // The guidance names a next action only if you are allowed to do it.
          body: canAnnounce
              ? l10n.announcementsEmptyBodyCanPost
              : l10n.announcementsEmptyBodyReadOnly,
        )
      else
        TorchBleed(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var i = 0; i < announcements.length; i++)
                _AnnouncementRow(
                  key: ValueKey<String>(
                    'announcement-${announcements[i].id}',
                  ),
                  announcement: announcements[i],
                  last: i == announcements.length - 1,
                ),
            ],
          ),
        ),
      ..._feedFooter(
        next: next,
        summary: l10n.announcementsShowing(announcements.length),
        action: l10n.announcementsShowOlder,
        key: const ValueKey<String>('announcements-older'),
        onPressed: () => _loadOlder(() async {
          final older = await ref
              .read(collaborationRepositoryProvider)
              .listAnnouncements(cursor: next);
          _olderAnnouncements.addAll(older.data);
          _announcementsCursor = older.nextCursor;
          _announcementsCursorRead = true;
        }),
      ),
    ];
  }
}

/// One message, as a row that names people rather than ids.
class _MessageRow extends StatelessWidget {
  const _MessageRow({
    super.key,
    required this.message,
    required this.directory,
    required this.last,
  });

  final Message message;
  final Map<String, AppUser> directory;
  final bool last;

  /// A person's name, or null when the roster cannot say who this is.
  static String? nameOf(Map<String, AppUser> directory, String? id) {
    if (id == null) return null;
    final user = directory[id];
    if (user == null) return null;
    final display = user.displayName;
    return display != null && display.trim().isNotEmpty
        ? display
        : user.email;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final images = message.attachments;
    // An image can be the whole message; the row still needs a headline.
    final title = message.body.trim().isNotEmpty
        ? message.body
        : images.length == 1
        ? l10n.messagePhotoOne
        : l10n.messagePhotoMany(images.length);

    final direct = message.recipientId != null;
    final sender = nameOf(directory, message.senderId);
    final recipient = nameOf(directory, message.recipientId);

    // The id appears in exactly one case: as the explicit unknown state, in
    // the identifier face, with the words that say why it is there.
    final unknowns = <String>[
      if (message.senderId != null && sender == null)
        l10n.messageSenderNotOnRoster(message.senderId!),
      if (direct && recipient == null)
        l10n.messageRecipientNotOnRoster(message.recipientId!),
    ];

    final who = <String>[
      if (sender != null) l10n.messageFrom(sender),
      if (direct)
        recipient != null
            ? l10n.messageTo(recipient)
            : l10n.messageDirectUnknownRecipient
      else
        l10n.messageToTeam,
    ].join(' · ');

    return SoftRow(
      key: ValueKey<String>('message-row-${message.id}'),
      density: SoftRowDensity.tall,
      title: title,
      subtitle: who,
      leading: TiqMark(
        shape: direct ? MarkShape.sectionHalfDisc : MarkShape.onTargetCircle,
        color: skin.palette.ink2,
        size: MarkScale.glyph(context, 16),
      ),
      meta: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            direct ? l10n.messageDirect : l10n.messageBroadcast,
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
          for (final line in unknowns)
            Padding(
              padding: const EdgeInsets.only(top: TiqSpace.s1),
              child: Text(
                line,
                style: skin.text.monoIdent.style(color: skin.palette.ink3),
              ),
            ),
        ],
      ),
      // The thumbs are buttons, so they live in the row's `actions` slot and
      // NOT in `meta`. A `SoftRow` with no actions and no trailing control
      // wraps itself in `excludeSemantics: true`, which does not make the
      // thumb inert — it deletes its node outright, so a reader hears "2
      // photos" and has nothing to open. `actions` is the declared home for a
      // row's own verbs precisely because it keeps its children's nodes
      // beneath the row's (soft_row.dart §5).
      actions: images.isEmpty
          ? null
          : Wrap(
              key: ValueKey<String>('message-attachments-${message.id}'),
              spacing: TiqSpace.s2,
              runSpacing: TiqSpace.s2,
              children: <Widget>[
                for (final (index, a) in images.indexed)
                  MessageAttachmentThumb(
                    photoId: a.photoId,
                    label: l10n.messagePhotoOfCount(index + 1, images.length),
                  ),
              ],
            ),
      // The id is still reachable for a bug report, and reachable is where it
      // belongs — not printed across the row where a name should be.
      onLongPress: () async {
        await Clipboard.setData(ClipboardData(text: message.id));
        if (context.mounted) {
          showTorchToast(
            context,
            message: l10n.messageIdCopied,
            kind: ToastKind.neutral,
          );
        }
      },
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: <String>[
        title,
        if (who.isNotEmpty) who,
        direct ? l10n.messageDirect : l10n.messageBroadcast,
        if (images.isNotEmpty) l10n.messagePhotoCount(images.length),
        ...unknowns,
        l10n.messageLongPressForId,
      ].join('. '),
    );
  }
}

class _AnnouncementRow extends StatelessWidget {
  const _AnnouncementRow({
    super.key,
    required this.announcement,
    required this.last,
  });

  final Announcement announcement;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    return SoftRow(
      key: ValueKey<String>('announcement-row-${announcement.id}'),
      density: SoftRowDensity.tall,
      // The title is the headline; the body is what it actually says.
      title: announcement.title,
      subtitle: l10n.announcementSubtitle,
      leading: TiqMark(
        shape: MarkShape.onTargetCircle,
        color: skin.palette.ink2,
        size: MarkScale.glyph(context, 16),
      ),
      meta: Text(
        announcement.body,
        style: skin.text.body.style(color: skin.palette.ink2),
      ),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: l10n.announcementSemantics(
        announcement.title,
        announcement.body,
      ),
    );
  }
}

/// ONE MESSAGE, IN THE DETAIL PANE — who, what it says, and its photographs.
///
/// A message row is a dead end on a phone: no `onTap`, no route, and the whole
/// record in a title, a `who` line, two words of kind and a wrap of thumbs.
/// So the pane is [ConsoleRecordDetail] over exactly those, with the
/// attachments allowed to be the size they are.
///
/// ## There is no "when", and it is not an omission this pane can fix
///
/// `GET /messages` does not send one: `Message` carries an id, a body, a
/// sender, a recipient and its attachments, and nothing else (see
/// `collaboration_repository.dart`). The row prints no time for the same
/// reason. A pane that printed "just now", or a date derived from a cursor,
/// would be inventing the one field a reader would most trust — so the record
/// says who and what, and the server has to grow a timestamp before it can
/// say when.
///
/// ## The id stays behind the long press
///
/// The row's own ruling is that an id appears "in exactly one case: as the
/// explicit unknown state", and that the id proper is **reachable** rather
/// than printed. The row is handed to the list pane unchanged, long press and
/// all, so on the desk the id is copied with the same gesture. What this pane
/// does print is that one case: a sender or a recipient the roster cannot
/// name, as a mono field whose label supplies the words the row's sentence
/// supplies.
///
/// **The thumbs are in `blocks`, not `actions`.** They sit in `SoftRow.actions`
/// on the row because that slot is what keeps their semantics nodes under the
/// row's; in the pane `actions` is a stack of full-width verbs, and a 56dp
/// photograph stretched to 440dp is not a verb. `blocks` is the slot
/// `ConsoleRecordDetail` documents for an evidence thumbnail.
///
/// Amber: none. There is no verb on the row to lift, and the composer's Send
/// — the one primary this route declares — stays on the composer.
class _MessageDetail extends StatelessWidget {
  const _MessageDetail({required this.message, required this.directory});

  final Message message;
  final Map<String, AppUser> directory;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final images = message.attachments;
    // An image can be the whole message; the record still needs a headline,
    // and it is the row's own.
    final title = message.body.trim().isNotEmpty
        ? message.body
        : images.length == 1
        ? l10n.messagePhotoOne
        : l10n.messagePhotoMany(images.length);

    final direct = message.recipientId != null;
    final sender = _MessageRow.nameOf(directory, message.senderId);
    final recipient = _MessageRow.nameOf(directory, message.recipientId);
    final unknowns = <String>[
      if (message.senderId != null && sender == null)
        l10n.messageSenderNotOnRoster(message.senderId!),
      if (direct && recipient == null)
        l10n.messageRecipientNotOnRoster(message.recipientId!),
    ];
    final who = <String>[
      if (sender != null) l10n.messageFrom(sender),
      if (direct)
        recipient != null
            ? l10n.messageTo(recipient)
            : l10n.messageDirectUnknownRecipient
      else
        l10n.messageToTeam,
    ].join(' · ');

    return ConsoleRecordDetail(
      key: ValueKey<String>('message-detail-${message.id}'),
      title: title,
      kicker: Eyebrow(direct ? l10n.messageDirect : l10n.messageBroadcast),
      lede: who.isEmpty ? null : who,
      // NO `facts` BLOCK, AND THE UNKNOWNS KEEP THE SENTENCE THEY ALREADY
      // HAVE. The id appears in exactly one case — the explicit unknown state
      // — and `messageSenderNotOnRoster` / `messageRecipientNotOnRoster` are
      // whole localised sentences with the id inside them. Splitting them into
      // a label and a value would have meant two new ARB keys saying what two
      // existing ones already say, in English only; `_MessageRow` prints the
      // same strings on the phone, so the pane and the row cannot drift.
      blocks: <Widget>[
        for (final unknown in unknowns)
          Text(
            unknown,
            style: context.skin.text.monoIdent.style(
              color: context.skin.palette.ink3,
            ),
          ),
        if (images.isNotEmpty)
          Wrap(
            key: ValueKey<String>('message-attachments-${message.id}-pane'),
            spacing: TiqSpace.s2,
            runSpacing: TiqSpace.s2,
            children: <Widget>[
              for (final (index, a) in images.indexed)
                MessageAttachmentThumb(
                  key: ValueKey<String>(
                    'message-attachment-${message.id}-$index-pane',
                  ),
                  photoId: a.photoId,
                  label: l10n.messagePhotoOfCount(index + 1, images.length),
                ),
            ],
          ),
      ],
    );
  }
}

/// ONE ANNOUNCEMENT, IN THE DETAIL PANE.
///
/// The row has the headline in its title and the whole broadcast in its
/// `meta`, where a long one is a paragraph squeezed into a list. In the pane
/// the headline is the title and the body is a block, which is the one thing
/// this record actually needed room for.
///
/// Amber: none, and nothing lifted — posting is the list's verb and it stays
/// with the list (see [_MessagesScreenState._announcementsDesk]).
class _AnnouncementDetail extends StatelessWidget {
  const _AnnouncementDetail({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;

    return ConsoleRecordDetail(
      key: ValueKey<String>('announcement-detail-${announcement.id}'),
      title: announcement.title,
      lede: l10n.announcementSubtitle,
      blocks: <Widget>[
        // The same Text the row draws in its `meta`, at the same size and the
        // same ink — allowed to wrap rather than to be a row's third line.
        Text(
          announcement.body,
          style: skin.text.body.style(color: skin.palette.ink2),
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
    final l10n = context.l10n;
    return TorchSheet(
      title: l10n.attachSheetTitle,
      subtitle: l10n.attachSheetSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SoftRow(
            key: const ValueKey<String>('attach-camera'),
            density: SoftRowDensity.standard,
            title: l10n.attachCamera,
            onTap: () => Navigator.of(context).pop(PhotoSource.camera),
          ),
          SoftRow(
            key: const ValueKey<String>('attach-gallery'),
            density: SoftRowDensity.standard,
            title: l10n.attachGallery,
            onTap: () => Navigator.of(context).pop(PhotoSource.gallery),
            separator: SoftRowSeparator.none,
          ),
        ],
      ),
    );
  }
}

/// Title *and* body, because the endpoint requires both and rejects a blank
/// either way. Post stays blocked — and says why — until both are filled.
class _AnnouncementSheet extends StatefulWidget {
  const _AnnouncementSheet();

  @override
  State<_AnnouncementSheet> createState() => _AnnouncementSheetState();
}

class _AnnouncementSheetState extends State<_AnnouncementSheet> {
  final _title = TextEditingController();
  final _body = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final c in <TextEditingController>[_title, _body]) {
      c.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  String? get _blocked {
    final l10n = context.l10n;
    if (_title.text.trim().isEmpty) return l10n.announcementSheetBlockedTitle;
    if (_body.text.trim().isEmpty) return l10n.announcementSheetBlockedBody;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final blocked = _blocked;

    return TorchSheet(
      key: const ValueKey<String>('announcement-sheet'),
      title: l10n.announcementNew,
      subtitle: l10n.announcementSheetSubtitle,
      claims: <TorchClaim>[
        if (blocked == null) TorchPrimaryButton.claim('post-announcement'),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TorchTextField(
            key: const ValueKey<String>('announcement-title'),
            label: l10n.announcementSheetHeadline,
            controller: _title,
          ),
          const SizedBox(height: TiqSpace.s5),
          TorchTextField(
            key: const ValueKey<String>('announcement-body'),
            label: l10n.announcementSheetBody,
            controller: _body,
            minLines: 3,
            maximumLines: 6,
          ),
          SizedBox(height: skin.space.blockGap),
          TorchPrimaryButton(
            key: const ValueKey<String>('post-announcement'),
            label: l10n.announcementSheetCommit,
            claimId: 'post-announcement',
            blockedReason: blocked,
            onPressed: blocked != null
                ? null
                : () => Navigator.of(context).pop((
                    title: _title.text.trim(),
                    body: _body.text.trim(),
                  )),
          ),
          const SizedBox(height: TiqSpace.s2),
          TorchSecondaryButton(
            key: const ValueKey<String>('cancel-announcement'),
            label: l10n.announcementSheetCancel,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// THE COMPOSER — the pinned band between the thread and the nav.
///
/// A sibling of the scroll view rather than an overlay, so at 2.0× with three
/// pending photos it is as tall as it measures and the last message is still
/// above it. It clears the software keyboard itself, which is the shell's job
/// for a band and the reason the nav's amber grant is free while it is open.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.pending,
    required this.sending,
    required this.armed,
    required this.error,
    required this.onSend,
    required this.onAttach,
    required this.onRemove,
  });

  final TextEditingController controller;
  final List<PendingAttachment> pending;
  final bool sending;
  final bool armed;
  final String? error;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final canAttach = !sending && pending.length < maxMessageAttachments;
    final failure = error;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (pending.isNotEmpty) ...<Widget>[
          SingleChildScrollView(
            key: const ValueKey<String>('pending-attachments'),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (var i = 0; i < pending.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: TiqSpace.s2),
                    child: _PendingThumb(
                      index: i,
                      attachment: pending[i],
                      onRemove: sending ? null : () => onRemove(i),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: TiqSpace.s3),
        ],
        if (failure != null) ...<Widget>[
          ErrorState(
            key: const ValueKey<String>('composer-error'),
            scope: ErrorScope.inline,
            message: TorchErrorMessage(
              kind: TorchErrorKind.rejected,
              headline: l10n.composerNotSent,
              body: failure,
              offersRetry: false,
            ),
          ),
          const SizedBox(height: TiqSpace.s3),
        ],
        TorchTextField(
          key: const ValueKey<String>('message-body'),
          label: l10n.composerLabel,
          controller: controller,
          enabled: !sending,
          minLines: 1,
          maximumLines: 4,
          onSubmitted: (_) {
            if (armed) onSend();
          },
        ),
        const SizedBox(height: TiqSpace.s3),
        Row(
          children: <Widget>[
            TorchIconButton(
              key: const ValueKey<String>('attach-photo'),
              icon: Icons.add_a_photo_outlined,
              semanticLabel: canAttach
                  ? l10n.composerAddPhoto
                  : l10n.composerPhotoCap(maxMessageAttachments),
              onPressed: canAttach ? onAttach : null,
            ),
            const SizedBox(width: TiqSpace.s3),
            Expanded(
              child: Text(
                pending.isEmpty
                    ? l10n.composerPhotoCapLine(maxMessageAttachments)
                    : l10n.composerPhotosAttached(
                        pending.length,
                        maxMessageAttachments,
                      ),
                style: skin.text.meta.style(color: skin.palette.ink3),
              ),
            ),
            const SizedBox(width: TiqSpace.s3),
            SizedBox(
              width: 148,
              child: TorchPrimaryButton(
                key: const ValueKey<String>('send-message'),
                label: sending ? l10n.composerSending : l10n.composerSend,
                claimId: messageSendClaimId,
                busy: sending,
                blockedReason: armed
                    ? null
                    : sending
                    ? l10n.composerSending
                    : l10n.composerBlockedEmpty,
                onPressed: armed ? onSend : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A picked photo waiting in the draft: what will be sent, and a way to take
/// it back out before it is.
class _PendingThumb extends StatelessWidget {
  const _PendingThumb({
    required this.index,
    required this.attachment,
    required this.onRemove,
  });

  static const double size = 56;

  final int index;
  final PendingAttachment attachment;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final radius = BorderRadius.circular(skin.radii.chip);
    final bytes = attachment.bytes;
    final broken = DecoratedBox(
      decoration: BoxDecoration(color: skin.palette.well, borderRadius: radius),
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: TiqMark(
            shape: MarkShape.sectionBarredRing,
            color: skin.palette.ink3,
            size: MarkScale.glyph(context, 16),
          ),
        ),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          label: l10n.pendingPhotoReady(index + 1),
          image: true,
          child: ClipRRect(
            borderRadius: radius,
            child: bytes == null
                ? broken
                : Image.memory(
                    bytes,
                    key: ValueKey<String>('pending-attachment-$index'),
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => broken,
                  ),
          ),
        ),
        const SizedBox(width: TiqSpace.s1),
        TorchIconButton(
          key: ValueKey<String>('pending-attachment-remove-$index'),
          icon: Icons.close,
          semanticLabel: l10n.pendingPhotoRemove(index + 1),
          onPressed: onRemove,
        ),
      ],
    );
  }
}
