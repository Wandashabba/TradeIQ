import 'package:flutter/widgets.dart';

import '../../../design/figure_slot.dart';
import '../../../design/tiq_number.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import '../mark/delta.dart';
import '../mark/severity_mark.dart';
import '../mark/tiq_mark.dart';
import 'eyebrow.dart';
import 'meter.dart';
import 'provisional.dart';
import 'sample_threshold.dart';

/// What a tile's meter is drawing, if it has one.
@immutable
class MeterData {
  const MeterData({
    required this.value,
    this.minimum = 0,
    this.maximum = 100,
    this.target,
    this.notMeasuredReason,
  });

  /// Null renders the outlined empty track with no tick.
  final double? value;
  final double minimum;
  final double maximum;

  /// Null renders **no tick**. Never a tick at 100 and never one at the
  /// midpoint: an invented target is a target somebody gets measured against.
  final double? target;

  /// Non-null puts the track in the hatched not-measured state and supplies
  /// the sentence that has to go with it.
  final String? notMeasuredReason;
}

/// Which way a tile lays out.
enum StatTileLayout {
  /// **The phone layout, and the primary one.** Eyebrow expanded left, figure
  /// right-aligned, meter beneath, delta beneath.
  ///
  /// At 360dp with a 20dp gutter and 16dp of panel padding the inner panel is
  /// 288dp — below the 320dp at which a cluster would go two-up. So the square
  /// cell an earlier draft specified, and every argument built on "a 2×2 grid
  /// of tiles", describes a screen no manager holds.
  horizontal,

  /// The console layout: eyebrow, figure, meter, delta stacked. Tablet and
  /// desktop, at ≥320dp of inner width.
  vertical,
}

/// The English defaults for a tile's state lines. A localised screen passes
/// its own; none of them is ever absent.
@immutable
class StatTileStrings {
  const StatTileStrings({
    this.smallSample = 'small sample',
    this.notScored = 'not scored',
    this.provisional = 'Provisional',
  });

  final String smallSample;
  final String notScored;
  final String provisional;

  static const StatTileStrings defaults = StatTileStrings();
}

