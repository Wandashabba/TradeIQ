import 'package:flutter/widgets.dart';

import '../../../core/design/figure_slot.dart';
import '../../../core/design/tiq_number.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/figure/eyebrow.dart';
import '../../../core/widgets/torchlight/mark/delta.dart';
import '../../../l10n/l10n.dart';
import '../data/chat_controller.dart';
import 'stat_tiles_card.dart' show askUnitFor;

/// The `pillar_metrics` spec — a pillar's headline figures, and what they are
/// up or down against.
///
/// **This is the card comparison was built for.** The workflow being replaced
/// is "filter, export, filter again, overlay the two in Excel", so a figure
/// with nothing beside it has reproduced that problem rather than solved it.
/// When the turn carried a `compareTo`, every metric here wears its movement.
///
/// A block inside the answer's panel, not a panel of its own: one label, a
/// ledger of figures in JetBrains Mono through [FigureSlot] — so an Afrikaans
/// manager reads `88,5%` and a true minus — and one line naming the baseline.
///
/// Reads defensively. The server validates `params` against the spec schema,
/// but the *shape of the tool result* is not part of that contract — a service
/// may add or rename a field and ship before this build does. Every read has a
/// fallback, and a missing figure renders as an omission rather than a zero:
/// "0%" and "we did not measure this" call for opposite responses.
class PillarMetricsCard extends StatelessWidget {
  const PillarMetricsCard({super.key, required this.artifact});

  final ChatArtifact artifact;

  /// Keys that are context rather than headline figures.
  ///
  /// They are real numbers, but they are denominators — putting them in the
  /// same row as a compliance percentage invites reading them as performance.
  static const Set<String> _secondary = {'linesObserved'};

  static const Set<String> _percentSuffixed = {
    'osaPct',
    'onShelfAvailabilityPct',
    'shareOfShelfPct',
    'visibilityCompliancePct',
    'priceCompliancePct',
    'attainmentPct',
  };

  Map<String, dynamic> get _data {
    final data = artifact.data;
    return data is Map<String, dynamic> ? data : const {};
  }

  Map<String, dynamic> get _comparison {
    final value = _data['comparison'];
    return value is Map<String, dynamic> ? value : const {};
  }

  Map<String, dynamic> get _deltas {
    final value = _comparison['deltas'];
    return value is Map<String, dynamic> ? value : const {};
  }

  String _pillarTitle(AppLocalizations l10n) {
    final params = artifact.params;
    final pillar = params is Map<String, dynamic> ? params['pillar'] : null;
    return switch (pillar) {
      'sales' => l10n.askPillarSales,
      'stock' => l10n.askPillarStock,
      'visibility' => l10n.askPillarVisibility,
      'competition' => l10n.askPillarCompetition,
      _ => l10n.askPillarFigures,
    };
  }

  /// The numeric figures in the result, headline ones first.
  ///
  /// Only top-level numbers: the result also carries rows and flags, and a
  /// stray boolean rendered as a metric is worse than an absent one.
  List<MapEntry<String, num>> get _figures {
    final figures = <MapEntry<String, num>>[];
    for (final entry in _data.entries) {
      final value = entry.value;
      if (value is num && value.isFinite) {
        figures.add(MapEntry(entry.key, value));
      }
    }
    figures.sort((a, b) {
      final aSecondary = _secondary.contains(a.key);
      final bSecondary = _secondary.contains(b.key);
      if (aSecondary != bSecondary) return aSecondary ? 1 : -1;
      return 0;
    });
    return figures;
  }

  /// A human label for a metric key, in the reader's language.
  ///
  /// An unlisted key still renders, de-camel-cased — a backend that grows a
  /// metric before this build ships shows it with a plain name rather than
  /// hiding a number the user was told about in the narrative above.
  static String label(AppLocalizations l10n, String key) {
    final known = switch (key) {
      'osaPct' || 'onShelfAvailabilityPct' => l10n.askMetricOsa,
      'shareOfShelfPct' => l10n.askMetricShareOfShelf,
      'visibilityCompliancePct' => l10n.askMetricVisibility,
      'priceCompliancePct' => l10n.askMetricPrice,
      'attainmentPct' => l10n.askMetricAttainment,
      'rateOfSale' => l10n.askMetricRateOfSale,
      'outletsWithStockout' => l10n.askMetricOutletsWithStockout,
      'outOfStockLines' => l10n.askMetricOutOfStockLines,
      'linesObserved' => l10n.askMetricLinesObserved,
      'competitorFacings' => l10n.askMetricCompetitorFacings,
      _ => null,
    };
    if (known != null) return known;
    // camelCase → "Camel case". Better than showing a raw key.
    final spaced = key.replaceAllMapped(
      RegExp(r'(?<=[a-z0-9])([A-Z])'),
      (m) => ' ${m[1]!.toLowerCase()}',
    );
    return spaced.isEmpty ? key : spaced[0].toUpperCase() + spaced.substring(1);
  }

