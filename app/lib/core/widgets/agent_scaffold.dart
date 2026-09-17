import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../auth/session_controller.dart';
import '../l10n/app_language_controller.dart';
import '../sync/sync_status.dart';
import '../theme/lumen_glass.dart';
import '../theme/theme_mode_controller.dart';
import '../theme/tiq_colors.dart';
import 'agent_kit.dart';
import 'agent_motion.dart';
import 'background_location_banner.dart';
import 'glass.dart';
import 'location_sharing_banner.dart';
import 'lumen_kit.dart';
import '../theme/lumen_palette.dart';

/// The field agent's shell.
///
/// Deliberately not the manager's. A manager is at a desk with a mouse, so
/// their actions live top-right. An agent is standing in an aisle with one hand
/// on a shelf — so the primary action lives at the BOTTOM, where the thumb
/// already is, and nothing interactive is smaller than 48px.
///
/// In Lumen Glass the lit ground runs edge to edge: the app bar floats on it
/// with a glass back chip, and the primary action sits in a glass pane rather
/// than an opaque strip. The pane is still solid enough behind its blur that
/// the note explaining a disabled action stays readable over whatever scrolls
/// underneath it.
class AgentScaffold extends ConsumerWidget {
  const AgentScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.bottomAction,
    this.onBack,
    this.showSyncChip = true,
    this.showNotificationsAction = true,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final Widget body;

  /// The one primary action, pinned to the thumb zone.
  final Widget? bottomAction;

  /// Where back goes. Null on a root screen (no back arrow).
  final VoidCallback? onBack;

  /// The agent's most-asked question, answered on every screen.
  final bool showSyncChip;

  /// The bell that opens the notification settings (#67). Off on that screen,
  /// where it would only be a link to itself.
  final bool showNotificationsAction;

  final List<Widget>? actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A section is pushed as a plain route on top of the visit hub, which puts
    // it OUTSIDE the GoRoute subtree — and `GoRouterState.of` throws there. So
    // only ask GoRouter where we are when we actually need to know (to decide
    // whether this is the root screen); a screen given its own `onBack` has
    // already answered that question, and must never ask.
    final isRoot = onBack == null && _matchedLocation(context) == '/today';
    final showBack = !isRoot;
    final colors = context.colors;
    final glass = colors.glass;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final language = ref.watch(appLanguageProvider);
    final l10n = context.l10n;
    void goBack() => (onBack ?? () => context.go('/today'))();

    final content = Column(
      children: [
        if (showSyncChip)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SyncChip(),
          ),
        // On every agent screen, with or without the sync chip: whether the
        // agent's location is being shared must always have a visible answer
        // (#153 T1, POPIA risk 1). Renders nothing for anyone else.
        const LocationSharingBanner(),
        // And whether their ROUTE is being recorded when the app is closed,
        // which is a bigger thing and therefore a separate line with its own
        // notice, its own consent and its own off switch (#153 T2). Renders
        // nothing on anything but Android.
        const BackgroundLocationBanner(),
        Expanded(child: body),
      ],
    );

    return Scaffold(
      backgroundColor: colors.plane,
      // Glass floats the bar and the action pane over the lit ground, so the
      // ground has to run beneath both of them.
      extendBodyBehindAppBar: glass,
      extendBody: glass,
      appBar: AppBar(
        toolbarHeight: subtitle == null ? 56 : 64,
        backgroundColor: glass ? Colors.transparent : null,
        surfaceTintColor: glass ? Colors.transparent : null,
        shape: glass ? const Border() : null,
        leadingWidth: glass && showBack ? 60 : null,
        titleSpacing: glass && showBack ? 4 : null,
        leading: !showBack
            ? null
            : glass
            ? Padding(
                padding: const EdgeInsets.only(left: 8),
                child: GlassBackChip(onTap: goBack),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back, size: 22),
                tooltip: l10n.agentBackTooltip,
                onPressed: goBack,
              ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: glass
                  ? LumenGlass.title(color: context.lumen.ink, size: 17)
                  : TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: colors.ink1,
                    ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: glass ? context.lumen.inkMuted : colors.ink3,
                ),
              ),
          ],
        ),
        actions: [
          ...?actions,
          if (showNotificationsAction)
            IconButton(
              key: const ValueKey('agent-notifications'),
              icon: const Icon(Icons.notifications_outlined, size: 20),
              tooltip: l10n.agentNotificationsTooltip,
              onPressed: () => context.push('/notifications'),
            ),
          // Language override (#40): System follows the device; English and
          // Afrikaans pin the UI. Persisted like the theme choice beside it.
          PopupMenuButton<AppLanguage>(
            key: const ValueKey('agent-language-menu'),
            icon: const Icon(Icons.translate, size: 20),
            tooltip: l10n.languageMenuTooltip,
            initialValue: language,
            onSelected: (choice) =>
                ref.read(appLanguageProvider.notifier).select(choice),
            itemBuilder: (context) => [
              for (final option in AppLanguage.values)
                CheckedPopupMenuItem<AppLanguage>(
                  key: ValueKey('agent-language-${option.storageValue}'),
                  value: option,
                  checked: option == language,
                  child: Text(switch (option) {
                    AppLanguage.system => l10n.languageSystem,
                    AppLanguage.english => l10n.languageEnglish,
                    AppLanguage.afrikaans => l10n.languageAfrikaans,
                  }),
                ),
            ],
          ),
          // The agent carries the same light/dark toggle as the console — the
          // moon offers dark, the sun offers light, always the destination.
          IconButton(
            key: const ValueKey('agent-theme-toggle'),
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, size: 20),
            tooltip: l10n.agentThemeTooltip,
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: l10n.agentLogOutTooltip,
            onPressed: () =>
                ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: glass
          ? LitGround(
              child: Builder(
                // With the body extended under both bars, the Scaffold hands
                // the body their heights as padding. Apply it once, here, and
                // strip it so no scroll view below applies it a second time.
                builder: (context) {
                  final insets = MediaQuery.paddingOf(context);
                  return Padding(
                    padding: EdgeInsets.only(
                      top: insets.top,
                      bottom: insets.bottom,
                    ),
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      removeBottom: true,
                      child: content,
                    ),
                  );
                },
              ),
            )
          : content,
      bottomNavigationBar: bottomAction == null
          ? null
          : glass
          ? SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: GlassPane(
                kind: GlassKind.bar,
                padding: const EdgeInsets.all(12),
                child: bottomAction!,
              ),
            )
          : Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                // Opaque, never a fade — the note explaining why an action is
                // disabled has to stay readable over whatever is scrolling
                // underneath it.
                color: colors.surface1,
                border: Border(top: BorderSide(color: colors.line)),
              ),
              child: SafeArea(top: false, child: bottomAction!),
            ),
    );
  }
}

