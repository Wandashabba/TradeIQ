import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../camera/photo_capture_service.dart';
import '../theme/app_colors.dart';
import '../theme/tiq_colors.dart';
import 'console.dart';

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

  /// Called with the encoded data URL, or null when the photo is removed.
  final ValueChanged<String?> onCaptured;
  final String? helperText;

  @override
  ConsumerState<PhotoCaptureField> createState() => _PhotoCaptureFieldState();
}

class _PhotoCaptureFieldState extends ConsumerState<PhotoCaptureField> {
  String? _dataUrl;
  String? _error;
  bool _busy = false;

  Future<void> _capture(PhotoSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final photo = await ref.read(photoCaptureServiceProvider).capture(source);
      // A cancel is a normal outcome, not a failure — leave the field as it was.
      if (photo == null) return;
      setState(() => _dataUrl = photo.dataUrl);
      widget.onCaptured(photo.dataUrl);
    } on PhotoTooLargeException catch (e) {
      setState(() => _error = e.toString());
    } catch (e) {
      // Denied camera permission lands here. Say so — an agent who thinks the
      // button is broken will stop filing evidence.
      setState(() => _error = 'Could not capture a photo: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _remove() {
    setState(() => _dataUrl = null);
    widget.onCaptured(null);
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
        if (_dataUrl != null) _Preview(dataUrl: _dataUrl!, onRemove: _remove),
        if (_dataUrl == null)
          // A console-tokened tile frames the capture affordance so the empty
          // state reads as a deliberate slot, not two loose buttons. (The full
          // guided-camera redesign is sub-5c — this only re-skins the shell.)
          Container(
            key: const ValueKey('photo-capture-tile'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surface2,
              border: Border.all(color: colors.line),
              borderRadius: BorderRadius.circular(AppColors.radiusControl),
            ),
            // Wrap, not Row: the tile's inset narrows the ground, and in a
            // constrained context (the tasks closure sheet) the two buttons
            // must fall to a second line rather than overflow.
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('photo-camera'),
                  onPressed: _busy ? null : () => _capture(PhotoSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined, size: 15),
                  label: const Text('Take photo'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('photo-gallery'),
                  onPressed: _busy ? null : () => _capture(PhotoSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 15),
                  label: const Text('Choose'),
                ),
                if (_busy)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
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
  const _Preview({required this.dataUrl, required this.onRemove});

  final String dataUrl;
  final VoidCallback onRemove;

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
              onPressed: onRemove,
              child: const Text('Retake'),
            ),
          ],
        ),
      ],
    );
  }
}
