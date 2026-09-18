import 'dart:ui' show Color;

import '../l10n/l10n.dart';
import 'theme/lumen_glass.dart';
import 'theme/tiq_colors.dart';

/// A scorecard's rating band: the one place the wire value is turned into
/// something a person sees.
///
/// **The wire is unchanged.** The server still sends — and every repository,
/// model and test fixture still keeps — `green` / `amber` / `red`. Only the
/// display name moved: `green` → Healthy, `amber` → Watch, `red` → Gap. A
/// rename on the wire is a separate decision and is deliberately not taken
/// here, so nothing downstream of the data layer breaks.
///
/// The display names exist because the design system cannot have a severity
/// called Amber. Burning Flame (`#FFB162`) is the brand colour and is reserved
/// for emitted light — a rim, an underbar, a focus ring — never for a warning.
/// A band named "amber" that renders in crimson reads as a bug.
///
/// Two rules every render site inherits from this file:
///
/// 1. **Colour is never the only signal.** Every band carries [mark] beside its
///    word, in the '✓' / '!' / '✕' alphabet the rest of the app already uses,
///    so the band survives greyscale, colour blindness and direct sun.
/// 2. **Colour comes from severity, never from the brand.** [status] and
///    [inkOn] only ever reach `good` and the `bad`/`crit` family. There is no
///    `warn` band: severity abandons amber's hue entirely, so [watch] and [gap]
///    share one hue and are told apart by their word and their mark. Anything
///    reaching for `warn`, `brand` or a flame token for a band is the bug.
enum RatingBand {
  /// `green` on the wire.
  healthy('green', '✓', LumenStatus.good),

  /// `amber` on the wire — never shown, and never drawn, as amber.
  watch('amber', '!', LumenStatus.crit),

  /// `red` on the wire.
  gap('red', '✕', LumenStatus.crit);

  const RatingBand(this.wire, this.mark, this.status);

  /// The value the server sends and the data layer stores. Never shown.
  final String wire;

  /// The non-colour signal: meaning that survives a greyscale print.
  final String mark;

  /// The severity slot the band's colour comes from. `good` or `crit` — the
  /// semantic tokens — and never `warn`, which is amber's slot.
  final LumenStatus status;

  /// The band for a wire value, or null when the server sends something this
  /// build does not know. Callers decide what an unbanded scorecard looks
  /// like; they must not guess a severity for it.
  static RatingBand? fromWire(String wire) {
    for (final band in values) {
      if (band.wire == wire) return band;
    }
    return null;
  }

  /// The band for a wire value, falling back to [gap] for anything this build
  /// does not recognise — the conservative read, and what the screens did
  /// before this lived in one place: an unknown band is never called healthy.
  static RatingBand ofWire(String wire) => fromWire(wire) ?? RatingBand.gap;

  /// The translated word — "Watch", "Dophou".
  String word(AppLocalizations l10n) => l10n.ratingBand(wire);

  /// What every surface actually renders: the mark and the word, as one
  /// string, so no render site can keep one and drop the other.
  String markedWord(AppLocalizations l10n) => '$mark ${word(l10n)}';

  /// Flat (non-glass) ink. It is always a label, never a bare mark, so it takes
  /// the text grade: `crit` fails 4.5:1 as text on the hero wash, which is why
  /// Watch and Gap read [TiqColors.critText].
  Color inkOn(TiqColors colors) => switch (this) {
    RatingBand.healthy => colors.good,
    RatingBand.watch || RatingBand.gap => colors.critText,
  };

  /// The ink for a band set on a dark glass pane.
  Color glassInk() => switch (this) {
    RatingBand.healthy => LumenGlass.onDarkGood,
    RatingBand.watch || RatingBand.gap => LumenGlass.onDarkCrit,
  };
}
