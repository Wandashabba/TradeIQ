import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/camera/photo_capture_service.dart';
import '../../../../core/widgets/torchlight/input.dart';
import '../../../../core/widgets/torchlight/marks.dart';
import '../../../../l10n/l10n.dart';
import '../../data/photos_repository.dart';
import '../../data/visibility_repository.dart';
import 'section_form.dart';
import 'section_photo.dart';

/// S3–S4 — VISIBILITY & DISPLAY. Branding elements present, planogram
/// compliance, facings, high-traffic placement, and cleanliness.
///
/// Three field groups and one photo, in the one section grammar. On save the
/// capture is queued for sync (`POST /visibility`).
///
/// **Amber:** one object, the inline Save, and only once something has changed.
class S3S4VisibilityDisplayScreen extends ConsumerStatefulWidget {
  const S3S4VisibilityDisplayScreen({super.key, required this.visitDraftId});

  final String visitDraftId;

  @override
  ConsumerState<S3S4VisibilityDisplayScreen> createState() => _S3S4State();
}

class _S3S4State extends ConsumerState<S3S4VisibilityDisplayScreen> {
  static const _brandingKeys = <String>['poster', 'shelfStrip', 'wobbler'];

  final _branding = <String, bool>{for (final key in _brandingKeys) key: false};
  final _planogram = TextEditingController();
  final _facings = TextEditingController();
  final _cleanliness = TextEditingController();
  bool _highTraffic = false;
  bool _dirty = false;
  CapturedPhoto? _photo;

  @override
  void dispose() {
    _planogram.dispose();
    _facings.dispose();
    _cleanliness.dispose();
    super.dispose();
  }

  void _touch(VoidCallback change) => setState(() {
    change();
    _dirty = true;
  });

  Future<void> _save() async {
    await ref
        .read(visibilityRepositoryProvider)
        .saveVisibility(
          visitDraftId: widget.visitDraftId,
          capture: VisibilityCapture(
            brandingElements: Map<String, bool>.from(_branding),
            planogramCompliancePct: double.tryParse(_planogram.text) ?? 0.0,
            facingsCount: int.tryParse(_facings.text) ?? 0,
            highTrafficPass: _highTraffic,
            cleanlinessScore: int.tryParse(_cleanliness.text) ?? 0,
          ),
        );

    // The shelf photo is queued to POST /photos as *evidence*, deliberately
    // separate from the visibility payload.
    //
    // It is NOT passed as `photoUrl` on POST /visibility, and that is not an
    // oversight: `visibility.service.ts` treats a non-empty photoUrl as the
    // computer-vision seam and OVERWRITES the agent's measured planogram %,
    // facings and cleanliness with the output of `vision.stub.ts` — which is
    // Math.random(). Sending the photo there would silently replace real field
    // data with noise, and that noise feeds the scorecard and the dashboard.
    //
    // So: capture the evidence now (this is the corpus #1/#2 need to train on),
    // and wire photoUrl through only once the stub is a real model.
    final photo = _photo;
    if (photo != null) {
      await ref
          .read(queuedPhotosRepositoryProvider)
          .queuePhoto(
            visitDraftId: widget.visitDraftId,
            section: 'visibility',
            dataUrl: photo.dataUrl,
            gpsTag: photo.gpsTag,
            capturedAt: photo.capturedAt,
          );
      _photo = null;
    }

    if (mounted) setState(() => _dirty = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brandingOptions = <String, String>{
      'poster': l10n.s34BrandingPoster,
      'shelfStrip': l10n.s34BrandingShelfStrip,
      'wobbler': l10n.s34BrandingWobbler,
    };

    return SectionForm(
      title: l10n.visitSectionVisibility,
      phase: 'visibility',
      dirty: _dirty,
      onSave: _save,
      savedLine: l10n.s34Saved,
      photo: SectionPhotoField(
        label: l10n.s34PhotoLabel,
        framingLine: l10n.s34PhotoHelper,
        photo: _photo,
        onCaptured: (photo) => _touch(() => _photo = photo),
      ),
      children: <Widget>[
        SectionFieldGroup(
          title: l10n.s34BrandingLabel,
          children: <Widget>[
            TorchCheckboxGroup(
              label: l10n.s34BrandingLabel,
              children: <Widget>[
                for (final entry in brandingOptions.entries)
                  TorchCheckbox(
                    key: ValueKey<String>('branding-${entry.key}'),
                    label: entry.value,
                    value: _branding[entry.key] ?? false,
                    onChanged: (v) => _touch(() => _branding[entry.key] = v),
                  ),
              ],
            ),
          ],
        ),
        SectionFieldGroup(
          title: l10n.s34PlanogramLabel,
          children: <Widget>[
            TorchNumericField(
              key: const ValueKey<String>('planogram'),
              label: l10n.s34PlanogramLabel,
              controller: _planogram,
              unit: TiqUnit.percent,
              minimum: 0,
              maximum: 100,
              onChanged: (_) => _touch(() {}),
            ),
            TorchNumericField(
              key: const ValueKey<String>('facings'),
              label: l10n.s34FacingsLabel,
              controller: _facings,
              minimum: 0,
              onChanged: (_) => _touch(() {}),
            ),
            TorchNumericField(
              key: const ValueKey<String>('cleanliness'),
              label: l10n.s34CleanlinessLabel,
              controller: _cleanliness,
              minimum: 0,
              onChanged: (_) => _touch(() {}),
            ),
          ],
        ),
        SectionFieldGroup(
          children: <Widget>[
            TorchToggle(
              key: const ValueKey<String>('high-traffic'),
              label: l10n.s34HighTrafficLabel,
              value: _highTraffic,
              onWord: l10n.wordYes,
              offWord: l10n.wordNo,
              onChanged: (v) => _touch(() => _highTraffic = v),
            ),
          ],
        ),
      ],
    );
  }
}
