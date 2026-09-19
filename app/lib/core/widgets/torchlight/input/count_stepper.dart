import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../design/figure_slot.dart';
import '../../../design/motion_budget.dart';
import '../../../design/tiq_number.dart';
import '../../../design/torch_scope.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import '../button/buttons.dart';
import '../mark/status_chip.dart';
import '../mark/tiq_mark.dart';
import '../sheet/torch_sheet.dart';
import 'field_shell.dart';
import 'handedness.dart';
import 'numeric_field.dart';
import 'trough.dart';

/// COUNTING STOCK ONE-HANDED, WHILE THE OTHER HAND IS ON THE SHELF.
///
/// Unify §1.8 settled a real disagreement here, and the settlement is the
/// layout: **the value trough leads, and an adjacent `[−][+]` pair sits at the
/// trailing edge**, 56×56 each with a 1px rule between them. Two step targets
/// under one thumb is the arrangement of every till and fuel pump in the
/// country; `[−]` and `[+]` at opposite margins is 250dp of grip-shift per
/// adjustment, twelve times a bay, for an agent with a crate on their other
/// arm. [TorchHandedness] mirrors the whole control once (#407).
///
/// ```dart
/// CountStepper(
///   label: 'Units on shelf',
///   unitWord: 'facings',
///   value: count,
///   onChanged: (v) => setState(() => count = v),
///   zeroIsFinding: true,
/// )
/// ```
///
/// ## The three rules that are about data, not layout
///
/// **Typing opens a sheet.** Tapping the value opens a number sheet with
/// `Cancel` and `Set`. It is not an inline edit with the value selected,
/// because a stray tap that replaces a count with one digit is the data loss
/// this control exists to prevent — and it is not long-press-only either,
/// because a gesture with no affordance is not discoverable.
///
/// **`null → minus` records 0 and `null → plus` records 1.** From *not
/// counted*, pressing minus means "there are none" and is an explicit zero;
/// pressing plus means "I counted one". Landing on zero by accident silently
/// raises a task for a manager, so it is never the accident.
///
/// **Zero is a finding, and the whole control says so.** Not just the digit:
/// the trough takes the finding wash and a 2px `bad` outline, the figure goes
/// to `bad`, a status chip appears beneath, and the phone gives
/// [TorchBuzz.finding] — a heavier, distinct buzz, because the agent is
/// looking at the shelf and zero is the most valuable thing they can record.
class CountStepper extends StatefulWidget {
  const CountStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.unitWord,
    this.minimum = 0,
    this.maximum = 9999,
    this.zeroIsFinding = false,
    this.findingWord = 'Out of stock',
    this.findingLine = 'Out of stock. This raises a task for the manager.',
    this.notCountedLine = 'Not counted',
    this.help,
    this.enabled = true,
    this.decreaseLabel = 'One fewer',
    this.increaseLabel = 'One more',
    this.typeLabel = 'Type a count',
    this.cancelLabel = 'Cancel',
    this.setLabel = 'Set',
    this.setBlockedReason = 'Type a count first',
    this.sheetTitle,
  });

  final String label;

  /// Null is **not counted**, and it is a different fact from zero.
  final int? value;

  final ValueChanged<int?> onChanged;

  /// "facings", "units". Spoken with the value, so a reader hears
  /// "Units on shelf, 12 facings".
  final String? unitWord;

  final int minimum;
  final int maximum;

  final bool zeroIsFinding;
  final String findingWord;
  final String findingLine;
  final String notCountedLine;
  final String? help;
  final bool enabled;

  /// Localised by the caller. They name the unit, never the glyph.
  final String decreaseLabel;
  final String increaseLabel;
  final String typeLabel;
  final String cancelLabel;
  final String setLabel;

  /// What the number sheet's disabled `Set` says is missing. A disabled
  /// primary names what it is waiting for.
  final String setBlockedReason;

  /// The number sheet's title — the product's name on a stock count, so the
  /// agent typing a figure can see which shelf it is going to. Defaults to
  /// [label].
  final String? sheetTitle;

  /// One step tile's extent for a skin. 56 on Night and Day, 64 in Veld.
  static double tileExtentFor(TiqSkin skin) =>
      skin.density == TiqDensity.veld ? 64 : TiqSpace.s9;

  /// Above this text scale the pair drops beneath the trough as two halves —
  /// still adjacent, still one thumb. Measured, not guessed: the threshold is
  /// applied on a `LayoutBuilder` width in [build].
  static const double stackedMinimumTroughWidth = 120;

  /// Hold-to-repeat starts here. The kit said 500ms and the agent surface said
  /// 400; 400 wins on the agent's argument, which is that the repeat exists
  /// for a shelf of twenty-four and half a second is a long time to hold a
  /// phone still at arm's length.
  static const Duration repeatDelay = Duration(milliseconds: 400);

  /// Then eight a second, with the haptic dropping to every fifth step so a
  /// long hold is not a buzz.
  static const Duration repeatInterval = Duration(milliseconds: 125);
  static const int hapticEveryNthRepeat = 5;

  @override
  State<CountStepper> createState() => _CountStepperState();
}

