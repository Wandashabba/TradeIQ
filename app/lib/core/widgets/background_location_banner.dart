import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../location/background_location.dart';
import '../theme/torchlight/tiq_skin.dart';
import 'torchlight/bleed.dart';
import 'torchlight/button/buttons.dart';
import 'torchlight/card.dart';
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
/// afterwards. The standing statements are soft rows in the card form and the
/// two walls of text are a [TorchCard] — **both since 29 September 2026**, and
/// both for the reason #483 gave when it moved the agent's other standalone
/// blocks: this banner is the first object on Today, My work, Me and the map,
/// and it was the last radius-14 outlined rectangle on any of them. The
/// buttons are the button family, and the stop confirmation is a
/// [ConfirmSheet]: unify §1.7 deleted the dialog.
class BackgroundLocationBanner extends ConsumerWidget {
  const BackgroundLocationBanner({super.key, this.inset = true});

  /// Whether the banner brings its own side gutter. The legacy scaffold puts
  /// it above a body with no padding, so it does; a Torchlight shell's
  /// children are already inside the gutter, so there it must not.
  final bool inset;

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
        form: SoftRowForm.list,
        separator: SoftRowSeparator.none,
        // COMPACT — the kit's banner density. These three faces are standing
        // statements under the header on every agent screen, stacked under
        // the foreground one, and at standard density with a `body` second
        // line the pair took 166dp off the top of the fold before the screen
        // said anything of its own.
        density: SoftRowDensity.compact,
        title: l10n.backgroundLocationOfferTitle,
        meta: Text(l10n.backgroundLocationOfferSubtitle),
        semanticsLabel:
            '${l10n.backgroundLocationOfferTitle}. '
            '${l10n.backgroundLocationOfferSubtitle}',
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
        form: SoftRowForm.list,
        separator: SoftRowSeparator.none,
        density: SoftRowDensity.compact,
        title: l10n.backgroundLocationOutsideHoursTitle,
        meta: Text(l10n.backgroundLocationOutsideHoursSubtitle(hours.start)),
        semanticsLabel:
            '${l10n.backgroundLocationOutsideHoursTitle}. '
            '${l10n.backgroundLocationOutsideHoursSubtitle(hours.start)}',
        leading: Icon(
          Icons.schedule_outlined,
          size: MarkScale.glyph(context, 20),
          color: skin.palette.ink3,
        ),
      ),
      BackgroundTrackingStep.running => SoftRow(
        key: const ValueKey<String>('background-location-active'),
        form: SoftRowForm.list,
        separator: SoftRowSeparator.none,
        density: SoftRowDensity.compact,
        title: l10n.backgroundLocationActiveTitle,
        meta: Text(l10n.backgroundLocationActiveSubtitle),
        semanticsLabel:
            '${l10n.backgroundLocationActiveTitle}. '
            '${l10n.backgroundLocationActiveSubtitle}',
        leading: Icon(
          Icons.route,
          size: MarkScale.glyph(context, 20),
          color: skin.palette.ink2,
        ),
        trailing: const SoftRowChevron(),
        onTap: () => _confirmStop(context, controller),
      ),
    };

    // The gap goes BELOW, not above. Above, the last banner sat flush against
    // the first block of the screen's own body — a standing statement welded
    // to the day block, with all the air stacked on the other side of it.
    //
    // THE CARD BRINGS ITS OWN GUTTER, since 29 September 2026 — see
    // `LocationSharingBanner`, which this sits under and has to line up with.
    return Padding(
      padding: const EdgeInsets.only(bottom: TiqSpace.s4),
      child: inset
          ? child
          : TorchBleed(extra: skin.space.gutter * 2, child: child),
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

/// The frame both walls of text sit in — **a card, since 29 September 2026.**
///
/// It was a hand-built radius-14 block with a 1px `edgeStructure` rim: the
/// standalone row's material, which is the shape #483 took off every other
/// standalone block on the agent side and the shape the owner named twice.
/// Under it sit the card-form banners this class shares a column with, and
/// above it the header — one grammar down the column now, not two.
///
/// It is a `TorchCard` and not a hand-built one because the padding, the
/// radius, the fill and the absence of a shadow were already exactly
/// `TorchCard`'s four decisions; keeping a second copy of them here is how the
/// two drift apart in a month.
///
/// The gutter is spent here rather than by the caller so that this face and
/// the three row faces are **one geometry**: a card-form `SoftRow` insets its
/// own card by `margin: gutter`, and `TorchCard` does not, so without this the
/// notice would sit a gutter wider than the line it opens into.
class _Pane extends StatelessWidget {
  const _Pane({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: context.skin.space.gutter),
    child: TorchCard(child: child),
  );
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
            key: const ValueKey<String>(
              'background-location-permission-not-now',
            ),
            label: l10n.backgroundLocationPermissionNotNow,
            onPressed: onNotNow,
          ),
        ],
      ),
    );
  }
}
