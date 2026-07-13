import 'package:flutter/material.dart';
import 'app_colors.dart';

/// The TradeIQ dark theme.
///
/// Geometry is squared off — controls are 3px, panels 4px, and nothing is a
/// stadium/pill. One type family throughout (Inter), including on large
/// figures; `tabular-nums` is applied per-widget where digits must align
/// vertically, not globally.
///
/// Mirrors `design/tokens.css`.
class AppTheme {
  AppTheme._();

  static const _control = BorderRadius.all(
    Radius.circular(AppColors.radiusControl),
  );
  static const _panel = BorderRadius.all(
    Radius.circular(AppColors.radiusPanel),
  );

  static ThemeData dark() {
    const fieldBorder = OutlineInputBorder(
      borderRadius: _control,
      borderSide: BorderSide(color: AppColors.lineStrong),
    );

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.surface1,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.brand,
        onPrimary: Colors.white,
        secondary: AppColors.series1,
        onSecondary: Colors.white,
        surface: AppColors.surface1,
        onSurface: AppColors.ink1,
        error: AppColors.crit,
        onError: Colors.white,
        outline: AppColors.lineStrong,
      ),
      textTheme: const TextTheme(
        // Large standalone figures use proportional digits — tabular figures
        // make `121` look loose at display sizes.
        displaySmall: TextStyle(
          color: AppColors.ink1,
          fontSize: 40,
          height: 1.0,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.8,
        ),
        headlineSmall: TextStyle(
          color: AppColors.ink1,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          color: AppColors.ink1,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: AppColors.ink1,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(color: AppColors.ink1, fontSize: 13),
        bodySmall: TextStyle(color: AppColors.ink2, fontSize: 12),
        labelSmall: TextStyle(
          color: AppColors.ink3,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.9,
        ),
      ),
      fontFamily: 'Inter',
      fontFamilyFallback: const ['Arial', 'sans-serif'],
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface1,
        foregroundColor: AppColors.ink1,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.ink1,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
        ),
        shape: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface1,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: _panel,
          side: BorderSide(color: AppColors.line),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface2,
        contentPadding: EdgeInsets.symmetric(horizontal: 11, vertical: 12),
        hintStyle: TextStyle(color: AppColors.ink3, fontSize: 13),
        labelStyle: TextStyle(color: AppColors.ink2, fontSize: 12.5),
        floatingLabelStyle: TextStyle(color: AppColors.series1),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: _control,
          borderSide: BorderSide(color: AppColors.brand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: _control,
          borderSide: BorderSide(color: AppColors.crit),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: _control,
          borderSide: BorderSide(color: AppColors.crit, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.brand.withValues(alpha: .4),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: _control),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: _control),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink1,
          backgroundColor: AppColors.surface2,
          side: const BorderSide(color: AppColors.lineStrong),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          shape: const RoundedRectangleBorder(borderRadius: _control),
          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.series1,
          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          shape: const RoundedRectangleBorder(borderRadius: _control),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.brand
              : Colors.transparent,
        ),
        side: const BorderSide(color: AppColors.lineStrong),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.surface2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        space: 1,
        thickness: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.ink3,
        textColor: AppColors.ink2,
        dense: true,
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.surface2,
        side: BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: _control),
        labelStyle: TextStyle(fontSize: 11.5, color: AppColors.ink2),
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: Color(0xFF05060A),
          border: Border.fromBorderSide(BorderSide(color: AppColors.lineStrong)),
          borderRadius: _control,
        ),
        textStyle: TextStyle(color: AppColors.ink1, fontSize: 11.5),
      ),
      useMaterial3: true,
    );
  }
}
