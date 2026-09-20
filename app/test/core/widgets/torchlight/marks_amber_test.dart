import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';

import '../../design/amber_golden.dart';

/// THE MARKS EMIT NO AMBER.
///
/// Not the status chip's Watch level — the single most tempting place in the
/// product to reach for it. Not the Live dot. Not a flag. Not a delta. Not the
/// meter's target tick, which the written direction specified in `#FFB162` and
/// unify §1.1 deleted from the ladder outright.
///
/// Three enforcements, and this file is two of them:
///
/// 1. the **pixel census** below renders every state of every mark in all
///    three skins and counts the flame-hued regions, which catches a widget
///    that lit itself without asking the allocator;
/// 2. the **source scan** at the bottom proves no file in these two folders
///    names a flame token at all, which catches the same thing one layer
///    earlier and with a better error message;
/// 3. `TorchScope` asserts on over-claim, and none of these components makes a
///    claim to over-claim with.
const List<String> _markFolders = <String>[
  'lib/core/widgets/torchlight/mark',
  'lib/core/widgets/torchlight/figure',
];

/// One named state of one component.
typedef _Case = MapEntry<String, Widget>;

List<_Case> _cases() => <_Case>[
  for (final level in StatusLevel.values)
    _Case('StatusChip.${level.name}', StatusChip(level: level)),
  _Case(
    'StatusChip.watch stale',
    const StatusChip(level: StatusLevel.watch, detail: 'as at 08:15'),
  ),
  for (final kind in FlagKind.values)
    _Case('FlagChip.${kind.name}', FlagChip(kind: kind)),
  _Case(
    'FlagChip.outOfFence cleared',
    const FlagChip(kind: FlagKind.outOfFence, detail: '140 m', cleared: true),
  ),
  for (final kind in SeverityMarkKind.values)
    _Case('SeverityMark.${kind.name}', SeverityMark(kind: kind)),
  for (final state in SectionState.values)
    _Case('SectionStateGlyph.${state.name}', SectionStateGlyph(state: state)),
  for (final direction in DeltaDirection.values)
    for (final sentiment in TiqSentiment.values)
      _Case(
        'Delta.${direction.name}.${sentiment.name}',
        Delta(
          data: DeltaData(
            direction: direction,
            sentiment: sentiment,
            magnitude: 19,
            comparedTo: 'vs week 37',
          ),
        ),
      ),
  for (final state in MeterState.values)
    _Case(
      'Meter.${state.name}',
      Meter(
        value: state == MeterState.missing ? null : 61,
        target: 80,
        state: state,
        reasonForHatch: 'No competitor on shelf',
      ),
    ),
  _Case('NotMeasured', const NotMeasured(reason: 'No competitor on shelf')),
  _Case('ProvisionalMarker', const ProvisionalMarker()),
  _Case(
    'ProvisionalMarker.confirmed',
    const ProvisionalMarker(confirmed: true),
  ),
  _Case(
    'ReconciliationLine.console',
    const ReconciliationLine(
      finalValue: 71,
      seenValue: 84,
      voice: ReconciliationVoice.console,
      reason: "Two sections' photos arrived after scoring.",
    ),
  ),
  _Case(
    'ReconciliationLine.agent',
    const ReconciliationLine(
      finalValue: 71,
      seenValue: 84,
      voice: ReconciliationVoice.agent,
    ),
  ),
  _Case('Eyebrow', const Eyebrow('On-shelf availability')),
  _Case(
    'StatTile.measured',
    const StatTile(
      eyebrow: 'On-shelf availability',
      value: 61,
      unit: TiqUnit.percent,
      meter: MeterData(value: 61, target: 80),
      delta: DeltaData(
        direction: DeltaDirection.down,
        sentiment: TiqSentiment.bad,
        magnitude: 19,
      ),
    ),
  ),
  _Case(
    'StatTile.zero',
    const StatTile(eyebrow: 'Open critical alerts', value: 0),
  ),
  _Case(
    'StatTile.noData',
    const StatTile(
      eyebrow: 'Coverage',
      value: null,
      noDataReason: 'No visits in this window',
    ),
  ),
  _Case(
    'StatTile.lowSample',
    const StatTile(
      eyebrow: 'On-shelf availability',
      value: 100,
      unit: TiqUnit.percent,
      sampling: FigureSampling(kind: MetricKind.rate, n: 3),
      sampleNote: 'from 3 visits',
    ),
  ),
  _Case(
    'StatTile.provisional',
    const StatTile(
      eyebrow: 'Score',
      value: 71,
      provisional: true,
      stateLine: 'Provisional',
    ),
  ),
  _Case(
    'StatTile.lead.critical',
    const StatTile(
      eyebrow: 'On-shelf availability',
      value: 61,
      unit: TiqUnit.percent,
      lead: true,
      severity: SeverityMarkKind.critical,
      subordinates: 'Coverage 78% · Price compliance 91%',
    ),
  ),
];

void main() {
  group('no mark paints a lit object, in any skin', () {
    for (final skin in <TiqSkin>[
      // Night first, then Day, Veld last — the order the design says to build
      // them in, and therefore the order a failure should be read in.
      TiqSkin.night(),
      TiqSkin.day(),
      TiqSkin.veld(),
    ]) {
      testWidgets(skin.mode.name, (tester) async {
        for (final entry in _cases()) {
          await pumpAmberRoute(
            tester,
            skin: skin,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Align(alignment: Alignment.topLeft, child: entry.value),
            ),
          );
          final census = await amberCensus(tester);
          expect(
            census.objectCount,
            0,
            reason:
                '${entry.key} [${skin.mode.name}] painted '
                '${census.objectCount} amber object(s).\n\n'
                '${census.describe()}\n'
                'Amber is never a chip, flag, status, badge, tick, delta, '
                'section marker or word. Severity is crimson at two '
                'commitment levels and there is no amber warning anywhere in '
                'this system; the meter\'s target tick is ink-1 because a '
                'target is an annotation and an annotation is a label.',
          );
        }
      });
    }
  });

  group('and no source file in these folders names a flame token', () {
    test('the folders exist', () {
      for (final folder in _markFolders) {
        expect(Directory(folder).existsSync(), isTrue, reason: folder);
      }
    });

    test('not one of them', () {
      final named = <String>[];
      final pattern = RegExp(
        r'(?<![A-Za-z0-9_$])'
        r'(flame(300|500|600|700|900)|glowAmber|amberPressed|onAmberPressed'
        r'|onAmber)'
        r'(?![A-Za-z0-9_$])',
      );
      for (final folder in _markFolders) {
        for (final file
            in Directory(folder)
                .listSync(recursive: true)
                .whereType<File>()
                .where((f) => f.path.endsWith('.dart'))) {
          final lines = file.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final raw = lines[i];
            final comment = raw.indexOf('//');
            final code = comment == -1 ? raw : raw.substring(0, comment);
            if (pattern.hasMatch(code)) {
              named.add('${file.path}:${i + 1}  ${code.trim()}');
            }
          }
        }
      }
      expect(
        named,
        isEmpty,
        reason:
            'A mark that names an amber token is lit on every route, '
            'including the ones that already have two lights, and the census '
            'then fails on a screen whose own code looks innocent. These two '
            'folders are not on the emitter allowlist and should never be: '
            'every object in them is a label.\n${named.join('\n')}',
      );
    });
  });
}
