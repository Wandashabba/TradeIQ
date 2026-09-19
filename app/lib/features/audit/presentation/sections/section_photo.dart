import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/camera/photo_capture_service.dart';
import '../../../../core/theme/torchlight/tiq_skin.dart';
import '../../../../core/widgets/torchlight/button/buttons.dart';
import '../../../../core/widgets/torchlight/row/row.dart';
import '../../../../core/widgets/torchlight/section_rule.dart';
import '../../../../l10n/l10n.dart';

/// THE SECTION'S ONE PHOTO — the Phase 1 pre-capture card.
///
/// There is no camera package in this app, so capture is the OS camera behind
/// a card that says what to shoot and to switch the torch on first. This
/// screen does not pretend there is an in-app preview; what it does own is the
/// part that matters — telling the agent what a usable frame looks like *while
/// they are still standing in front of the bay*.
///
/// **Amber: none.** The section's one grant is its Save. `Open camera` is a
/// ghost, and the torch row is a square and a sentence: calling a torch
/// control a light source is a pun, not a rule.
class SectionPhotoField extends ConsumerStatefulWidget {
  const SectionPhotoField({
    super.key,
    required this.label,
    required this.onCaptured,
    this.photo,
    this.framingLine,
    this.now,
  });

  /// The section's own name for the shot: "Shelf photo".
  final String label;

  /// The capture, or null to clear it. A backed-out retake never clears.
  final ValueChanged<CapturedPhoto?> onCaptured;

  /// What the section is holding, so the field is a pure function of it.
  final CapturedPhoto? photo;

  /// The framing instruction. Defaults to the shelf-bay sentence.
  final String? framingLine;

  /// The clock, for the torch hint and for tests. The hint is a heuristic on
  /// local time, which is the only light reading this app can take without a
  /// camera stream of its own.
  final DateTime Function()? now;

  @override
  ConsumerState<SectionPhotoField> createState() => _SectionPhotoFieldState();
}

class _SectionPhotoFieldState extends ConsumerState<SectionPhotoField> {
  String? _error;
  bool _busy = false;

  bool get _darkOutside {
    final hour = (widget.now ?? DateTime.now)().hour;
    return hour < 6 || hour >= 18;
  }

