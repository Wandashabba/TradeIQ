import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/hatch_paint.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';

/// Four patterns, and the two rules that bound them.
void main() {
  group('the registry', () {
    test('there are exactly four patterns', () {
      // Pinned: adding a fifth is a design decision, not an import.
      expect(HatchPattern.values.map((p) => p.name), <String>[
        'notMeasured',
        'negative',
        'lowSampleOutline',
        'provisionalOutlineDots',
      ]);
    });

    test('not-measured falls and negative rises', () {
      final skin = TiqSkin.night();
      expect(
        HatchPaint.spec(skin, HatchPattern.notMeasured).degrees,
        45,
        reason:
            'A dimension nobody scored falls. It has to be distinguishable '
            'from a negative at a glance and from across a badly lit room.',
      );
      expect(
        HatchPaint.spec(skin, HatchPattern.negative).degrees,
        -45,
        reason:
            'bad against chart-neutral is 1.55:1 true and 1.26:1 in '
            'protanopia. The stripe direction is carrying the sign.',
      );
    });

    test('low sample and provisional are outlines, not stripes', () {
      final skin = TiqSkin.night();
      expect(HatchPaint.spec(skin, HatchPattern.lowSampleOutline).degrees, 0);
      expect(
        HatchPaint.spec(skin, HatchPattern.lowSampleOutline).fill,
        isNull,
        reason:
            'The fill is removed and only the outline stays: an outline is '
            'the honest shape for "there is a number here but not enough of '
            'it".',
      );
      expect(
        HatchPaint.spec(skin, HatchPattern.provisionalOutlineDots).dots,
        isTrue,
      );
    });

    test('a negative hatch is drawn in the severity ink, never in amber', () {
      for (final skin in <TiqSkin>[
        TiqSkin.night(),
        TiqSkin.day(),
        TiqSkin.veld(),
      ]) {
        final p = skin.palette;
        final negative = HatchPaint.spec(skin, HatchPattern.negative);
        expect(negative.line, p.bad);
        for (final pattern in HatchPattern.values) {
          expect(
            <Color>[
              p.flame300,
              p.flame500,
              p.flame600,
              p.flame700,
              p.flame900,
            ],
            isNot(contains(HatchPaint.spec(skin, pattern).line)),
            reason:
                '${skin.mode.name} ${pattern.name} is drawn in an amber. '
                'Burning Flame is a light source, never a label, and a hatch '
                'is the most label-like thing in the system.',
          );
        }
      }
    });

    test('Veld gets a heavier line and no wash', () {
      final veld = TiqSkin.veld();
      final night = TiqSkin.night();
      expect(
        HatchPaint.spec(veld, HatchPattern.notMeasured).strokeWidth,
        greaterThan(
          HatchPaint.spec(night, HatchPattern.notMeasured).strokeWidth,
        ),
      );
      expect(
        HatchPaint.spec(veld, HatchPattern.notMeasured).fill,
        isNull,
        reason:
            'Veld has no fill step to spend: a 1.12:1 wash is one '
            'quantisation level on a budget LCD in highveld sun.',
      );
      expect(
        HatchPaint.spec(veld, HatchPattern.notMeasured).pitch,
        greaterThan(HatchPaint.spec(night, HatchPattern.notMeasured).pitch),
        reason: 'A wider pitch survives glare; a tight one fills in.',
      );
    });
  });

  group('the two hard rules', () {
    final skin = TiqSkin.night();
    final spec = HatchPaint.spec(skin, HatchPattern.notMeasured);

    ui.PictureRecorder record() => ui.PictureRecorder();

    test('never inside a glyph', () {
      final recorder = record();
      final canvas = Canvas(recorder);
      expect(
        () => HatchPaint.paint(
          canvas,
          const Rect.fromLTWH(0, 0, 28, 28),
          spec,
          insideGlyph: true,
        ),
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message.toString(),
            'message',
            contains('flat grey disc'),
          ),
        ),
        reason:
            'A 3dp stripe inside a 28dp tile aliases to a flat grey disc at '
            '40% backlight — the half-disc it must not resemble. "Can\'t '
            'confirm" is a fourth silhouette, not a hatched third one.',
      );
      recorder.endRecording().dispose();
    });

    test('never on a mark under 4dp', () {
      expect(HatchPaint.minimumMarkExtent, 4.0);
      final recorder = record();
      final canvas = Canvas(recorder);
      expect(
        () => HatchPaint.paint(
          canvas,
          const Rect.fromLTWH(0, 0, 40, 3),
          spec,
        ),
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message.toString(),
            'message',
            contains('reads as noise'),
          ),
        ),
      );
      recorder.endRecording().dispose();
    });

    test('4dp exactly is allowed', () {
      final recorder = record();
      final canvas = Canvas(recorder);
      HatchPaint.paint(canvas, const Rect.fromLTWH(0, 0, 40, 4), spec);
      recorder.endRecording().dispose();
    });
  });

  group('it draws lines, not decorations', () {
    test('a hatch in a list row is painter lines', () {
      // The paint budget allows no gradient decoration inside a
      // ListView.builder row: a gradient there is a new Paint and a new
      // shader per row per scroll frame. There is no gradient form of a hatch
      // in the registry at all, so there is nothing to reach for by mistake.
      // Comments are stripped: the file says the word `LinearGradient` once,
      // in the sentence explaining why there is not one.
      final source = File('lib/core/design/hatch_paint.dart')
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      for (final banned in <String>[
        'LinearGradient',
        'BoxDecoration',
        'ImageFiltered',
        'BackdropFilter',
        'MaskFilter',
        'saveLayer',
      ]) {
        expect(
          source.contains(banned),
          isFalse,
          reason:
              'hatch_paint.dart mentions $banned. Every hatch is drawLine '
              'into the canvas the row already has.',
        );
      }
      expect(source, contains('drawLine'));
    });

    test('the stripes are hard-stop: no anti-aliasing, no blur', () {
      final recorder = ui.PictureRecorder();
      final canvas = _RecordingCanvas(recorder);
      HatchPaint.paint(
        canvas,
        const Rect.fromLTWH(0, 0, 60, 20),
        HatchPaint.spec(TiqSkin.night(), HatchPattern.notMeasured),
      );
      recorder.endRecording().dispose();
      expect(canvas.lineCount, greaterThan(3), reason: 'It drew stripes.');
      expect(
        canvas.antiAliased,
        isFalse,
        reason:
            'A feathered stripe at pitch 6 is a grey wash, and the design '
            'bans blur everywhere.',
      );
      expect(canvas.maskFilters, isEmpty);
    });

    test('a stripe pass covers the whole rect', () {
      final recorder = ui.PictureRecorder();
      final canvas = _RecordingCanvas(recorder);
      const rect = Rect.fromLTWH(10, 5, 100, 24);
      HatchPaint.paint(
        canvas,
        rect,
        HatchPaint.spec(TiqSkin.night(), HatchPattern.notMeasured),
      );
      recorder.endRecording().dispose();
      // A "full-width falling hatch on its track" has to reach both ends —
      // a hatch that stops short reads as a partial measurement.
      expect(canvas.minX, lessThanOrEqualTo(rect.left));
      expect(canvas.maxX, greaterThanOrEqualTo(rect.right));
    });
  });
}

