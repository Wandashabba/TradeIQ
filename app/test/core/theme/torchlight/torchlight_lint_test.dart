import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'torchlight_source_scan.dart';
import 'torchlight_style_debt.dart';

/// The guard that stops the drift coming back.
///
/// The audit that produced the Torchlight Aisle direction counted 423
/// hardcoded `TextStyle`s, 357 magic paddings and 249 raw colours across the
/// app. Every one of them was added by someone reasonable, in a hurry, who did
/// not know a token existed. Review does not catch that — the diff always
/// looks small — so this does.
///
/// It is a source scan rather than a `custom_lint` plugin because `custom_lint`
/// is not set up in this repo and adding an analyzer plugin is a build-time
/// dependency, a second analysis pass and a version matrix to keep green. A
/// test runs in the suite that already runs, needs nothing new, and fails in
/// the same place as everything else. If `custom_lint` is adopted later, the
/// rules move and this file goes.
///
/// It runs in CI through `flutter test`, which app-ci.yml already invokes.
void main() {
  // `flutter test` runs with the package root as cwd.
  final features = Directory('lib/features');

  group('Torchlight style ratchet over lib/features', () {
    test('the folder this guards actually exists', () {
      expect(
        features.existsSync(),
        isTrue,
        reason:
            'lib/features is gone or the test is running from the wrong '
            'directory — a guard that silently scans nothing is worse than no '
            'guard at all.',
      );
      final dartFiles = features
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      expect(
        dartFiles.length,
        greaterThan(50),
        reason: 'Only ${dartFiles.length} Dart files found under lib/features.',
      );
    });

    test('no file gains a hardcoded colour, palette or text style', () {
      final violations = TorchlightScanner.scan(features);
      final counts = TorchlightScanner.countByFile(violations);

      final regressions = <String>[];
      final newFiles = <String>[];
      final improvements = <String, int>{};

      for (final entry in counts.entries) {
        final allowed = torchlightStyleDebt[entry.key];
        if (allowed == null) {
          newFiles.add(entry.key);
        } else if (entry.value > allowed) {
          regressions.add(
            '  ${entry.key}: ${entry.value} (ledger allows $allowed)',
          );
        }
      }
      for (final entry in torchlightStyleDebt.entries) {
        final now = counts[entry.key] ?? 0;
        if (now < entry.value) improvements[entry.key] = now;
      }

      if (newFiles.isNotEmpty || regressions.isNotEmpty) {
        final detail = StringBuffer()
          ..writeln('Hardcoded style decisions were added to lib/features.')
          ..writeln()
          ..writeln('Use the tokens instead:')
          ..writeln('  Color(0x…)   -> context.skin.palette.<token>')
          ..writeln('  Colors.<x>   -> context.skin.palette.<token>')
          ..writeln(
            '  TextStyle(…)  -> context.skin.type.<role>.style(color: …)',
          )
          ..writeln()
          ..writeln('See docs/design/torchlight-aisle.md.')
          ..writeln();

        if (newFiles.isNotEmpty) {
          detail.writeln(
            'These files are not in the ledger and must be token-clean:',
          );
          for (final f in newFiles..sort()) {
            detail.writeln('  $f: ${counts[f]}');
            for (final v in violations.where((v) => v.file == f).take(5)) {
              detail.writeln('      line ${v.line}  ${v.kind}');
            }
          }
          detail.writeln();
        }
        if (regressions.isNotEmpty) {
          detail
            ..writeln('These files went backwards:')
            ..writeln(regressions.join('\n'));
        }
        fail(detail.toString());
      }

      if (improvements.isNotEmpty) {
        // Not a failure: two other workstreams are editing these folders and a
        // two-sided ratchet would fail a PR for cleaning up. Just say so.
        // ignore: avoid_print
        print(
          'Torchlight: ${improvements.length} file(s) improved. Lower the '
          'ledger in torchlight_style_debt.dart:\n'
          '${improvements.entries.map((e) => "  '${e.key}': ${e.value},").join('\n')}',
        );
      }
    });

    test('the ledger describes the tree it claims to describe', () {
      // A ledger listing files that no longer exist is a ledger nobody has
      // read. It would also let a deleted-and-recreated file smuggle in
      // violations under an old allowance.
      final stale = torchlightStyleDebt.keys
          .where((f) => !File('lib/features/$f').existsSync())
          .toList();
      expect(
        stale,
        isEmpty,
        reason:
            'These ledger entries point at files that no longer exist — '
            'delete the entries:\n${stale.join('\n')}',
      );
      expect(
        torchlightStyleDebt.values.fold(0, (a, b) => a + b),
        torchlightStyleDebtTotal,
        reason: 'The ledger map and its declared total disagree.',
      );
    });
  });

  group('the retired systems have no call sites under lib/features', () {
    // The ledger counts hardcoded *values*. This counts hardcoded *systems*:
    // a screen can be token-clean and still be built out of Lumen Glass, and
    // the import is the thing that says which. The five sources below are all
    // `@Deprecated` and all still registered, so nothing breaks when one is
    // imported — which is exactly why it needs a test rather than a compiler
    // error.
    //
    // A file that appears here is a screen that has not been migrated,
    // whatever its style count says. The list is empty, and the point of the
    // test is that it stays empty: the next feature to reach for the old kit
    // fails on the PR that adds it.
    const retired = <String>[
      'core/widgets/agent_kit.dart',
      'core/widgets/agent_scaffold.dart',
      'core/widgets/glass.dart',
      'core/widgets/glass_page_scaffold.dart',
      'core/widgets/lumen_kit.dart',
      'core/widgets/manager_scaffold.dart',
      'core/theme/lumen_glass.dart',
      'core/theme/lumen_palette.dart',
      'core/theme/tiq_colors.dart',
      'core/theme/app_colors.dart',
      'core/theme/status_pill_colors.dart',
    ];

    test('no feature imports the Lumen kit or a deprecated colour source', () {
      final offenders = <String>[];
      for (final file in features
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final source = file.readAsStringSync();
        for (final retiredPath in retired) {
          // Feature files reach core through a relative path, so the tail of
          // it is what identifies the import.
          final tail = retiredPath.split('/').last;
          final folder = retiredPath.split('/')[1];
          if (RegExp("import '[^']*/$folder/$tail'").hasMatch(source)) {
            offenders.add('${file.path}: $retiredPath');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'These feature files are built on a retired system. Torchlight '
            'type inside violet glass panes is neither system — migrate the '
            'screen rather than half of it:\n${offenders.join('\n')}',
      );
    });
  });

  group('the scanner itself', () {
    // A guard that cannot fail is not a guard. These run the detector over
    // known-bad and known-good source so a refactor that quietly breaks a
    // regex is caught here rather than six months of drift later.
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('torchlight_scan'));
    tearDown(() => tmp.deleteSync(recursive: true));

    void write(String name, String source) =>
        File('${tmp.path}/$name')..writeAsStringSync(source);

    test('catches a raw colour, Material Colors and a bare TextStyle', () {
      write('bad.dart', '''
import 'package:flutter/material.dart';
const a = Color(0xFF00FF00);
const b = Colors.red;
const c = TextStyle(fontSize: 12);
''');
      final kinds = TorchlightScanner.scan(tmp).map((v) => v.kind).toSet();
      expect(kinds, {'raw-color', 'material-colors', 'bare-textstyle'});
    });

    test('does not fire on tokens, comments or allowed members', () {
      write('good.dart', '''
// Color(0xFFABCDEF) in a line comment is documentation, not a decision.
/* Colors.red in a block comment, likewise.
   TextStyle( across two lines. */
import 'package:flutter/material.dart';
final style = context.skin.type.body.style(color: context.skin.palette.ink1);
const gone = Colors.transparent;
final copied = base.copyWith(color: skin.palette.ink2);
''');
      expect(TorchlightScanner.scan(tmp), isEmpty);
    });

    test('does not mistake AppColors. or a method named TextStyle', () {
      write('nearmiss.dart', '''
const x = AppColors.radiusControl;
final y = theme.textTheme.bodyMedium;
''');
      expect(TorchlightScanner.scan(tmp), isEmpty);
    });

    test('an escape hatch needs the marker on the same line', () {
      write('hatch.dart', '''
const a = Color(0xFF00FF00); // torchlight-ignore: baked plate ceiling, server-side
const b = Color(0xFF00FF01);
''');
      final found = TorchlightScanner.scan(tmp);
      expect(found, hasLength(1));
      expect(found.single.line, 2);
    });
  });
}
