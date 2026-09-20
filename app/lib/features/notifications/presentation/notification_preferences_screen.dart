import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/network/human_error.dart';
import '../../../core/push/push_client.dart';
import '../../../core/push/push_repository.dart';
import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/agent_kit.dart';
import '../../../core/widgets/agent_scaffold.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../../../l10n/l10n.dart';

/// The signed-in user's push preferences (#67), saved optimistically.
class NotificationPreferencesController
    extends AsyncNotifier<NotificationPreferences> {
  @override
  Future<NotificationPreferences> build() =>
      ref.read(pushRepositoryProvider).fetchPreferences();

  /// Flips one category at once and saves it. A failed save puts the previous
  /// value back and returns false, so the toggle never lies about the server.
  Future<bool> setCategory(NotificationCategory category, bool enabled) async {
    final previous = state.value;
    if (previous == null) return false;
    state = AsyncData(previous.withValue(category, enabled));
    try {
      final saved = await ref.read(pushRepositoryProvider).updatePreferences({
        category: enabled,
      });
      state = AsyncData(saved);
      return true;
    } catch (_) {
      state = AsyncData(previous);
      return false;
    }
  }
}

final notificationPreferencesProvider =
    AsyncNotifierProvider.autoDispose<
      NotificationPreferencesController,
      NotificationPreferences
    >(NotificationPreferencesController.new);

/// `/notifications` — one route, each role in its own shell: the field agent's
/// translated app, or the manager's (English) console.
class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(sessionControllerProvider).value?.role;
    return role == 'field_agent'
        ? const _AgentNotificationPreferences()
        : const _ManagerNotificationPreferences();
  }
}

class _Item {
  const _Item(this.category, this.label, this.help);
  final NotificationCategory category;
  final String label;
  final String help;
}

Future<void> _save(
  BuildContext context,
  WidgetRef ref,
  NotificationCategory category,
  bool enabled,
  String failure,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final saved = await ref
      .read(notificationPreferencesProvider.notifier)
      .setCategory(category, enabled);
  if (!saved) messenger.showSnackBar(SnackBar(content: Text(failure)));
}

Widget _toggles(
  BuildContext context,
  WidgetRef ref,
  NotificationPreferences prefs,
  List<_Item> items,
  String failure,
) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    for (final item in items)
      AgentToggle(
        key: ValueKey('push-pref-${item.category.name}'),
        label: item.label,
        help: item.help,
        value: prefs[item.category],
        onChanged: (enabled) =>
            _save(context, ref, item.category, enabled, failure),
      ),
  ],
);

class _AgentNotificationPreferences extends ConsumerWidget {
  const _AgentNotificationPreferences();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final prefs = ref.watch(notificationPreferencesProvider);
    final pushOn = ref.watch(pushClientProvider).isEnabled;
    // Alerts go to managers only, so an agent is not offered them.
    final items = [
      _Item(
        NotificationCategory.tasks,
        l10n.notificationsTasksLabel,
        l10n.notificationsTasksHelp,
      ),
      _Item(
        NotificationCategory.messages,
        l10n.notificationsMessagesLabel,
        l10n.notificationsMessagesHelp,
      ),
      _Item(
        NotificationCategory.sla,
        l10n.notificationsSlaLabel,
        l10n.notificationsSlaHelp,
      ),
    ];

    return AgentScaffold(
      title: l10n.notificationsTitle,
      subtitle: l10n.notificationsSubtitle,
      onBack: () => context.canPop() ? context.pop() : context.go('/today'),
      showSyncChip: false,
      showNotificationsAction: false,
      body: prefs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            StatusBanner(
              level: BannerLevel.bad,
              title: l10n.notificationsLoadErrorTitle,
              subtitle: humanErrorMessage(error, l10n),
            ),
            const SizedBox(height: 12),
            AgentButton(
              key: const ValueKey('push-prefs-retry'),
              label: l10n.notificationsRetry,
              icon: Icons.refresh,
              secondary: true,
              onPressed: () => ref.invalidate(notificationPreferencesProvider),
            ),
            const _AgentAccountEntry(),
          ],
        ),
        data: (value) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            if (!pushOn) ...[
              StatusBanner(
                key: const ValueKey('push-not-set-up'),
                level: BannerLevel.info,
                title: l10n.notificationsNotSetUpTitle,
                subtitle: l10n.notificationsNotSetUpBody,
              ),
              const SizedBox(height: 16),
            ],
            GlassPane(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: _toggles(
                context,
                ref,
                value,
                items,
                l10n.notificationsSaveFailed,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.notificationsFooter,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: context.colors.glass
                    ? context.lumen.inkMuted
                    : context.colors.ink3,
              ),
            ),
            const _AgentAccountEntry(),
          ],
        ),
      ),
    );
  }
}

class _ManagerNotificationPreferences extends ConsumerWidget {
  const _ManagerNotificationPreferences();

  static const _items = [
    _Item(
      NotificationCategory.alerts,
      'Alerts',
      'When a visit raises an alert for your team',
    ),
    _Item(
      NotificationCategory.tasks,
      'Tasks assigned to you',
      'When someone assigns you a task',
    ),
    _Item(
      NotificationCategory.messages,
      'Messages and announcements',
      'Direct messages, team messages and announcements',
    ),
    _Item(
      NotificationCategory.sla,
      'Overdue tasks',
      'When a task passes its SLA deadline — yours, or anyone’s on your team',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPreferencesProvider);
    final pushOn = ref.watch(pushClientProvider).isEnabled;
    final colors = context.colors;
    final muted = colors.glass ? context.lumen.inkMuted : colors.ink2;

    return ManagerScaffold(
      title: 'Notifications',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: AsyncSection<NotificationPreferences>(
                value: prefs,
                label: 'notification settings',
                onRetry: () => ref.invalidate(notificationPreferencesProvider),
                builder: (value) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!pushOn) ...[
                      GlassPane(
                        key: const ValueKey('push-not-set-up'),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 18,
                              color: muted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Push notifications aren’t switched on for '
                                'this app yet. Your choices are saved and '
                                'apply as soon as they are.',
                                style: TextStyle(fontSize: 13, color: muted),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    PanelCard(
                      title: 'Push notifications',
                      subtitle: 'What reaches your phone or browser',
                      child: _toggles(
                        context,
                        ref,
                        value,
                        _items,
                        'Couldn’t save that — check your connection and try again',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Outside the preferences' async section, so a failed load of the
          // toggles never hides the way to change a password (#400).
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: PanelCard(
                title: 'Your account',
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const ValueKey('account-change-password'),
                    icon: const Icon(Icons.password_outlined, size: 18),
                    label: const Text('Change password'),
                    onPressed: () => context.push('/account/password'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The way to the change-password screen (#400), on both of the agent's
/// branches — loaded and failed — so a preferences load that fails never hides
/// it.
class _AgentAccountEntry extends StatelessWidget {
  const _AgentAccountEntry();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.settingsAccountHeading,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: 8),
          AgentButton(
            key: const ValueKey('account-change-password'),
            label: l10n.changePasswordTitle,
            icon: Icons.password_outlined,
            secondary: true,
            onPressed: () => context.push('/account/password'),
          ),
        ],
      ),
    );
  }
}
