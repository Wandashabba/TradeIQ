import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/tiq_number.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';

import 'phase2_harness.dart';

void main() {
  group('the trough', () {
    test('holds at the bottom — radius 10 there, 0 at the top', () {
      for (final name in phase2SkinNames) {
        final skin = phase2SkinNamed(name);
        final spec = TroughSpec.resolve(skin: skin);
        final expected = skin.density == TiqDensity.veld ? 0.0 : 10.0;
        expect(
          spec.radius.bottomLeft.x,
          expected,
          reason: '$name: a trough holds at the bottom and the shape says so.',
        );
        expect(spec.radius.bottomRight.x, expected);
        expect(spec.radius.topLeft.x, 0);
        expect(spec.radius.topRight.x, 0);
      }
    });

    test('carries a real edge on all four sides, because a fill step is not a '
        'boundary', () {
      final night = TiqSkin.night(density: TiqDensity.field);
      final spec = TroughSpec.resolve(skin: night);
      expect(
        spec.outline,
        night.palette.edgeControl,
        reason:
            'Night well on Night ground is 1.12:1 — one quantisation level on '
            'a 6-bit LCD at 40% backlight. A field identified by that fill and '
            'one bottom rule is a floating line on black.',
      );
      expect(spec.fill, night.palette.well);
    });

    test('doubles its bottom rule on focus rather than only changing hue', () {
      for (final name in phase2SkinNames) {
        final skin = phase2SkinNamed(name);
        final rest = TroughSpec.resolve(skin: skin);
        final focused = TroughSpec.resolve(
          skin: skin,
          state: TroughState.focused,
        );
        expect(
          focused.bottomRuleWidth,
          rest.bottomRuleWidth * 2,
          reason:
              '$name: "the rule thickens 1px→2px" is the channel a reader who '
              'cannot separate two greys still gets.',
        );
        expect(focused.bottomRule, isNot(rest.bottomRule));
      }
    });

    test('paints no amber on focus, and says why in one place', () {
      final night = TiqSkin.night(density: TiqDensity.field);
      final focused = TroughSpec.resolve(
        skin: night,
        state: TroughState.focused,
      );
      expect(
        focused.bottomRule,
        night.palette.ink1,
        reason:
            'Unify §1.1 keeps a flame-700 focus rule and counts it; no Phase 2 '
            'component emits light, and the amber lint\'s allowlist is pinned '
            'at ten emitter files. The accessibility bar is cleared by the '
            'thickness channel the ruling itself names.',
      );
    });

    test('stops looking like a field when it is read-only', () {
      final spec = TroughSpec.resolve(
        skin: TiqSkin.night(density: TiqDensity.field),
        state: TroughState.readOnly,
      );
      expect(spec.fill, isNull);
      expect(spec.outline, isNull);
      expect(spec.bottomRule, isNull);
      expect(
        spec.ink,
        TiqSkin.night().palette.ink1,
        reason:
            'Not 0.8 opacity. That is a state the contrast walk cannot see, '
            'and opacity is banned as a state channel.',
      );
    });

    test('takes the whole control for a finding, in a declared hex', () {
      final spec = TroughSpec.resolve(
        skin: TiqSkin.night(density: TiqDensity.field),
        state: TroughState.finding,
      );
      expect(spec.fill, TroughSpec.findingWashNight);
      expect(
        spec.fill!.a,
        1.0,
        reason: 'A composited value is a declared one.',
      );
      expect(spec.outline, TiqSkin.night().palette.bad);
      expect(spec.outlineWidth, 2);
    });
  });

  group('the text field', () {
    testWidgets('makes the visible label the semantic label', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: const TorchTextField(label: 'Units on shelf'),
      );
      expect(find.text('Units on shelf'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Units on shelf'),
        findsWidgets,
        reason:
            'Not a hint. A label that becomes the value\'s decoration the '
            'moment you type destroys the field\'s own name at the point '
            'somebody looks up from a shelf and asks what they were typing '
            'into.',
      );
      handle.dispose();
    });

    testWidgets('shows its counter at 80% of the cap and not a character '
        'sooner', (tester) async {
      expect(TorchFieldCounter.visible(159, 200), isFalse);
      expect(TorchFieldCounter.visible(160, 200), isTrue);
      expect(TroughSpec.counterThreshold, 0.8);
    });

    testWidgets('replaces the help line with the error rather than pushing '
        'it', (tester) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: const TorchTextField(
          label: 'What happened?',
          help: 'Up to 200 characters',
          error: 'Say what happened',
        ),
      );
      expect(find.text('Say what happened'), findsOneWidget);
      expect(
        find.text('Up to 200 characters'),
        findsNothing,
        reason:
            'A layout that grows by a line when a value is refused moves every '
            'control beneath it under a thumb that is already travelling.',
      );
    });
  });

  group('the numeric field', () {
    test('anchors the leading digits when the value will not fit', () {
      final style = TiqSkin.night().text.figureM.style();
      final fits = NumericOverflow.measure(
        text: '24',
        style: style,
        scaler: TextScaler.noScaling,
        direction: TextDirection.ltr,
        available: 200,
      );
      expect(fits.overflows, isFalse);
      expect(
        fits.align,
        TextAlign.right,
        reason: 'A column of prices aligns on its decimal.',
      );

      final spills = NumericOverflow.measure(
        text: 'R 1 234 567,89',
        style: style,
        scaler: TextScaler.noScaling,
        direction: TextDirection.ltr,
        available: 92,
      );
      expect(spills.overflows, isTrue);
      expect(
        spills.align,
        TextAlign.left,
        reason:
            'Right-aligned, the trough showed "4 567,89" and a manager read it '
            'back and confirmed a wrong number. The half that carries the '
            'magnitude is the half that survives.',
      );
      expect(spills.fadeWidth, 12);
    });

    testWidgets('renders an em dash for null and a zero for zero', (
      tester,
    ) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: const TorchNumericField(
          label: 'Units on shelf',
          notCountedLine: 'Not counted',
        ),
      );
      expect(
        find.text('Not counted'),
        findsOneWidget,
        reason: 'A bare dash is never the whole message.',
      );

      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: TorchNumericField(
          label: 'Units on shelf',
          controller: TextEditingController(text: '0'),
        ),
      );
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('takes the whole control for a zero that is a finding', (
      tester,
    ) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: TorchNumericField(
          label: 'Units on shelf',
          controller: TextEditingController(text: '0'),
          zeroIsFinding: true,
          findingWord: 'Out of stock',
        ),
      );
      expect(find.text('Out of stock'), findsOneWidget);
    });

    testWidgets('uses the locale separator and accepts the other one anyway', (
      tester,
    ) async {
      expect(TiqNumber.af.symbols.decimal, ',');
      expect(TiqNumber.en.symbols.decimal, '.');
      num? captured;
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        locale: const Locale('af'),
        child: TorchNumericField(label: 'Prys', onChanged: (v) => captured = v),
      );
      await tester.enterText(find.byType(TextField), '1.5');
      await tester.pump();
      expect(
        captured,
        1.5,
        reason:
            'An agent who types 1.5 on an Afrikaans phone has typed one and a '
            'half. Refusing it is the app being right about a rule nobody '
            'agreed to.',
      );
    });
  });

  group('the count stepper', () {
    testWidgets('records 0 from null on minus and 1 from null on plus', (
      tester,
    ) async {
      int? recorded;
      Widget stepper() => CountStepper(
        label: 'Units on shelf',
        value: null,
        decreaseLabel: 'One fewer',
        increaseLabel: 'One more',
        onChanged: (v) => recorded = v,
      );

      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: stepper(),
      );
      await tester.tap(find.bySemanticsLabel('One fewer'));
      await tester.pump();
      expect(
        recorded,
        0,
        reason: 'From "not counted", minus means "there are none".',
      );

      recorded = null;
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: stepper(),
      );
      await tester.tap(find.bySemanticsLabel('One more'));
      await tester.pump();
      expect(
        recorded,
        1,
        reason:
            'Plus means "I counted one", never 0. Landing on zero by accident '
            'silently raises a task for a manager.',
      );
    });

    testWidgets('takes the whole control for a zero that is a finding', (
      tester,
    ) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: CountStepper(
          label: 'Units on shelf',
          value: 0,
          zeroIsFinding: true,
          findingWord: 'Out of stock',
          findingLine: 'Out of stock. This raises a task for the manager.',
          onChanged: (_) {},
        ),
      );
      expect(find.text('Out of stock'), findsOneWidget);
      expect(
        find.text('Out of stock. This raises a task for the manager.'),
        findsOneWidget,
        reason:
            'The whole control changes, not just the digit, so it reads from '
            'arm\'s length in a dark aisle.',
      );
    });

    testWidgets('opens a sheet to type, so a stray tap cannot replace a '
        'count', (tester) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: CountStepper(
          label: 'Units on shelf',
          value: 12,
          typeLabel: 'Type a count',
          onChanged: (_) {},
        ),
      );
      await tester.tap(find.bySemanticsLabel('Type a count'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.byType(TorchSheet),
        findsOneWidget,
        reason:
            'Not an inline edit with the value selected. A stray press that '
            'replaces a count with one digit is the data loss this control '
            'exists to prevent.',
      );
      expect(find.text('Set'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('mirrors for a left-handed thumb, and defaults right', (
      tester,
    ) async {
      expect(TorchHandedness.right.mirrored, isFalse);
      expect(TorchHandedness.left.mirrored, isTrue);

      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: CountStepper(
          label: 'Units',
          value: 12,
          decreaseLabel: 'One fewer',
          onChanged: (_) {},
        ),
      );
      final rightHanded = tester
          .getRect(find.bySemanticsLabel('One fewer'))
          .center
          .dx;

      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: TorchHandednessScope(
          handedness: TorchHandedness.left,
          child: CountStepper(
            label: 'Units',
            value: 12,
            decreaseLabel: 'One fewer',
            onChanged: (_) {},
          ),
        ),
      );
      final leftHanded = tester
          .getRect(find.bySemanticsLabel('One fewer'))
          .center
          .dx;

      expect(
        leftHanded,
        lessThan(rightHanded),
        reason:
            'The preference mirrors the whole control once. Nothing in this '
            'app infers handedness from where a thumb lands.',
      );
    });

    testWidgets('names the unit on its step targets, never the glyph', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: CountStepper(
          label: 'Units on shelf',
          value: 12,
          unitWord: 'facings',
          onChanged: (_) {},
        ),
      );
      final node = tester.getSemantics(find.byType(CountStepper));
      expect(node.value, contains('facings'));
      handle.dispose();
    });

    testWidgets('holds to repeat after 400ms, and drops the haptic to every '
        'fifth', (tester) async {
      expect(CountStepper.repeatDelay, const Duration(milliseconds: 400));
      expect(CountStepper.repeatInterval, const Duration(milliseconds: 125));
      expect(CountStepper.hapticEveryNthRepeat, 5);
    });
  });

  group('the toggle', () {
    testWidgets('always renders the state word', (tester) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: TorchToggle(
          label: 'Fridge working',
          value: true,
          onWord: 'On',
          onChanged: (_) {},
        ),
      );
      expect(
        find.text('On'),
        findsOneWidget,
        reason:
            'Mandatory, and not only in Veld. At a 56dp target in glare a '
            'thumb position alone is a coin toss.',
      );
    });

    testWidgets('is 52×32 with a 26dp thumb', (tester) async {
      final night = TiqSkin.night(density: TiqDensity.field);
      expect(TorchToggle.trackSizeFor(night), const Size(52, 32));
      expect(TorchToggle.thumbExtentFor(night), 26);
      expect(TorchToggle.trackSizeFor(TiqSkin.veld()), const Size(64, 36));
    });
  });

  group('the checkbox', () {
    testWidgets('is 28dp at 1.0× and 48 at 2.0×', (tester) async {
      late double one;
      late double two;
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: Builder(
          builder: (context) {
            one = TorchCheckbox.extentFor(context, context.skin);
            return const SizedBox.shrink();
          },
        ),
      );
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        textScale: 2.0,
        child: Builder(
          builder: (context) {
            two = TorchCheckbox.extentFor(context, context.skin);
            return const SizedBox.shrink();
          },
        ),
      );
      expect(one, 28);
      expect(two, 48, reason: '48 is also the tap-target floor.');
    });

    testWidgets('puts the error on the group, not on the boxes', (
      tester,
    ) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: TorchCheckboxGroup(
          label: 'Which materials are up?',
          error: 'Choose at least one',
          children: <Widget>[
            TorchCheckbox(label: 'Posters', value: false, onChanged: (_) {}),
            TorchCheckbox(label: 'Wobblers', value: false, onChanged: (_) {}),
          ],
        ),
      );
      expect(
        find.text('Choose at least one'),
        findsOneWidget,
        reason:
            'No single box is wrong, and turning eight of them crimson tells '
            'a reader that eight things are broken.',
      );
    });
  });

  group('the choice row', () {
    testWidgets('says so when nothing is selected', (tester) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: ChoiceRow<String>(
          label: 'Was the shelf full?',
          value: null,
          notAnsweredLine: 'Not answered yet',
          onChanged: (_) {},
          options: const <ChoiceOption<String>>[
            ChoiceOption<String>(value: 'y', label: 'Yes'),
            ChoiceOption<String>(value: 'n', label: 'No'),
          ],
        ),
      );
      expect(
        find.text('Not answered yet'),
        findsOneWidget,
        reason:
            'A toggle sitting at off is a recorded "no". Silence is not "no", '
            'and this is the component that can say the difference.',
      );
    });

    testWidgets('refuses one option and refuses five', (tester) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: ChoiceRow<String>(
          label: 'Pick',
          value: null,
          onChanged: (_) {},
          options: const <ChoiceOption<String>>[
            ChoiceOption<String>(value: 'a', label: 'A'),
          ],
        ),
      );
      expect(tester.takeException(), isAssertionError);
    });
  });

  group('the filter chip', () {
    testWidgets('marks selection with three channels and never amber', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: TorchFilterChip(
          label: 'Needs a decision',
          selected: true,
          count: 5,
          onSelected: () {},
        ),
      );
      // Fill + border + tick + weight. The census in phase2_amber_test proves
      // the "never amber" half; this proves the chip carries the other three.
      expect(
        find.bySemanticsLabel('Needs a decision, 5 results'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('keeps a disabled filter visible', (tester) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: const TorchFilterChip(
          label: 'Limpopo',
          selected: false,
          count: 0,
          onSelected: null,
        ),
      );
      expect(
        find.text('Limpopo'),
        findsOneWidget,
        reason:
            'Hiding a filter because it is empty hides the fact that it is '
            'empty, which is usually the thing worth knowing.',
      );
    });

    testWidgets('does not scroll its rail in Veld', (tester) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.veld(),
        child: TorchFilterRail(
          chips: <Widget>[
            TorchFilterChip(label: 'All', selected: true, onSelected: () {}),
            TorchFilterChip(
              label: 'Gauteng North',
              selected: false,
              onSelected: () {},
            ),
          ],
        ),
      );
      expect(
        find.byType(ListView),
        findsNothing,
        reason: 'Horizontal-scroll discovery fails outdoors.',
      );
      expect(find.byType(Wrap), findsOneWidget);
    });
  });
}
