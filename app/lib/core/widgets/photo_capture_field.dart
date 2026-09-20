import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../camera/photo_capture_service.dart';
import '../theme/app_colors.dart';
import '../theme/lumen_glass.dart';
import '../theme/lumen_palette.dart';
import '../theme/tiq_colors.dart';
import 'agent_motion.dart';
import 'console.dart';
import 'glass.dart';
import 'guided_capture_screen.dart';

/// Capture a photo, see what you captured, and be able to retake it.
///
/// The preview is not decoration. An agent photographing a shelf in a dark aisle
/// needs to see that the shot is usable *before* they walk out of the store —
/// this is the only moment the evidence can still be re-taken.
class PhotoCaptureField extends ConsumerStatefulWidget {
  const PhotoCaptureField({
    super.key,
    required this.label,
    this.onCaptured,
    this.onPhotoCaptured,
    this.helperText,
    this.geotag = false,
  });

  final String label;

  /// Called with the encoded data URL of a fresh capture. The field never emits
  /// null of its own accord — Retake re-shoots rather than clearing, and backing
  /// out of a retake keeps the existing photo. `onCaptured(null)` stays a valid
  /// contract call, but nothing in this field triggers it.
  final ValueChanged<String?>? onCaptured;

  /// Called with the whole capture — data URL, device capture time and
  /// `gpsTag` — for callers that upload it as visit evidence.
  final ValueChanged<CapturedPhoto>? onPhotoCaptured;
  final String? helperText;

  /// Geotag the capture (#310). For visit evidence — audit sections and task
  /// closures (#317) — and off by default, so a photo that is not evidence
  /// never asks for the device's location. See [PhotoCaptureService.capture].
  final bool geotag;

  @override
  ConsumerState<PhotoCaptureField> createState() => _PhotoCaptureFieldState();
}

class _PhotoCaptureFieldState extends ConsumerState<PhotoCaptureField> {
  String? _dataUrl;
  String? _error;

  /// Whether the kept frame came back underexposed.
  ///
  /// The review step in [GuidedCaptureScreen] already asked about it and the
  /// agent said keep it — during Stage 6 a dark photo may be the only
  /// obtainable evidence, so it is never dropped. The mark survives into the
  /// section body so the fact travels with the evidence rather than being
  /// forgotten the moment the capture route pops.
  bool _dark = false;

