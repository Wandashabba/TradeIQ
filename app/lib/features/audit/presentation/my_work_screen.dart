import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/torch_scope.dart';
import '../../../core/widgets/agent_kit.dart' show formatAgo;
import '../../../core/sync/sync_status.dart';
import '../../../core/theme/torchlight/agent_skin.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/skin_controls.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../core/widgets/agent_location_banners.dart';
import '../../../l10n/l10n.dart';
import '../../beatplans/presentation/today_screen.dart' show TodayFrame;
import '../../contests/data/contests_repository.dart';
import 'outbox_item_sheet.dart';

/// MY WORK — everything the agent has captured, and whether the server has it.
///
/// ```text
///   My work                                        [ ☾ ]
///   Everything you’ve captured
///   ┌───────────────────────────────────────────┐
///   │ ■  12 items held on this phone            │
///   │    They will send themselves              │
///   │    [          Send now          ]         │
///   └───────────────────────────────────────────┘
///   ── Waiting to send ─────────────────────────
///   ▣ Stock count            about 0,3 MB    WAITING
///     Waiting for signal · queued 07:58          ›
///   ── Sent ────────────────────────────────────
///   ◉ Submitted visit        about 1,4 MB       SENT
///   [ nav pill ] ( + )
/// ```
///
/// ## Held is the normal state
///
/// Towers go down with the grid, a back aisle is a Faraday cage, and "12 held"
/// is a normal Tuesday. So the held summary is **Oatmeal plus a square plus a
/// word** — never crimson, never a severity, and never the word "error". Only
/// [SyncStatus.stuck] — a capture that will not send *on its own* — raises a
/// colour, and even then it raises it on that capture and not on the screen.
/// A capture held because the session ended is held, not stuck (unify §1.13):
/// signing in sends it, so it is Oatmeal like the rest and the "Sign in"
/// amber carries the call to action.
///
/// ## The amber, counted
///
/// A tab root, so the nav pill's active tab is object 1 in Night whenever the
/// nav renders, and the content has exactly one grant left. It goes to
/// **"Send now"**, and only when pressing it is the expected next move:
///
/// * nothing stuck → the queue sends itself and the button is a ghost, so the
///   screen paints **one** amber object in Night and **zero** in Day and Veld.
///   That is the correct reading of a screen whose whole message is *nothing
///   to do*.
/// * something stuck → "Send now" is armed and takes the grant.
/// * signed out → the grant moves off "Send now" and onto **"Sign in"**,
///   because a flush with no session sends nothing. This is the one state
///   where the screen's commit is not the button beside the queue.
///
/// ## What is not here
///
/// The spec's arming condition is "stuck items **and** connectivity to act
/// on". The app has no connectivity channel — no plugin, no provider, nothing
/// that knows whether a radio is up — so the condition implemented is the half
/// that is knowable. A "Send now" that lit itself on a guess would be worse
/// than one that lights on a fact.
class MyWorkScreen extends ConsumerWidget {
  const MyWorkScreen({super.key});

  /// "Send now". Rung 1, declared only when something is actually stuck.
  static const String sendNowClaimId = 'my-work-send-now';

  /// "Sign in". The same rung, and never declared at the same time as
  /// [sendNowClaimId] — a session that has ended makes the other button a lie.
  static const String signInClaimId = 'my-work-sign-in';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const TorchlightRoute(child: _MyWork());
  }
}

class _MyWork extends ConsumerWidget {
  const _MyWork();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(syncStatusProvider);

    return status.when(
      loading: () => const _MyWorkFrame(
        phase: 'loading',
        children: <Widget>[_MyWorkSkeleton()],
      ),
      // Reading the outbox failed. The outbox itself did not: the captures are
      // rows in a database on this phone and they are exactly where they were.
      // So the footer sentence stays, because it is still true.
      error: (error, stack) => _MyWorkFrame(
        phase: 'error',
        children: <Widget>[
          ErrorState(
            message: TorchErrorMessage(
              kind: TorchErrorKind.unknown,
              headline: l10n.myWorkLoadErrorTitle,
              body: l10n.myWorkLoadErrorBody,
              offersRetry: true,
            ),
            drawing: EmptyDrawing.envelope,
            // A read of a table on this phone that failed once is worth one
            // more read. A secondary, never the amber: it is not a commit.
            action: TorchSecondaryButton(
              key: const ValueKey<String>('retry-work'),
              label: l10n.myWorkRetry,
              onPressed: () => ref.invalidate(syncStatusProvider),
            ),
          ),
          const _Footer(),
        ],
      ),
      data: (data) => _Queue(status: data),
    );
  }
}

