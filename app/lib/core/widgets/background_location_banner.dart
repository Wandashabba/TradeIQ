import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../location/background_location.dart';
import '../theme/torchlight/tiq_skin.dart';
import 'torchlight/button/buttons.dart';
import 'torchlight/marks.dart';
import 'torchlight/row/row.dart';
import 'torchlight/sheet.dart';

/// Background route tracking, told to the agent in words (#153 T2, POPIA).
///
/// Sits under `LocationSharingBanner` and is deliberately a SEPARATE line with
/// a separate off switch. Foreground sharing and background tracking are
/// different asks, they are answered separately on the server, and an agent who
/// wants to stop one must be able to do so without stopping the other.
///
/// Renders nothing at all on anything but Android, and nothing before the
/// settings are known.
///
/// Five faces:
///
/// - **A quiet offer**, when tracking is off. Never the full notice unasked:
///   the foreground notice is already on screen when an agent first signs in,
///   and stacking a second wall of text under it is how people learn to tap
///   past both. Tapping opens the notice.
/// - **The notice**, when they ask to see it: what is recorded, how often, in
///   which hours, that it runs with the app closed, and that a notification
///   stays up the whole time. A clear yes and a clear no.
/// - **A permission prompt**, when they said yes but Android has not granted
///   "Allow all the time". Offers the settings page, and says plainly that
///   everything else keeps working if they would rather not.
/// - **A paused line**, outside the client's working hours.
/// - **The indicator**, while the service is running. Not dismissible, and
///   tapping it offers to stop.
///
/// ## Torchlight, and not one word changed
///
/// A restyle. Every sentence and every key is the one that was here — a
/// consent notice whose wording drifts is a consent notice nobody can point at
/// afterwards. The standing statements are standalone soft rows, the two walls
/// of text are the panel material, the buttons are the button family, and the
/// stop confirmation is a [ConfirmSheet]: unify §1.7 deleted the dialog.
class BackgroundLocationBanner extends ConsumerWidget {
  const BackgroundLocationBanner({super.key});

  /// The notice's yes, and the permission prompt's "Open settings". Only one
  /// of the two is ever on screen.
  static const String consentClaimId = 'background-location-consent';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(backgroundLocationControllerProvider);
    final settings = state.settings;
    if (state.step == BackgroundTrackingStep.unavailable || settings == null) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final skin = context.skin;
    final controller = ref.read(backgroundLocationControllerProvider.notifier);

    // The permanent notification is the one piece of this feature that renders
    // outside Flutter, so it cannot reach the localisations itself. This is the
    // only place with a BuildContext that is guaranteed to be built before the
    // service can start, so the words are pushed down from here.
    controller.setNotificationText(
      BackgroundNotificationText(
        title: l10n.backgroundLocationNotificationTitle,
        body: l10n.backgroundLocationNotificationBody,
        channelName: l10n.backgroundLocationNotificationChannel,
      ),
    );

