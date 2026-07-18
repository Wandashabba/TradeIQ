import 'package:flutter/material.dart';
import 'tiq_colors.dart';
import 'tiq_geometry.dart';

/// The TradeIQ themes — one `_base` parameterized by [TiqColors], so light and
/// dark cannot drift component-by-component.
///
/// Geometry is squared off — controls are 3px, panels 4px, and nothing is a
/// stadium/pill. One type family throughout (Inter). Mirrors `design/tokens.css`.
class AppTheme {
  AppTheme._();

  static const _control = BorderRadius.all(
    Radius.circular(TiqGeometry.control),
  );
  static const _panel = BorderRadius.all(
    Radius.circular(TiqGeometry.panel),
  );

  // Cached: stable identity for rebuilds/tests. Theme edits need hot RESTART,
  // not reload.
  static final ThemeData _dark = _base(TiqColors.dark);
  static final ThemeData _light = _base(TiqColors.light);

  static ThemeData dark() => _dark;
  static ThemeData light() => _light;

  static ThemeData _base(TiqColors c) {
    final isDark = c.brightness == Brightness.dark;
    final fieldBorder = OutlineInputBorder(
      borderRadius: _control,
      borderSide: BorderSide(color: c.lineStrong),
    );

    return ThemeData(
      brightness: c.brightness,
      extensions: [c],
      scaffoldBackgroundColor: c.plane,
      canvasColor: c.surface1,
      colorScheme: ColorScheme(
        brightness: c.brightness,
        primary: c.brand,
        onPrimary: Colors.white,
        secondary: c.series1,
        onSecondary: Colors.white,
        surface: c.surface1,
        onSurface: c.ink1,
        error: c.crit,
        onError: Colors.white,
        outline: c.lineStrong,
      ),
      textTheme: TextTheme(
        // Large standalone figures use proportional digits — tabular figures
        // make `121` look loose at display sizes.
        displaySmall: TextStyle(
          color: c.ink1,
          fontSize: 40,
          height: 1.0,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.8,
        ),
        headlineSmall: TextStyle(
          color: c.ink1,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          color: c.ink1,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: c.ink1,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(color: c.ink1, fontSize: 13),
        bodySmall: TextStyle(color: c.ink2, fontSize: 12),
        labelSmall: TextStyle(
          color: c.ink3,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.9,
        ),
      ),
      fontFamily: 'Inter',
      fontFamilyFallback: const ['Arial', 'sans-serif'],
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface1,
        foregroundColor: c.ink1,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: c.ink1,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
        ),
        shape: Border(bottom: BorderSide(color: c.line)),
      ),
      cardTheme: CardThemeData(
        color: c.surface1,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: _panel,
          side: BorderSide(color: c.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
        hintStyle: TextStyle(color: c.ink3, fontSize: 13),
        labelStyle: TextStyle(color: c.ink2, fontSize: 12.5),
        floatingLabelStyle: TextStyle(color: c.series1),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: _control,
          borderSide: BorderSide(color: c.brand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: _control,
          borderSide: BorderSide(color: c.crit),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: _control,
          borderSide: BorderSide(color: c.crit, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: c.brand.withValues(alpha: .4),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: _control),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: _control),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink1,
          backgroundColor: c.surface2,
          side: BorderSide(color: c.lineStrong),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          shape: const RoundedRectangleBorder(borderRadius: _control),
          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.series1,
          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          shape: const RoundedRectangleBorder(borderRadius: _control),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.brand
              : Colors.transparent,
        ),
        side: BorderSide(color: c.lineStrong),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.surface2),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: c.line,
        space: 1,
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.ink3,
        textColor: c.ink2,
        dense: true,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface2,
        side: BorderSide(color: c.line),
        shape: const RoundedRectangleBorder(borderRadius: _control),
        labelStyle: TextStyle(fontSize: 11.5, color: c.ink2),
      ),
      // Inverted tooltip: readable on any surface, in both modes.
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF05060A) : c.ink1,
          border: Border.fromBorderSide(BorderSide(color: c.lineStrong)),
          borderRadius: _control,
        ),
        textStyle: TextStyle(
          color: isDark ? c.ink1 : Colors.white,
          fontSize: 11.5,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: c.surface3,
      ),
      drawerTheme: DrawerThemeData(scrimColor: c.scrim),
      useMaterial3: true,
    );
  }
}
