import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../l10n/l10n.dart';
import '../data/agent_map.dart';
import 'agent_map_screen.dart' show MapDistanceFigure, mapStateWord;
import 'outlet_map.dart' show MapPinGlyph;

/// WHAT YOU CAN DO AT THIS STORE.
///
/// Opened by a marker and by its row — the same object, the same sheet. That
/// is not symmetry for its own sake: in Veld there is no map to tap, and a
/// sheet reachable only from a marker would be a feature that disappears
/// outdoors.
///
/// ## The amber
///
/// A sheet is an untabbed surface, and while it is up every amber on the route
/// beneath goes out (unify §1.10) — the nav's active tab included. So the
/// screen's one lit object is **Check in here**, which is the one thing the
/// agent opened this sheet to do.
///
/// A store already visited today gets `Check in again` as a **ghost**, not a
/// primary: going back is allowed, and it is not what anybody expects. That
/// leaves such a sheet with no amber at all, which is the honest count for a
/// screen where nothing is armed.
const String outletSheetCheckInClaimId = 'map-sheet-check-in';

/// Opens [pin]'s sheet. A bottom sheet in Night and Day, a full-screen route
/// with a 56dp close row in Veld — [TorchSheet] owns that difference.
Future<void> showOutletSheet(BuildContext context, MapOutlet pin) {
  return showTorchSheet<void>(
    context,
    builder: (context) => OutletSheet(pin: pin),
  );
}

/// The sheet's content. Public so a test can pump it without a navigator.
class OutletSheet extends StatelessWidget {
  const OutletSheet({super.key, required this.pin});

  final MapOutlet pin;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final done = pin.state == MapPinState.doneToday;

    return TorchSheet(
      title: pin.outlet.name,
      subtitle: pin.outlet.code,
      closeLabel: l10n.sheetClose,
      claims: done
          ? const <TorchClaim>[]
          : const <TorchClaim>[
              TorchClaim.primaryCommit(outletSheetCheckInClaimId),
            ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // The facts, in the row grammar the rest of the agent app is built
          // from: the silhouette the marker wore, the state in words, and the
          // distance as a figure — or no distance at all, when the phone will
          // not say where it is.
          SoftRow(
            key: const ValueKey<String>('map-sheet-facts'),
            form: SoftRowForm.standalone,
            title: mapStateWord(l10n, pin.state),
            leading: MapPinGlyph(pin: pin),
            trailing: MapDistanceFigure(
              distance: pin.distance,
              role: skin.text.figureS,
            ),
            separator: SoftRowSeparator.none,
          ),

          if (pin.disputed) ...<Widget>[
            SizedBox(height: skin.space.intraBlock),
            Text(
              l10n.mapDisputedLine,
              style: skin.text.body.style(color: skin.palette.ink2),
            ),
          ],

          if (done) ...<Widget>[
            SizedBox(height: skin.space.intraBlock),
            Text(
              l10n.mapVisitedTodayLine,
              style: skin.text.body.style(color: skin.palette.ink2),
            ),
            SizedBox(height: skin.space.blockGap),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TorchSecondaryButton(
                key: const ValueKey<String>('map-sheet-check-in-again'),
                label: l10n.mapCheckInAgain,
                onPressed: () => _checkIn(context),
              ),
            ),
          ] else ...<Widget>[
            SizedBox(height: skin.space.blockGap),
            TorchPrimaryButton(
              key: const ValueKey<String>('map-sheet-check-in'),
              claimId: outletSheetCheckInClaimId,
              label: l10n.todayCheckInHere,
              onPressed: () => _checkIn(context),
            ),
          ],
        ],
      ),
    );
  }

  /// Close the sheet first, then go. A sheet left on the stack over a check-in
  /// screen is a modal the back gesture would drop the agent back into.
  void _checkIn(BuildContext context) {
    final router = GoRouter.of(context);
    Navigator.of(context).maybePop();
    router.go('/audit/${pin.outlet.id}');
  }
}
