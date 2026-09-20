import 'package:flutter/widgets.dart';

import '../../../../l10n/l10n.dart';
import '../../../design/tiq_number.dart' show emDash;
import '../../../theme/torchlight/tiq_skin.dart';
import '../mark/tiq_mark.dart';
import '../row/row.dart';
import '../section_rule.dart';
import '../sheet.dart';
import '../state/empty_state.dart';
import 'field_shell.dart';
import 'trough.dart';

/// One choice a [TorchPickerField] offers.
@immutable
class PickerOption<T> {
  const PickerOption({
    required this.value,
    required this.label,
    this.detail,
    this.identifier,
  });

  final T value;

  /// What a person calls it — a territory's name, a store's name, a SKU's
  /// name. Never an id: unify §1.15's rule is the whole reason this component
  /// exists.
  final String label;

  /// A second line in the sheet: a scope, a channel, a price.
  final String? detail;

  /// The machine identifier, set in the identifier face beneath the label
  /// where a person genuinely quotes it — a store code on paperwork, a
  /// territory code on an import. It is never the primary line.
  final String? identifier;
}

/// THE PICKER — what replaces `DropdownButtonFormField`.
///
/// ```dart
/// TorchPickerField<String>(
///   label: l10n.outletFieldTerritory,
///   value: _territoryCode,
///   options: <PickerOption<String>>[
///     for (final t in territories)
///       PickerOption<String>(value: t.code, label: t.name, identifier: t.code),
///   ],
///   notChosenLine: l10n.outletTerritoryNotChosen,
///   onChanged: (code) => setState(() => _territoryCode = code),
/// )
/// ```
///
/// A Material dropdown is a menu that opens over the field, sizes itself to
/// its longest item, scrolls under a thumb and has no place to put a second
/// line. Unify §1.10 gives this product **one modal container**, so a choice
/// from a list too long for a [ChoiceRow]'s two-to-four options opens that
/// container: a sheet of [SoftRow]s, each one a 56dp target with room for the
/// name, the code and a detail line.
///
/// ## Nothing selected is a state, not a ghost
///
/// The trough holds the chosen label, or an em dash — never "Choose a
/// territory" set in the value's own slot pretending to be a value. What is
/// missing is said in words underneath, in the help line's place, exactly as
/// [ChoiceRow] says it.
///
/// ## It is operable by a screen reader
///
/// The field is one node: `button: true`, a label that reads "Territory,
/// Gauteng North", and **`onTap` on the node itself**. A `Semantics` that
/// excludes its descendants and forwards no action is a control a reader can
/// focus and cannot press — the defect the button family was repaired for, and
/// the reason this one declares the action rather than relying on the
/// `GestureDetector` beneath it.
///
/// **Amber: none.** It is a field. Selection is `lifted` plus a tick plus
/// weight, like every other selection in the system.
class TorchPickerField<T> extends StatelessWidget {
  const TorchPickerField({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.notChosenLine,
    this.help,
    this.error,
    this.enabled = true,
    this.disabledReason,
    this.sheetSubtitle,
    this.emptyHeadline,
    this.emptyBody,
  });

  final String label;
  final List<PickerOption<T>> options;
  final T? value;

  /// Null disables the field — a locked choice on an edit form, where the
  /// thing being edited is identified by it.
  final ValueChanged<T>? onChanged;

  /// What the help line says while nothing is chosen. It is a sentence in
  /// words, because an em dash on its own is not a reason.
  final String notChosenLine;

  final String? help;
  final String? error;
  final bool enabled;

  /// Shown in the help line's place while [enabled] is false, so a locked
  /// field says why rather than simply refusing.
  final String? disabledReason;

  final String? sheetSubtitle;

  /// What the sheet says when there is nothing to choose from. A picker with
  /// no options is a fact about the account, not a broken control.
  final String? emptyHeadline;
  final String? emptyBody;

  PickerOption<T>? get _selected {
    for (final option in options) {
      if (option.value == value) return option;
    }
    return null;
  }

