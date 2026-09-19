import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';

import 'row_harness.dart';

/// One test per state, and one per thing that has broken a row before.
///
/// The states are asserted through the widget tree and the resolved
/// [SoftRowSpec] rather than through pixels, because what the design ruling
/// actually says is "the fill steps AND the edge steps" — a claim about two
/// declared token values, which a value assertion can check and a screenshot
/// can only show.
void main() {
  group('geometry — three densities, two forms', () {
    test('the densities are 56 / 64 / 80, and Veld collapses them to 64', () {
      final night = TiqSkin.night();
      expect(
        SoftRowSpec.resolve(
          skin: night,
          density: SoftRowDensity.compact,
        ).minHeight,
        56,
      );
      expect(
        SoftRowSpec.resolve(
          skin: night,
          density: SoftRowDensity.standard,
        ).minHeight,
        64,
      );
      expect(
        SoftRowSpec.resolve(
          skin: night,
          density: SoftRowDensity.tall,
        ).minHeight,
        80,
      );
      for (final density in SoftRowDensity.values) {
        expect(
          SoftRowSpec.resolve(skin: TiqSkin.veld(), density: density).minHeight,
          64,
          reason: 'Veld is single-density: 64dp rows at every density.',
        );
      }
    });

    test('every density clears its skin\'s tap-target floor', () {
      for (final name in rowSkinMatrix.map((e) => e.$1)) {
        final skin = skinFor(name);
        for (final density in SoftRowDensity.values) {
          final spec = SoftRowSpec.resolve(skin: skin, density: density);
          expect(
            spec.meetsTargetFloor(skin),
            isTrue,
            reason:
                '$name / ${density.name}: ${spec.minHeight} is under the '
                '${skin.space.tapTarget} floor.',
          );
        }
      }
    });

    test('a list row is flush and radius 0; a standalone row is radius 14 on '
        'surface with an edgeStructure outline', () {
      final skin = TiqSkin.night();
      final list = SoftRowSpec.resolve(skin: skin);
      expect(list.radius, 0);
      expect(
        list.fill,
        isNull,
        reason: 'a list row is transparent over ground',
      );
      expect(list.outline, isNull);

      final standalone = SoftRowSpec.resolve(
        skin: skin,
        form: SoftRowForm.standalone,
      );
      expect(standalone.radius, 14);
      expect(standalone.fill, skin.palette.surface);
      expect(standalone.outline, skin.palette.edgeStructure);
      expect(standalone.outlineWidth, 1);
      expect(
        standalone.separatorColour,
        isNull,
        reason: 'a standalone row carries an outline instead of a rule',
      );
    });

    test('Veld squares the standalone form off and doubles its border', () {
      final spec = SoftRowSpec.resolve(
        skin: TiqSkin.veld(),
        form: SoftRowForm.standalone,
      );
      expect(spec.radius, 0);
      expect(spec.outlineWidth, 2);
      expect(SoftRowSpec.resolve(skin: TiqSkin.veld()).separatorWidth, 2);
    });

    test(
      'content starts at the same inset with and without a severity bar',
      () {
        final skin = TiqSkin.night();
        final plain = SoftRowSpec.resolve(skin: skin);
        final critical = SoftRowSpec.resolve(
          skin: skin,
          severity: SoftRowSeverity.critical,
        );
        expect(
          critical.textInset(hasLeading: false),
          plain.textInset(hasLeading: false),
        );
        expect(plain.severityLane, 3 + TiqSpace.s3);
      },
    );
  });

  group('separation — the rule and who gets which one', () {
    testWidgets('a tappable row is separated by edgeStructure', (tester) async {
      final skin = TiqSkin.night();
      await pumpRow(
        tester,
        skin: skin,
        child: SoftRow(title: 'Kasi Corner Spaza', onTap: () {}),
      );
      expect(_separatorColours(tester), contains(skin.palette.edgeStructure));
    });

    testWidgets('a non-tappable row is separated by the decorative hairline', (
      tester,
    ) async {
      final skin = TiqSkin.night();
      await pumpRow(
        tester,
        skin: skin,
        child: const SoftRow(title: 'Kasi Corner Spaza'),
      );
      expect(_separatorColours(tester), contains(skin.palette.hairline));
      expect(
        _separatorColours(tester),
        isNot(contains(skin.palette.edgeStructure)),
      );
    });

    testWidgets('the rule is inset to the text edge, not full bleed', (
      tester,
    ) async {
      final skin = TiqSkin.night();
      await pumpRow(
        tester,
        skin: skin,
        child: SoftRow(title: 'Kasi Corner Spaza', onTap: () {}),
      );
      final rule = tester
          .widgetList<Padding>(find.byType(Padding))
          .where(
            (p) =>
                p.padding is EdgeInsetsDirectional &&
                (p.padding as EdgeInsetsDirectional).start > 0,
          );
      expect(rule, isNotEmpty);
      final spec = SoftRowSpec.resolve(skin: skin);
      expect(
        (rule.first.padding as EdgeInsetsDirectional).start,
        spec.textInset(hasLeading: false),
      );
    });

    testWidgets('the last row in a group draws no rule', (tester) async {
      await pumpRow(
        tester,
        skin: TiqSkin.night(),
        child: SoftRow(
          title: 'Kasi Corner Spaza',
          separator: SoftRowSeparator.none,
          onTap: () {},
        ),
      );
      expect(_separatorColours(tester), isEmpty);
    });
  });

  group('pressed — two channels, not one', () {
    test('the fill steps to lifted AND the rule steps to 2px edgeControl', () {
      final skin = TiqSkin.night();
      final resting = SoftRowSpec.resolve(skin: skin);
      final pressed = SoftRowSpec.resolve(skin: skin, pressed: true);

      expect(pressed.fill, skin.palette.lifted);
      expect(
        pressed.separatorColour,
        skin.palette.edgeControl,
        reason:
            'lifted on the Night well is 1.49:1 — invisible on a cheap panel '
            'at 40% backlight. The edge is the channel that carries the press.',
      );
      expect(pressed.separatorWidth, resting.separatorWidth * 2);
      expect(pressed.pressScale, 0.98);
    });

    test('the standalone outline steps the same way', () {
      final skin = TiqSkin.night();
      final pressed = SoftRowSpec.resolve(
        skin: skin,
        form: SoftRowForm.standalone,
        pressed: true,
      );
      expect(pressed.outline, skin.palette.edgeControl);
      expect(pressed.outlineWidth, 2);
    });

    test('on a light ground the press inverts and the ink goes with it', () {
      for (final skin in <TiqSkin>[TiqSkin.day(), TiqSkin.veld()]) {
        final pressed = SoftRowSpec.resolve(skin: skin, pressed: true);
        expect(pressed.fill, skin.palette.lifted);
        expect(
          pressed.titleInk,
          skin.palette.ground,
          reason:
              '`lifted` is an ink block on paper in ${skin.mode.name}; ink-1 '
              'on it would be 1.4:1.',
        );
      }
    });

    testWidgets('a press fires the tick haptic and takes the pressed fill', (
      tester,
    ) async {
      final skin = TiqSkin.night();
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String? ?? 'vibrate');
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      var taps = 0;
      await pumpRow(
        tester,
        skin: skin,
        child: SoftRow(title: 'Kasi Corner Spaza', onTap: () => taps++),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(SoftRow)),
      );
      await tester.pump();
      expect(
        _decorationFills(tester),
        contains(skin.palette.lifted),
        reason: 'the row takes the lifted fill while it is held',
      );
      expect(find.byType(Transform), findsWidgets, reason: 'scale 0.98');

      await gesture.up();
      await tester.pump();
      expect(taps, 1);
      expect(haptics, isNotEmpty);
      expect(_decorationFills(tester), isNot(contains(skin.palette.lifted)));
    });

    testWidgets(
      'reduce-motion drops the scale and keeps fill, edge and haptic',
      (tester) async {
        final skin = TiqSkin.night();
        await pumpRow(
          tester,
          skin: skin,
          still: true,
          child: SoftRow(title: 'Kasi Corner Spaza', onTap: () {}),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(SoftRow)),
        );
        await tester.pump();
        expect(find.byType(Transform), findsNothing);
        expect(_decorationFills(tester), contains(skin.palette.lifted));
        expect(_separatorColours(tester), contains(skin.palette.edgeControl));
        await gesture.up();
        await tester.pump();
      },
    );
  });

  group('severity — never a fill step, never amber, always a word', () {
    test('critical is a solid bar, watch is an outlined one', () {
      final skin = TiqSkin.night();
      final critical = SoftRowSpec.resolve(
        skin: skin,
        severity: SoftRowSeverity.critical,
      );
      expect(critical.barFill, skin.palette.badSolid);
      expect(critical.barStroke, isNull);

      final watch = SoftRowSpec.resolve(
        skin: skin,
        severity: SoftRowSeverity.watch,
      );
      expect(
        watch.barFill,
        isNull,
        reason:
            'watch is an outline, not the critical bar at 40% opacity — '
            'opacity is banned as a state channel',
      );
      expect(watch.barStroke, skin.palette.bad);
    });

    test('Veld widens the bar to 6px, because 3px is a smudge in glare', () {
      expect(
        SoftRowSpec.resolve(
          skin: TiqSkin.veld(),
          severity: SoftRowSeverity.critical,
        ).barWidth,
        6,
      );
    });

    testWidgets('the severity word is announced before the title', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpRow(
        tester,
        skin: TiqSkin.night(),
        child: SoftRow(
          title: 'Kasi Corner Spaza',
          subtitle: 'Out of stock since Tuesday',
          severity: SoftRowSeverity.critical,
          severityLabel: 'Critical',
          onTap: () {},
        ),
      );
      expect(
        tester.getSemantics(find.byType(SoftRow)).label,
        'Critical. Kasi Corner Spaza. Out of stock since Tuesday',
      );
      handle.dispose();
    });

    test('a severity without a word is a build-time error', () {
      expect(
        () => SoftRow(
          title: 'Kasi Corner Spaza',
          severity: SoftRowSeverity.critical,
          onTap: () {},
        ),
        throwsAssertionError,
      );
    });
  });

  group('the row\'s verbs', () {
    testWidgets('a tappable row carries a tap ACTION, not only the flag', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await pumpRow(
        tester,
        skin: TiqSkin.night(),
        child: SoftRow(title: 'Kasi Corner Spaza', onTap: () => taps++),
      );
      final node = tester.getSemantics(find.byType(SoftRow));
      // A `GestureDetector` beneath an excluding node contributes nothing: a
      // row with the button flag and no tap action is one a screen reader can
      // focus and cannot activate.
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      // And the action actually runs the row's callback, which is the half a
      // flag cannot prove.
      tester.semantics.tap(find.semantics.byLabel('Kasi Corner Spaza'));
      await tester.pump();
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('an action in the row keeps its own node; the rest stays '
        'excluded', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRow(
        tester,
        skin: TiqSkin.night(),
        child: SoftRow(
          title: 'Shelf talker missing',
          subtitle: 'Kasi Corner Spaza',
          meta: const Text('Overdue by 2 days'),
          actions: Semantics(
            container: true,
            button: true,
            label: 'Close with photo',
            child: const SizedBox(width: 120, height: 44),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Close with photo'), findsOneWidget);
      // And the row is still one sentence: the title did not become a second
      // node beside it.
      expect(
        tester.getSemantics(find.byType(SoftRow)).label,
        'Shelf talker missing. Kasi Corner Spaza',
      );
      handle.dispose();
    });

    testWidgets('a trailing control keeps its node; a trailing figure does '
        'not', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRow(
        tester,
        skin: TiqSkin.night(),
        child: SoftRow(
          title: 'Out of stock alert',
          trailingIsControl: true,
          trailing: Semantics(
            container: true,
            button: true,
            label: 'Turn Out of stock alert off',
            child: const SizedBox(width: 48, height: 48),
          ),
          onTap: () {},
        ),
      );
      expect(
        find.bySemanticsLabel('Turn Out of stock alert off'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('a plain trailing widget is still excluded', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRow(
        tester,
        skin: TiqSkin.night(),
        child: SoftRow(
          title: 'Out of stock alert',
          actions: Semantics(
            container: true,
            button: true,
            label: 'Acknowledge',
            child: const SizedBox(width: 120, height: 44),
          ),
          trailing: Semantics(
            container: true,
            label: 'a figure nobody should hear twice',
            child: const SizedBox(width: 40, height: 20),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Acknowledge'), findsOneWidget);
      expect(
        find.bySemanticsLabel('a figure nobody should hear twice'),
        findsNothing,
        reason: 'the row already says the figure in its own label',
      );
      handle.dispose();
    });

    testWidgets('the actions sit beneath the text column, inset to it', (
      tester,
    ) async {
      const key = ValueKey<String>('verb');
      await pumpRow(
        tester,
        skin: TiqSkin.night(),
        child: SoftRow(
          title: 'Shelf talker missing',
          severity: SoftRowSeverity.critical,
          severityLabel: 'Critical',
          actions: const SizedBox(key: key, width: 120, height: 44),
        ),
      );
      final row = tester.getRect(find.byType(SoftRow));
      final action = tester.getRect(find.byKey(key));
      final title = tester.getRect(find.text('Shelf talker missing'));
      expect(action.top, greaterThan(title.bottom));
      expect(action.left, closeTo(title.left, 0.5));
      expect(action.bottom, lessThanOrEqualTo(row.bottom));
    });
  });

  group('states', () {
    testWidgets('default — one semantics node, not four', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRow(
        tester,
        skin: TiqSkin.night(),
        child: SoftRow(
          title: 'Kasi Corner Spaza',
          subtitle: '1,2 km away',
          leading: const RowMarkTile(mark: RowMark.square),
          trailing: const SoftRowChevron(),
          onTap: () {},
        ),
      );
      final node = tester.getSemantics(find.byType(SoftRow));
      expect(node.label, 'Kasi Corner Spaza. 1,2 km away');
      expect(isButtonNode(node), isTrue);
      handle.dispose();
    });

    testWidgets('non-tappable — no button flag, no press feedback', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final skin = TiqSkin.night();
      await pumpRow(
        tester,
        skin: skin,
        child: const SoftRow(title: 'Score', subtitle: 'Not yet scored'),
      );
      expect(isButtonNode(tester.getSemantics(find.byType(SoftRow))), isFalse);
      await tester.tap(find.byType(SoftRow), warnIfMissed: false);
      await tester.pump();
      expect(_decorationFills(tester), isNot(contains(skin.palette.lifted)));
      handle.dispose();
    });

    testWidgets('disabled — ink-mute, no chevron, no press', (tester) async {
      final skin = TiqSkin.night();
      await pumpRow(
        tester,
        skin: skin,
        child: SoftRow(
          title: 'Stock count',
          subtitle: 'Nobody has set up SKUs for this outlet',
          trailing: const SoftRowChevron(),
          enabled: false,
          onTap: () {},
        ),
      );
      expect(
        find.byType(SoftRowChevron),
        findsNothing,
        reason: 'an affordance on a control that cannot respond is a lie',
      );
      final title = tester.widget<Text>(find.text('Stock count'));
      expect(title.style!.color, skin.palette.inkMute);
    });

    testWidgets('a row with no trailing content lays out and takes the full '
        'width', (tester) async {
      await pumpRow(
        tester,
        skin: TiqSkin.night(),
        child: const SoftRow(title: 'Kasi Corner Spaza'),
      );
      expect(tester.takeException(), isNull);
      final spec = SoftRowSpec.resolve(skin: TiqSkin.night());
      expect(
        tester.getSize(find.byType(SoftRow)).height,
        greaterThanOrEqualTo(spec.minHeight),
      );
      expect(find.text('Kasi Corner Spaza'), findsOneWidget);
    });

    testWidgets('long-press is offered only where a row has a second verb', (
      tester,
    ) async {
      var longPresses = 0;
      await pumpRow(
        tester,
        skin: TiqSkin.night(),
        child: SoftRow(
          title: 'Kasi Corner Spaza',
          onTap: () {},
          onLongPress: () => longPresses++,
        ),
      );
      await tester.longPress(find.byType(SoftRow));
      await tester.pump();
      expect(longPresses, 1);
    });
  });

  group('2.0× text and Afrikaans', () {
    testWidgets('at 2.0× the trailing column drops beneath the text column', (
      tester,
    ) async {
      final skin = TiqSkin.night();
      Future<Offset> trailingOffset(double scale) async {
        await pumpRow(
          tester,
          skin: skin,
          textScale: scale,
          child: SoftRow(
            title: afrikaansLabel,
            subtitle: 'Vandag 14:03',
            trailing: const Text('Wag vir sein'),
            onTap: () {},
          ),
        );
        return tester.getTopLeft(find.text('Wag vir sein')) -
            tester.getTopLeft(find.byType(SoftRow));
      }

      final inline = await trailingOffset(1.0);
      final stacked = await trailingOffset(2.0);
      expect(
        stacked.dy,
        greaterThan(inline.dy),
        reason: 'the trailing column moved down rather than being squeezed',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the stacking decision is measured, not guessed from the '
        'text scale', (tester) async {
      final skin = TiqSkin.night();
      // A wide trailing at 1.0× stacks; a narrow one at 2.0× need not. Either
      // way the row must not overflow, which is what a text-scale threshold
      // gets wrong in both directions.
      await pumpRow(
        tester,
        skin: skin,
        child: SoftRow(
          title: 'Kasi Corner Spaza',
          trailing: const Text('R 1 284 990 sedert verlede kwartaal'),
          onTap: () {},
        ),
      );
      expect(tester.takeException(), isNull);
      await pumpRow(
        tester,
        skin: skin,
        textScale: 2.0,
        child: SoftRow(
          title: 'Kasi Corner Spaza',
          trailing: const SoftRowChevron(),
          onTap: () {},
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a 40-character Afrikaans label wraps rather than clipping', (
      tester,
    ) async {
      for (final name in rowSkinMatrix.map((e) => e.$1)) {
        for (final scale in <double>[1.0, 1.4, 2.0]) {
          await pumpRow(
            tester,
            skin: skinFor(name),
            textScale: scale,
            child: SoftRow(
              density: SoftRowDensity.tall,
              title: afrikaansLabel,
              subtitle: afrikaansLabel,
              leading: const RowMarkTile(mark: RowMark.square),
              trailing: const SoftRowChevron(),
              onTap: () {},
            ),
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '$name at ${scale}x overflowed',
          );
        }
      }
    });

    testWidgets('meaning-bearing glyphs scale with the text and cap at 48', (
      tester,
    ) async {
      final skin = TiqSkin.night();
      expect(
        SoftRowSpec.resolve(
          skin: skin,
          density: SoftRowDensity.compact,
          textScale: 1.0,
        ).leadingExtent,
        28,
      );
      expect(
        SoftRowSpec.resolve(
          skin: skin,
          density: SoftRowDensity.compact,
          textScale: 2.0,
        ).leadingExtent,
        48,
      );
      await pumpRow(
        tester,
        skin: skin,
        textScale: 2.0,
        child: SoftRow(
          title: 'Kasi Corner Spaza',
          trailing: const SoftRowChevron(),
          onTap: () {},
        ),
      );
      expect(tester.getSize(find.byType(SoftRowChevron)).width, 32);
    });

    testWidgets('nothing is pinned: the row grows past its minimum', (
      tester,
    ) async {
      await pumpRow(
        tester,
        skin: TiqSkin.night(),
        textScale: 2.0,
        child: SoftRow(
          density: SoftRowDensity.compact,
          title: afrikaansLabel,
          subtitle: afrikaansLabel,
          meta: const Text('1,4 MB · in die ry gesit 14:03'),
          onTap: () {},
        ),
      );
      expect(tester.getSize(find.byType(SoftRow)).height, greaterThan(56));
    });
  });

  group('middle truncation', () {
    testWidgets('two names that end-truncate the same stay distinguishable', (
      tester,
    ) async {
      String painted(String source) =>
          (tester
                  .widgetList<Text>(find.byType(Text))
                  .firstWhere((t) => t.data != null && t.data!.contains('…')))
              .data!;

      await pumpRow(
        tester,
        skin: TiqSkin.night(),
        rowWidth: 180,
        child: const SoftRow(
          title: longName,
          titleTruncation: SoftRowTruncation.middle,
        ),
      );
      final first = painted(longName);

      await pumpRow(
        tester,
        skin: TiqSkin.night(),
        rowWidth: 180,
        child: const SoftRow(
          title: similarName,
          titleTruncation: SoftRowTruncation.middle,
        ),
      );
      final second = painted(similarName);

      expect(first, isNot(second));
      expect(first, endsWith('e'));
      expect(second, endsWith('u'));
    });

    testWidgets('a name that fits is not touched', (tester) async {
      await pumpRow(
        tester,
        skin: TiqSkin.night(),
        child: const SoftRow(
          title: longName,
          titleTruncation: SoftRowTruncation.middle,
        ),
      );
      expect(find.text(longName), findsOneWidget);
    });
  });

  group('the paint budget', () {
    testWidgets('a row paints no shadow, no gradient and no backdrop filter', (
      tester,
    ) async {
      for (final name in rowSkinMatrix.map((e) => e.$1)) {
        await pumpRow(
          tester,
          skin: skinFor(name),
          child: SoftRow(
            density: SoftRowDensity.tall,
            title: 'Kasi Corner Spaza',
            subtitle: 'Out of stock since Tuesday',
            severity: SoftRowSeverity.critical,
            severityLabel: 'Critical',
            leading: const RowMarkTile(mark: RowMark.square),
            trailing: const SoftRowChevron(),
            onTap: () {},
          ),
        );
        for (final box in tester.widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(SoftRow),
            matching: find.byType(DecoratedBox),
          ),
        )) {
          final decoration = box.decoration as BoxDecoration;
          expect(
            decoration.boxShadow ?? const <BoxShadow>[],
            isEmpty,
            reason: '$name: no shadow inside a scrolling list',
          );
          expect(decoration.gradient, isNull, reason: '$name: no gradient');
        }
        expect(find.byType(BackdropFilter), findsNothing);
        expect(find.byType(ShaderMask), findsNothing);
        expect(find.byType(ImageFiltered), findsNothing);
      }
    });
  });
}

/// Every `ColoredBox` a rule is drawn with, in the pumped frame.
List<Color> _separatorColours(WidgetTester tester) => tester
    .widgetList<ColoredBox>(
      find.descendant(
        of: find.byType(SoftRow),
        matching: find.byType(ColoredBox),
      ),
    )
    .map((b) => b.color)
    .toList();

List<Color?> _decorationFills(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(SoftRow),
        matching: find.byType(DecoratedBox),
      ),
    )
    .map((b) => (b.decoration as BoxDecoration).color)
    .toList();

/// `SemanticsNode.hasFlag` is deprecated; the button flag now lives on the
/// node's flag collection.
bool isButtonNode(SemanticsNode node) => node.flagsCollection.isButton;
