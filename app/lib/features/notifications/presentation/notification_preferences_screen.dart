import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/design/torch_scope.dart';
import '../../../core/network/human_error.dart';
import '../../../core/push/push_client.dart';
import '../../../core/push/push_repository.dart';
import '../../../core/theme/torchlight/agent_skin.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/skin_controls.dart';
import '../../../core/widgets/torchlight/state.dart';
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
///
/// ## Toggles, and the word that is not optional
///
/// Every preference is a [TorchToggle], whose state word is mandatory by
/// construction — it has a default rather than being nullable, so a caller can
/// localise it but cannot remove it. On the agent's screen the words come from
/// the ARB, because an English "On" inside an Afrikaans screen is a defect.
///
/// There is no indeterminate state: a toggle sitting at off is a recorded no.
///
/// ## The amber, counted
///
/// Neither branch has a commit. The agent's is a pushed screen with no nav, so
/// it has two content grants and declares none; the manager's is a tab root,
/// so Night paints the nav's active tab and nothing else. Day and Veld paint
/// zero on both.
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

/// One preference: the category, the words that describe it, and the help line
/// beneath.
class _Item {
  const _Item(this.category, this.label, this.help);

  final NotificationCategory category;
  final String label;
  final String help;
}

/// The toggle stack, shared by both roles.
class _Toggles extends ConsumerWidget {
  const _Toggles({
    required this.prefs,
    required this.items,
    required this.failure,
    required this.onWord,
    required this.offWord,
  });

  final NotificationPreferences prefs;
  final List<_Item> items;

  /// What a failed save says, in the reader's language.
  final String failure;
  final String onWord;
  final String offWord;

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    NotificationCategory category,
    bool enabled,
  ) async {
    final saved = await ref
        .read(notificationPreferencesProvider.notifier)
        .setCategory(category, enabled);
    if (saved || !context.mounted) return;
    // The preference is already back where it was — the toggle never lies
    // about the server — and the toast says so rather than leaving the flip
    // to be discovered.
    showTorchToast(
      context,
      message: failure,
      kind: ToastKind.failure,
      navRenders: false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = context.skin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final item in items) ...<Widget>[
          TorchToggle(
            key: ValueKey<String>('push-pref-${item.category.name}'),
            label: item.label,
            value: prefs[item.category],
            onWord: onWord,
            offWord: offWord,
            onChanged: (enabled) => _save(context, ref, item.category, enabled),
          ),
          const SizedBox(height: TiqSpace.s2),
          Text(
            item.help,
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
          SizedBox(height: skin.space.intraBlock),
        ],
      ],
    );
  }
}

/// THE AGENT'S BRANCH — translated, pushed, and always carrying the way to
/// change a password.
class _AgentNotificationPreferences extends ConsumerWidget {
  const _AgentNotificationPreferences();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const TorchlightRoute(child: _AgentBody());
  }
}

class _AgentBody extends ConsumerWidget {
  const _AgentBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final prefs = ref.watch(notificationPreferencesProvider);
    final pushOn = ref.watch(pushClientProvider).isEnabled;

    // Alerts go to managers only, so an agent is not offered them.
    final items = <_Item>[
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

    return prefs.when(
      loading: () => _AgentFrame(
        phase: 'loading',
        children: <Widget>[
          Skeleton(
            label: l10n.notificationsTitle,
            child: const SkeletonRows(count: 3, rowHeight: 64),
          ),
        ],
      ),
      // The way to the change-password screen (#400) is on BOTH branches, so
      // a preferences load that fails never hides it.
      error: (error, stack) => _AgentFrame(
        phase: 'error',
        children: <Widget>[
          TorchErrorRegion(
            name: 'notification settings',
            child: ErrorState(
              key: const ValueKey<String>('push-prefs-error'),
              message: TorchErrorMessage(
                kind: TorchErrorKind.unknown,
                headline: l10n.notificationsLoadErrorTitle,
                body: humanErrorMessage(error, l10n),
                offersRetry: true,
              ),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('push-prefs-retry'),
                label: l10n.notificationsRetry,
                onPressed: () =>
                    ref.invalidate(notificationPreferencesProvider),
              ),
            ),
          ),
          const _AgentAccountEntry(),
        ],
      ),
      data: (value) => _AgentFrame(
        phase: 'loaded',
        children: <Widget>[
          if (!pushOn) ...<Widget>[
            EmptyState(
              key: const ValueKey<String>('push-not-set-up'),
              scope: EmptyScope.inline,
              headline: l10n.notificationsNotSetUpTitle,
              body: l10n.notificationsNotSetUpBody,
            ),
            SizedBox(height: context.skin.space.blockGap),
          ],
          SectionRule(l10n.notificationsHeading),
          const SizedBox(height: TiqSpace.s5),
          _Toggles(
            prefs: value,
            items: items,
            failure: l10n.notificationsSaveFailed,
            onWord: l10n.wordOn,
            offWord: l10n.wordOff,
          ),
          Text(
            l10n.notificationsFooter,
            style: context.skin.text.meta.style(
              color: context.skin.palette.ink3,
            ),
          ),
          const _AgentAccountEntry(),
        ],
      ),
    );
  }
}