/// GoRouter's state is only reachable inside a GoRoute subtree. A pushed section
/// sits outside one, so asking is an error rather than a miss — hence the catch.
String? _matchedLocation(BuildContext context) {
  try {
    return GoRouterState.of(context).matchedLocation;
  } on Object {
    return null;
  }
}

/// "Is my work safe?" — answered wherever the agent is.
///
/// Tapping it opens the full queue. The app is offline-first, so this is not an
/// error indicator: holding work on the phone is the *normal* state in a shop
/// with no signal, and the copy says so rather than alarming anyone.
class SyncChip extends ConsumerWidget {
  const SyncChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final syncing = ref.watch(syncingProvider);
    final glass = context.colors.glass;

    return status.maybeWhen(
      data: (s) {
        final (level, title, sub) = _describe(context.l10n, s, syncing);
        return PressFeedback(
          onTap: () => context.push('/my-work'),
          child: StatusBanner(
            key: const ValueKey('sync-chip'),
            level: level,
            title: title,
            subtitle: sub,
            // Breathing means "sending, right now" — never merely "pending".
            pulsing: syncing,
            // Glass turns a retry mark slowly beside held work: it is waiting
            // for signal, and it will try again on its own.
            trailing: glass && level == BannerLevel.warn
                ? const AmbientSpin(
                    child: Icon(Icons.sync, size: 16, color: Color(0xFF7A4D00)),
                  )
                : null,
          ),
        );
      },
      // Never guess. If we cannot read the queue we say nothing rather than
      // claim everything is fine.
      orElse: () => const SizedBox.shrink(),
    );
  }

  static (BannerLevel, String, String) _describe(
    AppLocalizations l10n,
    SyncStatus s,
    bool syncing,
  ) {
    if (syncing && s.pending.isNotEmpty) {
      return (
        BannerLevel.info,
        l10n.syncSendingTitle(s.pendingCount),
        l10n.syncSendingSubtitle,
      );
    }
    if (s.needsAttention.isNotEmpty) {
      return (
        BannerLevel.bad,
        l10n.syncAttentionTitle(s.needsAttention.length),
        l10n.syncAttentionSubtitle,
      );
    }
    if (s.pending.isNotEmpty) {
      return (
        BannerLevel.warn,
        l10n.syncHeldTitle(s.pendingCount),
        l10n.syncHeldSubtitle,
      );
    }
    return (
      BannerLevel.good,
      l10n.syncAllSentTitle,
      s.lastSentAt == null
          ? l10n.syncNothingWaiting
          : l10n.syncLastSent(formatAgo(s.lastSentAt!, l10n)),
    );
  }
}
