import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_colors.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';

void main() {
  test('dark theme uses the shared AppColors background', () {
    final theme = AppTheme.dark();
    expect(theme.scaffoldBackgroundColor, AppColors.background);
  });

  test('both themes register the TiqColors extension', () {
    expect(AppTheme.dark().extension<TiqColors>(), same(TiqColors.dark));
    expect(AppTheme.light().extension<TiqColors>(), same(TiqColors.light));
  });

  test('dark component themes are byte-identical to the pre-extension values', () {
    final t = AppTheme.dark();
    expect(t.brightness, Brightness.dark);
    expect(t.scaffoldBackgroundColor, const Color(0xFF0B0C10));
    expect(t.canvasColor, const Color(0xFF14161C));
    expect(t.colorScheme.primary, const Color(0xFF0A6CF0));
    expect(t.appBarTheme.backgroundColor, const Color(0xFF14161C));
    expect(t.inputDecorationTheme.fillColor, const Color(0xFF1A1D25));
    expect(
      (t.cardTheme.shape as RoundedRectangleBorder).side.color,
      const Color(0xFF23262F),
    );
    expect(t.dividerTheme.color, const Color(0xFF23262F));
    expect(t.chipTheme.backgroundColor, const Color(0xFF1A1D25));
    expect(t.textTheme.bodyMedium?.color, const Color(0xFFE9EBEE));
    expect(t.textTheme.bodySmall?.color, const Color(0xFF99A1AD));
    // ink3, post-M6: labelSmall is 10px text, so it rides the 4.5:1 value.
    expect(t.textTheme.labelSmall?.color, const Color(0xFF838D9E));
  });

  test('light derives the same component themes from TiqColors.light', () {
    final t = AppTheme.light();
    expect(t.brightness, Brightness.light);
    expect(t.scaffoldBackgroundColor, TiqColors.light.plane);
    expect(t.appBarTheme.backgroundColor, TiqColors.light.surface1);
    expect(t.inputDecorationTheme.fillColor, TiqColors.light.surface2);
    expect(t.textTheme.bodyMedium?.color, TiqColors.light.ink1);
  });
}