/// One figure in an instrument cluster: eyebrow, figure, optional meter,
/// optional delta — with no card of its own.
///
/// ## Unknown versus zero, which is the whole of this component
///
/// * A **measured zero** renders `0`. It keeps its place, it is never
///   suppressed, and its delta is the flat bar. An all-zero list is a finding,
///   not an empty state.
/// * A **null** renders an em dash in ink-3, at the figure's own role and
///   face, with the unit suppressed, no delta, and a sentence in words. Pass
///   [noDataReason] — the assert below refuses a tile that has no figure and
///   nothing to say about it.
/// * **Not measured** — a dimension nobody scored — is an em dash plus a
///   full-width falling hatch on the track plus a reason. Set
///   [MeterData.notMeasuredReason].
/// * **Low sample** keeps the figure at ink-2, outlines the meter's fill, and
///   removes the delta — for a thin baseline as well as a thin current window.
///
/// **A tile is never hidden.** A cluster that silently drops a tile changes
/// shape, and the reader cannot tell whether the metric was bad or missing.
///
/// ## No amber
///
/// Not in the figure, not in the eyebrow, not in the meter's target tick. A
/// stat tile emits nothing on the `TorchScope` ladder and declares no claim; a
/// route that genuinely wants its dashboard figure lit declares it as the
/// route's `subject` and the emitter is the chart, not the tile.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.eyebrow,
    required this.value,
    this.unit = TiqUnit.none,
    this.decimals,
    this.sampling = FigureSampling.unknown,
    this.delta,
    this.meter,
    this.noDataReason,
    this.sampleNote,
    this.stateLine,
    this.freshness,
    this.provisional = false,
    this.reconciliation,
    this.lead = false,
    this.severity,
    this.subordinates,
    this.layout,
    this.padding,
    this.strings = StatTileStrings.defaults,
    this.deltaStrings = DeltaStrings.defaults,
    this.onTap,
    this.semanticsHint,
  }) : assert(
         value != null || noDataReason != null,
         'StatTile: a tile with no figure needs a sentence. Pass '
         'noDataReason — "No visits in this window" — because an em dash on '
         'its own is a puzzle and a zero in its place is a lie. The tile is '
         'never hidden and a grey "Unknown" chip is never shown.',
       );

  /// The label. Uppercase, 11/700, +4% tracking, two lines — and at full ink
  /// in every state including no data, because the label is still true when
  /// the figure is not.
  final String eyebrow;

  /// Null is a state, not an absence.
  final num? value;

  final TiqUnit unit;

  /// The metric's declared precision, where the server sends one. A metric
  /// reported to two places prints `4.10`: the second place says the metric
  /// resolves that finely.
  final int? decimals;

  final FigureSampling sampling;

  final DeltaData? delta;
  final MeterData? meter;

  /// The words for a null figure. "No visits in this window", or the cause
  /// where the server knows it: "No competitor on shelf", "Outlet closed all
  /// week".
  final String? noDataReason;

  /// "from 3 visits". Defaults to the count where there is one and to "small
  /// sample" where there is not — never a number the client invented.
  final String? sampleNote;

  /// A caller-supplied state line: an error, a filter note. Renders under the
  /// figure in meta ink-3.
  final String? stateLine;

  /// " · as of 14:06". A **second slot**, not the same one as the state line,
  /// so a tile that is provisional *and* stale cannot lose its staleness.
  final String? freshness;

  /// Server-stamped provisional (#410). Console only — the agent app never
  /// shows a provisional score.
  final bool provisional;

  /// Rendered under the figure when a final replaced a provisional that
  /// differed.
  final ReconciliationLine? reconciliation;

  /// The "lead indicator" variant: this figure is what sends somebody to an
  /// outlet, and its neighbours are not its peers. Adds a severity outline and
  /// a line of subordinate figures.
  final bool lead;

  /// The lead tile's standing. Outline for watch, solid for critical — never
  /// a fill on a plain tile.
  final SeverityMarkKind? severity;

  /// "Coverage 78% · Price compliance 91%". Renders what exists; never padded
  /// to three because a reference had three.
  final String? subordinates;

  /// Null measures the tile's own width and picks.
  final StatTileLayout? layout;

  /// Overrides the density's own inset.
  ///
  /// The default is right for a tile inside a panel or wearing the lead
  /// variant's severity outline: an outline needs something to be outside of.
  /// It is wrong for a bare tile on the ground, where the shell has already
  /// spent the gutter — there the inset is a second, invisible gutter that
  /// pushes the eyebrow 16dp past every other left edge on the screen and
  /// spends 32dp of fold on nothing. `EdgeInsets.zero` is the honest value in
  /// that case, and the caller is the only one who knows which case it is in.
  final EdgeInsetsGeometry? padding;

  final StatTileStrings strings;
  final DeltaStrings deltaStrings;

  /// Opens the figure's provenance: the window, the sample size, the
  /// definition, the table twin. A composite number nobody can decompose is a
  /// number you cannot act on.
  final VoidCallback? onTap;

  final String? semanticsHint;

  /// The inner width at which a cluster stops being a column. Every phone is
  /// below it.
  static const double consoleWidth = 320;

  /// How much of a horizontal tile's width the figure may claim. The eyebrow
  /// keeps the rest and wraps into it; "R 1,28 mln" at `figure.l` is about
  /// 150dp and steps down to `figure.m` when it is not given that.
  static const double _figureShare = 0.62;

  /// The figure's state, resolved from the value and the sample. Exposed
  /// because the delta rule and the tests both need it, and because a state
  /// that is computed in a `build` method is a state nobody can assert on.
  FigureState get figureState {
    if (value == null) return FigureState.missing;
    if (sampling.isLowSample) return FigureState.lowSample;
    if (provisional) return FigureState.provisional;
    return FigureState.measured;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    if (layout != null) return _build(context, skin, layout!);
    return LayoutBuilder(
      builder: (context, constraints) => _build(
        context,
        skin,
        constraints.maxWidth < consoleWidth
            ? StatTileLayout.horizontal
            : StatTileLayout.vertical,
      ),
    );
  }

  static double _insetFor(TiqSkin skin) => switch (skin.density) {
    TiqDensity.console => 16.0,
    TiqDensity.field => 20.0,
    TiqDensity.veld => 24.0,
  };

  Widget _build(BuildContext context, TiqSkin skin, StatTileLayout resolved) {
    final resolvedPadding = padding ?? EdgeInsets.all(_insetFor(skin));
    final minHeight = switch (skin.density) {
      TiqDensity.console => 88.0,
      TiqDensity.field => 96.0,
      TiqDensity.veld => 128.0,
    };

    final figure = _figure(skin);
    final label = Eyebrow(eyebrow);

    final head = resolved == StatTileLayout.horizontal
        ? LayoutBuilder(
            builder: (context, constraints) => Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                // Expanded, so the figures of a stacked cluster align on one
                // right edge — which is the instrument-panel read and the
                // reason the run is monospace.
                Expanded(child: label),
                const SizedBox(width: 12),
                // A bounded box rather than a flex child: the figure takes
                // only the width it needs, and FigureSlot needs a finite
                // constraint to *measure* its candidate roles against. A
                // non-flex child of a Row is handed an unbounded main axis,
                // and an unbounded measurement is no measurement.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth.isFinite
                        ? constraints.maxWidth * _figureShare
                        : double.infinity,
                  ),
                  child: figure,
                ),
              ],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[label, const SizedBox(height: 8), figure],
          );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        head,
        if (meter != null) ...<Widget>[
          const SizedBox(height: 8),
          Meter(
            value: meter!.value,
            minimum: meter!.minimum,
            maximum: meter!.maximum,
            target: meter!.target,
            state: _meterState,
            reasonForHatch: meter!.notMeasuredReason,
          ),
        ],
        ..._notes(context, skin),
      ],
    );

    final outlined =
        lead &&
        (severity == SeverityMarkKind.watch ||
            severity == SeverityMarkKind.critical);

    final tile = Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: resolvedPadding,
      decoration: outlined
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(skin.radii.chip),
              // Outline, never fill. A filled severity block inside a cluster
              // is a second severity system competing with the row's bar.
              border: Border.all(
                color: severity == SeverityMarkKind.critical
                    ? skin.palette.badSolid
                    : skin.palette.bad,
                width: skin.depth.borderWidth,
              ),
            )
          : null,
      child: body,
    );

    final announced = Semantics(
      container: true,
      label: eyebrow,
      value: _spokenValue(context),
      hint: semanticsHint,
      button: onTap != null,
      excludeSemantics: true,
      child: tile,
    );

    if (onTap == null) return announced;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: announced,
    );
  }

  Widget _figure(TiqSkin skin) => FigureSlot(
    value: value,
    role: skin.text.figureL,
    // Measured, not guessed: the first role whose real glyphs and real
    // affixes fit the real constraint at the real scale wins.
    fit: <TiqTypeToken>[skin.text.figureL, skin.text.figureM],
    unit: unit,
    decimals: decimals,
    state: figureState,
    textAlign: TextAlign.end,
    // A low-sample figure keeps its role and its size and steps one ink level
    // down; a missing one is ink-3 whatever anybody asked for. Both are
    // decided inside FigureSlot, which is why the tile does not pass a colour.
    semanticsLabel: figureState == FigureState.measured ? null : _figureWords(),
  );

  String _figureWords() => switch (figureState) {
    FigureState.missing ||
    FigureState.notMeasured => noDataReason ?? strings.notScored,
    FigureState.lowSample => _sampleWords(),
    FigureState.provisional => strings.provisional,
    FigureState.measured => '',
  };

  String _sampleWords() {
    final note = sampleNote;
    if (note != null) return note;
    final n = sampling.n;
    return n == null ? strings.smallSample : 'from $n';
  }

  MeterState get _meterState {
    if (meter == null) return MeterState.missing;
    if (meter!.notMeasuredReason != null) return MeterState.notMeasured;
    if (value == null || meter!.value == null) return MeterState.missing;
    if (sampling.isLowSample) return MeterState.lowSample;
    return MeterState.filled;
  }

  /// Everything under the figure and the meter, in declared order: the delta
  /// (or the sentence that replaces it), the sample note, the provisional
  /// marker, the reconciliation, the state line and the freshness suffix.
  List<Widget> _notes(BuildContext context, TiqSkin skin) {
    final meta = skin.text.meta.style(color: skin.palette.ink3);
    final out = <Widget>[];

    void add(Widget w) {
      out
        ..add(const SizedBox(height: 8))
        ..add(w);
    }

    // The delta slot decides for itself whether it is a delta, a sentence, or
    // nothing at all. A delta never stands beside nothing.
    final deltaSuppression = DeltaRule.resolve(
      figureState: figureState,
      delta: delta,
      sampling: sampling,
    );
    if (deltaSuppression != DeltaSuppression.noData &&
        deltaSuppression != DeltaSuppression.nullFigure) {
      add(
        DeltaSlot(
          data: delta,
          figureState: figureState,
          sampling: sampling,
          strings: deltaStrings,
          compact: true,
        ),
      );
    }

    if (value == null) {
      // The words, always. Never a zero, never a 0%, never a "—%", never a
      // delta arrow, never a zero-length bar, and never a hidden tile.
      add(Text(noDataReason!, style: meta));
    } else if (sampling.isLowSample) {
      add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TiqMark(
              shape: MarkShape.hollowSquare,
              color: skin.palette.ink3,
              size: MarkScale.glyph(context, 7),
              strokeWidth: 1.5,
            ),
            const SizedBox(width: 4),
            Flexible(child: Text(_sampleWords(), style: meta)),
          ],
        ),
      );
    }

    if (provisional && value != null) {
      add(ProvisionalMarker(word: strings.provisional));
    }
    if (reconciliation != null) add(reconciliation!);
    if (subordinates != null) add(Text(subordinates!, style: meta));
    if (stateLine != null) add(Text(stateLine!, style: meta));
    if (freshness != null) add(Text(freshness!, style: meta));
    return out;
  }

  /// What a screen reader says in place of the figure. An em dash is never
  /// spoken as "dash": the reason is part of the same utterance, so absence
  /// and cause arrive together.
  String _spokenValue(BuildContext context) {
    if (value == null) return noDataReason!;
    final spoken = TiqNumber.of(
      context,
    ).format(value, unit: unit, decimals: decimals);
    return sampling.isLowSample ? '$spoken, ${_sampleWords()}' : spoken;
  }
}
