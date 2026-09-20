import 'package:flutter/material.dart';

import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/lumen_kit.dart';
import '../data/campaigns_repository.dart';

/// The caveat every return carries, always on screen. The figures are orders
/// outlets placed with the client (sell-in), not what shoppers bought
/// (sell-through, #119), and an order carries one campaign when campaigns
/// overlap (#94).
const campaignReturnCaveat =
    'Sell-in, not shopper sales: these are orders stores placed with you, not '
    'what shoppers bought. Where campaigns overlap, an order counts toward '
    'one campaign only.';

/// The honest sentence shown in place of a percentage that cannot be measured.
String roiUnmeasurableReason(RoiUnmeasurable reason) => switch (reason) {
  RoiUnmeasurable.noBudget => "No budget set — return can't be measured.",
  RoiUnmeasurable.zeroBudget => "Budget is zero — return can't be measured.",
  RoiUnmeasurable.unknown => "Return can't be measured for this campaign.",
};

/// A return's status: always a status AND a word, never colour alone.
({LumenStatus status, String word}) roiStatusOf(double? roiPct) =>
    switch (roiPct) {
      null => (status: LumenStatus.none, word: 'Not measured'),
      > 0 => (status: LumenStatus.good, word: 'Positive return'),
      < 0 => (status: LumenStatus.crit, word: 'Negative return'),
      _ => (status: LumenStatus.warn, word: 'Break-even'),
    };

/// Rand, as orders format it (`R 1234.00`), with a true minus when negative
/// and an explicit plus when [signed].
String formatRand(double value, {bool signed = false}) {
  final body = 'R ${value.abs().toStringAsFixed(2)}';
  if (value < 0) return '−$body';
  if (signed && value > 0) return '+$body';
  return body;
}

String _formatPct(double pct) {
  final body = '${pct.abs().toStringAsFixed(1)}%';
  if (pct < 0) return '−$body';
  if (pct > 0) return '+$body';
  return body;
}

String _orders(int n) => '$n ${n == 1 ? 'order' : 'orders'}';

/// A campaign's return: incremental sell-in against spend, the figures that
/// make it, and the caveat that keeps it from being read as consumer sales.
class CampaignReturnView extends StatelessWidget {
  const CampaignReturnView({super.key, required this.roi});

  final CampaignRoi roi;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pct = roi.roiPct;
    final (:status, :word) = roiStatusOf(pct);
    final days = roi.baselineWindow.days;
    final baselineLabel = days >= 1
        ? 'Baseline, prior $days ${days == 1 ? 'day' : 'days'}'
        : 'Baseline, same-length prior window';

    return Column(
      key: ValueKey<String>('roi-${roi.campaignId}'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Return'),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: pct == null
                  ? Text(
                      roiUnmeasurableReason(
                        roi.unmeasurable ?? RoiUnmeasurable.unknown,
                      ),
                      key: const ValueKey<String>('roi-unmeasurable'),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: c.ink2,
                      ),
                    )
                  : Text(
                      _formatPct(pct),
                      key: const ValueKey<String>('roi-headline'),
                      style: LumenGlass.figure(size: 26, color: c.ink1),
                    ),
            ),
            const SizedBox(width: 12),
            LumenStatusPill(
              key: const ValueKey<String>('roi-status'),
              status: status,
              label: word,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _ReturnLine(
          'Sell-in during campaign',
          _orders(roi.attributedOrders),
          formatRand(roi.attributedRevenue),
        ),
        _ReturnLine(
          baselineLabel,
          _orders(roi.baselineOrders),
          formatRand(roi.baselineRevenue),
        ),
        _ReturnLine(
          'Incremental sell-in',
          null,
          formatRand(roi.incrementalRevenue, signed: true),
        ),
        _ReturnLine(
          'Spend',
          null,
          roi.spend == null ? 'Not set' : formatRand(roi.spend!),
        ),
        const SizedBox(height: 10),
        Row(
          key: const ValueKey<String>('roi-caveat'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.info_outline, size: 14, color: c.ink3),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                campaignReturnCaveat,
                style: TextStyle(fontSize: 12, height: 1.35, color: c.ink3),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One figure in the return: the words and their order count left, the mono
/// figure right.
class _ReturnLine extends StatelessWidget {
  const _ReturnLine(this.label, this.meta, this.value);

  final String label;
  final String? meta;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: label,
                children: [
                  if (meta != null)
                    TextSpan(
                      text: ' · $meta',
                      style: LumenGlass.figure(
                        size: 11,
                        color: c.ink3,
                        weight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              style: TextStyle(fontSize: 13, color: c.ink3),
            ),
          ),
          const SizedBox(width: 12),
          Text(value, style: LumenGlass.figure(color: c.ink1)),
        ],
      ),
    );
  }
}
