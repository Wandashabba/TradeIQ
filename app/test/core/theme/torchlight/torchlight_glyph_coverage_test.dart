import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/tiq_number.dart';

/// THE CODEPOINT GUARD.
///
/// `package:pdf` does not fall back. Hand it a glyph the embedded face does
/// not have and it draws nothing at all — no tofu box, no warning, no error:
/// the character simply is not in the report. That is how a delta arrow
/// vanished from every exported PDF in #401 and was noticed by a customer
/// rather than by CI.
///
/// So two things have to be true, and neither is true by inspection:
///
/// 1. **The subset actually contains what the app prints.** `pyftsubset` is
///    run by hand from `tool/build_pdf_fonts.sh` and the `.ttf` files are
///    committed. A range added to the script and never re-run is a range that
///    does not exist. This test reads the committed binaries' `cmap` tables,
///    not the script's intentions.
/// 2. **The app does not print what Onest has never had.** Onest carries no
///    geometric shapes. U+25B2 and U+25BC — the solid up and down triangles —
///    are not in the face at any weight, are not in the subset, and cannot be
///    added to it.
void main() {
  // `flutter test` runs with the package root as cwd.
  final pdfFonts = <String>[
    'assets/fonts/Onest-Pdf-400.ttf',
    'assets/fonts/Onest-Pdf-500.ttf',
    'assets/fonts/Onest-Pdf-700.ttf',
  ];

  group('the pyftsubset script and the committed fonts agree', () {
    late String script;
    late List<_Range> declared;

    setUpAll(() {
      script = File('../tool/build_pdf_fonts.sh').readAsStringSync();
      declared = _declaredRanges(script);
    });

    test('the script declares its ranges where this test can read them', () {
      expect(
        declared,
        isNotEmpty,
        reason:
            'No `unicodes=` line in tool/build_pdf_fonts.sh. If the subset '
            'call moves, move this parser with it — a guard that silently '
            'reads nothing is worse than none.',
      );
      expect(script, contains('pyftsubset'));
    });

    test('every declared range is really in every shipped weight', () {
      for (final path in pdfFonts) {
        final covered = _cmapCodepoints(File(path).readAsBytesSync());
        expect(
          covered.length,
          greaterThan(200),
          reason: '$path has only ${covered.length} mapped codepoints.',
        );
        final holes = <int>[];
        for (final range in declared) {
          for (var c = range.start; c <= range.end && holes.length < 20; c++) {
            // A range may legitimately contain codepoints Onest never had —
            // Latin Extended-B is sparse in almost every face. What must hold
            // is that the range is not wholly absent, and that the specific
            // characters the formatters emit are present (asserted below).
            if (!covered.contains(c)) holes.add(c);
          }
          final inRange = <int>[
            for (var c = range.start; c <= range.end; c++)
              if (covered.contains(c)) c,
          ];
          expect(
            inRange,
            isNotEmpty,
            reason:
                '$path contains nothing at all from the declared range '
                '${range.label}. The script was edited and never re-run: '
                'regenerate with tool/build_pdf_fonts.sh and commit the three '
                '.ttf files.',
          );
        }
      }
    });

    test('every character the formatters emit is in every shipped weight', () {
      // Not "the range is declared" — the actual characters, from the actual
      // constants, so renaming a token cannot silently drop one.
      final required = <int, String>{
        minusSign.codeUnitAt(0): 'the true minus U+2212',
        emDash.codeUnitAt(0): 'the em dash for a null figure',
        0x00A0: "Afrikaans's no-break group separator",
        for (final symbols in TiqNumberSymbols.all) ...<int, String>{
          symbols.group.codeUnitAt(0): '${symbols.languageCode} group mark',
          symbols.decimal.codeUnitAt(0): '${symbols.languageCode} decimal mark',
          symbols.currencyPrefix.codeUnitAt(0):
              '${symbols.languageCode} currency sign',
        },
        0x0025: 'the percent sign',
        0x002B: 'the plus on a signed delta',
        for (var d = 0x30; d <= 0x39; d++) d: 'digit ${d - 0x30}',
      };

      for (final path in pdfFonts) {
        final covered = _cmapCodepoints(File(path).readAsBytesSync());
        for (final MapEntry(key: cp, value: why) in required.entries) {
          expect(
            covered.contains(cp),
            isTrue,
            reason:
                '$path has no U+${cp.toRadixString(16).toUpperCase().padLeft(4, '0')} '
                '($why). package:pdf does not draw tofu for a missing glyph — '
                'it draws nothing, and the report goes out without it.',
          );
        }
      }
    });

    test('every character in the translations is in every shipped weight', () {
      final needed = <int>{};
      for (final arb in <String>['lib/l10n/app_en.arb', 'lib/l10n/app_af.arb']) {
        final file = File(arb);
        if (!file.existsSync()) continue;
        final json =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        for (final MapEntry(key: key, value: value) in json.entries) {
          if (key.startsWith('@')) continue;
          if (value is! String) continue;
          needed.addAll(value.runes);
        }
      }
      expect(needed, isNotEmpty, reason: 'No .arb strings were read.');

      for (final path in pdfFonts) {
        final covered = _cmapCodepoints(File(path).readAsBytesSync());
        final missing = needed
            .where((c) => c >= 0x20 && !covered.contains(c))
            .map(
              (c) =>
                  'U+${c.toRadixString(16).toUpperCase().padLeft(4, '0')} '
                  '"${String.fromCharCode(c)}"',
            )
            .toList()
          ..sort();
        expect(
          missing,
          isEmpty,
          reason:
              'A translated string uses characters $path does not have:\n'
              '  ${missing.join('\n  ')}\n'
              'Add the range to `unicodes` in tool/build_pdf_fonts.sh, re-run '
              'it, and commit the three .ttf files. Until then those '
              'characters are invisible in every exported PDF.',
        );
      }
    });
  });

  group('no Dart source reaches for a glyph Onest has never had', () {
    // U+25B2 / U+25BC. The PDF exporter carries a JetBrains Mono fallback
    // purely to draw these two, which is a whole extra embedded face for two
    // characters — and the fallback is why the bug was survivable rather than
    // why it was fine.
    const blackUpTriangle = 0x25B2;
    const blackDownTriangle = 0x25BC;

    /// The call sites that still spell a triangle, and the component that
    /// deletes each one.
    ///
    /// This is a **ratchet**, not a pass: the count may go down and never up,
    /// and a file that is not listed may not have one at all. It is written
    /// this way rather than as a flat ban because removing these five lines
    /// changes what is on screen, and Phase 0 changes nothing on screen. The
    /// unify ruling deletes all three widgets in Phase 1 in favour of one
    /// **Delta** that draws its triangle as a path — at which point the
    /// ledger empties and this becomes the flat ban it wants to be.
    const ledger = <String, int>{
      // `delta_pill.dart` came OFF this ledger by being deleted, which is
      // what unify §2 asked for: DeltaChip, DeltaPill and TileDelta.text are
      // replaced by one Delta that draws its triangle as a path. Two of the
      // five typed triangles went with it.
      'features/assistant/view_specs/rich_figures.dart': 2,
      // Replaced when the exporter draws the mark instead of setting it.
      'features/assistant/export/artifact_pdf.dart': 1,
    };

    test('the ledger describes the tree it claims to describe', () {
      for (final path in ledger.keys) {
        expect(
          File('lib/$path').existsSync(),
          isTrue,
          reason:
              'The ledger names lib/$path, which no longer exists — delete '
              'the entry rather than leaving an allowance a new file could '
              'inherit.',
        );
      }
    });

    test('no file gains a triangle, and unlisted files have none', () {
      final counts = <String, int>{};
      final lines = <String>[];
      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final rel = file.path
            .substring(file.path.indexOf('lib/') + 4)
            .replaceAll(r'\', '/');
        final source = file.readAsLinesSync();
        for (var i = 0; i < source.length; i++) {
          final raw = source[i];
          // Comments are stripped: several of these files carry a comment
          // explaining exactly this problem, and a guard that fired on its
          // own documentation would be deleted within a week.
          final comment = raw.indexOf('//');
          final code = comment == -1 ? raw : raw.substring(0, comment);
          if (code.runes.any(
            (r) => r == blackUpTriangle || r == blackDownTriangle,
          )) {
            counts[rel] = (counts[rel] ?? 0) + 1;
            lines.add('  $rel:${i + 1}  ${code.trim()}');
          }
        }
      }

      final problems = <String>[];
      for (final MapEntry(key: file, value: count) in counts.entries) {
        final allowed = ledger[file];
        if (allowed == null) {
          problems.add('  $file: $count (not in the ledger — must be zero)');
        } else if (count > allowed) {
          problems.add('  $file: $count (ledger allows $allowed)');
        }
      }

      if (problems.isNotEmpty) {
        fail(
          'Dart source references U+25B2 or U+25BC.\n\n'
          'Onest has no geometric shapes, at any weight. On screen the glyph '
          'falls back to whatever the platform has; in an exported PDF '
          '`package:pdf` draws NOTHING — no tofu, no warning — and the arrow '
          'is simply absent from the report. That is #401.\n\n'
          'Draw the triangle as a path instead. Phase 1 has one Delta '
          'component that does exactly that.\n\n'
          '${problems.join('\n')}\n\nAll occurrences:\n${lines.join('\n')}',
        );
      }

      final improved = <String>[
        for (final MapEntry(key: file, value: allowed) in ledger.entries)
          if ((counts[file] ?? 0) < allowed)
            "  '$file': ${counts[file] ?? 0},",
      ];
      if (improved.isNotEmpty) {
        // ignore: avoid_print
        print(
          'Torchlight: triangles removed. Lower the ledger:\n'
          '${improved.join('\n')}',
        );
      }
    });

    test('the two triangles are genuinely absent from every Onest face', () {
      for (final path in <String>[
        ...pdfFonts,
        'assets/fonts/Onest-Variable.ttf',
      ]) {
        final covered = _cmapCodepoints(File(path).readAsBytesSync());
        expect(
          covered.contains(blackUpTriangle),
          isFalse,
          reason:
              '$path now has U+25B2. If Onest has gained geometric shapes '
              'this whole ledger can go — check U+25BC too and delete both.',
        );
        expect(covered.contains(blackDownTriangle), isFalse);
      }
    });

    test('the subset script does not pretend to include them', () {
      final script = File('../tool/build_pdf_fonts.sh').readAsStringSync();
      expect(
        script.contains('25B2'),
        isFalse,
        reason:
            'The script asks pyftsubset for U+25B2. pyftsubset cannot add a '
            'glyph the source face does not have; it will silently produce a '
            'font without it, which is the failure this guard exists for.',
      );
      expect(script.contains('25BC'), isFalse);
    });
  });
}

