import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';

/// Inter must actually ship, not just be named. The theme declared
/// `fontFamily: 'Inter'` for months while pubspec.yaml's fonts section was
/// commented out — Flutter fell back to Arial/Roboto without a single
/// warning, and every metric tuned against Inter (letterSpacing: -0.8, the
/// 12.5/11.5px scale) rendered in the wrong typeface. A misdeclared bundled
/// font fails exactly as silently, so these tests pin all three layers:
/// the theme asks for Inter, the built asset bundle's FontManifest declares
/// it, and the font files themselves are real TrueType binaries.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The weights lib/ uses. FontWeight.w800 (landing headline) is absent on
  // purpose: the engine resolves it to the nearest bundled weight (700),
  // and the landing screen is being reworked under N6 anyway.
  const expectedWeights = {
    400: 'assets/fonts/Inter-Regular.ttf',
    500: 'assets/fonts/Inter-Medium.ttf',
    600: 'assets/fonts/Inter-SemiBold.ttf',
    700: 'assets/fonts/Inter-Bold.ttf',
  };

  test('both themes resolve their text styles to Inter', () {
    for (final theme in [AppTheme.dark(), AppTheme.light()]) {
      // ThemeData applies its fontFamily to the typography defaults before
      // merging our TextTheme on top, so every style must come out as Inter.
      // If this fails, the theme itself no longer requests the typeface.
      expect(theme.textTheme.displaySmall?.fontFamily, 'Inter');
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
      expect(theme.textTheme.labelSmall?.fontFamily, 'Inter');
      expect(theme.appBarTheme.titleTextStyle?.fontFamily, 'Inter');
    }
  });

  test('FontManifest declares Inter at every weight lib/ uses', () async {
    // FontManifest.json is generated from pubspec.yaml at build time; it is
    // what the engine consults when resolving 'Inter'. If the pubspec fonts
    // section is deleted or mangled, this — not the theme — is what breaks.
    final manifest =
        json.decode(await rootBundle.loadString('FontManifest.json')) as List;
    final inter = manifest.cast<Map<String, dynamic>>().firstWhere(
          (family) => family['family'] == 'Inter',
          orElse: () => fail('Inter is not declared in FontManifest.json — '
              'the pubspec.yaml fonts section is missing or misnamed'),
        );

    final declared = <int, String>{
      for (final font in (inter['fonts'] as List).cast<Map<String, dynamic>>())
        font['weight'] as int: font['asset'] as String,
    };
    expect(declared, expectedWeights);
  });

  test('every declared Inter asset ships real TrueType bytes', () async {
    for (final entry in expectedWeights.entries) {
      // rootBundle.load throws if the asset is declared but the file is
      // missing; the magic-number check catches a corrupt or placeholder
      // file that would also make the engine fall back silently.
      final bytes = await rootBundle.load(entry.value);
      expect(bytes.lengthInBytes, greaterThan(100 * 1024),
          reason: '${entry.value} is implausibly small for a full Inter face');
      expect(bytes.getUint32(0), 0x00010000,
          reason: '${entry.value} does not start with the TrueType sfnt '
              'magic number — not a valid font file');
    }
  });
}
