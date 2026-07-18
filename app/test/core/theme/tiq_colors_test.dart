import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_colors.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';

/// WCAG relative luminance.
double _luminance(Color c) => c.computeLuminance();

/// WCAG contrast ratio between two colors.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  const white = Color(0xFFFFFFFF);

  test('light series and status colors hold >=3:1 on white panels', () {
    const c = TiqColors.light;
    for (final (name, color) in [
      ('series1', c.series1),
      ('series2', c.series2),
      ('series3', c.series3),
      ('good', c.good),
      ('warn', c.warn),
      ('crit', c.crit),
    ]) {
      expect(_contrast(color, white), greaterThanOrEqualTo(3.0),
          reason: '$name fails 3:1 against white');
    }
  });

  test('light ink holds >=4.5:1 on plane and panel', () {
    const c = TiqColors.light;
    expect(_contrast(c.ink1, c.plane), greaterThanOrEqualTo(4.5));
    expect(_contrast(c.ink1, c.surface1), greaterThanOrEqualTo(4.5));
    expect(_contrast(c.ink2, c.surface1), greaterThanOrEqualTo(4.5));
  });

  test('dark values are unchanged from the historical palette', () {
    const c = TiqColors.dark;
    expect(c.plane, const Color(0xFF0B0C10));
    expect(c.surface1, const Color(0xFF14161C));
    expect(c.ink1, const Color(0xFFE9EBEE));
    expect(c.brand, const Color(0xFF0A6CF0));
    expect(c.series1, const Color(0xFF3987E5));
    expect(c.good, const Color(0xFF0CA30C));
  });

  test('TiqColors.dark mirrors the AppColors statics until AppColors dies', () {
    const c = TiqColors.dark;
    expect(c.plane, AppColors.plane);
    expect(c.surface1, AppColors.surface1);
    expect(c.surface2, AppColors.surface2);
    expect(c.surface3, AppColors.surface3);
    expect(c.line, AppColors.line);
    expect(c.lineStrong, AppColors.lineStrong);
    expect(c.ink1, AppColors.ink1);
    expect(c.ink2, AppColors.ink2);
    expect(c.ink3, AppColors.ink3);
    expect(c.brand, AppColors.brand);
    expect(c.brandHover, AppColors.brandHover);
    expect(c.series1, AppColors.series1);
    expect(c.series2, AppColors.series2);
    expect(c.series3, AppColors.series3);
    expect(c.good, AppColors.good);
    expect(c.warn, AppColors.warn);
    expect(c.crit, AppColors.crit);
    expect(c.grid, AppColors.grid);
    expect(c.axis, AppColors.axis);
  });

  test('both themes register the TiqColors extension and correct brightness', () {
    expect(AppTheme.dark().extension<TiqColors>(), same(TiqColors.dark));
    expect(AppTheme.light().extension<TiqColors>(), same(TiqColors.light));
    expect(AppTheme.dark().brightness, Brightness.dark);
    expect(AppTheme.light().brightness, Brightness.light);
  });

  testWidgets('context.colors resolves the active theme extension',
      (tester) async {
    late TiqColors seen;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Builder(builder: (context) {
        seen = context.colors;
        return const SizedBox();
      }),
    ));
    expect(seen, same(TiqColors.light));
  });

  testWidgets('context.colors falls back to dark when no theme is registered',
      (tester) async {
    late TiqColors seen;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        seen = context.colors;
        return const SizedBox();
      }),
    ));
    expect(seen, same(TiqColors.dark));
  });

  test('lerp interpolates every slot instead of snapping', () {
    expect(TiqColors.dark.lerp(TiqColors.light, 0.0).plane,
        TiqColors.dark.plane);
    expect(TiqColors.dark.lerp(TiqColors.light, 1.0).plane,
        TiqColors.light.plane);
    final mid = TiqColors.dark.lerp(TiqColors.light, 0.5).plane;
    expect(mid, Color.lerp(TiqColors.dark.plane, TiqColors.light.plane, 0.5));
    expect(mid, isNot(TiqColors.dark.plane));
    expect(mid, isNot(TiqColors.light.plane));
  });
}