class _CountStepperState extends State<CountStepper> {
  Timer? _holdTimer;
  Timer? _repeatTimer;
  int _repeats = 0;
  bool _wasFinding = false;

  @override
  void dispose() {
    _holdTimer?.cancel();
    _repeatTimer?.cancel();
    super.dispose();
  }

  bool get _isFinding =>
      widget.zeroIsFinding && widget.value == 0 && widget.enabled;

  bool get _atMin => widget.value != null && widget.value! <= widget.minimum;
  bool get _atMax => widget.value != null && widget.value! >= widget.maximum;

  /// THE NULL RULE, in one place. From *not counted*: minus records the
  /// minimum (zero), plus records one.
  int _next(int delta) {
    final current = widget.value;
    if (current == null) return delta < 0 ? widget.minimum : 1;
    return (current + delta).clamp(widget.minimum, widget.maximum);
  }

  void _step(int delta, {bool haptic = true}) {
    if (!widget.enabled) return;
    final next = _next(delta);
    if (next == widget.value) return;
    widget.onChanged(next);
    if (!haptic) return;
    final landsOnFinding = widget.zeroIsFinding && next == 0;
    if (landsOnFinding) {
      TorchBuzz.finding();
    } else {
      TorchBuzz.tick();
    }
  }

  void _startHold(int delta) {
    _holdTimer?.cancel();
    _repeats = 0;
    _holdTimer = Timer(CountStepper.repeatDelay, () {
      _repeatTimer = Timer.periodic(CountStepper.repeatInterval, (_) {
        _repeats++;
        _step(delta, haptic: _repeats % CountStepper.hapticEveryNthRepeat == 0);
      });
    });
  }

  void _endHold() {
    _holdTimer?.cancel();
    _repeatTimer?.cancel();
    _holdTimer = null;
    _repeatTimer = null;
    _repeats = 0;
  }

