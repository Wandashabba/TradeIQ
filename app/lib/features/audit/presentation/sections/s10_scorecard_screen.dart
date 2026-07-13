import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/scorecard_service.dart';

/// S10 — Execution Scorecard: the offline scorecard computed on-device from
/// the queued captures (ADR 0005), shown before the agent leaves the outlet.
/// Finalizing queues a marker so the server recomputes authoritatively.
class S10ScorecardScreen extends ConsumerStatefulWidget {
  const S10ScorecardScreen({super.key, required this.visitDraftId});

  final String visitDraftId;

  @override
  ConsumerState<S10ScorecardScreen> createState() => _S10State();
}

class _S10State extends ConsumerState<S10ScorecardScreen> {
  static const _dimensionLabels = {
    'availability': 'Availability',
    'visibility': 'Visibility',
    'display': 'Display',
    'pricing': 'Pricing',
    'competitive': 'Competitive',
    'salesCapability': 'Sales Capability',
  };

  late Future<LocalScorecard> _scorecard;
  bool _finalized = false;

  @override
  void initState() {
    super.initState();
    _scorecard = ref.read(scorecardServiceProvider).computeForVisit(widget.visitDraftId);
  }

  void _refresh() {
    setState(() {
      _scorecard = ref.read(scorecardServiceProvider).computeForVisit(widget.visitDraftId);
    });
  }

  Future<void> _finalize() async {
    await ref.read(scorecardServiceProvider).finalizeScorecard(widget.visitDraftId);
    if (mounted) setState(() => _finalized = true);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LocalScorecard>(
      future: _scorecard,
      builder: (context, snapshot) {
        final scorecard = snapshot.data;
        if (scorecard == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('S10 Scorecard'),
            const SizedBox(height: 8),
            for (final entry in _dimensionLabels.entries)
              Row(
                key: ValueKey('score-${entry.key}'),
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entry.value),
                  // An absent dimension is UNKNOWN, not zero — e.g. competitive
                  // in an outlet where no competitor was on shelf to measure
                  // against. Printing 0 would read as "you scored nothing".
                  Text(
                    scorecard.dimensionScores.containsKey(entry.key)
                        ? scorecard.dimensionScores[entry.key]!.toStringAsFixed(0)
                        : '—',
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Text(
              'Total: ${scorecard.weightedTotal.toStringAsFixed(1)}',
              key: const ValueKey('score-total'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              scorecard.ratingBand,
              key: const ValueKey('score-band'),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _refresh, child: const Text('Refresh')),
            ElevatedButton(onPressed: _finalize, child: const Text('Finalize scorecard')),
            if (_finalized)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Scorecard queued for sync'),
              ),
          ],
        );
      },
    );
  }
}
