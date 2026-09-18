import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';

import '../../../design/amber_golden.dart';
import '../../../theme/torchlight/torchlight_source_scan.dart';
import 'phase2_harness.dart';

/// PHASE 2 EMITS NO LIGHT. ZERO, in every state, on every skin.
///
/// Not the skeleton's travelling rule — an amber pulse on a placeholder tells
/// a manager that a blank is real-time data, and that is the one place this
/// system's own law was broken before. Not the held banner: working offline is
/// the normal state of South African field work and a torch-coloured offline
/// banner would make the brand mean *broken*. Not the reward bar, which is the
/// most motivating object an agent sees and therefore the most tempting thing
/// in the product to light; its near-reward amber exception was written,
/// argued and deleted. Not a selected filter chip, which would multiply down a
/// rail. Not a toggle, a tick, a toast or an empty state.
///
/// Three enforcements, and this file is two of them:
///
/// 1. the **pixel census** renders every state of every Phase 2 component in
///    all three skins and counts the flame-hued regions;
/// 2. the **source scan** proves no file in these three folders names a flame
///    token at all — which catches the same thing one layer earlier and with a
///    better error message;
/// 3. `TorchScope` asserts on over-claim, and the only claims these components
///    make are for a `TorchPrimaryButton`, which asks the allocator like every
///    other primary in the app.
///
/// ## Why the census renders these components *outside* a granting scope
///
/// Because that is the claim being made. The harness builds a real
/// `TorchScope` with **no claims**, so every `TorchScope.lit` call in the tree
/// answers false and every emitter takes its ink form. A component that
/// painted amber anyway would be a component lighting itself without asking —
/// which has happened in this codebase, twice — and it is exactly what the
/// pixel walk catches.
const List<String> _phase2Folders = <String>[
  'lib/core/widgets/torchlight/sheet',
  'lib/core/widgets/torchlight/state',
  'lib/core/widgets/torchlight/input',
];

void main() {
  group('no Phase 2 component paints a lit object, in any skin', () {
    for (final skin in <TiqSkin>[
      TiqSkin.night(density: TiqDensity.field),
      TiqSkin.day(),
      TiqSkin.veld(),
    ]) {
      testWidgets(skin.mode.name, (tester) async {
        for (final entry in phase2Cases()) {
          await pumpPhase2(tester, skin: skin, child: entry.value);
          final census = await amberCensus(tester);
          expect(
            census.objectCount,
            0,
            reason:
                '${entry.key} [${skin.mode.name}] painted '
                '${census.objectCount} amber object(s).\n\n'
                '${census.describe()}\n'
                'Burning Flame is a light source, never a label. It is never '
                'a chip, flag, status, badge, tick, divider, gridline, axis, '
                'toggle, toast, skeleton, sparkline, delta, empty state, icon '
                'tint, section marker, word, or anything repeated. A sheet, a '
                'state and an input are all four of the last three.',
          );
        }
      });
    }
  });

  group('and no source file in these folders names a flame token', () {
    test('the folders exist', () {
      for (final folder in _phase2Folders) {
        expect(
          Directory(folder).existsSync(),
          isTrue,
          reason:
              '$folder is gone or the test is running from the wrong '
              'directory — a guard that silently scans nothing is worse than '
              'no guard at all.',
        );
      }
    });

    test('not one of them', () {
      final named = <String>[];
      for (final folder in _phase2Folders) {
        for (final v in TorchlightScanner.scanAmber(Directory(folder))) {
          named.add('  $folder/${v.file}:${v.line}  ${v.text.trim()}');
        }
      }
      expect(
        named,
        isEmpty,
        reason:
            'A Phase 2 file named an amber token:\n${named.join('\n')}\n\n'
            'None of these components emits light. If one of them genuinely '
            'has to — the text field\'s focus rule is the one real candidate, '
            'and it is deliberately ink in this PR — it needs a '
            'TorchlightScanner.amberAllowlist entry, a claim id, and an '
            'argument in the PR. That is a design decision, not an import.',
      );
    });

    test('the Phase 2 folders are not on the emitter allowlist', () {
      for (final path in TorchlightScanner.amberAllowlist) {
        for (final folder in _phase2Folders) {
          final relative = folder.replaceFirst('lib/', '');
          expect(
            path.startsWith(relative),
            isFalse,
            reason:
                'lib/$path is on the amber allowlist and lives in a Phase 2 '
                'folder. The allowlist is the list of things that may emit '
                'light; a sheet, a state and an input are none of them.',
          );
        }
      }
    });
  });
}
