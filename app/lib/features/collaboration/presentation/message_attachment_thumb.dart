import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/human_error.dart';
import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../audit/data/photos_repository.dart';

/// An image attached to a message (#125), as a thumbnail in the thread.
///
/// The same honesty rules as the evidence thumb (`evidence_thumb.dart`): only
/// real fetched bytes are ever shown; loading or failed is a neutral rounded
/// slot, never a spinner or placeholder art. It differs only where a message
/// differs from visit evidence — it is sized for a thread rather than a
/// worklist's 44px slot, and its full view opens the ONE photo by id instead of
/// listing a visit's photos.
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
    final colors = context.colors;
    final glass = colors.glass;
    final bytes = ref.watch(thumbnailBytesProvider(photoId));
    final radius = BorderRadius.circular(10);

    final content = bytes.maybeWhen(
      data: (value) {
        final image = Image.memory(
          value,
          key: ValueKey('message-attachment-image-$photoId'),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
        final clipped = ClipRRect(borderRadius: radius, child: image);
        if (!glass) return clipped;
        // Glass frames the photo with a rim over its edge and never tints it.
        return DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: context.lumen.tileRim),
          ),
          child: clipped,
        );
      },
      orElse: () => DecoratedBox(
        key: ValueKey('message-attachment-slot-$photoId'),
        decoration: glass
            ? BoxDecoration(
                color: colors.surface3,
                borderRadius: radius,
                border: Border.all(color: context.lumen.tileRim),
              )
            : BoxDecoration(color: colors.surface2, borderRadius: radius),
        child: SizedBox(width: size, height: size),
      ),
    );

    return MergeSemantics(
      child: Semantics(
        label: 'Photo attachment',
        image: true,
        button: true,
        child: GestureDetector(
          key: ValueKey('message-attachment-$photoId'),
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => MessageAttachmentDialog(photoId: photoId),
          ),
          child: content,
        ),
      ),
    );
  }
}

/// The full-size attachment, fetched when it is opened — not before.
class MessageAttachmentDialog extends ConsumerWidget {
  const MessageAttachmentDialog({super.key, required this.photoId});

  final String photoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final image = ref.watch(photoImageBytesProvider(photoId));

    return AlertDialog(
      key: const ValueKey('attachment-dialog'),
      backgroundColor: colors.surface1,
      title: const Text('Photo', style: TextStyle(fontSize: 15)),
      content: SizedBox(
        width: 420,
        child: image.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          // Never a dead end: the failure names itself and offers the way back.
          error: (err, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Failed to load photo. ${humanErrorMessage(err)}',
                style: TextStyle(fontSize: 12.5, color: colors.ink2),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                key: const ValueKey('attachment-dialog-retry'),
                onPressed: () =>
                    ref.invalidate(photoImageBytesProvider(photoId)),
                child: const Text('Retry'),
              ),
            ],
          ),
          data: (bytes) => Image.memory(
            bytes,
            key: const ValueKey('attachment-dialog-image'),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => Text(
              'This photo could not be displayed.',
              style: TextStyle(fontSize: 12.5, color: colors.ink2),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('attachment-dialog-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