  bool get _live => enabled && onChanged != null;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final selected = _selected;
    final state = !_live
        ? TroughState.disabled
        : error != null
        ? TroughState.error
        : selected == null
        ? TroughState.empty
        : TroughState.filled;
    final spec = TroughSpec.resolve(skin: skin, state: state);

    final valueWord = selected?.label ?? emDash;

    final trough = DecoratedBox(
      decoration: spec.decoration(),
      child: CustomPaint(
        foregroundPainter: TroughRulePainter(spec),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: spec.minHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spec.horizontalPadding,
              vertical: spec.verticalPadding,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    valueWord,
                    style: skin.text.body.style(
                      color: selected == null ? spec.hintInk : spec.ink,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: TiqSpace.s3),
                SoftRowChevron(
                  color: _live ? skin.palette.ink2 : skin.palette.inkMute,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final field = TorchFieldShell(
      label: label,
      spec: spec,
      help: !_live
          ? (disabledReason ?? help)
          : selected == null
          ? notChosenLine
          : help,
      error: error,
      child: trough,
    );

    return Semantics(
      button: _live,
      enabled: _live,
      label: '$label. $valueWord',
      // The node carries the action. Without this a reader announces the
      // picker and cannot open it.
      onTap: _live ? () => _open(context) : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _live ? () => _open(context) : null,
        child: field,
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final chosen = await showTorchSheet<T>(
      context,
      builder: (sheetContext) => TorchSheet(
        title: label,
        subtitle: sheetSubtitle,
        child: options.isEmpty
            ? EmptyState(
                scope: EmptyScope.inPanel,
                headline: emptyHeadline ?? notChosenLine,
                body: emptyBody,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (var i = 0; i < options.length; i++)
                    _OptionRow<T>(
                      option: options[i],
                      selected: options[i].value == value,
                      last: i == options.length - 1,
                      onTap: () =>
                          Navigator.of(sheetContext).pop(options[i].value),
                    ),
                ],
              ),
      ),
    );
    if (chosen != null) onChanged?.call(chosen);
  }
}

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.selected,
    required this.last,
    required this.onTap,
  });

  final PickerOption<T> option;
  final bool selected;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final identifier = option.identifier;

    return SoftRow(
      key: ValueKey<String>('picker-option-${option.value}'),
      density: identifier == null && option.detail == null
          ? SoftRowDensity.compact
          : SoftRowDensity.standard,
      title: option.label,
      titleTruncation: SoftRowTruncation.middle,
      subtitle: option.detail,
      meta: identifier == null
          ? null
          : Text(
              identifier,
              style: skin.text.monoIdent.style(color: skin.palette.ink3),
            ),
      // Selection is a mark plus a fill plus a weight everywhere in this
      // system; in a list of rows the mark is what a row has room for, and the
      // row's own semantics label carries the word.
      //
      // It has to carry it **by name**. `TiqMark` has no semantics node of its
      // own, the row has no `actions` and no `trailingIsControl`, so the row
      // drops every descendant node and speaks its title and detail only: the
      // tick was the single channel, which is both silence to a reader and
      // colour-as-the-only-signal. A manager reopening the territory picker
      // could not tell which territory was already set without leaving the
      // sheet to read the trough — and on a locked edit sheet, not at all.
      //
      // The word goes first, as severity does on every other row: a listener
      // walking nine options should not have to hold each name in mind until
      // its last syllable.
      semanticsLabel: <String?>[
        if (selected) context.l10n.pickerSelected,
        option.label,
        option.detail,
      ].whereType<String>().where((s) => s.isNotEmpty).join('. '),
      trailing: selected
          ? TiqMark(
              shape: MarkShape.sectionTickDisc,
              color: skin.palette.ink1,
              size: MarkScale.glyph(context, 16),
            )
          : null,
      onTap: onTap,
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
    );
  }
}

/// A section rule inside a picker sheet, for a sheet that groups its options.
///
/// Exported so a caller does not have to reach past the barrel for the one
/// thing a grouped picker needs.
typedef PickerGroupRule = SectionRule;
