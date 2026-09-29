/// THE PUBLISHED STANDARDS, IN ONE PLACE.
///
/// On-shelf availability and the perfect-store band are published industry
/// reference points (the design handoff sources them); the rest are the
/// handoff's internal standards. They live here rather than inside the
/// Execution overview because The Floor reads the same two figures the
/// overview does — the execution score and availability — and a score of 73 is
/// not "watch" on one screen and plain ink on another.
///
/// A figure is never read without the line it is measured against, and a
/// figure with no line here is never coloured: see `standing.dart`.
library;

import '../../../core/widgets/torchlight/marks.dart' show StatusLevel;
import '../../../l10n/l10n.dart';

/// The standing, in the three words the console prints for it.
///
/// Here rather than on the Execution overview, where it lived until
/// 29 September 2026, for the reason the file's own preamble gives: The Floor
/// and the overview read the same figures against the same lines, so they have
/// to name a gap with the same word. The Floor's plate started printing it
/// that day, when Night stopped colouring the hero and the standing needed a
/// carrier that was not a hue.
String standingWord(AppLocalizations l10n, StatusLevel level) =>
    switch (level) {
      StatusLevel.critical => l10n.dashStandingCritical,
      StatusLevel.watch => l10n.dashStandingWatch,
      _ => l10n.dashStandingOnTarget,
    };

/// The client's published execution-score standard.
const double executionScoreTarget = 75;

/// On-shelf availability.
const double availabilityStandard = 95;

/// The perfect-store band.
const double perfectStoreStandard = 80;

/// Price compliance.
const double priceStandard = 95;

/// Visibility compliance.
const double visibilityStandard = 80;

/// Share of shelf — the category fair share, not a rate to maximise.
const double shareOfShelfStandard = 33;

/// Weighted distribution.
const double weightedDistributionStandard = 85;

/// Numeric distribution.
const double numericDistributionStandard = 85;