    final hours = settings.workingHours;
    final Widget child = switch (state.step) {
      BackgroundTrackingStep.unavailable => const SizedBox.shrink(),
      BackgroundTrackingStep.notice => _BackgroundNotice(
        minutes: (settings.intervalSeconds / 60).round().clamp(1, 120),
        start: hours.start,
        end: hours.end,
        onAccept: controller.enable,
        onDecline: () {
          controller.dismissNotice();
          // An explicit "no" is recorded, not just dismissed — a decline is an
          // answer the server keeps, and it is what stops the offer nagging.
          controller.stop();
        },
      ),
      BackgroundTrackingStep.off => SoftRow(
        key: const ValueKey<String>('background-location-off'),
        form: SoftRowForm.standalone,
        title: l10n.backgroundLocationOfferTitle,
        subtitle: l10n.backgroundLocationOfferSubtitle,
        leading: Icon(
          Icons.route_outlined,
          size: MarkScale.glyph(context, 20),
          color: skin.palette.ink3,
        ),
        trailing: const SoftRowChevron(),
        onTap: controller.showNotice,
      ),
      BackgroundTrackingStep.needsPermission => _PermissionPrompt(
        onOpenSettings: controller.openSettings,
        onNotNow: controller.stop,
      ),
      // Not tappable: the pause is the clock's decision, not the agent's, and
      // a row that opens nothing must not wear a chevron.
      BackgroundTrackingStep.outsideHours => SoftRow(
        key: const ValueKey<String>('background-location-paused'),
        form: SoftRowForm.standalone,
        title: l10n.backgroundLocationOutsideHoursTitle,
        subtitle: l10n.backgroundLocationOutsideHoursSubtitle(hours.start),
        leading: Icon(
          Icons.schedule_outlined,
          size: MarkScale.glyph(context, 20),
          color: skin.palette.ink3,
        ),
      ),
      BackgroundTrackingStep.running => SoftRow(
        key: const ValueKey<String>('background-location-active'),
        form: SoftRowForm.standalone,
        title: l10n.backgroundLocationActiveTitle,
        subtitle: l10n.backgroundLocationActiveSubtitle,
        leading: Icon(
          Icons.route,
          size: MarkScale.glyph(context, 20),
          color: skin.palette.ink2,
        ),
        trailing: const SoftRowChevron(),
        onTap: () => _confirmStop(context, controller),
      ),
    };

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
    BackgroundLocationController controller,
  ) async {
    final l10n = context.l10n;
    final stop = await showTorchSheet<bool>(
      context,
      builder: (context) => ConfirmSheet(
        key: const ValueKey<String>('background-location-stop-dialog'),
        action: l10n.backgroundLocationStopTitle,
        consequences: <String>[l10n.backgroundLocationStopBody],
        commitLabel: l10n.backgroundLocationStopConfirm,
        cancelLabel: l10n.backgroundLocationStopCancel,
      ),
    );
    if (stop == true) await controller.stop();
  }
}

/// The frame both walls of text sit in — the panel material, once.
class _Pane extends StatelessWidget {
  const _Pane({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
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
      child: child,
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          icon,
          size: MarkScale.glyph(context, 20),
          color: skin.palette.ink1,
        ),
        const SizedBox(width: TiqSpace.s3),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              text,
              style: skin.text.titleM.style(color: skin.palette.ink1),
            ),
          ),
        ),
      ],
    );
  }
}

class _BackgroundNotice extends StatelessWidget {
  const _BackgroundNotice({
    required this.minutes,
    required this.start,
    required this.end,
    required this.onAccept,
    required this.onDecline,
  });

  final int minutes;
  final String start;
  final String end;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;

    return _Pane(
      child: Column(
        key: const ValueKey<String>('background-location-notice'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _Heading(Icons.route_outlined, l10n.backgroundLocationNoticeTitle),
          const SizedBox(height: TiqSpace.s3),
          Text(
            l10n.backgroundLocationNoticeBody(minutes, start, end),
            style: skin.text.body.style(color: skin.palette.ink2),
          ),
          SizedBox(height: skin.space.intraBlock),
          TorchPrimaryButton(
            key: const ValueKey<String>('background-location-accept'),
            claimId: BackgroundLocationBanner.consentClaimId,
            label: l10n.backgroundLocationNoticeAccept,
            onPressed: onAccept,
          ),
          const SizedBox(height: TiqSpace.s2),
          TorchTertiaryButton(
            key: const ValueKey<String>('background-location-decline'),
            label: l10n.backgroundLocationNoticeDecline,
            onPressed: onDecline,
          ),
        ],
      ),
    );
  }
}

class _PermissionPrompt extends StatelessWidget {
  const _PermissionPrompt({
    required this.onOpenSettings,
    required this.onNotNow,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;

    return _Pane(
      child: Column(
        key: const ValueKey<String>('background-location-permission'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _Heading(
            Icons.settings_outlined,
            l10n.backgroundLocationPermissionTitle,
          ),
          const SizedBox(height: TiqSpace.s3),
          Text(
            l10n.backgroundLocationPermissionBody,
            style: skin.text.body.style(color: skin.palette.ink2),
          ),
          SizedBox(height: skin.space.intraBlock),
          TorchPrimaryButton(
            key: const ValueKey<String>('background-location-open-settings'),
            claimId: BackgroundLocationBanner.consentClaimId,
            label: l10n.backgroundLocationPermissionOpenSettings,
            onPressed: onOpenSettings,
          ),
          const SizedBox(height: TiqSpace.s2),
          TorchTertiaryButton(
            key: const ValueKey<String>('background-location-permission-not-now'),
            label: l10n.backgroundLocationPermissionNotNow,
            onPressed: onNotNow,
          ),
        ],
      ),
    );
  }
}
