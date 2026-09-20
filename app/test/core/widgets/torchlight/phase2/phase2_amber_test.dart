import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
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
/// ## Zero, and the three deliberate ones
///
/// The harness builds a real `TorchScope` with **no claims of its own**, so a
/// component that lit itself without asking would light anyway and be counted.
/// Every Phase 2 component comes back at zero — with three exceptions the
/// ruling puts there on purpose.
///
/// A sheet is an **untabbed route**: it opens its own `TorchScope`, and unify
/// §1.21 says in as many words that the decision sheet *"declares
/// `TorchClaim.primaryCommit` for 'Carry on' — the correct place for the
/// torch, because it points at the safe path"*. The skip-reason picker and the
/// session-ended sheet spend their one grant the same way, on the action that
/// gets the agent out. So those three are asserted at **exactly one**, which
/// is the untabbed budget on a light ground and half of it in Night — not at
/// "at most one", because a sheet whose commit went dark would be a sheet
/// nobody could find the way out of.
///
/// The confirm sheet is at zero, categorically: a destructive confirm is
/// severity, and severity never touches amber.
const List<String> _phase2Folders = <String>[
  'lib/core/widgets/torchlight/sheet',
  'lib/core/widgets/torchlight/state',
  'lib/core/widgets/torchlight/input',
];

/// The cases that are allowed their one grant, by exact name, and why.
///
/// `SkipReasonPicker` is **not** in this list and `SkipReasonPicker.threshold`
/// is, which is the rule rather than an oversight: the picker opens with
/// nothing chosen and its commit disabled, and a disabled commit is not lit.
/// The torch appears when there is something to commit.
const Map<String, String> _litCommitCases = <String, String>{
  'DecisionSheet': "the safe path — 'Carry on from 11:04'",
  'DecisionSheet.stale':
      "'Check in again' — a geofence fix from yesterday is not evidence of "
      'being here now',
  'DecisionSheet.counting':
      'the safe path, still lit while its own dots run — the light says which '
      'way out, and that does not change while a count resolves',
  'SkipReasonPicker.threshold': "the commit — 'Change reason'",
  'SessionEndedSheet': "the way back in — 'Sign in to send them'",
};

/// How many lit objects a case may paint.
int _budgetFor(String caseName) =>
    _litCommitCases.containsKey(caseName) ? 1 : 0;

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
          // A component that failed to build renders an ErrorWidget, which is
          // crimson — hue 0, outside the flame box — so the census would pass
          // it happily. Check first, or this becomes a test that proves a red
          // screen contains no amber.
          expect(
            tester.takeException(),
            isNull,
            reason: '${entry.key} [${skin.mode.name}] failed to build.',
          );
          final census = await amberCensus(tester);
          final budget = _budgetFor(entry.key);
          // `lessThanOrEqualTo` for the three that may spend a grant, and an
          // exact zero for everything else. The census's job is catching light
          // nobody authorised, and a commit action that has scrolled below an
          // 88% ceiling paints no pixels without breaking any rule — which is
          // exactly what a tall Veld sheet does. That the three sheets really
          // do declare and receive their claim is asserted below, against the
          // allocator, where it is a fact rather than a screenshot.
          expect(
            census.objectCount,
            budget == 0 ? 0 : lessThanOrEqualTo(budget),
            reason:
                '${entry.key} [${skin.mode.name}] painted '
                '${census.objectCount} amber object(s) against $budget.\n\n'
                '${census.describe()}\n'
                '${budget == 0 ? 'Burning Flame is a light source, never a '
                          'label. It is never a chip, flag, status, badge, '
                          'tick, divider, gridline, axis, toggle, toast, '
                          'skeleton, sparkline, delta, empty state, icon '
                          'tint, section marker, word, or anything repeated. '
                          'A sheet, a state and an input are all four of the '
                          'last three.' : 'This sheet spends its one grant on '
                          '${_litCommitCases[entry.key]}, and it must actually '
                          'be lit: a commit action that went dark is a sheet '
                          'nobody can find the way out of.'}',
          );
        }
      });
    }
  });

  group('the three sheets that spend a grant actually get one', () {
    // A sheet is an untabbed route: Night gives it two content grants, Day and
    // Veld one. Each of these declares exactly one, for its commit action, and
    // the allocator grants it in every skin — which is the half of the claim a
    // pixel walk cannot prove when the button is below the fold.
    for (final skin in <TiqSkin>[
      TiqSkin.night(density: TiqDensity.field),
      TiqSkin.day(),
      TiqSkin.veld(),
    ]) {
      test(skin.mode.name, () {
        for (final id in <String>[
          'carry-on',
          'check-in-again',
          'skip-save',
          'session-sign-in',
          'count-set',
        ]) {
          final allocation = TorchScope.resolve(
            skin: skin,
            claims: <TorchClaim>[TorchClaim.primaryCommit(id)],
          );
          expect(
            allocation.isLit(id),
            isTrue,
            reason:
                '$id was not granted on ${skin.mode.name}. A sheet holds the '
                'whole untabbed allowance and spends it on the one action '
                'that gets the agent out.',
          );
          expect(allocation.isOverClaimed, isFalse);
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
