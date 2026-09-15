import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'lumen_glass.dart';
import 'lumen_palette.dart';
import 'tiq_colors.dart';

/// The TradeIQ themes.
///
/// Both modes are built by one [_base] from a [TiqColors] scheme, so component
/// themes (inputs, buttons, cards, appbar, chips…) cannot drift between them.
/// Both are Lumen Glass (14px controls, 20px panels): light on the lit
/// lavender ground with the dark `#241F47` primary action, dark on the indigo
/// night ground with a bright lavender one. One text family throughout
/// (Inter); figures and micro-labels opt into JetBrains Mono per-widget via
/// `LumenGlass.figure` / `kickerStyle`, not globally.
class AppTheme {
  AppTheme._();

  /// Lumen Glass at night. The flat instrument palette ([TiqColors.dark])
  /// no longer backs a theme; it remains only as the fallback for widgets
  /// pumped without one.
  static ThemeData dark() => _base(TiqColors.night, Brightness.dark);

  static ThemeData light() => _base(TiqColors.light, Brightness.light);

  static ThemeData _base(TiqColors c, Brightness brightness) {
    final control = BorderRadius.all(Radius.circular(c.radiusControl));
    final lumen = c.isNight ? LumenPalette.dark : LumenPalette.light;
    final panel = BorderRadius.all(Radius.circular(c.radiusPanel));

    final fieldBorder = OutlineInputBorder(
      borderRadius: control,
      borderSide: BorderSide(color: c.lineStrong),
    );

    final colorScheme = brightness == Brightness.dark
        ? ColorScheme.dark(
            primary: c.brand,
            onPrimary: c.isNight ? c.onAction : Colors.white,
            secondary: c.series1,
            onSecondary: Colors.white,
            surface: c.surface1,
            onSurface: c.ink1,
            error: c.crit,
            onError: Colors.white,
            outline: c.lineStrong,
          )
        : ColorScheme.light(
            primary: c.brand,
            onPrimary: Colors.white,
            secondary: c.series1,
            onSecondary: Colors.white,
            surface: c.surface1,
            onSurface: c.ink1,
            error: c.crit,
            onError: Colors.white,
            outline: c.lineStrong,
          );

    return ThemeData(
      brightness: brightness,
      extensions: <ThemeExtension<dynamic>>[c],
      scaffoldBackgroundColor: c.plane,
      canvasColor: c.surface1,
      // Keyboard focus is a brand-tinted wash, so a manager tabbing through the
      // console can always see where they are. Inputs additionally draw the
      // 1.5px brand ring via focusedBorder below.
      focusColor: c.brand.withValues(alpha: 0.12),
      colorScheme: colorScheme,
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
          borderRadius: panel,
          side: BorderSide(color: c.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 11,
          vertical: 12,
        ),
        hintStyle: TextStyle(color: c.ink3, fontSize: 13),
        labelStyle: TextStyle(color: c.ink2, fontSize: 12.5),
        floatingLabelStyle: TextStyle(color: c.series1),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: control,
          borderSide: BorderSide(color: c.brand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: control,
          borderSide: BorderSide(color: c.crit),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: control,
          borderSide: BorderSide(color: c.crit, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.action,
          foregroundColor: c.onAction,
          disabledBackgroundColor: c.action.withValues(alpha: .4),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: control),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.action,
          foregroundColor: c.onAction,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: control),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink1,
          backgroundColor: c.surface2,
          side: BorderSide(color: c.lineStrong),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: control),
          textStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.glass ? c.brand : c.series1,
          textStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(borderRadius: control),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        // A lavender box at night takes the dark tick.
        checkColor: c.isNight ? WidgetStatePropertyAll(c.onAction) : null,
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
      dividerTheme: DividerThemeData(color: c.line, space: 1, thickness: 1),
      listTileTheme: ListTileThemeData(
        iconColor: c.ink3,
        textColor: c.ink2,
        dense: true,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface2,
        side: BorderSide(color: c.line),
        shape: RoundedRectangleBorder(borderRadius: control),
        labelStyle: TextStyle(fontSize: 11.5, color: c.ink2),
      ),
      // Tooltips stay the dark instrument surface in BOTH modes: an inverted
      // tooltip is the standard premium treatment, and deriving it from light
      // ink would put near-black text on a near-black panel. Deliberately
      // AppColors (dark constants), not `c`.
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: Color(0xFF05060A),
          border: Border.fromBorderSide(
            BorderSide(color: AppColors.lineStrong),
          ),
          borderRadius: BorderRadius.all(
            Radius.circular(AppColors.radiusControl),
          ),
        ),
        textStyle: TextStyle(color: AppColors.ink1, fontSize: 11.5),
      ),
      // Overlays. Glass only: dark keeps Material's defaults, untouched. The
      // grounds are opaque on purpose — a dialog's words must clear AA on their
      // own, whatever is behind the scrim.
      dialogTheme: c.glass
          ? DialogThemeData(
              backgroundColor: c.surface1,
              surfaceTintColor: Colors.transparent,
              elevation: 18,
              shadowColor: const Color(0x40241F47),
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(
                  Radius.circular(LumenGlass.radiusHero),
                ),
                side: BorderSide(color: lumen.panelRim),
              ),
              titleTextStyle: TextStyle(
                color: c.ink1,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
              contentTextStyle: TextStyle(
                color: c.ink2,
                fontSize: 13.5,
                height: 1.45,
                fontFamily: 'Inter',
              ),
            )
          : null,
      snackBarTheme: c.glass
          ? SnackBarThemeData(
              // By day the one dark pane; by night a pane lifted off the ground.
              backgroundColor: c.isNight
                  ? const Color(0xFF2D2A48)
                  : LumenGlass.inkDark,
              contentTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontFamily: 'Inter',
              ),
              actionTextColor: lumen.accentLight,
              behavior: SnackBarBehavior.floating,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(LumenGlass.radiusControl),
                ),
              ),
            )
          : null,
      bottomSheetTheme: c.glass
          ? BottomSheetThemeData(
              backgroundColor: c.surface1,
              surfaceTintColor: Colors.transparent,
              dragHandleColor: c.lineStrong,
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(LumenGlass.radiusScore),
                ),
                side: BorderSide(color: lumen.panelRim),
              ),
            )
          : null,
      popupMenuTheme: c.glass
          ? PopupMenuThemeData(
              color: c.surface1,
              surfaceTintColor: Colors.transparent,
              elevation: 10,
              shadowColor: const Color(0x33241F47),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LumenGlass.radiusControl),
                side: BorderSide(color: lumen.panelRim),
              ),
            )
          : null,
      useMaterial3: true,
    );
  }
}