  Future<void> _capture([PhotoSource source = PhotoSource.camera]) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final l10n = context.l10n;
    try {
      final photo = await ref
          .read(photoCaptureServiceProvider)
          .capture(source, geotag: true);
      if (!mounted) return;
      setState(() => _busy = false);
      // A cancel returns null — the field keeps whatever it already had, so a
      // backed-out retake loses nothing.
      if (photo != null) widget.onCaptured(photo);
    } on PhotoTooLargeException {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.sectionPhotoTooLarge;
      });
    } catch (error, stack) {
      debugPrint('Photo capture failed: $error\n$stack');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.sectionPhotoFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final photo = widget.photo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionRule(widget.label),
        const SizedBox(height: TiqSpace.s5),
        if (photo == null)
          _FramingCard(line: widget.framingLine ?? l10n.sectionPhotoFraming)
        else
          _CapturedTile(
            photo: photo,
            onRemove: () => widget.onCaptured(null),
          ),
        if (photo == null && _darkOutside) ...<Widget>[
          const SizedBox(height: TiqSpace.s4),
          Semantics(
            liveRegion: true,
            child: Row(
              key: const ValueKey<String>('photo-torch-hint'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const RowMarkTile(mark: RowMark.square),
                const SizedBox(width: TiqSpace.s3),
                Expanded(
                  child: Text(
                    l10n.sectionPhotoTorchHint,
                    style: skin.text.label.style(color: skin.palette.ink2),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: TiqSpace.s4),
        Text(
          l10n.sectionPhotoStamped,
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s3),
          Semantics(
            liveRegion: true,
            child: Row(
              key: const ValueKey<String>('photo-error'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const RowMarkTile(
                  mark: RowMark.triangle,
                  tone: RowMarkTone.severe,
                ),
                const SizedBox(width: TiqSpace.s3),
                Expanded(
                  child: Text(
                    _error!,
                    style: skin.text.body.style(color: skin.palette.ink1),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: TiqSpace.s4),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TorchSecondaryButton(
            key: const ValueKey<String>('photo-add'),
            label: photo == null
                ? l10n.sectionPhotoOpenCamera
                : l10n.photoFieldRetake,
            semanticLabel: l10n.sectionPhotoOpenCameraSemantics,
            icon: Icons.photo_camera_outlined,
            busy: _busy,
            onPressed: _busy ? null : _capture,
          ),
        ),
        // The gallery is not a convenience. A cracked camera in a dark aisle
        // still has to be able to file evidence — the guided capture screen
        // this field replaced offered it, and a migration does not take a
        // capability away.
        const SizedBox(height: TiqSpace.s2),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TorchTertiaryButton(
            key: const ValueKey<String>('photo-gallery'),
            label: l10n.captureGalleryButton,
            onPressed: _busy ? null : () => _capture(PhotoSource.gallery),
          ),
        ),
      ],
    );
  }
}

/// The framing card: a drawing of a bay with corner brackets, and the one
/// sentence that decides whether the photo is usable.
class _FramingCard extends StatelessWidget {
  const _FramingCard({required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      key: const ValueKey<String>('photo-framing-card'),
      padding: const EdgeInsets.all(TiqSpace.s4),
      decoration: BoxDecoration(
        color: skin.palette.surface,
        borderRadius: BorderRadius.circular(skin.radii.panel),
        border: Border.all(
          color: skin.palette.edgeStructure,
          width: skin.depth.borderWidth,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // The drawing carries nothing a reader needs: the sentence beside it
          // is the whole instruction.
          ExcludeSemantics(
            child: CustomPaint(
              size: const Size(64, 64),
              painter: _BayPainter(
                colour: skin.palette.edgeControl,
                stroke: skin.mode == SkinMode.veld ? 3 : 2,
              ),
            ),
          ),
          const SizedBox(width: TiqSpace.s4),
          Expanded(
            child: Text(
              line,
              style: skin.text.body.style(color: skin.palette.ink1),
            ),
          ),
        ],
      ),
    );
  }
}

/// Four corner brackets and three shelves. No fill, no shadow, one draw call.
class _BayPainter extends CustomPainter {
  const _BayPainter({required this.colour, required this.stroke});

  final Color colour;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;
    final arm = size.width * 0.28;
    final r = Offset.zero & size;
    // Corner brackets.
    for (final (Offset corner, double dx, double dy) in <(Offset, double, double)>[
      (r.topLeft, 1, 1),
      (r.topRight, -1, 1),
      (r.bottomLeft, 1, -1),
      (r.bottomRight, -1, -1),
    ]) {
      final start = corner.translate(dx * stroke / 2, dy * stroke / 2);
      canvas
        ..drawLine(start, start.translate(dx * arm, 0), paint)
        ..drawLine(start, start.translate(0, dy * arm), paint);
    }
    // Two shelves inside them.
    for (final f in <double>[0.42, 0.68]) {
      canvas.drawLine(
        Offset(size.width * 0.18, size.height * f),
        Offset(size.width * 0.82, size.height * f),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BayPainter old) =>
      old.colour != colour || old.stroke != stroke;
}

/// What was actually captured, while it can still be re-taken.
class _CapturedTile extends StatelessWidget {
  const _CapturedTile({required this.photo, required this.onRemove});

  final CapturedPhoto photo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final bytes = _decode(photo.dataUrl);
    final time = _hhmm(photo.capturedAt);
    return Row(
      key: const ValueKey<String>('photo-preview'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          label: l10n.sectionPhotoSemantics(time),
          image: true,
          excludeSemantics: true,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: skin.palette.well,
              borderRadius: BorderRadius.circular(skin.radii.control),
              border: Border.all(color: skin.palette.edgeControl, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: bytes == null
                ? null
                // A 12 MP shelf photo decoded full size is an out-of-memory
                // kill on a 2 GB handset, so the decode is capped at the tile.
                : Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    cacheWidth: 144,
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stack) =>
                        const SizedBox.shrink(),
                  ),
          ),
        ),
        const SizedBox(width: TiqSpace.s4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${l10n.photoFieldCaptured} · $time',
                style: skin.text.bodyStrong.style(color: skin.palette.ink1),
              ),
              const SizedBox(height: TiqSpace.s1),
              Text(
                l10n.sectionPhotoHeld,
                style: skin.text.meta.style(color: skin.palette.ink3),
              ),
              const SizedBox(height: TiqSpace.s2),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TorchTertiaryButton(
                  key: const ValueKey<String>('photo-remove'),
                  label: l10n.sectionPhotoRemoveSemantics,
                  onPressed: onRemove,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Uint8List? _decode(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(dataUrl.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
