import 'dart:convert';
import 'dart:ui' show FontFeature;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';

/// THE FIGURE-FACE LAW.
///
/// Onest must never render a figure or a code. It has no slashed zero, its
/// digits are proportional unless `tnum` is explicitly enabled, and its capital
/// I and lowercase l are identical shapes. None of that matters in a sentence
/// and all of it matters in an outlet code, a GTIN, an order ref or a column of
/// stock counts.
///
/// So the split is enforced here rather than left to discipline: every role
/// declared `figure` or `identifier` must resolve to JetBrains Mono with
/// tabular figures on, and every `prose` role must resolve to Onest.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final skins = <String, TiqSkin>{
    'night.console': TiqSkin.night(),
    'night.field': TiqSkin.night(density: TiqDensity.field),
    'day.console': TiqSkin.day(density: TiqDensity.console),
    'day.field': TiqSkin.day(),
    'veld': TiqSkin.veld(),
  };

  group('the Onest / JetBrains Mono split', () {
    for (final MapEntry(key: skinName, value: skin) in skins.entries) {
      for (final token in skin.text.all) {
        test('$skinName ${token.name} resolves to the right face', () {
          final style = token.style();
          if (token.isFigure) {
            expect(
              style.fontFamily,
              TiqFonts.mono,
              reason:
                  '${token.name} is a ${token.kind.name} role. Onest has no '
                  'slashed zero and its I and l are the same shape; a figure '
                  'or a code set in it is a support ticket.',
            );
            expect(
              style.fontFeatures,
              contains(const FontFeature.tabularFigures()),
              reason:
                  '${token.name} carries numerals that get read down a column. '
                  'Without tnum the column is not a column.',
            );
            expect(style.fontFamilyFallback, TiqFonts.monoFallback);
          } else {
            expect(
              style.fontFamily,
              TiqFonts.prose,
              reason:
                  '${token.name} is prose. It is set in Onest, and Onest is '
                  'bundled precisely so it is not a system fallback.',
            );
            expect(
              style.fontFeatures ?? const <FontFeature>[],
              isNot(contains(const FontFeature.tabularFigures())),
              reason:
                  'tnum on prose locks the digits in a sentence to a monospace '
                  'advance, which reads as a typo.',
            );
            expect(style.fontFamilyFallback, TiqFonts.proseFallback);
          }
        });
      }
    }

    test('the roles that carry data are exactly the ones declared', () {
      // Pinned by name, so moving a role across the line is a deliberate edit
      // to this list rather than a quiet change in a factory.
      final figures = TiqSkin.night().text.all
          .where((t) => t.isFigure)
          .map((t) => t.name)
          .toSet();
      expect(figures, {
        'hero.figure',
        'hero.figure.compact',
        'figure.l',
        'figure.m',
        'figure.s',
        'axis.label',
        'mono.ident',
      });
    });

    test('every skin declares the same sixteen roles', () {
      final names = skins.values
          .map((s) => s.text.all.map((t) => t.name).join(','))
          .toSet();
      expect(
        names,
        hasLength(1),
        reason: 'A skin is a value set, not a different scale.',
      );
      expect(names.single.split(','), hasLength(16));
    });
  });

  group('the fonts actually ship', () {
    test('FontManifest declares Onest as a single variable asset', () async {
      final manifest =
          json.decode(await rootBundle.loadString('FontManifest.json'))
              as List<dynamic>;
      final families = manifest.cast<Map<String, dynamic>>();

      final onest = families.firstWhere(
        (f) => f['family'] == TiqFonts.prose,
        orElse: () => fail(
          'Onest is not in FontManifest.json — the pubspec fonts section is '
          'missing or misnamed, and the engine will fall back silently.',
        ),
      );
      final fonts = (onest['fonts'] as List).cast<Map<String, dynamic>>();
      expect(
        fonts,
        hasLength(1),
        reason:
            'Onest ships as ONE variable font. Google Fonts publishes only '
            'Onest[wght].ttf, and Flutter has mapped FontWeight onto a '
            'variable wght axis since 3.41 — static instances would be four '
            'downloads of the same outlines.',
      );
      expect(fonts.single['asset'], 'assets/fonts/Onest-Variable.ttf');
      expect(
        fonts.single.containsKey('weight'),
        isFalse,
        reason:
            'Declaring a weight on a variable font pins it to that instance '
            'and throws the axis away.',
      );
    });

    test('JetBrains Mono still ships at every weight the roles use', () async {
      final manifest =
          json.decode(await rootBundle.loadString('FontManifest.json'))
              as List<dynamic>;
      final mono = manifest.cast<Map<String, dynamic>>().firstWhere(
        (f) => f['family'] == TiqFonts.mono,
        orElse: () => fail(
          'JetBrains Mono is not declared — every figure would fall '
          'back to a proportional system face.',
        ),
      );
      final weights = (mono['fonts'] as List)
          .cast<Map<String, dynamic>>()
          .map((f) => f['weight'] as int)
          .toSet();
      final used = <int>{
        for (final skin in skins.values)
          for (final t in skin.text.all)
            if (t.isFigure) t.weight.value,
      };
      expect(
        weights.containsAll(used),
        isTrue,
        reason:
            'Figure roles use weights $used; the bundle declares $weights. A '
            'missing weight is synthesised by the engine and a synthesised '
            'bold mono is not a tabular mono.',
      );
    });

    test('Onest is a real variable TrueType, not a placeholder', () async {
      final bytes = await rootBundle.load('assets/fonts/Onest-Variable.ttf');
      expect(
        bytes.getUint32(0),
        0x00010000,
        reason: 'Not a TrueType sfnt — the engine would fall back silently.',
      );
      expect(
        bytes.lengthInBytes,
        greaterThan(120 * 1024),
        reason: 'Implausibly small for a full variable face.',
      );
      expect(
        bytes.lengthInBytes,
        lessThan(400 * 1024),
        reason:
            'Larger than the variable font Google Fonts ships (~193 KB) — is '
            'this a static instance, or an unsubset superset?',
      );

      // The fvar table is what makes the weight axis work at all. Without it
      // every FontWeight renders at the same weight and nothing complains.
      final tableCount = bytes.getUint16(4);
      final tags = <String>{
        for (var i = 0; i < tableCount; i++)
          String.fromCharCodes(
            Uint8List.view(bytes.buffer, bytes.offsetInBytes + 12 + 16 * i, 4),
          ),
      };
      expect(
        tags,
        contains('fvar'),
        reason:
            'No fvar table: this is a static instance, so every weight from '
            '100 to 900 would paint identically.',
      );
    });

    test('Inter is gone from the bundle', () async {
      final manifest =
          json.decode(await rootBundle.loadString('FontManifest.json'))
              as List<dynamic>;
      final families = manifest
          .cast<Map<String, dynamic>>()
          .map((f) => f['family'] as String)
          .toSet();
      expect(
        families,
        isNot(contains('Inter')),
        reason:
            'Inter was 1.67 MB of a 1 GB monthly bundle and nothing renders '
            'in it any more.',
      );
      expect(families, containsAll(<String>[TiqFonts.prose, TiqFonts.mono]));
    });
  });
}
