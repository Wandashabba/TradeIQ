import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/lumen_glass.dart';
import '../../../../core/theme/tiq_colors.dart';
import '../../../../core/widgets/agent_kit.dart';
import '../../../../core/widgets/console.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/photo_capture_field.dart';
import '../../../../l10n/l10n.dart';
import '../../data/photos_repository.dart';
import '../../data/visibility_repository.dart';

/// S3–S4 — Visibility & Display capture: branding elements present, planogram
/// compliance, facings, high-traffic placement, and cleanliness. On save the
/// capture is queued for sync (POST /visibility).
class S3S4VisibilityDisplayScreen extends ConsumerStatefulWidget {
  const S3S4VisibilityDisplayScreen({super.key, required this.visitDraftId});

  final String visitDraftId;

  @override
  ConsumerState<S3S4VisibilityDisplayScreen> createState() => _S3S4State();
}

class _S3S4State extends ConsumerState<S3S4VisibilityDisplayScreen> {
  static const _brandingKeys = ['poster', 'shelfStrip', 'wobbler'];

  final _branding = {for (final key in _brandingKeys) key: false};
  final _planogram = TextEditingController();
  final _facings = TextEditingController();
  final _cleanliness = TextEditingController();
  bool _highTraffic = false;
  bool _saved = false;
  String? _photoDataUrl;

  @override
  void dispose() {
    _planogram.dispose();
    _facings.dispose();
    _cleanliness.dispose();
    super.dispose();
  }

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
    if (_photoDataUrl != null) {
      await ref
          .read(queuedPhotosRepositoryProvider)
          .queuePhoto(
            visitDraftId: widget.visitDraftId,
            section: 'visibility',
            dataUrl: _photoDataUrl!,
          );
    }

    if (mounted) setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final brandingOptions = {
      'poster': l10n.s34BrandingPoster,
      'shelfStrip': l10n.s34BrandingShelfStrip,
      'wobbler': l10n.s34BrandingWobbler,
    };
    final branding = <Widget>[
      SectionLabel(l10n.s34BrandingLabel),
      const SizedBox(height: 4),
      for (final entry in brandingOptions.entries)
        AgentCheck(
          key: ValueKey('branding-${entry.key}'),
          label: entry.value,
          value: _branding[entry.key] ?? false,
          onChanged: (v) => setState(() => _branding[entry.key] = v),
        ),
    ];
    final measures = <Widget>[
      AgentField(
        label: l10n.s34PlanogramLabel,
        child: TextField(
          key: const ValueKey('planogram'),
          controller: _planogram,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: '0–100'),
        ),
      ),
      AgentField(
        label: l10n.s34FacingsLabel,
        child: TextField(
          key: const ValueKey('facings'),
          controller: _facings,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '0'),
        ),
      ),
      AgentField(
        label: l10n.s34CleanlinessLabel,
        child: TextField(
          key: const ValueKey('cleanliness'),
          controller: _cleanliness,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '0'),
        ),
      ),
    ];
    final traffic = AgentToggle(
      key: const ValueKey('high-traffic'),
      label: l10n.s34HighTrafficLabel,
      value: _highTraffic,
      onChanged: (v) => setState(() => _highTraffic = v),
    );

    // No section header here — the shared section wrapper already titles this
    // "Visibility & display".
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (colors.glass) ...[
          // Glass: one tile per question group, so each reads as its own
          // answer rather than a long form.
          _Tile(children: branding),
          const SizedBox(height: 10),
          // AgentField pads its own bottom; the tile trims it back.
          _Tile(bottom: 0, children: measures),
          const SizedBox(height: 10),
          _Tile(vertical: 4, children: [traffic]),
        ] else
          PanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...branding,
                const SizedBox(height: 12),
                ...measures,
                traffic,
              ],
            ),
          ),
        const SizedBox(height: 16),
        PhotoCaptureField(
          label: l10n.s34PhotoLabel,
          helperText: l10n.s34PhotoHelper,
          onCaptured: (dataUrl) => setState(() => _photoDataUrl = dataUrl),
        ),
        const SizedBox(height: 12),
        AgentButton(label: l10n.s34SaveButton, onPressed: _save),
        if (_saved)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              l10n.s34Saved,
              style: TextStyle(fontSize: 13, color: colors.ink2),
            ),
          ),
      ],
    );
  }
}

/// One question group as a no-blur glass tile (the section scrolls).
class _Tile extends StatelessWidget {
  const _Tile({required this.children, this.vertical = 14, this.bottom});

  final List<Widget> children;
  final double vertical;
  final double? bottom;

  @override
  Widget build(BuildContext context) {
    return GlassPane(
      kind: GlassKind.tile,
      blur: false,
      radius: LumenGlass.radiusCard,
      padding: EdgeInsets.fromLTRB(16, vertical, 16, bottom ?? vertical),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
