import 'package:flutter/foundation.dart';

/// What kind of quantity a figure is, for the purpose of deciding whether
/// there is enough of it to believe.
enum MetricKind {
  /// A rate or a percentage — on-shelf availability, coverage, compliance.
  /// The most sample-sensitive thing the product shows: 100% from one visit is
  /// arithmetically true and epistemically worthless.
  rate,

  /// A mean — average basket, average dwell.
  average,

  /// A score. A single visit's score is a **fact about that visit**, not an
  /// estimate of anything, so one is enough.
  score,

  /// A count of things that happened. A count of one is a count of one.
  count,
}

/// THE SAMPLE THRESHOLDS, declared once.
///
/// Declared here and not per caller, because "is three visits enough" is a
/// property of the metric and not of the screen — and because a threshold
/// that each call site chooses is a threshold that is 5 on the dashboard, 3 on
/// the territory view and absent on the scorecard.
///
/// The numbers come straight from the ruling: rates and percentages need
/// n ≥ 5; averages need n ≥ 3; a score needs n ≥ 1.
///
/// The boundary is not a gradient. Exactly at the threshold is the normal
/// treatment with no marker at all.
@immutable
class TiqSample {
  const TiqSample._();

  static int minimumFor(MetricKind kind) => switch (kind) {
    MetricKind.rate => 5,
    MetricKind.average => 3,
    MetricKind.score => 1,
    MetricKind.count => 1,
  };

  /// Whether [n] observations are too few for [kind].
  ///
  /// A null [n] — the wire did not send `sampleSize` — is **not** low sample.
  /// The client does not know, and inventing a number to compare against is
  /// how a good figure gets marked weak. Where a caller does know the sample
  /// is thin but not how thin, it passes [FigureSampling.unknownAndThin].
  static bool isLow(MetricKind kind, int? n) =>
      n != null && n < minimumFor(kind);
}

/// What a caller knows about a figure's sample.
///
/// Three cases, and they are genuinely different: a known n, no n at all, and
/// "the server says this is thin but not how thin". The third exists because
/// the ruling asks for "small sample" in words where no number is available,
/// and a widget cannot tell that apart from "nobody sent the field" unless the
/// caller says so.
@immutable
class FigureSampling {
  const FigureSampling({
    required this.kind,
    this.n,
    this.baselineN,
    this.thinWithoutCount = false,
  });

  /// No sampling information at all. The figure is treated as measured — the
  /// honest default, because marking every figure weak by default is the same
  /// lie in the other direction.
  static const FigureSampling unknown = FigureSampling(kind: MetricKind.rate);

  /// The server says the sample is thin and did not say how thin. The figure
  /// steps down and the meta line reads "small sample" — never a number the
  /// client invented.
  static const FigureSampling unknownAndThin = FigureSampling(
    kind: MetricKind.rate,
    thinWithoutCount: true,
  );

  final MetricKind kind;

  /// Observations behind the current window's figure.
  final int? n;

  /// Observations behind the **baseline** window — the one the delta compares
  /// against.
  ///
  /// This field is the fix for the failure the low-sample rule missed
  /// entirely. Gauteng North loses week 37 to a strike, gets one visit at
  /// 100%, then twenty visits at 84% in week 38. The current window is
  /// healthy, so nothing about the figure is marked — and the delta reads
  /// "−16 pts vs week 37", a hard verdict computed against a single visit, and
  /// a manager reassigns an agent over it. A delta compares two windows and
  /// each has its own n.
  final int? baselineN;

  final bool thinWithoutCount;

  /// Whether the **current** window is too thin to show at full commitment.
  bool get isLowSample =>
      thinWithoutCount || TiqSample.isLow(kind, n);

  /// Whether the **baseline** window is too thin to compare against. On a
  /// load-shedding calendar this is the common case, not the edge case.
  bool get isThinBaseline => TiqSample.isLow(kind, baselineN);

  /// Zero observations is not a low sample — it is no data, and the no-data
  /// treatment takes over.
  bool get isEmpty => n == 0;

  FigureSampling copyWith({int? n, int? baselineN}) => FigureSampling(
    kind: kind,
    n: n ?? this.n,
    baselineN: baselineN ?? this.baselineN,
    thinWithoutCount: thinWithoutCount,
  );
}
