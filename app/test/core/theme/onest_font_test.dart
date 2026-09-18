import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';

/// The replacement for `inter_font_test.dart`.
///
/// Its point stands word for word and is why this file exists rather than the
/// deletion: the theme once declared `fontFamily: 'Inter'` for months while the
/// pubspec's fonts section was commented out, Flutter fell back to
/// Arial/Roboto without a single warning, and every metric tuned against Inter
/// rendered in the wrong typeface. A misdeclared bundled font fails exactly as
/// silently for Onest.
///
/// The three layers it pinned are pinned here for the new face. The manifest
/// and byte-level checks live in
/// `test/core/theme/torchlight/torchlight_type_test.dart`, which also enforces
/// the figure/prose split; this file holds the part that is about the *themes*
/// asking for the right family.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every theme resolves its text styles to Onest', () {
    for (final theme in <ThemeData>[
      AppTheme.dark(),
      AppTheme.light(),
      AppTheme.night(),
      AppTheme.day(),
      AppTheme.veld(),
    ]) {
      // ThemeData applies its fontFamily to the typography defaults before
      // merging our TextTheme on top, so every prose style must come out as
      // Onest. If this fails, the theme no longer requests the typeface.
      expect(theme.textTheme.displaySmall?.fontFamily, TiqFonts.prose);
      expect(theme.textTheme.bodyMedium?.fontFamily, TiqFonts.prose);
      expect(theme.textTheme.labelSmall?.fontFamily, TiqFonts.prose);
      expect(theme.appBarTheme.titleTextStyle?.fontFamily, TiqFonts.prose);
    }
  });

  test('the Torchlight themes set their figures in JetBrains Mono', () {
    for (final theme in <ThemeData>[
      AppTheme.night(),
      AppTheme.day(),
      AppTheme.veld(),
    ]) {
      // displayLarge/Medium carry hero.figure and hero.figure.compact.
      expect(theme.textTheme.displayLarge?.fontFamily, TiqFonts.mono);
      expect(theme.textTheme.displayMedium?.fontFamily, TiqFonts.mono);
    }
  });

  test('the PDF-only Onest instances ship, and are static', () async {
    // package:pdf ignores a variable font's gvar deltas. If one of these ever
    // becomes the variable file, every report renders medium and bold at 400
    // and nothing complains.
    for (final weight in <int>[400, 500, 700]) {
      final asset = 'assets/fonts/Onest-Pdf-$weight.ttf';
      final bytes = await rootBundle.load(asset);
      expect(
        bytes.getUint32(0),
        0x00010000,
        reason: '$asset is not a TrueType sfnt.',
      );
      expect(
        bytes.lengthInBytes,
        greaterThan(20 * 1024),
        reason: '$asset is implausibly small.',
      );

      final tableCount = bytes.getUint16(4);
      final tags = <String>{
        for (var i = 0; i < tableCount; i++)
          String.fromCharCodes(
            Uint8List.view(bytes.buffer, bytes.offsetInBytes + 12 + 16 * i, 4),
          ),
      };
      expect(
        tags,
        isNot(contains('fvar')),
        reason:
            '$asset still carries a variable axis. package:pdf would render '
            'it at its default instance, so medium and bold would come out as '
            'regular. Regenerate with tool/build_pdf_fonts.sh.',
      );
    }
  });
}
