import 'package:flutter/material.dart'
    show
        InputDecoration,
        InputDecorationTheme,
        Material,
        MaterialType,
        TextField,
        TextSelectionThemeData,
        Theme;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';
import 'field_shell.dart';
import 'trough.dart';

/// FREE TEXT IN A TROUGH — a note, an outlet search, a skip reason.
///
/// Replaces every `TextField` decoration in the app.
///
/// ```dart
/// TorchTextField(
///   label: 'What happened?',
///   controller: _note,
///   hint: 'e.g. the fridge was off',
///   maximumLength: 200,
///   minLines: 3,
///   maximumLines: 8,
/// )
/// ```
///
/// The geometry, the states and the reason the focus rule is ink rather than
/// amber are all on [TroughSpec]. What this widget adds is the wiring: the
/// label is the semantic label (not a hint), the error is a live region, the
/// counter appears at 80% of the cap, and a multi-line field grows from its
/// `minLines` to `maximumLines` and then scrolls inside itself with the bottom
/// rule staying put.
class TorchTextField extends StatefulWidget {
  const TorchTextField({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.hint,
    this.help,
    this.error,
    this.enabled = true,
    this.readOnly = false,
    this.maximumLength,
    this.minLines = 1,
    this.maximumLines = 1,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.autocorrect = true,
    this.identifier = false,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.obscureText = false,
    this.autofillHints,
  }) : assert(
         maximumLines >= minLines,
         'A field cannot grow to fewer lines than it starts at.',
       ),
       assert(
         !obscureText || maximumLines == 1,
         'A hidden field is one line: a multi-line secret has nowhere to put '
         'the line breaks it hides.',
       );

  /// Sentence case, and the semantic label. Never a floating placeholder.
  final String label;

  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// Restates the unit or the format — "e.g. 12 facings". **Never** a repeat
  /// of the label, and never a value.
  final String? hint;

  /// One meta line beneath. Also where a disabled field says why.
  final String? help;

  /// Replaces [help], with a triangle and a 2px bottom rule in `bad`. The
  /// entered value is kept.
  final String? error;

  final bool enabled;

  /// Reviewing a submitted visit: no rule, no outline, no fill, ink-1.
  final bool readOnly;

  /// A counter appears at 80% of this and the value is never silently cut.
  final int? maximumLength;

  final int minLines;
  final int maximumLines;

  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  /// Off automatically when [identifier] is true.
  final bool autocorrect;

  /// An outlet code, a GTIN, a batch number. Renders in `mono.ident`, turns
  /// autocorrect and capitalisation off, and never gets a spell-check
  /// underline under a barcode.
  final bool identifier;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  /// A password. The characters are hidden, and autocorrect and suggestions
  /// are off — a keyboard that learns a password offers it back to the next
  /// person who borrows the phone.
  final bool obscureText;

  /// Lets a password manager fill the field, e.g. [AutofillHints.password].
  final Iterable<String>? autofillHints;

  @override
  State<TorchTextField> createState() => _TorchTextFieldState();
}

class _TorchTextFieldState extends State<TorchTextField> {
  TextEditingController? _owned;
  FocusNode? _ownedFocus;