  Future<void> _openNumberSheet(BuildContext context) async {
    if (!widget.enabled) return;
    final result = await showTorchSheet<int?>(
      context,
      builder: (sheetContext) => _CountSheet(
        title: widget.sheetTitle ?? widget.label,
        fieldLabel: widget.label,
        blockedReason: widget.setBlockedReason,
        initial: widget.value,
        minimum: widget.minimum,
        maximum: widget.maximum,
        cancelLabel: widget.cancelLabel,
        setLabel: widget.setLabel,
      ),
    );
    if (!mounted || result == null || result == widget.value) return;
    widget.onChanged(result);
    // A typed zero is the same finding a stepped zero is, and it lands with
    // the same heavier buzz — the sheet is a way to enter a count, not a way
    // round the one signal the agent feels in a dark aisle.
    if (widget.zeroIsFinding && result == 0) {
      TorchBuzz.finding();
    } else {
      TorchBuzz.tick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final numbers = TiqNumber.of(context);
    final handedness = TorchHandednessScope.of(context);
    final tile = CountStepper.tileExtentFor(skin);

    if (_isFinding != _wasFinding) {
      _wasFinding = _isFinding;
    }

    final spec = TroughSpec.resolve(
      skin: skin,
      numeric: true,
      state: !widget.enabled
          ? TroughState.disabled
          : _isFinding
          ? TroughState.finding
          : widget.value == null
          ? TroughState.empty
          : TroughState.filled,
    );

    final figureInk = _isFinding
        ? skin.palette.bad
        : widget.value == null
        ? skin.palette.ink3
        : spec.ink;

    final trough = _ValueTrough(
      spec: spec,
      value: widget.value,
      ink: figureInk,
      onTap: widget.enabled ? () => _openNumberSheet(context) : null,
      typeLabel: widget.typeLabel,
      // A null figure is an em dash, and an em dash announced as "em dash" is
      // not a sentence. `FigureSlot` asserts on a missing value with no words
      // beside it, which is the rule doing its job: *not counted* has to say
      // so, out loud, to a reader who cannot see the dash.
      missingLabel: widget.notCountedLine,
    );

    final pair = _StepPair(
      extent: tile,
      spec: spec,
      minusEnabled: widget.enabled && !_atMin,
      plusEnabled: widget.enabled && !_atMax,
      decreaseLabel: widget.decreaseLabel,
      increaseLabel: widget.increaseLabel,
      onMinus: () => _step(-1),
      onPlus: () => _step(1),
      onHoldMinus: () => _startHold(-1),
      onHoldPlus: () => _startHold(1),
      onRelease: _endHold,
    );

    final spoken = widget.value == null
        ? widget.notCountedLine
        : _isFinding
        ? 'Zero. ${widget.findingLine}'
        : '${numbers.format(widget.value)}'
              '${widget.unitWord == null ? '' : ' ${widget.unitWord}'}';

    // ONE node for the whole control — the label, the figure, the finding line
    // and the two step targets — carrying the adjustable role, so a screen
    // reader user steps it with a gesture and never hunts a 56dp tile. It
    // wraps the **shell**, not the control inside it: a node buried under the
    // label is a node nobody reaches by walking the form.
    return Semantics(
      container: true,
      slider: true,
      label: widget.label,
      value: spoken,
      increasedValue: widget.enabled && !_atMax
          ? '${_next(1)}${widget.unitWord == null ? '' : ' ${widget.unitWord}'}'
          : null,
      decreasedValue: widget.enabled && !_atMin
          ? '${_next(-1)}${widget.unitWord == null ? '' : ' ${widget.unitWord}'}'
          : null,
      onIncrease: widget.enabled && !_atMax ? () => _step(1) : null,
      onDecrease: widget.enabled && !_atMin ? () => _step(-1) : null,
      child: TorchFieldShell(
        label: widget.label,
        spec: spec,
        // A finding keeps the caller's help beneath its own line: "this raises
        // a task" says what happens, the help says why it matters, and the
        // spec's zero state carries both.
        help: _isFinding
            ? (widget.help == null
                  ? widget.findingLine
                  : '${widget.findingLine}\n${widget.help}')
            : widget.value == null
            ? (widget.help ?? widget.notCountedLine)
            : widget.help,
        trailing: _isFinding
            ? StatusChip(level: StatusLevel.critical, label: widget.findingWord)
            : null,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final pairExtent = tile * 2 + skin.depth.borderWidth;
            final troughRoom = width - pairExtent - TiqSpace.s2;
            // MEASURED, never a text-scale guess (unify §4). At 2.0× on a
            // 360dp phone the trough cannot hold a four-digit mono figure
            // beside a 113dp pair, so the pair drops beneath as two halves —
            // still adjacent, still one thumb.
            final stacked =
                width.isFinite &&
                troughRoom < CountStepper.stackedMinimumTroughWidth;

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  trough,
                  const SizedBox(height: TiqSpace.s2),
                  SizedBox(height: tile, child: pair),
                ],
              );
            }

            final children = <Widget>[
              Expanded(child: trough),
              const SizedBox(width: TiqSpace.s2),
              SizedBox(width: pairExtent, height: tile, child: pair),
            ];
            return Row(
              children: handedness.mirrored
                  ? children.reversed.toList()
                  : children,
            );
          },
        ),
      ),
    );
  }
}

