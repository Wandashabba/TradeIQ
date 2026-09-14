import 'package:flutter/material.dart';

import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/console.dart';
// Imported directly: console.dart uses DeltaPill but does not re-export it.
import '../../../core/widgets/delta_pill.dart';
import '../data/chat_controller.dart';

/// The `pillar_metrics` spec — a pillar's headline figures, and what they are
/// up or down against.
///
/// **This is the card comparison was built for.** The workflow being replaced
/// is "filter, export, filter again, overlay the two in Excel", so a figure
/// with nothing beside it has reproduced that problem rather than solved it.
/// When the turn carried a `compareTo`, every metric here wears its movement.
///
/// **Deliberately minimal — the anti-crowding rule.** Headline figures, their
/// deltas, and one line naming what the comparison is measured against. No
/// filter chrome and no period picker: Phase 2's Expanded mode is where those
/// belong, and a wall of near-identical panels is the named failure mode for
/// generative UI in a chat surface.
///
/// Reads defensively. The server validates `params` against the spec schema,
/// but the *shape of the tool result* is not part of that contract — a service
/// may add or rename a field and ship before this build does. Every read has a
/// fallback, and a missing figure renders as an omission rather than a zero:
/// "0%" and "we did not measure this" call for opposite responses.
class PillarMetricsCard extends StatelessWidget {
  const PillarMetricsCard({super.key, required this.artifact});

  final ChatArtifact artifact;

  /// Human labels for the figures the pillar services return.
  ///
  /// An unlisted key still renders, de-camel-cased — a backend that grows a
  /// metric before this build ships shows it with a plain name rather than
  /// hiding a number the user was told about in the narrative above.
  static const Map<String, String> _labels = {
    'osaPct': 'On-shelf availability',
    'onShelfAvailabilityPct': 'On-shelf availability',
    'shareOfShelfPct': 'Share of shelf',
    'visibilityCompliancePct': 'Visibility compliance',
    'priceCompliancePct': 'Price compliance',
    'attainmentPct': 'Attainment',
    'rateOfSale': 'Rate of sale',
    'outletsWithStockout': 'Outlets with a stockout',
    'outOfStockLines': 'Out-of-stock lines',
    'linesObserved': 'Lines observed',
    'competitorFacings': 'Competitor facings',
  };

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

  String get _pillarTitle {
    final params = artifact.params;
    final pillar = params is Map<String, dynamic> ? params['pillar'] : null;
    return switch (pillar) {
      'sales' => 'Sales',
      'stock' => 'Stock',
      'visibility' => 'Visibility',
      'competition' => 'Competition',
      _ => 'Pillar figures',
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
      if (value is num && value.isFinite) figures.add(MapEntry(entry.key, value));
    }
    figures.sort((a, b) {
      final aSecondary = _secondary.contains(a.key);
      final bSecondary = _secondary.contains(b.key);
      if (aSecondary != bSecondary) return aSecondary ? 1 : -1;
      return 0;
    });
    return figures;
  }

  static String _label(String key) {
    final known = _labels[key];
    if (known != null) return known;
    // camelCase → "Camel case". Better than showing a raw key.
    final spaced = key.replaceAllMapped(
      RegExp(r'(?<=[a-z0-9])([A-Z])'),
      (m) => ' ${m[1]!.toLowerCase()}',
    );
    return spaced.isEmpty ? key : spaced[0].toUpperCase() + spaced.substring(1);
  }

  static String _format(String key, num value) {
    final suffix = _percentSuffixed.contains(key) ? '%' : '';
    final asDouble = value.toDouble();
    // Integers stay integers: "24 lines", not "24.0 lines".
    final body = asDouble == asDouble.roundToDouble() && suffix.isEmpty
        ? asDouble.round().toString()
        : asDouble.toStringAsFixed(1);
    return '$body$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final figures = _figures;
    final label = _comparison['label'];

    return PanelCard(
      title: _pillarTitle,
      subtitle: label is String && label.isNotEmpty ? 'vs $label' : null,
      child: figures.isEmpty
          // Honest about an empty answer rather than drawing an empty card.
          ? Text(
              'No figures were returned for this period.',
              style: TextStyle(fontSize: 12.5, color: colors.ink3),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (colors.glass)
                  ..._glassRows(context.lumen, figures)
                else
                  for (final figure in figures)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _FigureRow(
                        label: _label(figure.key),
                        value: _format(figure.key, figure.value),
                        delta: _deltaFor(figure.key),
                      ),
                    ),
                if (label is String && label.isNotEmpty)
                  Text(
                    // Says what the movement is against, in words. A pill on its
                    // own is a number without a baseline.
                    'Change is measured against $label.',
                    style: TextStyle(fontSize: 11.5, color: colors.ink3),
                  ),
              ],
            ),
    );
  }

  /// Glass: the figures as table rows, divided by the pane's white rim rather
  /// than spaced apart, so a column of numbers reads as one ledger.
  List<Widget> _glassRows(
    LumenPalette lumen,
    List<MapEntry<String, num>> figures,
  ) => [
    for (var i = 0; i < figures.length; i++)
      Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          border: i == 0
              ? null
              : Border(top: BorderSide(color: lumen.white(0xB3))),
        ),
        child: _FigureRow(
          label: _label(figures[i].key),
          value: _format(figures[i].key, figures[i].value),
          delta: _deltaFor(figures[i].key),
        ),
      ),
    const SizedBox(height: 6),
  ];

  _Delta? _deltaFor(String key) {
    final raw = _deltas[key];
    if (raw is! Map<String, dynamic>) return null;
    final absolute = raw['absolute'];
    if (absolute is! num || !absolute.isFinite) return null;
    final pct = raw['pct'];
    return _Delta(
      absolute: absolute.toDouble(),
      // Null is meaningful, not missing: the server sends it when the baseline
      // was zero, because "up from nothing" has no percentage.
      pct: pct is num && pct.isFinite ? pct.toDouble() : null,
    );
  }
}

class _Delta {
  const _Delta({required this.absolute, required this.pct});

  final double absolute;
  final double? pct;
}

class _FigureRow extends StatelessWidget {
  const _FigureRow({required this.label, required this.value, this.delta});

  final String label;
  final String value;
  final _Delta? delta;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final glass = colors.glass;
    final lumen = context.lumen;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: glass ? lumen.ink : colors.ink2,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          // Glass sets every figure in JetBrains Mono, so a column of them
          // aligns by glyph.
          style: glass
              ? LumenGlass.figure(size: 15, color: lumen.ink)
              : TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.ink1,
                ),
        ),
        if (delta != null) ...[
          const SizedBox(width: 8),
          DeltaPill(
            delta: delta!.absolute,
            tone: delta!.absolute < 0 ? DeltaTone.bad : DeltaTone.good,
          ),
          const SizedBox(width: 6),
          Text(
            // "n/a" rather than a percentage the server refused to invent.
            delta!.pct == null ? 'n/a' : '${delta!.pct!.toStringAsFixed(1)}%',
            style: glass
                ? LumenGlass.figure(
                    size: 11.5,
                    weight: FontWeight.w400,
                    color: lumen.inkMuted,
                  )
                : TextStyle(fontSize: 11.5, color: colors.ink3),
          ),
        ],
      ],
    );
  }
}