  TextEditingController get _controller =>
      widget.controller ?? (_owned ??= TextEditingController());
  FocusNode get _focus => widget.focusNode ?? (_ownedFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
    _controller.addListener(_onTextChange);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _controller.removeListener(_onTextChange);
    _owned?.dispose();
    _ownedFocus?.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  void _onTextChange() {
    if (mounted) setState(() {});
  }

  TroughState get _state {
    if (widget.readOnly) return TroughState.readOnly;
    if (!widget.enabled) return TroughState.disabled;
    if (widget.error != null) return TroughState.error;
    if (_focus.hasFocus) return TroughState.focused;
    return _controller.text.isEmpty ? TroughState.empty : TroughState.filled;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final spec = TroughSpec.resolve(skin: skin, state: _state);
    final role = widget.identifier ? skin.text.monoIdent : skin.text.body;
    final length = _controller.text.characters.length;
    final cap = widget.maximumLength;

    // `TextField` with a COLLAPSED decoration. The widget is Flutter's — the
    // selection handles, the caret, the IME and the toolbar are a year of work
    // nobody should rewrite — and every pixel of the decoration is this
    // system's. That is exactly what "replaces TextField *decoration*" means.
    // `Material` at `transparency`, which paints **nothing**: no ink, no
    // elevation, no colour, no shape. `TextField` asks for a Material ancestor
    // for its splash machinery and refuses to build without one; this is the
    // form of that ancestor which cannot contribute a pixel, so the trough
    // stays the only thing drawing the field.
    final field = Material(
      type: MaterialType.transparency,
      child: Theme(
        data: Theme.of(context).copyWith(
          // An EMPTY decoration theme. The app theme's input decoration carries
          // a flame-700 focused underline for the Material forms, and a
          // collapsed decoration inherits `focusedBorder` from it — which painted
          // an unclaimed amber line under every focused trough, a second lit
          // object in Day and Veld. The trough draws the only rule.
          inputDecorationTheme: const InputDecorationTheme(),
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: spec.ink,
            selectionColor: skin.palette.lifted,
            selectionHandleColor: spec.ink,
          ),
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focus,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          style: role.style(color: spec.ink),
          cursorColor: spec.ink,
          cursorWidth: 2,
          minLines: widget.minLines,
          maxLines: widget.maximumLines,
          keyboardType:
              widget.keyboardType ??
              (widget.maximumLines > 1
                  ? TextInputType.multiline
                  : TextInputType.text),
          textCapitalization: widget.identifier
              ? TextCapitalization.characters
              : widget.textCapitalization,
          // An outlet code is not a sentence and must never be autocorrected
          // into one; a GTIN "0736" becoming "736" is a record nobody can find
          // again.
          autocorrect: widget.identifier || widget.obscureText
              ? false
              : widget.autocorrect,
          enableSuggestions: !widget.identifier && !widget.obscureText,
          obscureText: widget.obscureText,
          autofillHints: widget.autofillHints,
          textInputAction: widget.textInputAction,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          inputFormatters: cap == null
              ? null
              : <TextInputFormatter>[LengthLimitingTextInputFormatter(cap)],
          // A trough scrolls the focused field into view above the keyboard with
          // a gutter of margin — the sheet itself never resizes under a thumb.
          scrollPadding: EdgeInsets.all(skin.space.gutter),
          decoration: InputDecoration.collapsed(
            hintText: widget.hint,
            hintStyle: role.style(color: spec.hintInk),
          ),
        ),
      ),
    );

    final trough = CustomPaint(
      foregroundPainter: TroughRulePainter(spec),
      child: Container(
        constraints: BoxConstraints(minHeight: spec.minHeight),
        decoration: spec.decoration(),
        padding: EdgeInsets.symmetric(
          horizontal: spec.horizontalPadding,
          vertical: spec.verticalPadding,
        ),
        alignment: widget.maximumLines > 1
            ? Alignment.topLeft
            : Alignment.centerLeft,
        child: field,
      ),
    );

    return TorchFieldShell(
      label: widget.label,
      spec: spec,
      help: widget.help,
      error: widget.error,
      counter: cap != null && TorchFieldCounter.visible(length, cap)
          ? TorchFieldCounter(length: length, maximum: cap, spec: spec)
          : null,
      // THE VISIBLE LABEL IS THE SEMANTIC LABEL. Not a `hint`, which
      // disappears the moment there is a value, and not a second node —
      // `container: true` makes the label the field's parent, so a reader
      // hears "Units on shelf" and then edits the field, once.
      child: Semantics(
        container: true,
        label: widget.label,
        textField: true,
        child: trough,
      ),
    );
  }
}
