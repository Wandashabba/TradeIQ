import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pins its subtree to the dark theme regardless of the app-level ThemeMode.
///
/// The field-agent flow (AgentScaffold screens) and the public login/landing
/// screens ship dark-only in this pass — spec: "Agent side stays pinned
/// dark". Inside this wrapper, `context.colors` resolves to TiqColors.dark,
/// so shared widgets (e.g. console.dart's StatusChip inside
/// photo_capture_field.dart) render dark here while following the toggle in
/// the manager console. Agent light mode is a separate later ticket.
class PinnedDark extends StatelessWidget {
  const PinnedDark({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Theme(data: AppTheme.dark(), child: child);
}