/// The frame every state of this route wears.
class _MyWorkFrame extends ConsumerWidget {
  const _MyWorkFrame({required this.phase, required this.children, this.armed});

  final String phase;

  /// The claim id the screen's one grant goes to, or null when nothing on the
  /// screen is the expected next move. One nullable id rather than two
  /// booleans, so "Send now" and "Sign in" can never both be lit.
  final String? armed;

  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final skin = context.skin;

    return TorchScope(
      skin: skin,
      phase: phase,
      navRenders: TorchShell.navWillRender(context, hasNav: true),
      tabbedRoute: true,
      claims: <TorchClaim>[if (armed != null) TorchClaim.primaryCommit(armed!)],
      child: TorchShell(
        profile: TorchShellProfile.agent,
        header: TorchAppHeader(
          title: l10n.myWorkTitle,
          facts: <String>[l10n.myWorkSubtitle],
          // The sync chip is suppressed on the screen it opens — it would be a
          // link to itself. The one trailing icon button on a tab root is the
          // skin cycle (unify §1.2).
          trailing: skinCycleIconButton(context, ref),
        ),
        navPill: TorchNavPill(
          slots: TodayFrame.slotsIn(
            l10n,
            runningContests: ref.watch(runningContestsCountProvider).value ?? 0,
          ),
          activeIndex: TodayFrame.myWorkSlot,
          onSelect: (i) => TodayFrame.go(context, i),
        ),
        // The agent's standing action, declared honestly and never expected
        // here: an agent on My work came to look at the queue, not to start a
        // visit. It asks for nothing, so it can never take the grant off the
        // thing that needs it.
        navCircle: TorchNavCircle(
          claimId: 'my-work-visit-another',
          expected: false,
          icon: Icons.add,
          expectedIcon: Icons.arrow_forward,
          semanticLabel: l10n.todayVisitAnotherStore,
          expectedSemanticLabel: l10n.todayVisitAnotherStore,
          onPressed: () => context.go('/audit'),
        ),
        // Whether the agent is being located has an answer on every agent
        // screen (#153, POPIA) — see AgentLocationBanners.
        children: <Widget>[const AgentLocationBanners(), ...children],
      ),
    );
  }
}

/// The queue itself, in three groups.
class _Queue extends ConsumerStatefulWidget {
  const _Queue({required this.status});

  final SyncStatus status;

  /// How many sent captures the list shows before it stops, and how many more
  /// each "Show older" adds. Beyond this the footer states the cap rather than
  /// the list quietly ending — a truncated list that does not say it is
  /// truncated is how an agent concludes a capture was lost.
  static const int sentCap = 20;

  @override
  ConsumerState<_Queue> createState() => _QueueState();
}

class _QueueState extends ConsumerState<_Queue> {
  int _sentShown = _Queue.sentCap;

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final l10n = context.l10n;
    final skin = context.skin;
    final sending = ref.watch(syncingProvider) && status.pending.isNotEmpty;

    // Stuck, not needsAttention: a session-ended capture is held, and it is
    // listed with the rest of the held work rather than under "Needs you".
    final needsYou = status.stuck;
    final waiting = status.held;
    final sent = status.sent;
    final sessionEnded = status.sessionEnded;

    // The amber, resolved once for the whole route. Signing in wins: a flush
    // with no session sends nothing, so arming "Send now" there would light
    // the one button on the screen that cannot work.
    final String? armed = sessionEnded.isNotEmpty
        ? MyWorkScreen.signInClaimId
        : needsYou.isNotEmpty
        ? MyWorkScreen.sendNowClaimId
        : null;

    final String phase;
    if (status.pending.isEmpty && sent.isEmpty) {
      phase = 'empty';
    } else if (sessionEnded.isNotEmpty) {
      phase = 'signed-out';
    } else if (needsYou.isNotEmpty) {
      phase = 'stuck';
    } else if (sending) {
      phase = 'sending';
    } else if (status.pending.isNotEmpty) {
      phase = 'held';
    } else {
      phase = 'all-sent';
    }

    if (status.pending.isEmpty && sent.isEmpty) {
      return _MyWorkFrame(
        phase: phase,
        children: <Widget>[
          EmptyState(
            headline: l10n.myWorkEmpty,
            drawing: EmptyDrawing.envelope,
            body: l10n.myWorkEmptyBody,
          ),
          const _Footer(),
        ],
      );
    }

