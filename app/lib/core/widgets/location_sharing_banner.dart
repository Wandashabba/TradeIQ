import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../location/location_sharing.dart';
import '../theme/lumen_glass.dart';
import '../theme/lumen_palette.dart';
import '../theme/tiq_colors.dart';
import 'agent_kit.dart';
import 'agent_motion.dart';
import 'glass.dart';

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
class LocationSharingBanner extends ConsumerWidget {
  const LocationSharingBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(locationSharingControllerProvider);
    final settings = s.settings;
    if (!s.isAgent || settings == null) return const SizedBox.shrink();
    final l10n = context.l10n;
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
      child = PressFeedback(
        onTap: () => _confirmStop(context, controller),
        child: StatusBanner(
          key: const ValueKey('location-sharing-indicator'),
          level: BannerLevel.info,
          title: l10n.locationSharingActiveTitle,
          subtitle: s.noFix
              ? l10n.locationSharingNoFixSubtitle
              : l10n.locationSharingActiveSubtitle,
          trailing: Icon(
            Icons.my_location,
            size: 16,
            semanticLabel: l10n.locationSharingActiveTitle,
          ),
        ),
      );
    } else {
      child = PressFeedback(
        onTap: controller.reconsider,
        child: StatusBanner(
          key: const ValueKey('location-sharing-off'),
          level: BannerLevel.good,
          title: l10n.locationSharingOffTitle,
          subtitle: l10n.locationSharingOffSubtitle,
          trailing: const Icon(Icons.location_disabled, size: 16),
        ),
      );
    }
    return Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: child);
  }

  static Future<void> _confirmStop(
    BuildContext context,
    LocationSharingController controller,
  ) async {
    final l10n = context.l10n;
    final stop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('location-stop-dialog'),
        title: Text(l10n.locationStopTitle),
        content: Text(l10n.locationStopBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.locationStopCancel),
          ),
          FilledButton(
            key: const ValueKey('location-stop-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.locationStopConfirm),
          ),
        ],
      ),
    );
    if (stop == true) await controller.decline();
  }
}

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
    final colors = context.colors;
    final glass = colors.glass;
    final ink = glass ? context.lumen.ink : colors.ink1;
    final muted = glass ? context.lumen.inkMuted : colors.ink2;

    final body = Column(
      key: const ValueKey('location-notice'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.share_location, size: 20, color: ink),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.locationNoticeTitle,
                style: glass
                    ? LumenGlass.title(color: ink, size: 15)
                    : TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.locationNoticeBody(minutes),
          style: TextStyle(fontSize: 13, height: 1.4, color: muted),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('location-notice-acknowledge'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: onAcknowledge,
          child: Text(l10n.locationNoticeAcknowledge),
        ),
        const SizedBox(height: 4),
        TextButton(
          key: const ValueKey('location-notice-decline'),
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: onDecline,
          child: Text(l10n.locationNoticeDecline),
        ),
      ],
    );

    if (glass) {
      return GlassPane(padding: const EdgeInsets.all(14), child: body);
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.line),
      ),
      child: body,
    );
  }
}
