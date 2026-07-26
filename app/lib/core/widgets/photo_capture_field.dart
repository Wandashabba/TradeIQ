import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../camera/photo_capture_service.dart';
import '../theme/app_colors.dart';
import '../theme/tiq_colors.dart';
import 'agent_motion.dart';
import 'console.dart';
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
    required this.onCaptured,
    this.helperText,
  });

  final String label;

  /// Called with the encoded data URL of a fresh capture. The field never emits
  /// null of its own accord — Retake re-shoots rather than clearing, and backing
  /// out of a retake keeps the existing photo. `onCaptured(null)` stays a valid
  /// contract call, but nothing in this field triggers it.
  final ValueChanged<String?> onCaptured;
  final String? helperText;

  @override
  ConsumerState<PhotoCaptureField> createState() => _PhotoCaptureFieldState();
}

class _PhotoCaptureFieldState extends ConsumerState<PhotoCaptureField> {
  String? _dataUrl;
  String? _error;

  /// The tile is now a single affordance that hands off to the full-screen
  /// [GuidedCaptureScreen]. That screen owns the capture — it drives the
  /// unchanged [PhotoCaptureService] and surfaces its own errors inline — and
  /// pops the encoded `dataUrl`, or `null` when the agent backs out.
  Future<void> _openGuidedCapture() async {
    // A framing line for the guide: the section's own helper if it has one,
    // otherwise a sensible default derived from the label.
    final hint =
        widget.helperText ??
        'Frame the ${widget.label.toLowerCase()} '
            'inside the guides, edge to edge.';
    try {
      final dataUrl = await Navigator.of(context).push<String>(
        agentSectionRoute(GuidedCaptureScreen(label: widget.label, hint: hint)),
      );
      if (!mounted) return;
      // A cancel returns null — leave the field exactly as it was (a retake
      // that is backed out of keeps the existing photo).
      if (dataUrl == null) return;
      setState(() {
        _dataUrl = dataUrl;
        _error = null;
      });
      widget.onCaptured(dataUrl);
    } catch (e) {
      // The guided screen surfaces capture errors itself; this only guards the
      // handoff, so a permission-denied still reads as an explanation here.
      if (mounted) setState(() => _error = 'Could not capture a photo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
          _Preview(dataUrl: _dataUrl!, onRetake: _openGuidedCapture),
        if (_dataUrl == null)
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
              child: InkWell(
                key: const ValueKey('photo-add'),
                borderRadius: BorderRadius.circular(AppColors.radiusControl),
                onTap: _openGuidedCapture,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 15,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 18,
                        color: colors.brand,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Add photo',
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
              ),
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StatusChip(label: 'Error', level: StatusLevel.critical),
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
  const _Preview({required this.dataUrl, required this.onRetake});

  final String dataUrl;

  /// Retake re-opens the guided screen; the current photo survives until a new
  /// one is captured, so a backed-out retake loses nothing.
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final base64Part = dataUrl.split(',').last;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppColors.radiusControl),
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
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StatusChip(label: 'Captured', level: StatusLevel.good),
            const SizedBox(height: 6),
            OutlinedButton(
              key: const ValueKey('photo-remove'),
              onPressed: onRetake,
              child: const Text('Retake'),
            ),
          ],
        ),
      ],
    );
  }
}
