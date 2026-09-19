import 'package:flutter/material.dart'
    show
        InputDecoration,
        Material,
        MaterialType,
        TextField,
        TextSelectionThemeData,
        Theme;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../design/tiq_number.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import '../button/torch_press.dart';
import '../mark/status_chip.dart';
import 'field_shell.dart';
import 'trough.dart';

/// Whether a numeric trough's value fits, and what to do when it does not.
///
/// THE OVERFLOW ANCHOR IS THE WHOLE POINT. A right-aligned mono value that is
/// wider than its trough scrolls to show the **trailing** characters, which is
/// what a text field does and what every price field in this app used to do:
/// `R 1 234 567,89` in a 92dp trough displayed `4 567,89`, and a manager read
/// it back and confirmed a wrong number. A figure is never partially displayed
/// without a mark that it is partial, and the half that must survive is the
/// half that carries the magnitude.
@immutable
class NumericOverflow {
  const NumericOverflow({
    required this.overflows,
    required this.textWidth,
    required this.available,
  });

  final bool overflows;
  final double textWidth;
  final double available;

  /// Right-aligned while it fits — a column of prices aligns on its decimal.
  /// Left-aligned the moment it does not, which anchors the **leading** digits
  /// and lets the trailing ones scroll out under the fade.
  TextAlign get align => overflows ? TextAlign.left : TextAlign.right;

  /// The width of the ground-to-transparent fade marking the trailing edge as
  /// partial. Zero when the value fits.
  double get fadeWidth => overflows ? 12 : 0;

  /// Pure, so the rule can be argued about in a unit test rather than in a
  /// screenshot.
  static NumericOverflow measure({
    required String text,
    required TextStyle style,
    required TextScaler scaler,
    required TextDirection direction,
    required double available,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return NumericOverflow(
      overflows: width > available,
      textWidth: width,
      available: available,
    );
  }
}

/// A TYPED FIGURE — a price, a large count, a percentage.
///
/// The text field's trough with four differences, all of them about the fact
/// that this holds a **number**:
///
/// * the value is JetBrains Mono `figure.m` 22/600 tabular and right-aligned,
///   because a column of prices has to align on the decimal;
/// * a unit or currency affix sits inside the trough in `label` ink-3, outside
///   the editable area;
/// * the keyboard's decimal separator follows the locale — an Afrikaans user
///   gets a comma, and `1.5` typed in an Afrikaans locale is accepted and
///   normalised on blur rather than refused;
/// * overflow anchors the leading digits. See [NumericOverflow].
///
/// ## Unknown, zero, and zero-as-a-finding
///
/// Three different facts and three different renders (unify §4). `null` is an
/// em dash in ink-3 with a sentence beside it — *not counted* and
/// *counted as none* are not the same thing, and a null that renders as `0`
/// accuses a store. A measured zero renders `0` in ink-1 and is never
/// suppressed. A zero that raises a task takes the **whole control**: the
/// trough goes to the finding wash with a 2px `bad` outline, the figure goes
/// to `bad`, a status chip appears beneath it, and the phone buzzes
/// [TorchBuzz.finding] on landing there.
class TorchNumericField extends StatefulWidget {
  const TorchNumericField({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.unit = TiqUnit.none,
    this.decimals = 0,
    this.help,
    this.error,
    this.enabled = true,
    this.readOnly = false,
    this.zeroIsFinding = false,
    this.findingWord = 'Out of stock',
    this.notCountedLine = 'Not counted',
    this.onChanged,
    this.minimum,
    this.maximum,
  });

  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// Rendered inside the trough, trailing (or leading for a currency), in
  /// `label` ink-3 and outside the editable run.
  final TiqUnit unit;

  /// How many decimal places the formatter keeps on blur.
  final int decimals;

  final String? help;
  final String? error;
  final bool enabled;
  final bool readOnly;

  /// A stock count where none is a finding, not an empty box.
  final bool zeroIsFinding;

  /// The word on the chip beneath a finding. Localised by the caller.
  final String findingWord;

  /// The sentence beside an em dash, so a bare dash is never the whole
  /// message.
  final String notCountedLine;

  final ValueChanged<num?>? onChanged;

  /// Out of range is a message, never a silent clamp.
  final num? minimum;
  final num? maximum;

  @override
  State<TorchNumericField> createState() => _TorchNumericFieldState();
}

class _TorchNumericFieldState extends State<TorchNumericField> {
  TextEditingController? _owned;
  FocusNode? _ownedFocus;
  bool _wasFinding = false;

  TextEditingController get _controller =>
      widget.controller ?? (_owned ??= TextEditingController());
  FocusNode get _focus => widget.focusNode ?? (_ownedFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onChange);
    _controller.addListener(_onChange);
  }

