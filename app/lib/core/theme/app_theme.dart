import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'lumen_glass.dart';
import 'lumen_palette.dart';
import 'tiq_colors.dart';
import 'torchlight/tiq_skin.dart';

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
  ///
  /// Still Lumen: the 60 screens are painted in it and two other workstreams
  /// are editing those screens right now. What changed is that this theme now
  /// also registers a [TiqSkin], so `context.skin` resolves everywhere from
  /// today and a screen can be migrated one at a time instead of all at once.
  static ThemeData dark() =>
      _base(TiqColors.night, Brightness.dark, skin: TiqSkin.night());

  static ThemeData light() => _base(
    TiqColors.light,
    Brightness.light,
    skin: TiqSkin.day(density: TiqDensity.console),
  );

  // ── Torchlight Aisle ─────────────────────────────────────────────────
  // The three skins, built from the one token source. Nothing routes to them
  // yet: they are what `main.dart` switches to when the screens are ported,
  // and what the token, contrast and render tests exercise today.
  //
  // Each one registers BOTH the new [TiqSkin] and a [TiqColors] derived from
  // it by [TiqColors.fromSkin], so a screen still on `context.colors` renders
  // in Torchlight tokens the moment it is pointed at one of these.

  /// NIGHT — the cinematic dark console.
  static ThemeData night({TiqDensity density = TiqDensity.console}) =>
      torchlight(TiqSkin.night(density: density));

  /// DAY — Palladian paper, the field agent's default.
  static ThemeData day({TiqDensity density = TiqDensity.field}) =>
      torchlight(TiqSkin.day(density: density));

  /// VELD — outdoor high-contrast. Single-density by construction.
  static ThemeData veld() => torchlight(TiqSkin.veld());

  /// Build a [ThemeData] from a skin. One function, three value sets — there
  /// is deliberately no per-mode branch in here.
  static ThemeData torchlight(TiqSkin skin) {
    final p = skin.palette;
    final control = BorderRadius.circular(skin.radii.control);
    final chip = BorderRadius.circular(skin.radii.chip);
    final panel = BorderRadius.circular(skin.radii.panel);
    final edge = BorderSide(
      color: p.edgeControl,
      width: skin.depth.borderWidth,
    );

    TextStyle role(TiqTypeToken token, Color color) =>
        token.style(color: color);

    return ThemeData(
      brightness: skin.brightness,
      extensions: <ThemeExtension<dynamic>>[skin, TiqColors.fromSkin(skin)],
      scaffoldBackgroundColor: p.ground,
      canvasColor: p.surface,
      // The focus ring is amber — emitted light pointing at where you are.
      focusColor: p.flame700,
      colorScheme: ColorScheme(
        brightness: skin.brightness,
        primary: p.flame600,
        onPrimary: p.onAmber,
        secondary: p.comparison,
        onSecondary: p.ground,
        surface: p.surface,
        onSurface: p.ink1,
        error: p.badSolid,
        onError: p.onBadSolid,
        outline: p.edgeControl,
        outlineVariant: p.hairline,
        shadow: skin.depth.sh1?.color ?? const Color(0x00000000),
        scrim: p.scrim,
      ),
      fontFamily: TiqFonts.prose,
      fontFamilyFallback: TiqFonts.proseFallback,
      textTheme: TextTheme(
        // Material's slots, filled from the Torchlight roles. The roles are
        // the real API — this mapping exists so a stock Material widget in a
        // not-yet-migrated screen is at least set in the right face.
        displayLarge: role(skin.text.heroFigure, p.ink1),
        displayMedium: role(skin.text.heroFigureCompact, p.ink1),
        displaySmall: role(skin.text.display, p.ink1),
        headlineMedium: role(skin.text.headlineAnswer, p.ink1),
        headlineSmall: role(skin.text.titleL, p.ink1),
        titleLarge: role(skin.text.titleL, p.ink1),
        titleMedium: role(skin.text.titleM, p.ink1),
        titleSmall: role(skin.text.bodyStrong, p.ink1),
        bodyLarge: role(skin.text.body, p.ink1),
        bodyMedium: role(skin.text.body, p.ink1),
        bodySmall: role(skin.text.meta, p.ink3),
        labelLarge: role(skin.text.label, p.ink1),
        labelMedium: role(skin.text.label, p.ink2),
        labelSmall: role(skin.text.eyebrow, p.ink2),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.ground,
        foregroundColor: p.ink1,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: role(skin.text.titleL, p.ink1),
        shape: Border(
          bottom: BorderSide(color: p.hairline, width: skin.depth.borderWidth),
        ),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: panel,
          side: BorderSide(
            color: p.edgeStructure,
            width: skin.depth.borderWidth,
          ),
        ),
      ),
      // An input is a trough: it holds at the bottom, and its focus cue is a
      // 2px amber rule rather than a box that lights up.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.well,
        contentPadding: EdgeInsets.symmetric(
          horizontal: TiqSpace.s3,
          vertical: TiqSpace.s3,
        ),
        hintStyle: role(skin.text.body, p.ink3),
        labelStyle: role(skin.text.label, p.ink2),
        floatingLabelStyle: role(skin.text.label, p.ink2),
        border: UnderlineInputBorder(
          borderRadius: skin.radii.input,
          borderSide: edge,
        ),
        enabledBorder: UnderlineInputBorder(
          borderRadius: skin.radii.input,
          borderSide: edge,
        ),
        focusedBorder: UnderlineInputBorder(
          borderRadius: skin.radii.input,
          borderSide: BorderSide(color: p.flame700, width: 2),
        ),
        errorBorder: UnderlineInputBorder(
          borderRadius: skin.radii.input,
          borderSide: BorderSide(color: p.bad, width: 2),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderRadius: skin.radii.input,
          borderSide: BorderSide(color: p.bad, width: 2),
        ),
        errorStyle: role(skin.text.meta, p.bad),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              backgroundColor: p.flame600,
              foregroundColor: p.onAmber,
              disabledBackgroundColor: p.well,
              disabledForegroundColor: p.inkMute,
              minimumSize: Size(0, skin.space.primaryActionHeight),
              padding: EdgeInsets.symmetric(horizontal: TiqSpace.s4),
              shape: RoundedRectangleBorder(borderRadius: control),
              textStyle: skin.text.label.style(),
            ).copyWith(
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.pressed)
                    ? p.onAmberPressed
                    : states.contains(WidgetState.disabled)
                    ? p.inkMute
                    : p.onAmber,
              ),
              // Pressed keeps DARK ink on flame-500. flame-900 on flame-500 is
              // 2.00:1 and makes the label vanish at the moment of commitment.
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.pressed)
                    ? p.amberPressed
                    : states.contains(WidgetState.disabled)
                    ? p.well
                    : p.flame600,
              ),
            ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.flame600,
          foregroundColor: p.onAmber,
          disabledBackgroundColor: p.well,
          disabledForegroundColor: p.inkMute,
          elevation: 0,
          minimumSize: Size(0, skin.space.primaryActionHeight),
          padding: EdgeInsets.symmetric(horizontal: TiqSpace.s4),
          shape: RoundedRectangleBorder(borderRadius: control),
          textStyle: skin.text.label.style(),
        ),
      ),
      // Secondary is a ghost. No amber anywhere on it.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.ink1,
          backgroundColor: const Color(0x00000000),
          side: edge,
          minimumSize: Size(0, skin.space.tapTarget),
          padding: EdgeInsets.symmetric(horizontal: TiqSpace.s3),
          shape: RoundedRectangleBorder(borderRadius: control),
          textStyle: skin.text.label.style(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: skin.amberIsInk ? p.flame300 : p.flame700,
          minimumSize: Size(0, skin.space.tapTarget),
          shape: RoundedRectangleBorder(borderRadius: control),
          textStyle: skin.text.label.style(),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0x00000000),
        side: edge,
        shape: RoundedRectangleBorder(borderRadius: chip),
        labelStyle: role(skin.text.label, p.ink2),
        padding: EdgeInsets.symmetric(horizontal: TiqSpace.s3),
      ),
      checkboxTheme: CheckboxThemeData(
        checkColor: WidgetStatePropertyAll(p.onAmber),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.flame600
              : const Color(0x00000000),
        ),
        side: BorderSide(color: p.edgeControl, width: skin.depth.borderWidth),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(skin.radii.chip),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: p.hairline,
        space: skin.depth.borderWidth,
        thickness: skin.depth.borderWidth,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.ink3,
        textColor: p.ink2,
        minVerticalPadding: TiqSpace.s2,
        minTileHeight: skin.space.rowMinHeight,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: panel,
          side: BorderSide(
            color: p.edgeStructure,
            width: skin.depth.borderWidth,
          ),
        ),
        titleTextStyle: role(skin.text.titleL, p.ink1),
        contentTextStyle: role(skin.text.body, p.ink2),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: const Color(0x00000000),
        modalBarrierColor: p.scrim,
        dragHandleColor: p.ink2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(skin.radii.panel),
          ),
          side: BorderSide(
            color: p.edgeStructure,
            width: skin.depth.borderWidth,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surface,
        contentTextStyle: role(skin.text.body, p.ink1),
        actionTextColor: skin.amberIsInk ? p.flame300 : p.flame700,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: control),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: panel,
          side: BorderSide(
            color: p.edgeStructure,
            width: skin.depth.borderWidth,
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.well,
          border: Border.all(color: p.edgeStructure),
          borderRadius: chip,
        ),
        textStyle: role(skin.text.meta, p.ink1),
      ),
      // Veld kills every ambient loop, so it also kills page transitions.
      pageTransitionsTheme: skin.motion.enabled
          ? const PageTransitionsTheme()
          : const PageTransitionsTheme(
              builders: <TargetPlatform, PageTransitionsBuilder>{
                TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
                TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
              },
            ),
      useMaterial3: true,
    );
  }

  static ThemeData _base(
    TiqColors c,
    Brightness brightness, {
    required TiqSkin skin,
  }) {
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
      // Both extensions ride together through the migration: `context.colors`
      // keeps painting the 60 Lumen screens, `context.skin` is what a migrated
      // one reads.
      extensions: <ThemeExtension<dynamic>>[c, skin],
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
      // Onest replaces Inter. The Lumen scale was tuned against Inter's
      // metrics; Onest's x-height is close enough that nothing reflows, and
      // this theme is scheduled for replacement by torchlight() anyway.
      fontFamily: TiqFonts.prose,
      fontFamilyFallback: TiqFonts.proseFallback,
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
          fontFamily: TiqFonts.prose,
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
                fontFamily: TiqFonts.prose,
              ),
              contentTextStyle: TextStyle(
                color: c.ink2,
                fontSize: 13.5,
                height: 1.45,
                fontFamily: TiqFonts.prose,
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
                fontFamily: TiqFonts.prose,
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