/// The value, leading, in a trough. Tapping it opens the number sheet.
class _ValueTrough extends StatelessWidget {
  const _ValueTrough({
    required this.spec,
    required this.value,
    required this.ink,
    required this.onTap,
    required this.typeLabel,
    required this.missingLabel,
  });

  final TroughSpec spec;
  final int? value;
  final Color ink;
  final VoidCallback? onTap;
  final String typeLabel;
  final String missingLabel;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Semantics(
      button: onTap != null,
      label: typeLabel,
      excludeSemantics: true,
      child: TorchPressable(
        onPressed: onTap,
        pressScale: 1,
        borderRadius: spec.radius,
        builder: (context, pressed) => CustomPaint(
          foregroundPainter: TroughRulePainter(spec),
          child: Container(
            constraints: BoxConstraints(minHeight: spec.minHeight),
            decoration: spec.decoration().copyWith(
              color: pressed ? torchPressSurface(skin).fill : spec.fill,
            ),
            padding: EdgeInsets.symmetric(horizontal: spec.horizontalPadding),
            alignment: Alignment.centerLeft,
            // Aligned to the trough's leading padding so the figure sits under
            // the SKU name it belongs to, rather than floating in the middle of
            // a control.
            child: FigureSlot(
              value: value,
              role: skin.text.figureM,
              color: ink,
              semanticsLabel: value == null ? missingLabel : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// `[−][+]`, adjacent, with a 1px rule between them.
class _StepPair extends StatelessWidget {
  const _StepPair({
    required this.extent,
    required this.spec,
    required this.minusEnabled,
    required this.plusEnabled,
    required this.decreaseLabel,
    required this.increaseLabel,
    required this.onMinus,
    required this.onPlus,
    required this.onHoldMinus,
    required this.onHoldPlus,
    required this.onRelease,
  });

  final double extent;
  final TroughSpec spec;
  final bool minusEnabled;
  final bool plusEnabled;
  final String decreaseLabel;
  final String increaseLabel;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onHoldMinus;
  final VoidCallback onHoldPlus;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final border = skin.depth.borderWidth;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: skin.palette.well,
        borderRadius: BorderRadius.circular(skin.radii.control),
        border: Border.all(color: skin.palette.edgeControl, width: border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _StepTile(
              sign: -1,
              enabled: minusEnabled,
              semanticLabel: decreaseLabel,
              onPressed: onMinus,
              onHold: onHoldMinus,
              onRelease: onRelease,
            ),
          ),
          SizedBox(
            width: border,
            child: ColoredBox(color: skin.palette.edgeControl),
          ),
          Expanded(
            child: _StepTile(
              sign: 1,
              enabled: plusEnabled,
              semanticLabel: increaseLabel,
              onPressed: onPlus,
              onHold: onHoldPlus,
              onRelease: onRelease,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatefulWidget {
  const _StepTile({
    required this.sign,
    required this.enabled,
    required this.semanticLabel,
    required this.onPressed,
    required this.onHold,
    required this.onRelease,
  });

  final int sign;
  final bool enabled;
  final String semanticLabel;
  final VoidCallback onPressed;
  final VoidCallback onHold;
  final VoidCallback onRelease;

  @override
  State<_StepTile> createState() => _StepTileState();
}

class _StepTileState extends State<_StepTile> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final still = MotionBudget.of(context).still;
    final ink = widget.enabled ? skin.palette.ink1 : skin.palette.inkMute;
    final glyph = MarkScale.glyph(context, 20);

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled
            ? (_) {
                _set(true);
                widget.onHold();
              }
            : null,
        onTapUp: widget.enabled
            ? (_) {
                _set(false);
                widget.onRelease();
              }
            : null,
        onTapCancel: widget.enabled
            ? () {
                _set(false);
                widget.onRelease();
              }
            : null,
        onTap: widget.enabled ? widget.onPressed : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _pressed && widget.enabled
                ? torchPressSurface(skin).fill
                : null,
          ),
          child: Center(
            child: AnimatedScale(
              scale: (_pressed && widget.enabled && !still) ? 0.9 : 1,
              duration: skin.motion.resolve(TiqMotion.press),
              curve: TiqMotion.stateCurve,
              child: CustomPaint(
                size: Size.square(glyph),
                painter: _StepGlyphPainter(
                  sign: widget.sign,
                  color: ink,
                  strokeWidth: skin.depth.borderWidth >= 2 ? 3 : 2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A drawn minus and plus. Drawn rather than typeset because a font's glyphs
/// for `−` and `+` are optically different weights, and two step tiles that do
/// not match read as two different controls.
class _StepGlyphPainter extends CustomPainter {
  const _StepGlyphPainter({
    required this.sign,
    required this.color,
    required this.strokeWidth,
  });

  final int sign;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final arm = size.width / 2;
    canvas.drawLine(Offset(cx - arm, cy), Offset(cx + arm, cy), paint);
    if (sign > 0) {
      canvas.drawLine(Offset(cx, cy - arm), Offset(cx, cy + arm), paint);
    }
  }

  @override
  bool shouldRepaint(_StepGlyphPainter old) =>
      old.sign != sign || old.color != color || old.strokeWidth != strokeWidth;
}

/// THE NUMBER SHEET. One trough, `Cancel`, `Set`.
///
/// Its own sheet rather than an inline edit, and it pops the typed value
/// rather than writing it — so `Cancel` is genuinely free and a stray tap on
/// the value can never replace a count.
class _CountSheet extends StatefulWidget {
  const _CountSheet({
    required this.title,
    required this.fieldLabel,
    required this.blockedReason,
    required this.initial,
    required this.minimum,
    required this.maximum,
    required this.cancelLabel,
    required this.setLabel,
  });

  final String title;
  final String fieldLabel;
  final String blockedReason;
  final int? initial;
  final int minimum;
  final int maximum;
  final String cancelLabel;
  final String setLabel;

  @override
  State<_CountSheet> createState() => _CountSheetState();
}

class _CountSheetState extends State<_CountSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial?.toString() ?? '',
  );
  num? _typed;

  @override
  void initState() {
    super.initState();
    _typed = widget.initial;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final value = _typed;
    final valid =
        value != null && value >= widget.minimum && value <= widget.maximum;
    return TorchSheet(
      title: widget.title,
      claims: <TorchClaim>[TorchPrimaryButton.claim('count-set')],
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TorchNumericField(
            key: const ValueKey<String>('count-sheet-input'),
            label: widget.fieldLabel,
            controller: _controller,
            minimum: widget.minimum,
            maximum: widget.maximum,
            onChanged: (v) => setState(() => _typed = v),
          ),
          SizedBox(height: skin.space.blockGap),
          TorchPrimaryButton(
            key: const ValueKey<String>('count-sheet-set'),
            label: widget.setLabel,
            claimId: 'count-set',
            blockedReason: valid ? null : widget.blockedReason,
            onPressed: valid
                ? () => Navigator.of(context).pop(value.toInt())
                : null,
          ),
          const SizedBox(height: TiqSpace.s3),
          TorchSecondaryButton(
            key: const ValueKey<String>('count-sheet-cancel'),
            label: widget.cancelLabel,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
