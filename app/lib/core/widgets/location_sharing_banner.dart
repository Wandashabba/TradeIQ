import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../location/location_sharing.dart';
import '../theme/torchlight/tiq_skin.dart';
import 'torchlight/button/buttons.dart';
import 'torchlight/marks.dart';
import 'torchlight/row/row.dart';
import 'torchlight/sheet.dart';

/// Location sharing, told to the agent in words (#153 T1, POPIA risk 1).
///
/// Three faces, and nothing at all for anyone who is not a field agent or
/// before the settings are known:
///
/// - **The notice**, until the agent answers it: what is shared, with whom,
///   when, and when it stops — with a clear yes and a clear no. No ping is sent
///   before a yes.
/// - **The indicator**, on every agent screen for as long as sharing is on. It
///   is not dismissible, because "am I being located right now?" must always
///   have a visible answer. Tapping it offers to stop.
/// - **A quiet "not shared" line** after a no, so the agent can change their
///   mind without hunting for a setting.
///
/// ## Torchlight, and not one word changed
///
/// This is a **restyle**. Every sentence, every key and every branch is the
/// one that was here: POPIA copy is not the kind of thing a design migration
/// gets to improve, and a consent notice whose wording drifts is a consent
/// notice nobody can point at afterwards.
///
/// What did change is what it is built out of. The two faces that are a
/// standing statement are standalone soft rows; the notice is the panel
/// material; the buttons are the button family; and the stop confirmation is a
/// [ConfirmSheet] rather than an `AlertDialog`, because unify §1.7 deleted the
/// dialog outright — one modal container, one set of insets, one answer to
/// what happens to the amber underneath.
///
/// **Amber:** the notice's yes is a genuine commit and asks `TorchScope` for
/// the light like every other primary. On the un-migrated screens this banner
/// still appears on there is no scope to ask, so it renders its ink form — it
/// can never light itself on a screen that did not count it.
class LocationSharingBanner extends ConsumerWidget {
  const LocationSharingBanner({super.key});

  /// The notice's "I understand, share my location".
  static const String consentClaimId = 'location-consent';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(locationSharingControllerProvider);
    final settings = s.settings;
    if (!s.isAgent || settings == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final skin = context.skin;
    final controller = ref.read(locationSharingControllerProvider.notifier);

    final Widget child;
    if (s.needsNotice || s.reconsidering) {
      child = _LocationNotice(
        minutes: (settings.intervalSeconds / 60).round().clamp(1, 60),
        onAcknowledge: controller.acknowledge,
        onDecline: s.reconsidering
            ? controller.cancelReconsider
            : controller.decline,
      );
    } else if (s.acknowledged) {
      child = SoftRow(
        key: const ValueKey<String>('location-sharing-indicator'),
        form: SoftRowForm.standalone,
        title: l10n.locationSharingActiveTitle,
        subtitle: s.noFix
            ? l10n.locationSharingNoFixSubtitle
            : l10n.locationSharingActiveSubtitle,
        leading: Icon(
          Icons.my_location,
          size: MarkScale.glyph(context, 20),
          color: skin.palette.ink2,
        ),
        trailing: const SoftRowChevron(),
        onTap: () => _confirmStop(context, controller),
      );
    } else {
      child = SoftRow(
        key: const ValueKey<String>('location-sharing-off'),
        form: SoftRowForm.standalone,
        title: l10n.locationSharingOffTitle,
        subtitle: l10n.locationSharingOffSubtitle,
        leading: Icon(
          Icons.location_disabled,
          size: MarkScale.glyph(context, 20),
          color: skin.palette.ink3,
        ),
        trailing: const SoftRowChevron(),
        onTap: controller.reconsider,
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(
        skin.space.gutter,
        TiqSpace.s3,
        skin.space.gutter,
        0,
      ),
      child: child,
    );
  }

  static Future<void> _confirmStop(
    BuildContext context,
    LocationSharingController controller,
  ) async {
    final l10n = context.l10n;
    final stop = await showTorchSheet<bool>(
      context,
      builder: (context) => ConfirmSheet(
        key: const ValueKey<String>('location-stop-dialog'),
        action: l10n.locationStopTitle,
        consequences: <String>[l10n.locationStopBody],
        commitLabel: l10n.locationStopConfirm,
        cancelLabel: l10n.locationStopCancel,
      ),
    );
    if (stop == true) await controller.decline();
  }
}

/// What is shared, with whom, how often, and when it stops — with a clear yes
/// and a clear no, and no ping sent before the yes.
class _LocationNotice extends StatelessWidget {
  const _LocationNotice({
    required this.minutes,
    required this.onAcknowledge,
    required this.onDecline,
  });

  final int minutes;
  final VoidCallback onAcknowledge;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;

    return Container(
      key: const ValueKey<String>('location-notice'),
      padding: const EdgeInsets.all(TiqSpace.s4),
      decoration: BoxDecoration(
        color: skin.palette.surface,
        borderRadius: BorderRadius.circular(skin.radii.panel),
        border: Border.all(
          color: skin.palette.edgeStructure,
          width: skin.depth.borderWidth,
        ),
        boxShadow: skin.depth.shadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.share_location,
                size: MarkScale.glyph(context, 20),
                color: skin.palette.ink1,
              ),
              const SizedBox(width: TiqSpace.s3),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.locationNoticeTitle,
                    style: skin.text.titleM.style(color: skin.palette.ink1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: TiqSpace.s3),
          Text(
            l10n.locationNoticeBody(minutes),
            style: skin.text.body.style(color: skin.palette.ink2),
          ),
          SizedBox(height: skin.space.intraBlock),
          TorchPrimaryButton(
            key: const ValueKey<String>('location-notice-acknowledge'),
            claimId: LocationSharingBanner.consentClaimId,
            label: l10n.locationNoticeAcknowledge,
            onPressed: onAcknowledge,
          ),
          const SizedBox(height: TiqSpace.s2),
          TorchTertiaryButton(
            key: const ValueKey<String>('location-notice-decline'),
            label: l10n.locationNoticeDecline,
            onPressed: onDecline,
          ),
        ],
      ),
    );
  }
}
