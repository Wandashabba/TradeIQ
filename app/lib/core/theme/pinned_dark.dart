import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Pins a subtree to the dark theme regardless of the app-level ThemeMode.
///
/// The field-agent flow (and the pre-auth screens) ship dark-only in this
/// pass: their screens still read the static AppColors table, which is the
/// dark palette by definition — letting the ambient theme go light underneath
/// them would tear surfaces apart. Agent light mode is a separate ticket.
class PinnedDark extends StatelessWidget {
  const PinnedDark({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Theme(data: AppTheme.dark(), child: child);
}
