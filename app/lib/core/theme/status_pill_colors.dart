import 'package:flutter/material.dart';

/// A status pill's wash/text pair: a fixed background and the text colour that
/// clears WCAG AA (4.5:1) on it.
typedef StatusPillWash = ({Color bg, Color fg});

/// The single source of truth for the good/warn/bad status-pill washes.
///
/// These are FIXED status colours, not theme tokens: a verdict reads the same
/// in both themes, and each pair is self-contained — the text clears 4.5:1 on
/// its own wash without help from the plane behind it. That self-containment is
/// exactly why they are hard hexes rather than `context.colors` slots; do not
/// convert them. Pinned by `test/core/theme/status_pill_colors_test.dart`.
///
/// Every status pill in the app (DeltaPill, StatusBanner's light-mode
/// text tints, the beat-plan "route done" chip) references these — the literal
/// hexes must live here and nowhere else, so they cannot drift.
@Deprecated(
  'Torchlight Aisle has no fixed status washes. Severity is one hue at two '
  'commitment levels plus a glyph silhouette and a semanticLabel: watch is a '
  'bad outline with bad ink, critical is a solid badSolid block with '
  'onBadSolid ink, good is a good outline, and held is ink-2 on the well. '
  'There is no warn: severity abandons amber entirely. Use context.skin — see '
  'docs/design/torchlight-aisle.md.',
)
const StatusPillWash statusPillGood = (
  bg: Color(0xFFE7F5E7),
  fg: Color(0xFF0B6B0B),
);
@Deprecated(
  'Torchlight Aisle has no fixed status washes. Severity is one hue at two '
  'commitment levels plus a glyph silhouette and a semanticLabel: watch is a '
  'bad outline with bad ink, critical is a solid badSolid block with '
  'onBadSolid ink, good is a good outline, and held is ink-2 on the well. '
  'There is no warn: severity abandons amber entirely. Use context.skin — see '
  'docs/design/torchlight-aisle.md.',
)
const StatusPillWash statusPillWarn = (
  bg: Color(0xFFFDF3E2),
  fg: Color(0xFF8A5A00),
);
@Deprecated(
  'Torchlight Aisle has no fixed status washes. Severity is one hue at two '
  'commitment levels plus a glyph silhouette and a semanticLabel: watch is a '
  'bad outline with bad ink, critical is a solid badSolid block with '
  'onBadSolid ink, good is a good outline, and held is ink-2 on the well. '
  'There is no warn: severity abandons amber entirely. Use context.skin — see '
  'docs/design/torchlight-aisle.md.',
)
const StatusPillWash statusPillBad = (
  bg: Color(0xFFFDEEEE),
  fg: Color(0xFFA52A2A),
);
