import 'package:flutter/widgets.dart';

import '../../../core/design/tiq_number.dart';
import '../../../l10n/l10n.dart';

/// The keyboard a coordinate is typed on. Signed, decimal, and nothing else —
/// a pasted "-26.2041, 28.04" pair must not become a pin nobody meant.
const TextInputType coordinateKeyboard = TextInputType.numberWithOptions(
  signed: true,
  decimal: true,
);

/// A typed coordinate, or the reason it is not one.
///
/// Shared by the create form and the repair screen so the two cannot drift: a
/// latitude refused on one screen and accepted on the other is how an outlet
/// ends up off the globe.
String? validateCoordinate(
  AppLocalizations l10n,
  String? value, {
  required bool latitude,
}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return l10n.outletRequired;
  final parsed = double.tryParse(text);
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
