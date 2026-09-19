import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/evidence_thumb.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/format/person_label.dart';
import '../../users/data/users_repository.dart';
import '../../visits/data/visit_detail_repository.dart';
import '../data/alerts_view.dart';

/// EVERYTHING BEHIND ONE FIRED RULE, WITHOUT LEAVING THE WORKLIST.
///
/// A bottom sheet, because unify §1.7 deleted the dialog: one modal container,
/// one set of insets, one dismissal rule, one answer to what happens to the
/// amber underneath (it goes out — see [ConsoleFrame]).
///
/// Reading order, which is also the layout order: severity, message, rule,
/// evidence, person, flags, actions.
///
/// **Amber: none.** The nav is behind the scrim and inert while a modal route
/// owns the screen, and the sheet nominates nothing — its job is evidence, not
/// direction. The two controls are ghosts on purpose: acknowledging is not a
/// commit, it is a receipt, and a destructive action does not live here at all.
///
/// ## What is not here, and why
///
/// The spec asks for a six-point trend of the offending metric and a geotag
/// under the photograph. Neither is on the wire: `GET /alerts` carries no
/// series, `/trends/*` answers the territory rather than the metric behind one
/// rule, and `GET /visits/:id` returns a photo's `timestamp` and no location.
/// A fabricated shape and an invented place are both worse than their absence,
/// so the sheet omits them rather than drawing either.
Future<void> showAlertDetailSheet(
  BuildContext context, {
  required AlertRow alert,
  required Future<void> Function() onAcknowledge,
}) {
  return showTorchSheet<void>(
    context,
    builder: (sheetContext) =>
        _AlertDetailSheet(alert: alert, onAcknowledge: onAcknowledge),
  );
}

class _AlertDetailSheet extends ConsumerWidget {
  const _AlertDetailSheet({required this.alert, required this.onAcknowledge});

  final AlertRow alert;
  final Future<void> Function() onAcknowledge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = context.skin;
    final p = skin.palette;
    final kind = alert.severity == SoftRowSeverity.critical
        ? SeverityMarkKind.critical
        : SeverityMarkKind.watch;

    final directory = ref.watch(userDirectoryProvider);
    final visit = alert.visitId == null
        ? null
        : ref
              .watch(visitDetailProvider(alert.visitId!))
              .maybeWhen(data: (d) => d, orElse: () => null);

    return TorchSheet(
      semanticsLabel: '${alert.severityLabel}. ${alert.message}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 1. The severity, first — a mark, a word, and only then a hue.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SeverityMark(kind: kind),
              const SizedBox(width: 6),
              Text(
                alert.severityLabel,
                style: skin.text.label.style(color: p.ink1),
              ),
              if (alert.acknowledged) ...<Widget>[
                const SizedBox(width: 6),
                Text(
                  '· acknowledged',
                  style: skin.text.label.style(color: p.ink2),
                ),
              ],
            ],
          ),
          const SizedBox(height: TiqSpace.s3),

          // 2. The message.
          Semantics(
            header: true,
            child: Text(
              alert.message,
              style: skin.text.titleL.style(color: p.ink1),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: TiqSpace.s3),

          // 3. The rule, on a well block, in the identifier face — a manager
          //    can read it back into the rules screen character by character.
          _RuleBlock(rule: alert.rule, outlet: alert.outletName),

          // 4. The evidence. Absent entirely when there is none: no
          //    placeholder, because a placeholder is a claim that a photograph
          //    exists.
          if (alert.evidencePhotoId != null) ...<Widget>[
            const SizedBox(height: TiqSpace.s5),
            TorchEvidenceThumb(
              photoId: alert.evidencePhotoId!,
              aspectRatio: 16 / 9,
              semanticLabel:
                  'Shelf photograph from ${alert.outletName} for '
                  '${alert.message}',
            ),
            if (_captureTime(visit, alert.evidencePhotoId!) != null) ...<Widget>[
              const SizedBox(height: TiqSpace.s2),
              Text(
                _stamp(_captureTime(visit, alert.evidencePhotoId!)!),
                style: skin.text.monoIdent.style(color: p.ink3),
              ),
            ],
          ],

          // 5. Who submitted it. The visit carries the agent's id and sign-in
          //    address; the name comes from the roster. Named, the row reads
          //    name / role · outlet. Unnamed — no display name, or not on the
          //    roster yet — the sign-in address is the identifier line. Never
          //    a UUID, and never a name we made up.
          if (visit != null) ...<Widget>[
            const SizedBox(height: TiqSpace.s5),
            PersonRow(
              key: const ValueKey<String>('sheet-agent'),
              name: nonBlankName(directory[visit.agent.id]?.displayName),
              role: 'Field agent',
              outlet: visit.outlet.name,
              identifier: visit.agent.email,
              identifierLabel: 'Signed in as',
              separator: SoftRowSeparator.none,
            ),
          ],

          // 6. The flags. Facts, not verdicts, and every one of them tappable
          //    to its explanation would be better still — the map is not a
          //    console destination yet.
          if (visit != null && !visit.geofencePass) ...<Widget>[
            const SizedBox(height: TiqSpace.s3),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FlagChip(
                kind: FlagKind.outOfFence,
                detail: visit.distanceM == null
                    ? null
                    : '${visit.distanceM!.round()} m',
              ),
            ),
          ],

          // 7. Two stacked ghosts. Destructive actions do not live here.
          const SizedBox(height: TiqSpace.s6),
          if (alert.acknowledged)
            _AlreadyAcknowledged()
          else
            TorchSecondaryButton(
              key: const ValueKey<String>('sheet-acknowledge'),
              label: 'Acknowledge',
              onPressed: () {
                // Close first, then collapse the row behind it, so the manager
                // sees the list update rather than a sheet sitting over a
                // change they cannot see.
                Navigator.of(context).pop();
                onAcknowledge();
              },
            ),
          // A link with nowhere to go is dishonest chrome: an alert with no
          // visit gets no control at all, not a disabled one.
          if (alert.visitId != null) ...<Widget>[
            const SizedBox(height: TiqSpace.s3),
            TorchSecondaryButton(
              key: const ValueKey<String>('sheet-open-visit'),
              label: 'Open the visit',
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/visits/${alert.visitId}');
              },
            ),
          ],
        ],
      ),
    );
  }

  static DateTime? _captureTime(VisitDetail? visit, String photoId) => visit
      ?.photos
      .where((p) => p.id == photoId)
      .map((p) => p.timestamp)
      .firstOrNull;

  static String _stamp(DateTime t) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '${t.day} ${months[t.month - 1]} $hh:$mm';
  }
}

class _RuleBlock extends StatelessWidget {
  const _RuleBlock({required this.rule, required this.outlet});

  final String rule;
  final String outlet;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      decoration: BoxDecoration(
        color: skin.palette.well,
        borderRadius: BorderRadius.circular(skin.radii.chip),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: TiqSpace.s3,
        vertical: TiqSpace.s2,
      ),
      child: Text(
        '$rule · $outlet',
        style: skin.text.monoIdent.style(color: skin.palette.ink2),
      ),
    );
  }
}

/// Already acknowledged: the control becomes a stated fact, not a disabled
/// button that invites a press that will do nothing.
class _AlreadyAcknowledged extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SeverityMark(kind: SeverityMarkKind.held),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Acknowledged. It stays on the list until the rule stops firing.',
            style: skin.text.body.style(color: skin.palette.ink2),
          ),
        ),
      ],
    );
  }
}