  @override
  void dispose() {
    _focus.removeListener(_onChange);
    _controller.removeListener(_onChange);
    _owned?.dispose();
    _ownedFocus?.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  /// Parse against the ambient locale, and accept the *other* locale's
  /// separator rather than refusing it. An agent who types `1.5` on an
  /// Afrikaans phone has typed one and a half, and telling them otherwise is
  /// the app being right about a rule nobody agreed to.
  num? _parse(String raw, TiqNumberSymbols symbols) =>
      TiqNumber(symbols).parse(raw);

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final numbers = TiqNumber.of(context);
    final raw = _controller.text;
    final value = _parse(raw, numbers.symbols);
    final isFinding =
        widget.zeroIsFinding && value != null && value == 0 && !widget.readOnly;

    // The finding haptic fires on LANDING there, once, not on every rebuild —
    // an agent counting a bay does not need twelve heavy buzzes because the
    // list scrolled.
    if (isFinding && !_wasFinding) {
      _wasFinding = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) TorchBuzz.finding();
      });
    } else if (!isFinding && _wasFinding) {
      _wasFinding = false;
    }

    final outOfRange =
        value != null &&
        ((widget.minimum != null && value < widget.minimum!) ||
            (widget.maximum != null && value > widget.maximum!));

    final state = widget.readOnly
        ? TroughState.readOnly
        : !widget.enabled
        ? TroughState.disabled
        : (widget.error != null || outOfRange)
        ? TroughState.error
        : isFinding
        ? TroughState.finding
        : _focus.hasFocus
        ? TroughState.focused
        : raw.isEmpty
        ? TroughState.empty
        : TroughState.filled;

    final spec = TroughSpec.resolve(skin: skin, state: state, numeric: true);
    final role = skin.text.figureM;
    final ink = isFinding ? skin.palette.bad : spec.ink;
    final style = role.style(color: ink);
    final scaler = MediaQuery.textScalerOf(context);

    final suffix = widget.unit.suffix;
    final affix = suffix.isEmpty
        ? null
        : Text(suffix, style: spec.affixStyle.style(color: spec.affixInk));

    final displayed = raw.isEmpty ? emDash : raw;

    final errorText =
        widget.error ??
        (outOfRange
            ? 'Between ${numbers.format(widget.minimum ?? 0)} and '
                  '${numbers.format(widget.maximum ?? 0)}'
            : null);

    return TorchFieldShell(
      label: widget.label,
      spec: spec,
      help: raw.isEmpty && errorText == null
          ? (widget.help ?? widget.notCountedLine)
          : widget.help,
      error: errorText,
      trailing: isFinding
          ? StatusChip(level: StatusLevel.critical, label: widget.findingWord)
          : null,
      child: Semantics(
        container: true,
        label: widget.label,
        textField: true,
        // Spoken as a number with its unit, never as digits; the em dash
        // announces as the sentence rather than as a punctuation mark.
        value: raw.isEmpty
            ? widget.notCountedLine
            : isFinding
            ? 'Zero, ${widget.findingWord.toLowerCase()}, a finding'
            : '$raw$suffix',
        child: LayoutBuilder(
          builder: (context, constraints) {
            final inner =
                constraints.maxWidth -
                spec.horizontalPadding * 2 -
                spec.outlineWidth * 2 -
                (affix == null ? 0 : 44);
            final overflow = NumericOverflow.measure(
              text: displayed,
              style: style,
              scaler: scaler,
              direction: Directionality.of(context),
              available: inner.isFinite && inner > 0 ? inner : 0,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CustomPaint(
                  foregroundPainter: TroughRulePainter(spec),
                  child: Container(
                    constraints: BoxConstraints(
                      minHeight: spec.minHeight,
                      minWidth: spec.minNumericWidth,
                    ),
                    decoration: spec.decoration(),
                    padding: EdgeInsets.symmetric(
                      horizontal: spec.horizontalPadding,
                      vertical: spec.verticalPadding,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: _Editable(
                            controller: _controller,
                            focus: _focus,
                            style: style,
                            align: overflow.align,
                            enabled: widget.enabled,
                            readOnly: widget.readOnly,
                            decimalSeparator: numbers.symbols.decimal,
                            hintInk: spec.hintInk,
                            selectionFill: skin.palette.lifted,
                            onChanged: (text) => widget.onChanged?.call(
                              _parse(text, numbers.symbols),
                            ),
                          ),
                        ),
                        if (affix != null) ...<Widget>[
                          const SizedBox(width: TiqSpace.s2),
                          ExcludeSemantics(child: affix),
                        ],
                      ],
                    ),
                  ),
                ),
                // WHILE IT HOLDS FOCUS AND OVERFLOWS, the full value renders
                // beneath at figure.s. The trough shows part of a number; this
                // line shows all of it, and the reader is told which is which.
                if (overflow.overflows && _focus.hasFocus)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '$displayed$suffix',
                      style: skin.text.figureS.style(color: skin.palette.ink2),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Editable extends StatelessWidget {
  const _Editable({
    required this.controller,
    required this.focus,
    required this.style,
    required this.align,
    required this.enabled,
    required this.readOnly,
    required this.decimalSeparator,
    required this.hintInk,
    required this.selectionFill,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final TextStyle style;
  final TextAlign align;
  final bool enabled;
  final bool readOnly;
  final String decimalSeparator;
  final Color hintInk;
  final Color selectionFill;
  final ValueChanged<String> onChanged;

  @override
  // `Material` at `transparency` paints nothing; `TextField` simply refuses to
  // build without a Material ancestor. See the note in `text_field.dart`.
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: style.color,
          selectionColor: selectionFill,
          selectionHandleColor: style.color,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focus,
        enabled: enabled,
        readOnly: readOnly,
        style: style,
        textAlign: align,
        cursorColor: style.color,
        maxLines: 1,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: <TextInputFormatter>[
          // Digits, a true minus, and BOTH separators — the locale decides how a
          // value is written back, never what a thumb is allowed to type.
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\- ]')),
        ],
        onChanged: onChanged,
        decoration: InputDecoration.collapsed(
          // An EMPTY numeric trough shows an em dash, not a zero and not a
          // ghosted example: not counted and counted-as-none are different facts
          // and this is where they diverge.
          hintText: emDash,
          hintStyle: style.copyWith(color: hintInk),
        ),
      ),
    ),
  );
}
