import 'package:flutter/widgets.dart';

import '../../../../design/figure_slot.dart';
import '../../../../design/tiq_number.dart';
import '../../../../theme/torchlight/tiq_skin.dart';
import '../sample_threshold.dart';
import 'chart_series.dart';

/// THE NUMBERS BEHIND THE VISUAL. Canonical component 56.
///
/// A chart that is the *only* way to read a value fails anyone using a screen
/// reader, printing it, checking an exact figure, or standing in sunlight with
/// a chart that does not render. The twin is the WCAG-clean equivalent of the
/// same data, and it is **not** a debug view: in Veld it is the whole
/// presentation, because Veld draws no charts at all.
///
/// Three rules it keeps:
///
/// * **The period is unabbreviated.** The axis says `W26` because it has 40dp;
///   this says `2026-W26` because a manager quoting a week into a spreadsheet
///   needs the year.
/// * **A null is an em dash with the unit suppressed**, and the reason sits in
///   the row — never `0`, never `n/a`, never a blank cell that reads as a
///   value somebody forgot to fill in.
/// * **Every figure goes through [FigureSlot].** No `toStringAsFixed`, no
///   `NumberFormat('en_US')`, and the decimal separator is the reader's.
class TableTwin extends StatelessWidget {
  const TableTwin({
    super.key,
    required this.series,
    required this.unit,
    required this.periodHeading,
    required this.notMeasuredWord,
    this.decimals,
    this.sampleKind,
    this.lowSampleWord,
    this.semanticsLabel,
  });

  /// The subject first. A comparison series adds a column.
  final List<ChartSeries> series;

  final TiqUnit unit;
  final int? decimals;

  /// "Period" — the first column's heading, localised.
  final String periodHeading;

  /// The words that stand in for a null figure, localised: "Not measured".
  final String notMeasuredWord;

  /// What kind of quantity these readings are. Non-null makes the twin read
  /// [ChartReading.sampleSize]: a bucket with too few rows behind it prints at
  /// ink-2 rather than at full commitment. Null is today's behaviour — a
  /// caller that does not know the metric's kind does not get to guess one.
  final MetricKind? sampleKind;

  /// The words a thin bucket is captioned and announced with — "Small
  /// sample", "Klein steekproef". Required alongside [sampleKind].
  final String? lowSampleWord;

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    assert(
      sampleKind == null || lowSampleWord != null,
      'TableTwin: a twin that steps a thin bucket down needs the words for '
      'it. Ink-2 is not a channel a screen reader has.',
    );
    final skin = context.skin;
    final subject = series.first;
    final rows = subject.readings;

    return Semantics(
      label: semanticsLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: TiqSpace.s2),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    periodHeading,
                    style: skin.text.meta.style(color: skin.palette.ink3),
                  ),
                ),
                for (final s in series)
                  Expanded(
                    child: Text(
                      s.name,
                      textAlign: TextAlign.end,
                      style: skin.text.meta.style(color: skin.palette.ink3),
                    ),
                  ),
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: TiqSpace.s2),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: skin.palette.hairline,
                    width: skin.depth.borderWidth,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      rows[i].readLabel,
                      style: skin.text.monoIdent.style(
                        color: skin.palette.ink2,
                      ),
                    ),
                  ),
                  for (final s in series)
                    Expanded(
                      child: _Cell(
                        value: i < s.readings.length
                            ? s.readings[i].value
                            : null,
                        lowSample:
                            sampleKind != null &&
                            i < s.readings.length &&
                            TiqSample.isLow(
                              sampleKind!,
                              s.readings[i].sampleSize,
                            ),
                        unit: unit,
                        decimals: decimals,
                        notMeasuredWord: notMeasuredWord,
                        lowSampleWord: lowSampleWord,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.value,
    required this.lowSample,
    required this.unit,
    required this.decimals,
    required this.notMeasuredWord,
    required this.lowSampleWord,
  });

  final double? value;
  final bool lowSample;
  final TiqUnit unit;
  final int? decimals;
  final String notMeasuredWord;
  final String? lowSampleWord;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    if (value == null) {
      // The em dash AND the words. A dash on its own in a column of figures
      // is a hyphen somebody typed.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FigureSlot(
            value: null,
            role: skin.text.figureS,
            unit: TiqUnit.none,
            state: FigureState.missing,
            textAlign: TextAlign.end,
            // The kit asserts on this, and it is right to: an em dash
            // announced as "em dash" is a glyph, not a sentence.
            semanticsLabel: notMeasuredWord,
          ),
          Text(
            notMeasuredWord,
            textAlign: TextAlign.end,
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
        ],
      );
    }
    if (!lowSample) {
      return FigureSlot(
        value: value,
        role: skin.text.figureS,
        unit: unit,
        decimals: decimals,
        textAlign: TextAlign.end,
      );
    }
    // The figure AND the words, for the same reason the null cell carries
    // both: ink-2 against ink-1 is a contrast step a reader in sunlight, in
    // greyscale or on a screen reader does not get.
    final word = lowSampleWord ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FigureSlot(
          value: value,
          role: skin.text.figureS,
          unit: unit,
          decimals: decimals,
          state: FigureState.lowSample,
          textAlign: TextAlign.end,
          semanticsLabel:
              '${TiqNumber.of(context).format(value, unit: unit, decimals: decimals)}, $word',
        ),
        Text(
          word,
          textAlign: TextAlign.end,
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
      ],
    );
  }
}
