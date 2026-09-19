import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/audit/data/photos_repository.dart';
import '../../theme/torchlight/tiq_skin.dart';

/// THE EVIDENCE, AT ROW SIZE — the Torchlight form of the worklist thumbnail.
///
/// The thumbnail **is** the evidence, so it only ever renders real fetched
/// bytes. Three honesty rules carry over unchanged from the row it replaces:
///
/// * no photo id → the caller renders no thumbnail at all, and reserves no
///   gap for one (this widget requires a real id);
/// * loading or failed → the object's own 1px `edgeStructure` outline at its
///   real geometry, **empty** — the skeleton grammar, not a spinner (44dp of
///   chrome churn per row) and not a broken-image glyph (the manager did
///   nothing wrong);
/// * never placeholder art.
///
/// The bytes come through the app's authed client via [thumbnailBytesProvider]
/// — `GET /photos/:id/thumbnail` needs the bearer token, which a web
/// `Image.network` cannot send — and the repository caches per photo id, so
/// scrolling and refreshing never re-download.
///
/// **Amber: none.** A photograph of a shelf is not a light source.
class TorchEvidenceThumb extends ConsumerWidget {
  const TorchEvidenceThumb({
    super.key,
    required this.photoId,
    required this.semanticLabel,
    this.size = 40,
    this.aspectRatio,
  });

  final String photoId;

  /// What the photograph is of, in words: the outlet, the section and the
  /// time. A picture with no label is a picture a screen reader cannot report.
  final String semanticLabel;

  /// The square extent, when [aspectRatio] is null. 40dp on a row.
  final double size;

  /// Full width at this ratio instead of a square — 16:9 in a sheet.
  final double? aspectRatio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = context.skin;
    final radius = BorderRadius.circular(skin.radii.control);
    final bytes = ref.watch(thumbnailBytesProvider(photoId));

    final content = bytes.maybeWhen(
      data: (value) => ClipRRect(
        borderRadius: radius,
        child: Image.memory(
          value,
          fit: BoxFit.cover,
          width: aspectRatio == null ? size : double.infinity,
          height: aspectRatio == null ? size : null,
          // Never flash back to nothing on a rebuild mid-decode.
          gaplessPlayback: true,
        ),
      ),
      orElse: () => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: skin.palette.edgeStructure,
            width: skin.depth.borderWidth,
          ),
        ),
      ),
    );

    final sized = aspectRatio == null
        ? SizedBox.square(dimension: size, child: content)
        : AspectRatio(aspectRatio: aspectRatio!, child: content);

    return Semantics(
      image: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: sized,
    );
  }
}
