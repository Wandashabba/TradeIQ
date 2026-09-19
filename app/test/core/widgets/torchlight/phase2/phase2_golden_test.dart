import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';

import 'phase2_harness.dart';

/// THE PHASE 2 GOLDENS — Night first, then Day, Veld last.
///
/// A golden here is a **snapshot of every declared value a component resolves**
/// — one line per state, checked in as text. It is not a PNG, for the three
/// reasons `soft_row_golden_test.dart` gives and which have not changed:
///
/// * CI runs `flutter test` on `ubuntu-latest` and this repository is
///   developed on macOS. Two platforms rasterise anti-aliased Onest
///   differently, so an image golden generated here fails there on the day it
///   lands and gets `skip`ped within a week — which is a golden nobody runs.
/// * What the ruling states is a set of **values**: radius 10 at the bottom
///   and 0 at the top, a 72% scrim, an 88% ceiling, a rule that goes 1px → 2px
///   on focus. A text golden diffs those by name. A PNG diff says "3,412
///   pixels changed" and a human has to work out which token moved.
/// * The thing a PNG would catch and this does not — a component painting
///   something nobody declared — is caught by `phase2_amber_test.dart`, which
///   walks the real pixels of the real frame for the property that matters
///   most.
///
/// Regenerate with `UPDATE_PHASE2_GOLDENS=1 flutter test`, and read the diff
/// before committing it: a golden that is updated without being read is a
/// golden that has been deleted.
void main() {
  final update = Platform.environment['UPDATE_PHASE2_GOLDENS'] == '1';
  const dir = 'test/core/widgets/torchlight/phase2/goldens';

  for (final name in phase2SkinNames) {
    test('$name — the resolved Phase 2 specs match their golden', () {
      final skin = phase2SkinNamed(name);
      final buffer = StringBuffer()
        ..writeln('# Torchlight Phase 2 — resolved specs')
        ..writeln('# skin: $name  (${skin.mode.name} x ${skin.density.name})')
        ..writeln(
          '# Regenerate: UPDATE_PHASE2_GOLDENS=1 flutter test '
          'test/core/widgets/torchlight/phase2/phase2_golden_test.dart',
        )
        ..writeln()
        ..writeln('## sheet')
        ..writeln(TorchSheetSpec.resolve(skin: skin).describe())
        ..writeln(
          TorchSheetSpec.resolve(skin: skin, bottomSafeArea: 34).describe(),
        )
        ..writeln()
        ..writeln('## trough');
      for (final state in TroughState.values) {
        buffer.writeln(TroughSpec.resolve(skin: skin, state: state).describe());
      }
      buffer.writeln();

      final file = File('$dir/phase2_$name.txt');
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
            'The $name Phase 2 spec moved. Every line is a declared token '
            'value, so the diff names what changed. If the change is '
            'intended, regenerate with UPDATE_PHASE2_GOLDENS=1 and say in the '
            'PR which rule moved and why.',
      );
    });
  }

  test('the goldens cover every skin these components can be built on', () {
    final found = Directory(dir).existsSync()
        ? Directory(dir)
              .listSync()
              .whereType<File>()
              .map((f) => f.uri.pathSegments.last)
              .toSet()
        : <String>{};
    for (final name in phase2SkinNames) {
      expect(
        found,
        contains('phase2_$name.txt'),
        reason:
            'A skin with no golden is a skin nobody has looked at. Run '
            'UPDATE_PHASE2_GOLDENS=1 flutter test.',
      );
    }
  });
}
