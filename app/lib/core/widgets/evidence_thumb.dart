import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/audit/data/photos_repository.dart';
import '../network/human_error.dart';
import '../theme/tiq_colors.dart';

/// The captured shelf photo, 44×44, in a [WorklistRow]'s `thumb:` slot — the
/// thumbnail IS the evidence, so it only ever renders real fetched bytes.
///
/// Honesty rules:
/// * No photo id → the row shows no thumb at all (the caller's job — this
///   widget requires a real id).
/// * Loading or failed → a neutral rounded surface2 box. Never a spinner
///   (44px of chrome churn per row), never a broken-image icon (the manager
///   did nothing wrong), never placeholder art.
///
/// The bytes come through the app's AUTHED client via
/// [thumbnailBytesProvider] — `GET /photos/:id/thumbnail` requires the
/// bearer token, which a web `Image.network` cannot send. The repository
/// caches bytes per photo id, so scrolling and refreshing never re-download.
///
/// Tap → a dialog with the FULL photo, fetched lazily on open from
/// `GET /photos?visitId` (newest first).
class EvidenceThumb extends ConsumerWidget {
  const EvidenceThumb({
    super.key,
    required this.photoId,
    required this.visitId,
  });

  final String photoId;

  /// The visit the evidence belongs to — the full-photo dialog lists this
  /// visit's photos and shows the newest.
  final String visitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final bytes = ref.watch(thumbnailBytesProvider(photoId));

    final content = bytes.maybeWhen(
      data: (value) => Image.memory(
        value,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        // Never flash back to nothing on a rebuild mid-decode.
        gaplessPlayback: true,
      ),
      orElse: () => DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const SizedBox(width: 44, height: 44),
      ),
    );

    // MergeSemantics folds the GestureDetector's tap action into the labelled
    // node, so a screen reader hears one thing: an image called "Shelf photo
    // evidence" that can be activated.
    return MergeSemantics(
      child: Semantics(
        label: 'Shelf photo evidence',
        image: true,
        child: GestureDetector(
          key: ValueKey('evidence-thumb-$photoId'),
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => _EvidencePhotoDialog(visitId: visitId),
          ),
          child: content,
        ),
      ),
    );
  }
}

/// The full photo, at the moment the manager asks for it — not before.
class _EvidencePhotoDialog extends ConsumerWidget {
  const _EvidencePhotoDialog({required this.visitId});

  final String visitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final photos = ref.watch(visitPhotosProvider(visitId));

    return AlertDialog(
      key: const ValueKey('evidence-dialog'),
      backgroundColor: colors.surface1,
      title: const Text('Shelf photo', style: TextStyle(fontSize: 15)),
      content: SizedBox(
        width: 420,
        child: photos.when(
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
          error: (err, _) => Text(
            'Failed to load photo. ${humanErrorMessage(err)}',
            style: TextStyle(fontSize: 12.5, color: colors.ink2),
          ),
          data: (list) {
            // Newest first, per the backend's ordering — the newest photo is
            // the evidence.
            final bytes = list.isEmpty ? null : _dataUrlBytes(list.first.url);
            if (bytes == null) {
              return Text(
                'No photo available for this visit.',
                style: TextStyle(fontSize: 12.5, color: colors.ink2),
              );
            }
            return Image.memory(bytes, fit: BoxFit.contain);
          },
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('evidence-dialog-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Phase-1 photos are stored inline as base64 data URLs. Anything that is not
/// one — or does not decode — returns null, and the dialog says so instead of
/// rendering garbage.
Uint8List? _dataUrlBytes(String url) {
  if (!url.startsWith('data:')) return null;
  final comma = url.indexOf(',');
  if (comma == -1) return null;
  try {
    return base64Decode(url.substring(comma + 1));
  } on FormatException {
    return null;
  }
}
