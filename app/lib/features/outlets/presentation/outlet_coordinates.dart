import 'package:flutter/widgets.dart';

import '../../../core/design/tiq_number.dart';
import '../../../l10n/l10n.dart';

/// The keyboard a coordinate is typed on. Signed, decimal, and nothing else —
/// a pasted "-26.2041, 28.04" pair must not become a pin nobody meant.
const TextInputType coordinateKeyboard = TextInputType.numberWithOptions(
  signed: true,
  decimal: true,
);

/// Read back a typed coordinate **in the reader's own notation**.
///
/// An Afrikaans keyboard offers a comma where an English one offers a full
/// stop, and `-26,20410` is the very string this screen's help line and its
/// own refusal message print. Before this it went through `double.tryParse`,
/// which knows one notation: the screen told a manager what to type, she
/// typed it, and "Add the store" stayed dark while the refusal repeated the
/// comma back at her. The old field carried a digits-and-dot input filter, so
/// the comma was untypeable rather than rejected; the filter went when the
/// field did, and nothing took over the job.
///
/// [TiqNumber.parse] is the kit's answer and it already knows both: it drops
/// the locale's group separator and reads either decimal mark. The U+2212
/// minus is folded to ASCII first, because that is the minus [formatPosition]
/// prints two lines further up the same screen and therefore the one a
/// manager copies.
///
/// Empty is null — an untyped box is not a zero — and so is anything that is
/// not a number.
double? parseCoordinate(BuildContext context, String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  return TiqNumber.of(
    context,
  ).parse(text.replaceAll(minusSign, '-'))?.toDouble();
}

/// A typed coordinate, or the reason it is not one.
///
/// Shared by the create form and the repair screen so the two cannot drift: a
/// latitude refused on one screen and accepted on the other is how an outlet
/// ends up off the globe.
String? validateCoordinate(
  BuildContext context,
  AppLocalizations l10n,
  String? value, {
  required bool latitude,
}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return l10n.outletRequired;
  final parsed = parseCoordinate(context, text);
  if (parsed == null) return l10n.outletCoordinateNotANumber;
  final bound = latitude ? 90.0 : 180.0;
  if (parsed < -bound || parsed > bound) {
    return latitude
        ? l10n.outletLatitudeOutOfRange
        : l10n.outletLongitudeOutOfRange;
  }
  return null;
}

/// "-26,20410, 28,04730" — a position as a pair of figures, through the one
/// formatter.
///
/// Five places, always, because that is the precision the wire carries and a
/// coordinate that drops a trailing zero looks like a different coordinate.
/// It returns a `String` rather than a `FigureSlot` because every place it
/// appears is inside a translated sentence.
String formatPosition(BuildContext context, double lat, double lng) {
  final numbers = TiqNumber.of(context);
  return '${numbers.format(lat, decimals: 5)}, '
      '${numbers.format(lng, decimals: 5)}';
}

/// A coordinate out of a change-ledger payload, which is `dynamic` and may be
/// missing. An absent coordinate is said in words, never invented as a zero.
String formatLedgerCoordinate(BuildContext context, Object? value) =>
    value is num
    ? TiqNumber.of(context).format(value, decimals: 5)
    : context.l10n.outletChangeUnknownCoordinate;
