import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../audit/data/photos_repository.dart';

/// An image attached to a message (#125), as a thumbnail in the thread.
///
/// The same honesty rules as the evidence thumb (`evidence_thumb.dart`): only
/// real fetched bytes are ever shown; loading or failed is a plain `well` slot
/// at the real geometry — the skeleton's own colour — never a spinner and
/// never placeholder art. It differs only where a message differs from visit
/// evidence: it is sized for a thread rather than a worklist's slot, and its
/// full view opens the ONE photo by id instead of listing a visit's photos.
///
/// Bytes come through the authed client: [thumbnailBytesProvider] for the
/// thumb, [photoImageBytesProvider] for the full view. The server only answers
/// the message's sender, its recipient(s) and the client's managers/admins.
class MessageAttachmentThumb extends ConsumerWidget {
  const MessageAttachmentThumb({
    super.key,
    required this.photoId,
    this.size = 56,
  });

  final String photoId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = context.skin;
    final bytes = ref.watch(thumbnailBytesProvider(photoId));
    final radius = BorderRadius.circular(skin.radii.chip);

    final content = bytes.maybeWhen(
      data: (value) => ClipRRect(
        borderRadius: radius,
        child: Image.memory(
          value,
          key: ValueKey<String>('message-attachment-image-$photoId'),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      ),
      orElse: () => DecoratedBox(
        key: ValueKey<String>('message-attachment-slot-$photoId'),
        decoration: BoxDecoration(
          color: SkeletonLine.fillFor(skin),
          borderRadius: radius,
        ),
        child: SizedBox.square(dimension: size),
      ),
    );

    // One node, and a real tap action on it: a `GestureDetector` under an
    // excluding semantics node paints, hit-tests and is announced nowhere —
    // the kit-wide bug that left every button unpressable to a reader.
    return Semantics(
      label: 'Photo attachment',
      image: true,
      button: true,
      onTap: () => showMessageAttachmentSheet(context, photoId),
      child: GestureDetector(
        key: ValueKey<String>('message-attachment-$photoId'),
        onTap: () => showMessageAttachmentSheet(context, photoId),
        child: content,
      ),
    );
  }
}

/// The full-size attachment, fetched when it is opened — not before.
Future<void> showMessageAttachmentSheet(BuildContext context, String photoId) {
  return showTorchSheet<void>(
    context,
    builder: (_) => MessageAttachmentSheet(photoId: photoId),
  );
}

/// The one modal container, not a dialog (unify §1.7).
class MessageAttachmentSheet extends ConsumerWidget {
  const MessageAttachmentSheet({super.key, required this.photoId});

  final String photoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(photoImageBytesProvider(photoId));

    return TorchSheet(
      key: const ValueKey<String>('attachment-sheet'),
      title: 'Photo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          image.when(
            loading: () => Skeleton(
              label: 'the photo',
              child: const SkeletonShell(height: 220),
            ),
            // Never a dead end: the failure names itself and offers the way
            // back.
            error: (error, stack) => ErrorState(
              scope: ErrorScope.inline,
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('attachment-sheet-retry'),
                label: 'Try again',
                onPressed: () =>
                    ref.invalidate(photoImageBytesProvider(photoId)),
              ),
            ),
            data: (bytes) => Image.memory(
              bytes,
              key: const ValueKey<String>('attachment-sheet-image'),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => ErrorState(
                scope: ErrorScope.inline,
                message: const TorchErrorMessage(
                  kind: TorchErrorKind.rejected,
                  headline: 'This photo could not be displayed.',
                  body: 'The file arrived, but it is not an image this device '
                      'can decode.',
                  offersRetry: false,
                ),
              ),
            ),
          ),
          SizedBox(height: context.skin.space.blockGap),
          TorchSecondaryButton(
            key: const ValueKey<String>('attachment-sheet-close'),
            label: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