    Widget group(String heading, List<SyncItem> items, {bool capped = false}) {
      // A group with nothing in it prints no rule. An empty "Needs you" is a
      // heading about nothing and reads as a section that failed to load.
      if (items.isEmpty) return const SizedBox.shrink();
      final shown = capped ? items.take(_sentShown).toList() : items;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionRule(heading, count: items.length),
          const SizedBox(height: TiqSpace.s4),
          TorchBleed(
            extra: skin.space.gutter * 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final (i, item) in shown.indexed)
                  _Row(
                    item: item,
                    sending: sending,
                    last: i == shown.length - 1,
                  ),
              ],
            ),
          ),
          if (capped && items.length > shown.length) ...<Widget>[
            const SizedBox(height: TiqSpace.s4),
            PaginationFooter(
              summary: l10n.myWorkSentCapped(shown.length, items.length),
              action: TorchTertiaryButton(
                key: const ValueKey<String>('show-older'),
                label: l10n.myWorkShowOlder,
                onPressed: () => setState(() => _sentShown += _Queue.sentCap),
              ),
            ),
          ],
          SizedBox(height: skin.space.blockGap),
        ],
      );
    }

    return _MyWorkFrame(
      phase: phase,
      armed: armed,
      children: <Widget>[
        if (sessionEnded.isNotEmpty) ...<Widget>[
          _SignedOutBlock(count: status.pendingCount),
          const SizedBox(height: TiqSpace.s4),
        ],
        _Summary(
          status: status,
          sending: sending,
          armed: armed == MyWorkScreen.sendNowClaimId,
        ),
        SizedBox(height: skin.space.blockGap),
        group(l10n.myWorkNeedsYouHeading, needsYou),
        group(l10n.myWorkWaitingHeading, waiting),
        group(l10n.myWorkSentHeading, sent, capped: true),
        const _Footer(),
      ],
    );
  }
}

/// THE SUMMARY BLOCK — the state of the whole queue, in a glyph and a
/// sentence, with the one action that acts on it inside the block it is about.
///
/// A standalone soft surface: radius 14, `surface` fill, a 1px `edgeStructure`
/// rim (unify §1.3). Built here rather than through `SoftRow` because it
/// carries an action, and a list row that grows a 56dp button is not a row.
class _Summary extends ConsumerWidget {
  const _Summary({
    required this.status,
    required this.sending,
    required this.armed,
  });

  final SyncStatus status;
  final bool sending;

  /// Whether "Send now" is this route's granted commit. The button still asks
  /// [TorchScope] itself; this only decides whether it is *offered* as one.
  final bool armed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = context.skin;
    final l10n = context.l10n;

    final stuck = status.stuck;
    // A queue held because the session ended does not "send itself" — it
    // sends when the agent signs in, and the summary says so.
    final signedOut = status.sessionEnded.isNotEmpty;

    final (
      MarkShape shape,
      Color ink,
      String title,
      String subtitle,
    ) = switch ((stuck.isNotEmpty, sending, status.pending.isNotEmpty)) {
      // The one state that raises a colour, because it is the one state where
      // something is actually wrong. Session-ended captures are not in it:
      // they are held (unify §1.13), and counting them here painted work
      // that sends itself after sign-in as a failure.
      (true, _, _) => (
        MarkShape.criticalTriangle,
        skin.palette.bad,
        l10n.myWorkFailedTitle(stuck.length),
        l10n.myWorkFailedSubtitle,
      ),
      // Sending is Oatmeal and a word. The motion-coded amber "live" mark is
      // retired from the agent surface: an upload is progress, and progress is
      // a report (unify §1.1).
      (false, true, _) => (
        MarkShape.heldSquare,
        skin.palette.ink2,
        l10n.myWorkSendingTitle(status.pendingCount),
        l10n.myWorkSendingSubtitle,
      ),
      // HELD — the normal state. Oatmeal, a square, a word.
      (false, false, true) => (
        MarkShape.heldSquare,
        skin.palette.ink2,
        l10n.myWorkHeldTitle(status.pendingCount),
        signedOut
            ? l10n.outboxHeldUntilSignIn
            : status.lastSentAt == null
            ? l10n.myWorkHeldSubtitle
            : l10n.syncLastSent(formatAgo(status.lastSentAt!, l10n)),
      ),
      (false, false, false) => (
        MarkShape.onTargetCircle,
        skin.palette.good,
        l10n.syncAllSentTitle,
        status.lastSentAt == null
            ? l10n.syncNothingWaiting
            : l10n.syncLastSent(formatAgo(status.lastSentAt!, l10n)),
      ),
    };

