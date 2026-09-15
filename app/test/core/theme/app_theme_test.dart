import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_palette.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';

void main() {
  test('dark theme is the night ground', () {
    final theme = AppTheme.dark();
    expect(theme.scaffoldBackgroundColor, TiqColors.night.plane);
  });

  test('both themes register the TiqColors extension', () {
    expect(AppTheme.dark().extension<TiqColors>(), same(TiqColors.night));
    expect(AppTheme.light().extension<TiqColors>(), same(TiqColors.light));
  });

  test('dark derives its component themes from TiqColors.night', () {
    final t = AppTheme.dark();
    const c = TiqColors.night;
    expect(t.brightness, Brightness.dark);
    expect(t.canvasColor, c.surface1);
    expect(t.colorScheme.primary, c.brand);
    // A lavender primary takes the action's dark words, not white.
    expect(t.colorScheme.onPrimary, c.onAction);
    expect(t.appBarTheme.backgroundColor, c.surface1);
    expect(t.inputDecorationTheme.fillColor, c.surface2);
    expect(t.dividerTheme.color, c.line);
    expect(t.textTheme.bodyMedium?.color, c.ink1);
    expect(t.textTheme.labelSmall?.color, c.ink3);
  });

  test('light derives the same component themes from TiqColors.light', () {
    final t = AppTheme.light();
    expect(t.brightness, Brightness.light);
    expect(t.scaffoldBackgroundColor, TiqColors.light.plane);
    expect(t.appBarTheme.backgroundColor, TiqColors.light.surface1);
    expect(t.inputDecorationTheme.fillColor, TiqColors.light.surface2);
    expect(t.textTheme.bodyMedium?.color, TiqColors.light.ink1);
  });

  test('light buttons and panels take the Lumen Glass action and geometry', () {
    final t = AppTheme.light();
    final elevated = t.elevatedButtonTheme.style!;
    expect(
      elevated.backgroundColor!.resolve(<WidgetState>{}),
      TiqColors.light.action,
    );
    final shape =
        elevated.shape!.resolve(<WidgetState>{}) as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(14));
    expect(
      (t.cardTheme.shape as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(20),
    );
  });

  test('dark buttons take the bright night action and glass geometry', () {
    final elevated = AppTheme.dark().elevatedButtonTheme.style!;
    expect(
      elevated.backgroundColor!.resolve(<WidgetState>{}),
      TiqColors.night.action,
    );
    expect(
      elevated.foregroundColor!.resolve(<WidgetState>{}),
      TiqColors.night.onAction,
    );
    final shape =
        elevated.shape!.resolve(<WidgetState>{}) as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(14));
  });

  test('overlays are Lumen Glass in both themes', () {
    final l = AppTheme.light();
    expect(l.dialogTheme.backgroundColor, TiqColors.light.surface1);
    expect(
      (l.dialogTheme.shape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(20),
    );
    expect(l.snackBarTheme.behavior, SnackBarBehavior.floating);
    expect(l.bottomSheetTheme.backgroundColor, TiqColors.light.surface1);
    expect(l.popupMenuTheme.color, TiqColors.light.surface1);

    final d = AppTheme.dark();
    expect(d.dialogTheme.backgroundColor, TiqColors.night.surface1);
    expect(
      (d.dialogTheme.shape! as RoundedRectangleBorder).side.color,
      LumenPalette.dark.panelRim,
    );
    // A pane lifted off the night ground, not the day's near-black.
    expect(d.snackBarTheme.backgroundColor, const Color(0xFF2D2A48));
    expect(d.bottomSheetTheme.backgroundColor, TiqColors.night.surface1);
    expect(d.popupMenuTheme.color, TiqColors.night.surface1);
  });
}