/// A `Canvas` that remembers what it was asked to draw.
class _RecordingCanvas implements Canvas {
  _RecordingCanvas(ui.PictureRecorder recorder) : _inner = Canvas(recorder);

  final Canvas _inner;

  int lineCount = 0;
  bool antiAliased = false;
  final List<MaskFilter> maskFilters = <MaskFilter>[];
  double minX = double.infinity;
  double maxX = double.negativeInfinity;

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    lineCount++;
    if (paint.isAntiAlias) antiAliased = true;
    if (paint.maskFilter != null) maskFilters.add(paint.maskFilter!);
    for (final p in <Offset>[p1, p2]) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
    }
    _inner.drawLine(p1, p2, paint);
  }

  @override
  void drawRect(Rect rect, Paint paint) {
    if (paint.maskFilter != null) maskFilters.add(paint.maskFilter!);
    _inner.drawRect(rect, paint);
  }

  @override
  void noSuchMethod(Invocation invocation) =>
      // Everything else passes straight through to the real canvas.
      // ignore: avoid_dynamic_calls
      (_inner as dynamic).noSuchMethod(invocation);

  @override
  void save() => _inner.save();

  @override
  void restore() => _inner.restore();

  @override
  void clipRect(
    Rect rect, {
    ui.ClipOp clipOp = ui.ClipOp.intersect,
    bool doAntiAlias = true,
  }) => _inner.clipRect(rect, clipOp: clipOp, doAntiAlias: doAntiAlias);
}
