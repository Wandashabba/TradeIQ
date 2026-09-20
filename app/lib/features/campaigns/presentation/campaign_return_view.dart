import 'package:flutter/widgets.dart';

import '../../../core/design/tiq_number.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
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

/// A return's status: always a status **and** a word, never colour alone.
///
/// Three of the four are genuine severities — a negative return is a finding
/// and a positive one is on target — and the fourth is an absence, which takes
/// no chip at all. `null` here is the caller's instruction to render no chip:
/// a grey "Unknown" chip is a claim that the system looked and decided, and
/// nobody decided anything about a campaign with no budget.
({StatusLevel? level, String word}) roiStatusOf(double? roiPct) =>
    switch (roiPct) {
      null => (level: null, word: 'Not measured'),
      > 0 => (level: StatusLevel.onTarget, word: 'Positive return'),
      < 0 => (level: StatusLevel.critical, word: 'Negative return'),
      _ => (level: StatusLevel.watch, word: 'Break-even'),
    };

String _orders(TiqNumber numbers, int n) =>
    '${numbers.format(n)} ${n == 1 ? 'order' : 'orders'}';

/// A CAMPAIGN'S RETURN — incremental sell-in against spend, the figures that
/// make it, and the caveat that keeps it from being read as consumer sales.
///
/// ## Unmeasurable is not zero, and it is not a chip
///
/// A campaign with no budget has no return. It does not render 0%, it does not
/// render ∞, and it does not render a grey chip saying "Unknown" — it renders
/// the sentence that names the reason, because the reader's next action is to
/// go and set a budget.
class CampaignReturnView extends StatelessWidget {
  const CampaignReturnView({super.key, required this.roi});

  final CampaignRoi roi;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final numbers = TiqNumber.of(context);
    final pct = roi.roiPct;
    final (:level, :word) = roiStatusOf(pct);
    final days = roi.baselineWindow.days;
    final baselineLabel = days >= 1
        ? 'Baseline, prior $days ${days == 1 ? 'day' : 'days'}'
        : 'Baseline, same-length prior window';

    return Column(
      key: ValueKey<String>('roi-${roi.campaignId}'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionRule('Return'),
        const SizedBox(height: TiqSpace.s4),
        // A WRAP, not a row. At 2.0x a `+25,5 %` at figure.l beside a
        // "Positiewe opbrengs" chip is wider than a 360dp phone, and a Row of
        // two intrinsically-sized children cannot give way. The chip drops
        // beneath the figure instead of overflowing beside it.
        Wrap(
          spacing: TiqSpace.s3,
          runSpacing: TiqSpace.s3,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            if (pct == null)
              Text(
                roiUnmeasurableReason(
                  roi.unmeasurable ?? RoiUnmeasurable.unknown,
                ),
                key: const ValueKey<String>('roi-unmeasurable'),
                style: skin.text.bodyStrong.style(color: skin.palette.ink2),
              )
            else
              FigureSlot(
                key: const ValueKey<String>('roi-headline'),
                value: pct,
                role: skin.text.figureL,
                fit: <TiqTypeToken>[skin.text.figureL, skin.text.figureM],
                unit: TiqUnit.percent,
                decimals: 1,
                signed: true,
                color: skin.palette.ink1,
              ),
            // No level means no chip: an absence is stated in words above,
            // and a chip would be a verdict nobody reached.
            if (level != null)
              StatusChip(
                key: const ValueKey<String>('roi-status'),
                level: level,
                label: word,
              ),
          ],
        ),
        const SizedBox(height: TiqSpace.s4),
        _ReturnLine(
          'Sell-in during campaign',
          _orders(numbers, roi.attributedOrders),
          roi.attributedRevenue,
        ),
        _ReturnLine(
          baselineLabel,
          _orders(numbers, roi.baselineOrders),
          roi.baselineRevenue,
        ),
        _ReturnLine(
          'Incremental sell-in',
          null,
          roi.incrementalRevenue,
          signed: true,
        ),
        // A spend that was never recorded is an em dash and a word, never a 0
        // — nought rand of spend and no budget at all are different facts.
        _ReturnLine('Spend', roi.spend == null ? 'Not set' : null, roi.spend),
        const SizedBox(height: TiqSpace.s4),
        Text(
          campaignReturnCaveat,
          key: const ValueKey<String>('roi-caveat'),
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
      ],
    );
  }
}

/// One figure in the return: the words and their order count left, the mono
/// figure right.
class _ReturnLine extends StatelessWidget {
  const _ReturnLine(this.label, this.meta, this.value, {this.signed = false});

  final String label;
  final String? meta;
  final double? value;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TiqSpace.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              meta == null ? label : '$label · $meta',
              style: skin.text.meta.style(color: skin.palette.ink3),
            ),
          ),
          const SizedBox(width: TiqSpace.s3),
          // Flexible, so the slot is measured against the width it actually
          // has: an unconstrained FigureSlot is handed an infinite maxWidth,
          // never picks its smaller candidate role, and overflows the row at
          // 2.0x instead of stepping down.
          Flexible(
            child: FigureSlot(
              value: value,
              role: skin.text.figureS,
              unit: TiqUnit.currency,
              decimals: 2,
              signed: signed,
              state: value == null ? FigureState.missing : FigureState.measured,
              semanticsLabel: value == null ? 'Not set' : null,
              color: value == null ? skin.palette.ink3 : skin.palette.ink1,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
