import 'package:flutter/widgets.dart';

import '../../../../core/theme/torchlight/tiq_skin.dart';
import '../../../../core/widgets/torchlight/marks.dart';
import '../../../../core/widgets/torchlight/row/row.dart';
import '../../../../l10n/l10n.dart';
import 'section_form.dart';

/// S1 — OUTLET INFORMATION. A read-only confirmation of the check-in the agent
/// already completed.
///
/// There is nothing to capture here — the timestamp and the geofence result
/// come from check-in — so the section states them plainly and never presents
/// them as agent input. No Save, rather than a disabled one: a section with
/// nothing to commit does not offer to commit it.
///
/// **Amber: none, in any skin.** Nothing here is armed.
class S1OutletInfoScreen extends StatelessWidget {
  const S1OutletInfoScreen({super.key, this.checkinTs});

  final DateTime? checkinTs;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final ts = checkinTs;

    return SectionForm(
      title: l10n.visitSectionOutletInfo,
      phase: 'outlet-info',
      // Honesty: this is confirmed at check-in, not something the agent fills
      // in here.
      intro: l10n.s1ConfirmedAtCheckin,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SoftRow(
              title: l10n.s1CheckedIn,
              trailing: Text(
                // An absent check-in reads as such — never a fabricated time.
                ts == null ? l10n.s1NotRecorded : formatCheckinTs(ts),
                // Keyed: the shell's timestamp-stability test reads this value
                // across a leave-and-return to prove it is stamped once, not
                // re-derived on rebuild.
                key: const ValueKey<String>('checkin-timestamp'),
                style: ts == null
                    ? skin.text.body.style(color: skin.palette.ink3)
                    : skin.text.figureS.style(color: skin.palette.ink1),
              ),
              semanticsLabel:
                  '${l10n.s1CheckedIn}. '
                  '${ts == null ? l10n.s1NotRecorded : formatCheckinTs(ts)}',
            ),
            SoftRow(
              title: l10n.s1Geofence,
              // A tick and the word — the pass survives greyscale and a screen
              // reader, and it is never carried by a hue on its own.
              leading: const SectionStateGlyph(state: SectionState.done),
              trailing: Text(
                l10n.s1Passed,
                style: skin.text.bodyStrong.style(color: skin.palette.ink1),
              ),
              separator: SoftRowSeparator.none,
              semanticsLabel: '${l10n.s1Geofence}. ${l10n.s1Passed}',
            ),
          ],
        ),
      ],
    );
  }
}

/// The check-in stamp, as a sortable date and a 24-hour clock.
String formatCheckinTs(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} '
      '${two(t.hour)}:${two(t.minute)}';
}
