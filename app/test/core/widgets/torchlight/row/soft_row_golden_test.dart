import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';

import 'row_harness.dart';

/// THE ROW GOLDENS — Night first, then Day, Veld last.
///
/// A golden here is a **snapshot of every declared value the row resolves**,
/// one line per configuration, checked in as text. It is not a PNG, and that
/// is a decision rather than a shortcut:
///
/// * CI runs `flutter test` on `ubuntu-latest` and this repository is
///   developed on macOS. Two platforms rasterise anti-aliased Onest
///   differently, so an image golden generated here fails there on the day it
///   lands and gets `skip`ped within a week — which is a golden nobody runs.
/// * What unify §1.3 actually rules is a set of **values**: 56/64/80, radius 0
///   versus 14, `edgeStructure` between tappable rows and `hairline` between
///   non-tappable ones, the pressed rule at 2px `edgeControl`. A text golden
///   diffs those by name. A PNG diff says "3,412 pixels changed" and a human
///   has to work out which token moved.
/// * The thing a PNG would catch that this does not — a row that paints
///   something nobody declared — is caught by `row_amber_test.dart`, which
///   walks the real pixels of the real frame for the one property that
///   matters most.
///
/// Regenerate with `UPDATE_ROW_GOLDENS=1 flutter test`, and read the diff
/// before committing it: a golden that is updated without being read is a
/// golden that has been deleted.
void main() {
  final update = Platform.environment['UPDATE_ROW_GOLDENS'] == '1';

  // Night before Day before Veld, which is the ruling's sequencing and the
  // order these files should be read in.
  for (final name in rowSkinMatrix.map((e) => e.$1)) {
    test('$name — the resolved row spec matches its golden', () {
      final skin = skinFor(name);
      final buffer = StringBuffer()
        ..writeln('# Soft row — resolved spec')
        ..writeln('# skin: $name  (${skin.mode.name} x ${skin.density.name})')
        ..writeln(
          '# Regenerate: UPDATE_ROW_GOLDENS=1 flutter test '
          'test/core/widgets/torchlight/row/soft_row_golden_test.dart',
        )
        ..writeln();

      for (final scale in <double>[1.0, 2.0]) {
        buffer.writeln('## textScale $scale');
        for (final form in SoftRowForm.values) {
          for (final density in SoftRowDensity.values) {
            for (final severity in SoftRowSeverity.values) {
              for (final tappable in <bool>[true, false]) {
                for (final pressed in <bool>[false, true]) {
                  buffer.writeln(
                    SoftRowSpec.resolve(
                      skin: skin,
                      form: form,
                      density: density,
                      severity: severity,
                      tappable: tappable,
                      pressed: pressed,
                      textScale: scale,
                    ).describe(),
                  );
                }
              }
            }
          }
        }
        buffer.writeln();
      }

      final file = File(
        'test/core/widgets/torchlight/row/goldens/soft_row_$name.txt',
      );
      final produced = buffer.toString();
      if (update || !file.existsSync()) {
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(produced);
        if (!update) {
          fail(
            'No golden for $name — one has been written to ${file.path}. '
            'Read it, then commit it.',
          );
        }
        return;
      }
      expect(
        produced,
        file.readAsStringSync(),
        reason:
            'The $name row spec moved. Every line is a declared token value, '
            'so the diff names what changed. If the change is intended, '
            'regenerate with UPDATE_ROW_GOLDENS=1 and say in the PR which '
            'rule moved and why.',
      );
    });
  }

  test('the goldens cover every skin the row can be built on', () {
    final dir = Directory('test/core/widgets/torchlight/row/goldens');
    final found = dir.existsSync()
        ? dir
              .listSync()
              .whereType<File>()
              .map((f) => f.uri.pathSegments.last)
              .toSet()
        : <String>{};
    for (final name in rowSkinMatrix.map((e) => e.$1)) {
      expect(
        found,
        contains('soft_row_$name.txt'),
        reason:
            'A skin with no golden is a skin nobody has looked at. Run '
            'UPDATE_ROW_GOLDENS=1 flutter test.',
      );
    }
  });
}
