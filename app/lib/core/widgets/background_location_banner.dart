import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../location/background_location.dart';
import '../theme/lumen_glass.dart';
import '../theme/lumen_palette.dart';
import '../theme/tiq_colors.dart';
import 'agent_kit.dart';
import 'agent_motion.dart';
import 'glass.dart';

/// Background route tracking, told to the agent in words (#153 T2, POPIA).
///
/// Sits under [LocationSharingBanner] and is deliberately a SEPARATE line with
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
class BackgroundLocationBanner extends ConsumerWidget {
  const BackgroundLocationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(backgroundLocationControllerProvider);
    final settings = state.settings;
    if (state.step == BackgroundTrackingStep.unavailable || settings == null) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
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
      BackgroundTrackingStep.off => PressFeedback(
        onTap: controller.showNotice,
        child: StatusBanner(
          key: const ValueKey('background-location-off'),
          level: BannerLevel.good,
          title: l10n.backgroundLocationOfferTitle,
          subtitle: l10n.backgroundLocationOfferSubtitle,
          trailing: const Icon(Icons.route_outlined, size: 16),
        ),
      ),
      BackgroundTrackingStep.needsPermission => _PermissionPrompt(
        onOpenSettings: controller.openSettings,
        onNotNow: controller.stop,
      ),
      BackgroundTrackingStep.outsideHours => StatusBanner(
        key: const ValueKey('background-location-paused'),
        level: BannerLevel.info,
        title: l10n.backgroundLocationOutsideHoursTitle,
        subtitle: l10n.backgroundLocationOutsideHoursSubtitle(hours.start),
        trailing: const Icon(Icons.schedule_outlined, size: 16),
      ),
      BackgroundTrackingStep.running => PressFeedback(
        onTap: () => _confirmStop(context, controller),
        child: StatusBanner(
          key: const ValueKey('background-location-active'),
          level: BannerLevel.info,
          title: l10n.backgroundLocationActiveTitle,
          subtitle: l10n.backgroundLocationActiveSubtitle,
          trailing: Icon(
            Icons.route,
            size: 16,
            semanticLabel: l10n.backgroundLocationActiveTitle,
          ),
        ),
      ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: child,
    );
  }

  static Future<void> _confirmStop(
    BuildContext context,
    BackgroundLocationController controller,
  ) async {
    final l10n = context.l10n;
    final stop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('background-location-stop-dialog'),
        title: Text(l10n.backgroundLocationStopTitle),
        content: Text(l10n.backgroundLocationStopBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.backgroundLocationStopCancel),
          ),
          FilledButton(
            key: const ValueKey('background-location-stop-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.backgroundLocationStopConfirm),
          ),
        ],
      ),
    );
    if (stop == true) await controller.stop();
  }
}

/// The frame both the notice and the permission prompt sit in.
class _Pane extends StatelessWidget {
  const _Pane({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (colors.glass) {
      return GlassPane(padding: const EdgeInsets.all(14), child: child);
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.line),
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
    final colors = context.colors;
    final ink = colors.glass ? context.lumen.ink : colors.ink1;
    return Row(
      children: [
        Icon(icon, size: 20, color: ink),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: colors.glass
                ? LumenGlass.title(color: ink, size: 15)
                : TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ink,
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
    final colors = context.colors;
    final muted = colors.glass ? context.lumen.inkMuted : colors.ink2;

    return _Pane(
      child: Column(
        key: const ValueKey('background-location-notice'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Heading(Icons.route_outlined, l10n.backgroundLocationNoticeTitle),
          const SizedBox(height: 8),
          Text(
            l10n.backgroundLocationNoticeBody(minutes, start, end),
            style: TextStyle(fontSize: 13, height: 1.4, color: muted),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('background-location-accept'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: onAccept,
            child: Text(l10n.backgroundLocationNoticeAccept),
          ),
          const SizedBox(height: 4),
          TextButton(
            key: const ValueKey('background-location-decline'),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: onDecline,
            child: Text(l10n.backgroundLocationNoticeDecline),
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
    final colors = context.colors;
    final muted = colors.glass ? context.lumen.inkMuted : colors.ink2;

    return _Pane(
      child: Column(
        key: const ValueKey('background-location-permission'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Heading(
            Icons.settings_outlined,
            l10n.backgroundLocationPermissionTitle,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.backgroundLocationPermissionBody,
            style: TextStyle(fontSize: 13, height: 1.4, color: muted),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('background-location-open-settings'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: onOpenSettings,
            child: Text(l10n.backgroundLocationPermissionOpenSettings),
          ),
          const SizedBox(height: 4),
          TextButton(
            key: const ValueKey('background-location-permission-not-now'),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: onNotNow,
            child: Text(l10n.backgroundLocationPermissionNotNow),
          ),
        ],
      ),
    );
  }
}
