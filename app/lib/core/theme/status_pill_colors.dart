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
/// Every status pill in the app (DeltaPill, SlaPill, StatusBanner's light-mode
/// text tints, the beat-plan "route done" chip) references these — the literal
/// hexes must live here and nowhere else, so they cannot drift.
const StatusPillWash statusPillGood = (
  bg: Color(0xFFE7F5E7),
  fg: Color(0xFF0B6B0B),
);
const StatusPillWash statusPillWarn = (
  bg: Color(0xFFFDF3E2),
  fg: Color(0xFF8A5A00),
);
const StatusPillWash statusPillBad = (
  bg: Color(0xFFFDEEEE),
  fg: Color(0xFFA52A2A),
);