  /// The tile is now a single affordance that hands off to the full-screen
  /// [GuidedCaptureScreen]. That screen owns the capture — it drives the
  /// unchanged [PhotoCaptureService] and surfaces its own errors inline — and
  /// pops the [CapturedPhoto], or `null` when the agent backs out.
  Future<void> _openGuidedCapture() async {
    // A framing line for the guide: the section's own helper if it has one,
    // otherwise a sensible default derived from the label.
    final hint =
        widget.helperText ??
        context.l10n.photoFieldDefaultHint(widget.label.toLowerCase());
    try {
      final photo = await Navigator.of(context).push<CapturedPhoto>(
        agentSectionRoute(
          GuidedCaptureScreen(
            label: widget.label,
            hint: hint,
            geotag: widget.geotag,
          ),
        ),
      );
      if (!mounted) return;
      // A cancel returns null — leave the field exactly as it was (a retake
      // that is backed out of keeps the existing photo).
      if (photo == null) return;
      setState(() {
        _dataUrl = photo.dataUrl;
        _dark = photo.isUnderexposed;
        _error = null;
      });
      widget.onCaptured?.call(photo.dataUrl);
      widget.onPhotoCaptured?.call(photo);
    } catch (e) {
      // The guided screen surfaces capture errors itself; this only guards the
      // handoff, so a permission-denied still reads as an explanation here.
      if (mounted) {
        setState(() => _error = context.l10n.captureError('$e'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final radius = colors.glass
        ? LumenGlass.radiusControl
        : AppColors.radiusControl;
    final addPhoto = InkWell(
      key: const ValueKey('photo-add'),
      borderRadius: BorderRadius.circular(radius),
      onTap: _openGuidedCapture,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        child: Row(
          children: [
            Icon(Icons.add_a_photo_outlined, size: 18, color: colors.brand),
            const SizedBox(width: 10),
            Text(
              l10n.photoFieldAdd,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.ink1,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, size: 18, color: colors.ink3),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(widget.label),
        if (widget.helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.helperText!,
            style: TextStyle(fontSize: 11.5, color: colors.ink3, height: 1.4),
          ),
        ],
        const SizedBox(height: 8),
        if (_dataUrl != null)
          _Preview(
            dataUrl: _dataUrl!,
            dark: _dark,
            onRetake: _openGuidedCapture,
          ),
        if (_dataUrl == null && colors.glass)
          // Glass: a no-blur tile (a section can carry several of these),
          // its ink well inside the pane so the ripple shows over the fill.
          GlassPane(
            key: const ValueKey('photo-capture-tile'),
            kind: GlassKind.tile,
            blur: false,
            radius: radius,
            child: Material(
              type: MaterialType.transparency,
              child: addPhoto,
            ),
          )
        else if (_dataUrl == null)
          // A console-tokened tile framing a single "Add photo" affordance:
          // tapping anywhere on it opens the full-screen GuidedCaptureScreen,
          // which shows what to shoot before the OS camera launches.
          Container(
            key: const ValueKey('photo-capture-tile'),
            decoration: BoxDecoration(
              color: colors.surface2,
              border: Border.all(color: colors.line),
              borderRadius: BorderRadius.circular(AppColors.radiusControl),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppColors.radiusControl),
              child: addPhoto,
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusChip(
                label: l10n.captureErrorChip,
                level: StatusLevel.critical,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _error!,
                  key: const ValueKey('photo-error'),
                  style: TextStyle(fontSize: 11.5, color: colors.ink2),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.dataUrl,
    required this.dark,
    required this.onRetake,
  });

  final String dataUrl;

  /// A frame the exposure check called dark. Marked and questioned here, never
  /// deleted: the agent already chose to keep it.
  final bool dark;

  /// Retake re-opens the guided screen; the current photo survives until a new
  /// one is captured, so a backed-out retake loses nothing.
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final base64Part = dataUrl.split(',').last;
    final radius = BorderRadius.circular(
      colors.glass ? LumenGlass.radiusControl : AppColors.radiusControl,
    );

    Widget photo = ClipRRect(
      borderRadius: radius,
      child: Image.memory(
            base64Decode(base64Part),
            key: const ValueKey('photo-preview'),
            width: 92,
            height: 92,
            fit: BoxFit.cover,
            // A corrupt encode must not take the whole audit screen down.
            errorBuilder: (context, error, stack) => Container(
              width: 92,
              height: 92,
              color: colors.surface2,
              alignment: Alignment.center,
              child: Icon(
                Icons.broken_image_outlined,
                size: 18,
                color: colors.ink3,
              ),
            ),
          ),
        );
    if (colors.glass) {
      // The evidence itself stays unwashed; glass only frames it — a white
      // rim painted over the photo's edge and the tile shadow beneath it.
      final lumen = context.lumen;
      photo = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: lumen.shadow,
              blurRadius: LumenGlass.shadowTile.blurRadius,
              offset: LumenGlass.shadowTile.offset,
            ),
          ],
        ),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: lumen.tileRim),
          ),
          child: photo,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        photo,
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusChip(
              label: dark
                  ? context.l10n.captureDarkCaption
                  : context.l10n.photoFieldCaptured,
              level: dark ? StatusLevel.warning : StatusLevel.good,
            ),
            const SizedBox(height: 6),
            OutlinedButton(
              key: const ValueKey('photo-remove'),
              onPressed: onRetake,
              child: Text(context.l10n.photoFieldRetake),
            ),
          ],
        ),
      ],
    );
  }
}