/// One `U+xxxx` or `U+xxxx-yyyy` from the script's `unicodes` list.
class _Range {
  _Range(this.start, this.end, this.label);

  final int start;
  final int end;
  final String label;
}

List<_Range> _declaredRanges(String script) {
  final line = RegExp(
    r"^\s*unicodes='([^']+)'",
    multiLine: true,
  ).firstMatch(script);
  if (line == null) return const <_Range>[];
  final out = <_Range>[];
  for (final part in line.group(1)!.split(',')) {
    final token = part.trim();
    final match = RegExp(
      r'^U\+([0-9A-Fa-f]+)(?:-([0-9A-Fa-f]+))?$',
    ).firstMatch(token);
    if (match == null) continue;
    final start = int.parse(match.group(1)!, radix: 16);
    final end = match.group(2) == null
        ? start
        : int.parse(match.group(2)!, radix: 16);
    out.add(_Range(start, end, token));
  }
  return out;
}

/// Every codepoint a TrueType file's `cmap` maps to a real glyph.
///
/// Formats 4 and 12 only — the two a Unicode subset is ever written in. A
/// codepoint whose glyph id is 0 is `.notdef` and is not coverage.
Set<int> _cmapCodepoints(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final numTables = data.getUint16(4);
  var cmapOffset = -1;
  for (var i = 0; i < numTables; i++) {
    final record = 12 + i * 16;
    final tag = String.fromCharCodes(bytes.sublist(record, record + 4));
    if (tag == 'cmap') {
      cmapOffset = data.getUint32(record + 8);
      break;
    }
  }
  if (cmapOffset < 0) {
    throw StateError('No cmap table — this is not a usable font.');
  }

  final subtables = data.getUint16(cmapOffset + 2);
  var best = -1;
  var bestFormat = -1;
  for (var i = 0; i < subtables; i++) {
    final record = cmapOffset + 4 + i * 8;
    final platform = data.getUint16(record);
    final encoding = data.getUint16(record + 2);
    final offset = cmapOffset + data.getUint32(record + 4);
    final format = data.getUint16(offset);
    final unicode =
        (platform == 3 && (encoding == 1 || encoding == 10)) || platform == 0;
    if (!unicode) continue;
    if (format == 12) {
      best = offset;
      bestFormat = 12;
      break;
    }
    if (format == 4 && bestFormat != 12) {
      best = offset;
      bestFormat = 4;
    }
  }
  if (best < 0) {
    throw StateError('No Unicode cmap subtable in format 4 or 12.');
  }

  final out = <int>{};
  if (bestFormat == 12) {
    final groups = data.getUint32(best + 12);
    for (var i = 0; i < groups; i++) {
      final g = best + 16 + i * 12;
      final start = data.getUint32(g);
      final end = data.getUint32(g + 4);
      final startGlyph = data.getUint32(g + 8);
      if (startGlyph == 0 && start == end) continue;
      for (var c = start; c <= end; c++) {
        out.add(c);
      }
    }
    return out;
  }

  final segCountX2 = data.getUint16(best + 6);
  final segCount = segCountX2 ~/ 2;
  final endBase = best + 14;
  final startBase = endBase + segCountX2 + 2;
  final deltaBase = startBase + segCountX2;
  final rangeBase = deltaBase + segCountX2;
  for (var i = 0; i < segCount; i++) {
    final start = data.getUint16(startBase + i * 2);
    final end = data.getUint16(endBase + i * 2);
    if (start == 0xFFFF) continue;
    final delta = data.getInt16(deltaBase + i * 2);
    final rangeOffset = data.getUint16(rangeBase + i * 2);
    for (var c = start; c <= end; c++) {
      int glyph;
      if (rangeOffset == 0) {
        glyph = (c + delta) & 0xFFFF;
      } else {
        final index = rangeBase + i * 2 + rangeOffset + (c - start) * 2;
        if (index + 2 > bytes.length) continue;
        glyph = data.getUint16(index);
        if (glyph != 0) glyph = (glyph + delta) & 0xFFFF;
      }
      if (glyph != 0) out.add(c);
    }
  }
  return out;
}
