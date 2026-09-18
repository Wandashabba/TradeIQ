import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'torchlight_source_scan.dart';

/// The third of the three enforcements of the amber law.
///
/// [TorchScope] asserts on over-claim; the pixel census counts what was
/// painted; this one stops a widget naming an amber token at all. All three
/// are needed, because each catches a failure the others cannot: a widget can
/// light itself without asking the allocator, and a census only fires on a
/// route somebody remembered to write a golden for.
void main() {
  // `flutter test` runs with the package root as cwd.
  final lib = Directory('lib');

  group('flame tokens live inside an allowlist of emitters', () {
    test('the folder this guards actually exists', () {
      expect(lib.existsSync(), isTrue);
    });

    test('no file outside the allowlist names an amber token', () {
      final violations = TorchlightScanner.scanAmber(lib);
      if (violations.isEmpty) return;

      final detail = StringBuffer()
        ..writeln('Amber tokens were named outside the emitter allowlist.')
        ..writeln()
        ..writeln(
          'Burning Flame is a light source, never a label, and which objects '
          'are lit is decided by TorchScope, not by the widget that draws '
          'them. A widget that reaches for flame600 directly is lit on every '
          'route — including the ones that already have two lights.',
        )
        ..writeln()
        ..writeln('Ask the allocator instead:')
        ..writeln("  TorchScope.lit(context, 'my-claim-id')")
        ..writeln(
          '      ? skin.palette.flame600      // …inside an allowed emitter',
        )
        ..writeln('      : skin.palette.chartNeutral;')
        ..writeln()
        ..writeln(
          'If this file really is a new emitter, add it to '
          'TorchlightScanner.amberAllowlist and argue it in the PR — that is '
          'a design decision, not an import.',
        )
        ..writeln();
      for (final v in violations) {
        detail.writeln('  ${v.file}:${v.line}  ${v.text.trim()}');
      }
      fail(detail.toString());
    });

    test('the allowlist is short, and every entry exists', () {
      for (final path in TorchlightScanner.amberAllowlist) {
        expect(
          File('lib/$path').existsSync(),
          isTrue,
          reason:
              'The allowlist names lib/$path, which is not there. An '
              'allowlist entry for a deleted file is a hole nobody can see.',
        );
      }
      expect(
        TorchlightScanner.amberAllowlist,
        hasLength(9),
        reason:
            'Pinned. Five in core/theme — the token source, the skin, the '
            'contrast contract and the two shims that map an old screen onto '
            'the new palette — plus the four Phase 1 emitters: the primary '
            'button, the nav pill, the nav circle and the keyboard focus '
            'ring. Still to come: the plate and the chart focus bar, each '
            'argued in its own PR.',
      );
    });
  });

  group('the amber scanner itself', () {
    // A guard that cannot fail is not a guard.
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('torchlight_amber'));
    tearDown(() => tmp.deleteSync(recursive: true));

    void write(String name, String source) =>
        File('${tmp.path}/$name').writeAsStringSync(source);

    test('catches every spelling of an amber token', () {
      write('bad.dart', '''
final a = skin.palette.flame600;
final b = context.skin.palette.flame300;
final c = TiqPalette.glowAmber;
final d = p.amberPressed;
final e = p.onAmber;
''');
      final found = TorchlightScanner.scanAmber(tmp);
      expect(found.map((v) => v.line), <int>[1, 2, 3, 4, 5]);
      expect(found.map((v) => v.kind).toSet(), <String>{
        'amber-outside-allowlist',
      });
    });

    test('does not fire on a comment, a near-miss or a different token', () {
      write('good.dart', '''
// flame600 in a comment is documentation, not an emission.
final a = skin.palette.chartNeutral;
final b = skin.palette.comparison;
final c = myFlame600Helper();
final d = inflame600;
''');
      expect(TorchlightScanner.scanAmber(tmp), isEmpty);
    });

    test('an escape hatch needs the marker on the same line', () {
      write('hatch.dart', '''
final a = p.flame600; // torchlight-ignore: the plate's strip light, per TorchScope
final b = p.flame600;
''');
      final found = TorchlightScanner.scanAmber(tmp);
      expect(found, hasLength(1));
      expect(found.single.line, 2);
    });
  });
}
