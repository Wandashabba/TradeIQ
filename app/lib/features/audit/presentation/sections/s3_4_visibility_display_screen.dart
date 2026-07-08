import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  static const _brandingOptions = {'poster': 'Poster', 'shelfStrip': 'Shelf strip', 'wobbler': 'Wobbler'};

  final _branding = {for (final key in _brandingOptions.keys) key: false};
  final _planogram = TextEditingController();
  final _facings = TextEditingController();
  final _cleanliness = TextEditingController();
  bool _highTraffic = false;
  bool _saved = false;

  @override
  void dispose() {
    _planogram.dispose();
    _facings.dispose();
    _cleanliness.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(visibilityRepositoryProvider).saveVisibility(
          visitDraftId: widget.visitDraftId,
          capture: VisibilityCapture(
            brandingElements: Map<String, bool>.from(_branding),
            planogramCompliancePct: double.tryParse(_planogram.text) ?? 0.0,
            facingsCount: int.tryParse(_facings.text) ?? 0,
            highTrafficPass: _highTraffic,
            cleanlinessScore: int.tryParse(_cleanliness.text) ?? 0,
          ),
        );
    if (mounted) setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('S3-S4 Visibility & Display'),
        const SizedBox(height: 8),
        const Text('Branding elements present'),
        for (final entry in _brandingOptions.entries)
          CheckboxListTile(
            key: ValueKey('branding-${entry.key}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(entry.value),
            value: _branding[entry.key] ?? false,
            onChanged: (v) => setState(() => _branding[entry.key] = v ?? false),
          ),
        TextField(
          key: const ValueKey('planogram'),
          controller: _planogram,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Planogram compliance %', isDense: true),
        ),
        TextField(
          key: const ValueKey('facings'),
          controller: _facings,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Facings count', isDense: true),
        ),
        TextField(
          key: const ValueKey('cleanliness'),
          controller: _cleanliness,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Cleanliness score', isDense: true),
        ),
        SwitchListTile(
          key: const ValueKey('high-traffic'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('High-traffic location'),
          value: _highTraffic,
          onChanged: (v) => setState(() => _highTraffic = v),
        ),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _save, child: const Text('Save visibility')),
        if (_saved)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Visibility saved — queued for sync'),
          ),
      ],
    );
  }
}
