import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/lumen_glass.dart';

/// JetBrains Mono must actually ship, not just be named — the same silent
/// fallback inter_font_test.dart guards for Inter. Lumen Glass sets every
/// data numeral and every micro-label in it, so a missing face would quietly
/// re-typeset half of each screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const expectedWeights = {
    400: 'assets/fonts/JetBrainsMono-Regular.ttf',
    500: 'assets/fonts/JetBrainsMono-Medium.ttf',
    600: 'assets/fonts/JetBrainsMono-SemiBold.ttf',
    700: 'assets/fonts/JetBrainsMono-Bold.ttf',
  };

  test('the Lumen figure and kicker styles request JetBrains Mono', () {
    expect(LumenGlass.mono, 'JetBrains Mono');
    expect(LumenGlass.figure().fontFamily, 'JetBrains Mono');
    expect(LumenGlass.kickerStyle().fontFamily, 'JetBrains Mono');
  });

  test('FontManifest declares JetBrains Mono at every weight used', () async {
    final manifest =
        json.decode(await rootBundle.loadString('FontManifest.json')) as List;
    final mono = manifest.cast<Map<String, dynamic>>().firstWhere(
          (family) => family['family'] == 'JetBrains Mono',
          orElse: () => fail('JetBrains Mono is not declared in '
              'FontManifest.json — the pubspec.yaml fonts entry is missing'),
        );
    final declared = <int, String>{
      for (final font in (mono['fonts'] as List).cast<Map<String, dynamic>>())
        font['weight'] as int: font['asset'] as String,
    };
    expect(declared, expectedWeights);
  });

  test('every declared JetBrains Mono asset ships real TrueType bytes', () async {
    for (final entry in expectedWeights.entries) {
      final bytes = await rootBundle.load(entry.value);
      expect(bytes.lengthInBytes, greaterThan(100 * 1024),
          reason: '${entry.value} is implausibly small for a full face');
      expect(bytes.getUint32(0), 0x00010000,
          reason: '${entry.value} is not a TrueType font file');
    }
  });
}
