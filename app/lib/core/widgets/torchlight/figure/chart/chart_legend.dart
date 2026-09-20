import 'package:flutter/widgets.dart';

import '../../../../theme/torchlight/tiq_skin.dart';
import 'chart_series.dart';

/// THE LEGEND. Not optional, ever.
///
/// A chart with two runs on it and no legend is a picture of two lines. The
/// old `LineChart` took `comparisonName` and drew the key only when it felt
/// like it; here [TrendChart] builds this itself from the series it was
/// handed, so a caller cannot ship a chart without one.
///
/// Each entry draws the **sample of the mark it names** — a solid 2dp run for
/// the subject, a dashed 1.5dp run for the comparison, a dashed rule for a
/// threshold — so the key is legible with the hue removed. That is the whole
/// job: unify §4 requires a second channel on every hue-coded distinction, and
/// a legend whose swatches are three identical rectangles in three colours is
/// the first channel twice.
class ChartLegend extends StatelessWidget {
  const ChartLegend({
    super.key,
    required this.series,
    required this.dashedWord,
    this.threshold,
    this.gapNote,
  });

  final List<ChartSeries> series;
  final ChartThreshold? threshold;

  /// The word a reader hears where the swatch is dashed — "dashed",
  /// "gestippel". **Required, and localised by the caller**: the dash is the
  /// second channel the whole legend exists to carry (unify §4), so the one
  /// word that makes the key legible without hue is the last word that may be
  /// left in English. Nothing in this folder imports `l10n`.
  final String dashedWord;

  /// "2 weeks not measured" — the sentence a broken line needs beside it.
  /// Null when every bucket measured something.
  final String? gapNote;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final entries = <Widget>[
      for (final s in series)
        _LegendEntry(
          label: s.name,
          dashedWord: dashedWord,
          colour: s.role == ChartSeriesRole.subject
              ? skin.palette.chartNeutral
              : skin.palette.comparison,
          dashed: s.role == ChartSeriesRole.comparison,
          thickness: s.role == ChartSeriesRole.subject ? 2 : 1.5,
        ),
      if (threshold != null)
        _LegendEntry(
          label: threshold!.label,
          dashedWord: dashedWord,
          colour: skin.palette.ink1,
          dashed: true,
          thickness: 1,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // A Wrap and not a Row: at 2.0x in Afrikaans "Kliëntgemiddeld" and
        // "Gekonfigureerde standaard" do not share a 360dp line, and a legend
        // that ellipsised would be a key you cannot read.
        Wrap(spacing: TiqSpace.s5, runSpacing: TiqSpace.s2, children: entries),
        if (gapNote != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s2),
          Text(gapNote!, style: skin.text.meta.style(color: skin.palette.ink3)),
        ],
      ],
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({
    required this.label,
    required this.dashedWord,
    required this.colour,
    required this.dashed,
    required this.thickness,
  });

  final String label;
  final String dashedWord;
  final Color colour;
  final bool dashed;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final scaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    // The swatch is meaning-bearing — it is the only place the dash pattern is
    // named — so it scales with the text, at half rate like every other
    // graphic.
    final scale = ((scaler.scale(1) - 1) / 2 + 1).clamp(1.0, 2.0);

    return Semantics(
      label: dashed ? '$label, $dashedWord' : label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          CustomPaint(
            size: Size(24 * scale, thickness * scale * 2),
            painter: _SwatchPainter(
              colour: colour,
              dashed: dashed,
              thickness: thickness * scale,
            ),
          ),
          const SizedBox(width: TiqSpace.s2),
          Flexible(
            child: Text(
              label,
              style: skin.text.meta.style(color: skin.palette.ink2),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwatchPainter extends CustomPainter {
  const _SwatchPainter({
    required this.colour,
    required this.dashed,
    required this.thickness,
  });

  final Color colour;
  final bool dashed;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.butt;
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    const dash = 5.0;
    const gap = 3.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + dash).clamp(0, size.width), y),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_SwatchPainter old) =>
      old.colour != colour ||
      old.dashed != dashed ||
      old.thickness != thickness;
}