    return Container(
      key: const ValueKey<String>('work-summary'),
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
        children: <Widget>[
          // The state is ONE node for a screen reader, and it leads with the
          // state word. The button below is a second, separate node — a
          // summary that swallowed its own action would announce "12 items
          // held on this phone, Send now" as a single sentence.
          Semantics(
            container: true,
            label: '$title. $subtitle',
            excludeSemantics: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: TiqSpace.s1),
                  child: TiqMark(
                    shape: shape,
                    color: ink,
                    size: MarkScale.glyph(context, 16),
                  ),
                ),
                const SizedBox(width: TiqSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: skin.text.bodyStrong.style(
                          color: skin.palette.ink1,
                        ),
                      ),
                      const SizedBox(height: TiqSpace.s1),
                      Text(
                        subtitle,
                        style: skin.text.meta.style(color: skin.palette.ink3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: TiqSpace.s4),
          // "Send now" lives here, with the thing it acts on. My work is a
          // tab root and tab roots have no thumb zone (unify §1.2), and the
          // button belongs beside the queue anyway.
          TorchPrimaryButton(
            key: const ValueKey<String>('send-now'),
            claimId: MyWorkScreen.sendNowClaimId,
            label: l10n.myWorkSendNow,
            icon: Icons.upload_outlined,
            busy: sending,
            blockedReason: status.pending.isEmpty
                ? l10n.myWorkSendNowBlocked
                : null,
            onPressed: status.pending.isEmpty || sending
                ? null
                : () => ref.read(syncNowProvider)(),
          ),
        ],
      ),
    );
  }
}

/// The session ended under the queue. Not a load failure and not a stuck
/// capture: the work is fine, the token is not. So the block wears the
/// structural edge like every other surface — never crimson — and the "Sign
/// in" amber inside it is the call to action (unify §1.13).
class _SignedOutBlock extends StatelessWidget {
  const _SignedOutBlock({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    return Container(
      key: const ValueKey<String>('signed-out'),
      padding: const EdgeInsets.all(TiqSpace.s4),
      decoration: BoxDecoration(
        color: skin.palette.surface,
        borderRadius: BorderRadius.circular(skin.radii.panel),
        border: Border.all(
          color: skin.palette.edgeStructure,
          width: skin.depth.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.myWorkSignedOutTitle(count),
            style: skin.text.bodyStrong.style(color: skin.palette.ink1),
          ),
          const SizedBox(height: TiqSpace.s4),
          // THE SCREEN'S AMBER, in the one state where signing in is the
          // expected next move and "Send now" is not.
          TorchPrimaryButton(
            key: const ValueKey<String>('sign-in'),
            claimId: MyWorkScreen.signInClaimId,
            label: l10n.myWorkSignIn,
            onPressed: () => context.go('/login'),
          ),
        ],
      ),
    );
  }
}

/// One capture, as the shared outbox row (#382/#411).
class _Row extends ConsumerWidget {
  const _Row({required this.item, required this.sending, required this.last});

  final SyncItem item;
  final bool sending;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = outboxStateFor(item, sending: sending);
    final label = item.labelIn(l10n);

    return OutboxRow(
      key: ValueKey<String>('sync-item-${item.id}'),
      state: state,
      title: label,
      stateWord: outboxStateWord(state, l10n, item: item),
      sentence: outboxSentence(item, state, l10n),
      ageLine: outboxAgeLine(context, item, state),
      payloadBytes: item.payloadBytes,
      stuckLabel: state == OutboxState.stuck ? l10n.outboxNeedsYou : null,
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      onTap: () => showOutboxItemSheet(context, item: item, state: state),
    );
  }
}

/// The standing promise, on every state of the screen including the ones that
/// failed — because it is true on all of them.
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: const EdgeInsets.only(top: TiqSpace.s4),
      child: Text(
        context.l10n.myWorkFooter,
        style: skin.text.meta.style(color: skin.palette.ink3),
      ),
    );
  }
}

/// The real geometry, empty. Not a spinner.
class _MyWorkSkeleton extends StatelessWidget {
  const _MyWorkSkeleton();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Skeleton(
      label: context.l10n.myWorkTitle,
      slowLine: context.l10n.myWorkFooter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SkeletonShell(height: 140),
          SizedBox(height: skin.space.blockGap),
          const SkeletonRows(count: 4),
        ],
      ),
    );
  }
}