class _AgentFrame extends ConsumerWidget {
  const _AgentFrame({required this.phase, required this.children});

  final String phase;
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final canPop = context.canPop();

    return TorchScope(
      skin: context.skin,
      phase: phase,
      navRenders: false,
      tabbedRoute: false,
      // Nothing here is a commit: a preference saves itself on the flip.
      claims: const <TorchClaim>[],
      child: TorchShell(
        profile: TorchShellProfile.agent,
        header: TorchAppHeader(
          title: l10n.notificationsTitle,
          facts: <String>[l10n.notificationsSubtitle],
          back: TorchIconButton(
            key: const ValueKey<String>('notifications-back'),
            icon: Icons.arrow_back,
            semanticLabel: canPop
                ? l10n.notificationsBackToMe
                : l10n.notificationsBackToToday,
            onPressed: () => canPop ? context.pop() : context.go('/today'),
          ),
        ),
        skinCycle: const AgentSkinCycle(),
        children: children,
      ),
    );
  }
}

/// The way to the change-password screen (#400), on both of the agent's
/// branches — loaded and failed — so a preferences load that fails never
/// hides it.
class _AgentAccountEntry extends StatelessWidget {
  const _AgentAccountEntry();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(top: context.skin.space.blockGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SectionRule(l10n.settingsAccountHeading),
          const SizedBox(height: TiqSpace.s5),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TorchSecondaryButton(
              key: const ValueKey<String>('account-change-password'),
              label: l10n.changePasswordTitle,
              onPressed: () => context.push('/account/password'),
            ),
          ),
        ],
      ),
    );
  }
}

/// THE MANAGER'S BRANCH — the console, English, under the Menu slot.
class _ManagerNotificationPreferences extends ConsumerWidget {
  const _ManagerNotificationPreferences();

  static const List<_Item> _items = <_Item>[
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

    return prefs.when(
      loading: () => _frame(
        phase: 'loading',
        children: <Widget>[
          Skeleton(
            label: 'notification settings',
            child: const SkeletonRows(count: 4, rowHeight: 64),
          ),
        ],
      ),
      // Outside the preferences' region, so a failed load never hides the way
      // to change a password (#400).
      error: (error, stack) => _frame(
        phase: 'error',
        children: <Widget>[
          TorchErrorRegion(
            name: 'notification settings',
            child: ErrorState(
              key: const ValueKey<String>('push-prefs-error'),
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('push-prefs-retry'),
                label: 'Try again',
                onPressed: () =>
                    ref.invalidate(notificationPreferencesProvider),
              ),
            ),
          ),
          const _ManagerAccountEntry(),
        ],
      ),
      data: (value) => _frame(
        phase: 'loaded',
        children: <Widget>[
          if (!pushOn) ...<Widget>[
            const EmptyState(
              key: ValueKey<String>('push-not-set-up'),
              scope: EmptyScope.inline,
              headline: 'Push notifications aren’t switched on yet.',
              body: 'Your choices are saved and apply as soon as they are.',
            ),
            SizedBox(height: context.skin.space.blockGap),
          ],
          SectionRule('Push notifications'),
          const SizedBox(height: TiqSpace.s5),
          _Toggles(
            prefs: value,
            items: _items,
            failure:
                'Couldn’t save that — check your connection and try again.',
            onWord: 'On',
            offWord: 'Off',
          ),
          const _ManagerAccountEntry(),
        ],
      ),
    );
  }

  Widget _frame({required String phase, required List<Widget> children}) {
    return ConsoleFrame(
      phase: phase,
      active: ConsoleSlot.menu,
      header: const TorchAppHeader(
        title: 'Notifications',
        facts: <String>['What reaches your phone or browser.'],
      ),
      children: children,
    );
  }
}

class _ManagerAccountEntry extends StatelessWidget {
  const _ManagerAccountEntry();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: context.skin.space.blockGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SectionRule('Your account'),
          const SizedBox(height: TiqSpace.s5),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TorchSecondaryButton(
              key: const ValueKey<String>('account-change-password'),
              label: 'Change password',
              onPressed: () => context.push('/account/password'),
            ),
          ),
        ],
      ),
    );
  }
}