  /// Integers stay integers — "24 lines", not "24.0 lines" — and a rate
  /// keeps one place.
  static int decimalsFor(String key, num value) =>
      !_percentSuffixed.contains(key) && value == value.roundToDouble() ? 0 : 1;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final figures = _figures;
    final baseline = _comparison['label'];
    final hasBaseline = baseline is String && baseline.isNotEmpty;

    return Column(
      key: const ValueKey<String>('pillar-metrics'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // A block label inside the panel — one of the three places an
        // uppercase eyebrow is legal (unify §1.17).
        Eyebrow(_pillarTitle(l10n)),
        SizedBox(height: skin.space.intraBlock),
        if (figures.isEmpty)
          // Honest about an empty answer rather than drawing an empty block.
          Text(
            l10n.askPillarNoFigures,
            style: skin.text.meta.style(color: skin.palette.ink3),
          )
        else
          for (var i = 0; i < figures.length; i++)
            _FigureRow(
              key: ValueKey<String>('pillar-metric-${figures[i].key}'),
              label: label(l10n, figures[i].key),
              value: figures[i].value,
              percent: _percentSuffixed.contains(figures[i].key),
              decimals: decimalsFor(figures[i].key, figures[i].value),
              delta: _deltaFor(figures[i].key),
              last: i == figures.length - 1,
            ),
        if (hasBaseline) ...<Widget>[
          SizedBox(height: skin.space.intraBlock),
          // Says what the movement is against, in words. A triangle on its
          // own is a number without a baseline.
          Text(
            l10n.askPillarComparedWith(baseline),
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
        ],
      ],
    );
  }

  _PillarDelta? _deltaFor(String key) {
    final raw = _deltas[key];
    if (raw is! Map<String, dynamic>) return null;
    final absolute = raw['absolute'];
    if (absolute is! num || !absolute.isFinite) return null;
    final pct = raw['pct'];
    return _PillarDelta(
      absolute: absolute.toDouble(),
      // Null is meaningful, not missing: the server sends it when the baseline
      // was zero, because "up from nothing" has no percentage.
      pct: pct is num && pct.isFinite ? pct.toDouble() : null,
    );
  }
}

class _PillarDelta {
  const _PillarDelta({required this.absolute, required this.pct});

  final double absolute;
  final double? pct;
}

class _FigureRow extends StatelessWidget {
  const _FigureRow({
    super.key,
    required this.label,
    required this.value,
    required this.percent,
    required this.decimals,
    required this.delta,
    required this.last,
  });

  final String label;
  final num value;
  final bool percent;
  final int decimals;
  final _PillarDelta? delta;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final p = skin.palette;
    final veld = skin.mode == SkinMode.veld;
    final d = delta;

    return Container(
      padding: EdgeInsets.symmetric(vertical: veld ? TiqSpace.s3 : TiqSpace.s2),
      // A ledger: rows divided by a rule, so a column of numbers reads as one
      // reading. Hairline between non-tappable rows (unify §1.3).
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: veld ? p.ink1 : p.hairline,
                  width: veld ? 2 : 1,
                ),
              ),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              style: skin.text.body.style(color: p.ink2),
            ),
          ),
          const SizedBox(width: TiqSpace.s3),
          // The figure and its movement are one group that wraps as a group:
          // at 2.0x, or in Afrikaans, the movement drops beneath the figure
          // rather than pushing the row off the panel.
          Flexible(
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: TiqSpace.s2,
              runSpacing: TiqSpace.s1,
              children: <Widget>[
                FigureSlot(
                  value: value,
                  role: skin.text.figureS,
                  unit: percent ? TiqUnit.percent : TiqUnit.none,
                  decimals: decimals,
                  textAlign: TextAlign.end,
                  color: p.ink1,
                ),
                if (d != null)
                  Delta(
                    compact: true,
                    data: DeltaData(
                      direction: d.absolute > 0
                          ? DeltaDirection.up
                          : (d.absolute < 0
                                ? DeltaDirection.down
                                : DeltaDirection.flat),
                      // The tool result carries no sentiment, and the sign
                      // cannot supply one: more stock-outs is up and bad, more
                      // share of shelf is up and good. Neutral is the honest
                      // reading until the server says which way is better.
                      sentiment: TiqSentiment.neutral,
                      magnitude: d.absolute.abs(),
                      // A percentage metric moves in points.
                      unit: percent
                          ? askUnitFor(l10n, 'pts', d.absolute.abs())
                          : TiqUnit.none,
                      decimals: 1,
                    ),
                  ),
                // The relative change beside the absolute one. Absent — never
                // "0%" and never "n/a" — when the baseline was zero, because
                // "up from nothing" has no percentage.
                if (d != null && d.pct != null)
                  FigureSlot(
                    value: d.pct,
                    role: skin.text.monoIdent,
                    unit: TiqUnit.percent,
                    decimals: 1,
                    signed: true,
                    color: p.ink3,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
