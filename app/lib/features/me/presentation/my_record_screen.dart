import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/design/tiq_number.dart';
import '../../../core/design/torch_scope.dart';
import '../../../core/sync/sync_status.dart';
import '../../../core/theme/torchlight/agent_skin.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/agent_location_banners.dart';
import '../../../core/widgets/torchlight/agent_wash.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/card.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/skin_controls.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../core/widgets/torchlight/sync_status.dart';
import '../../../l10n/l10n.dart';
import '../../beatplans/presentation/today_screen.dart';
import '../../contests/data/contests_repository.dart';
import '../../gamification/data/gamification_repository.dart';
import '../data/my_record_repository.dart';

/// ME — the agent's own record, and the answer to "the client says nobody was
/// at Lesedi on Tuesday" (#383/#384).
///
/// ```text
///   Me · All time             [ 12 held on this phone ]  [ ☾ ]
///   ── What I've earned ──────────────────────────────
///   ╭─────────────────────────────────────────────╮
///   │ Twenty stores                1 840 of 2 000 │
///   │ ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬░░░░░┃            │
///   │ 160 to go · R 250 airtime                   │
///   ╰─────────────────────────────────────────────╯
///   ╭─────────────────────────────────────────────╮
///   │ POINTS ALL TIME                             │
///   │ 1 840                                       │
///   │                                             │
///   │ RANK                                      4 │
///   ╰─────────────────────────────────────────────╯
///   ── How you earned it ─────────────────────────────
///   ▣  Visit submitted        Thu 18 Sep     +5
///   ▣  Task closed            Thu 18 Sep     +5
///   ▣  Scorecard              Wed 17 Sep     85
///   Points are worked out on the server. They can change
///   if a visit is reviewed.
///   ── My visits ─────────────────────────────────────
///   ◧  Kasi Corner Spaza                          71
///      Thu 18 Sep · 41 min · 3 tasks raised
///      ▪ Now scored 71 ▽ — it was 84
///        It was scored again after you saw it.
///   [ nav pill ]
/// ```
///
/// ## Why this screen exists at all
///
/// A fraud engine scores an agent on evidence the agent cannot see, and their
/// incentives depend on numbers they cannot check. Until now the only record
/// of Tuesday was a rolling outbox list with no store name and no date, and
/// logging out deleted it. This route is the counterweight: server-backed, so
/// it survives a logout; self-scoped, so it is only ever theirs.
///
/// ## The amber, counted
///
/// **Night 1. Day 0.** A tab root, so the nav's active tab is object 1
/// whenever the nav renders — and the content claims nothing at all, which is
/// the whole ruling for this screen. There is no primary here and no nav
/// circle: reading your own record has no expected next move, and a light with
/// nothing to point at is a light that means "look here" about nothing.
/// On Day the nav's active slot is an Abyssal block, so there this
/// screen is genuinely unlit — which unify's ruling on My visits says in so
/// many words.
///
/// The reward bar is the most tempting object in the product to light and it
/// is deliberately not lit: unify §1.1 puts the meter's target tick in ink-1
/// everywhere and drops What I've earned to zero. The near-reward exception
/// was written, argued and deleted.
///
/// ## The honest score story
///
/// The in-store score is computed on the device and the server recomputes it
/// from what actually persisted (ADR 0005 chose speed over parity on the
/// phone, deliberately). The two legitimately disagree.
///
/// What this screen shows is the **authoritative** number, every time. Where
/// the server's number differs from the one the agent already read on the way
/// out of the shop, a [ReconciliationLine] says so in the agent's own voice —
/// "Now scored 71 — it was 84", and why — rather than one number
/// silently replacing another.
///
/// It does **not** carry a [ProvisionalMarker]. unify §1.20 rules that the
/// agent app never shows a provisional score, and the marker's own doc comment
/// says it is console-only: a caveat beside a figure is a reasonable thing to
/// give a reviewer and a guess shown to the person who produced it is not.
/// A visit the server has not scored therefore reads "Waiting to be scored",
/// with a hatched mark, and no number at all.
///
/// ## The period, named
///
/// Every figure here is the agent's **whole record**. `/gamification/me` is
/// read with no `from`/`to`, so it always was — but the header printed the
/// month name and three strings said "this month", which made a career total
/// read as September's. The words moved to the data rather than the other way
/// round, because the incentive payout engine has no period either and a
/// month-scoped bar would promise a reward the engine will not pay. The
/// reasoning is in `DioMyRecordRepository.myEarnings`.
///
/// ## Self-scoped, and not a leaderboard
///
/// Every endpoint behind this route takes its agent id from the token (see
/// `my_record_repository.dart`). Nothing here reads the standings or the
/// manager's drill-down: comparing an agent to their peers is Contests' job,
/// and it has its own tab.
class MyRecordScreen extends ConsumerWidget {
  const MyRecordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TorchlightRoute(child: _MyRecord());
  }
}

class _MyRecord extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final earnings = ref.watch(myEarningsProvider);
    final visits = ref.watch(myVisitsProvider);
    final sync = ref.watch(syncStatusProvider).value ?? SyncStatus.empty;

    // One phase name per composed state, because the claim set is resolved per
    // declared phase and never per frame. This route claims nothing in any of
    // them, so the phase is here for the census and the golden rather than for
    // the allocator — and that is worth saying out loud: a route with an empty
    // claim set still declares its phases, or the census cannot tell "nothing
    // is lit" from "nothing was measured".
    final phase = switch ((earnings, visits)) {
      (AsyncLoading(), _) || (_, AsyncLoading()) => 'loading',
      (AsyncError(), AsyncError()) => 'error',
      _ => 'loaded',
    };

    return MeFrame(
      phase: phase,
      children: <Widget>[
        SectionRule(l10n.meEarnedHeading),
        const SizedBox(height: TiqSpace.s5),
        _Earned(earnings: earnings),
        SizedBox(height: context.skin.space.blockGap),
        // Outside `earnings.when` on purpose: the way to the standings is not
        // a figure, and a failed points read must not take it away.
        _ContestsRow(
          running: ref.watch(runningContestsCountProvider).value ?? 0,
        ),
        SizedBox(height: context.skin.space.blockGap),
        _Visits(visits: visits, sync: sync),
        SizedBox(height: context.skin.space.blockGap),
        // THE SETTINGS, LAST. A record is read from the top and housekeeping
        // is not part of it, so `THIS APP` sits under the visits rather than
        // over the points — the same place the manager's rail keeps its own
        // foot, and for the same reason.
        const _ThisApp(),
      ],
    );
  }
}

/// ── THIS APP — theme, password, the way out ────────────────────────────
///
/// ```text
///   ── THIS APP ──────────────────────────────────
///   Night screen
///   Change password                            ›
///   [ Sign out ]
/// ```
///
/// **The same three objects the manager's menu carries**, in the same order,
/// drawn with the agent side's own row widget. `menu_sheet.dart`'s `THIS APP`
/// block is a `SectionRule`, two compact [SoftRow]s and a
/// [TorchSecondaryButton]; so is this. The strings are the menu's own —
/// `menuThisApp`, `menuChangePassword`, `menuSignOut` — so there is no fourth
/// name to translate and nothing to drift.
///
/// No manager file is touched by it. The three objects are core widgets and
/// the two shared strings are already in the bundle.
///
/// ## THE THEME ROW DRIVES `agentSkinProvider`, NOT `themeModeProvider`
///
/// This is the one place the two sides deliberately do **not** meet, and it is
/// worth being exact about why rather than letting the next reader "fix" it.
///
/// `AgentSkinController.build()` returns **Day**, and its doc comment says
/// what that is for: *"they start outdoors at 06:30 and the paper skin is the
/// one that reads in a car park."* `ThemeModeController` is the manager's
/// preference, persisted, and it defaults to the platform. Pointing this row
/// at `themeModeProvider` would make an agent's first morning frame depend on
/// a manager-shaped default and would silently delete the 06:30 ruling; making
/// `agentSkinProvider` follow `themeModeProvider` would do the same thing one
/// layer down. So the preferences stay independent and the row drives the
/// agent's own.
///
/// ## WHAT THAT COSTS, AND IT IS A WART
///
/// Independent preferences mean **an agent ends up with two appearance
/// controls**: this row, and the [AgentSkinCycle] that `TorchShell` puts at
/// the leading end of every thumb zone on every agent screen that is not a tab
/// root. Both drive `agentSkinProvider`, so they always agree and neither can
/// show a stale state — but there are two of them, and one of them is three
/// taps away inside a record while the other is on the screen you are standing
/// on.
///
/// The cycle is not removed, and the reason is `TorchShell`'s own sentence:
/// *"Never a screen without the skin cycle: the one control that gets a person
/// out of a skin they cannot read belongs on every screen they can reach."* An
/// agent who turns Night on in a dark aisle and then walks into the sun must be
/// able to turn it off from wherever they are, not from Me. Taking the cycle
/// away to make the count one would trade a wart for a trap.
///
/// **Amber: none.** Housekeeping commits nothing. A `SoftRow` declares no
/// claim, and `TorchSecondaryButton` is an `edgeControl` rim in both skins.
class _ThisApp extends ConsumerWidget {
  const _ThisApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode = ref.watch(agentSkinProvider);
    final next = TorchSkinCycle.next(mode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionRule(l10n.menuThisApp),
        const SizedBox(height: TiqSpace.s3),
        SoftRow(
          key: const ValueKey<String>('me-theme'),
          density: SoftRowDensity.compact,
          // NAMES THE STATE IT SWITCHES TO, never the one it is in — the skin
          // cycle's rule and the manager menu's, and for the same reason: a
          // control that announces where it is makes a blind agent press it to
          // find out where it goes. `skinName` is the existing formatter, so
          // the row and the cycle beside it say the skin's name the same way.
          //
          // `meThemeRow` wraps that name in a noun — "Night screen", not
          // "Night" — because the first render of this block put a one-word
          // row under a `THIS APP` marker and it read as a destination rather
          // than as a setting. The manager's row has the same shape for the
          // same reason ("Dark theme", not "Dark"); the words differ because
          // the two sides name this preference differently and it is
          // deliberately not one preference. See this class's note.
          title: l10n.meThemeRow(skinName(l10n, next)),
          // And the whole sentence to a screen reader, which is what the
          // cycle's own 56dp control is given. A row titled "Night" with no
          // verb in it is a noun a reader cannot act on.
          semanticsLabel: skinCycleLabel(l10n, mode),
          onTap: () => ref.read(agentSkinProvider.notifier).set(next),
        ),
        SoftRow(
          key: const ValueKey<String>('me-password'),
          density: SoftRowDensity.compact,
          title: l10n.menuChangePassword,
          trailing: const SoftRowChevron(),
          // `push`, not `go`: back comes here. The menu sheet pops itself
          // first because there is a modal over it; there is none over this.
          onTap: () => context.push('/account/password'),
        ),
        SizedBox(height: context.skin.space.blockGap),
        TorchSecondaryButton(
          key: const ValueKey<String>('me-sign-out'),
          label: l10n.menuSignOut,
          // A BUTTON AND NOT A ROW, which is `menu_sheet.dart`'s own ruling
          // and the rail footer's: the one irreversible control in the product
          // is shaped like a commitment rather than hidden behind a row that
          // does not say so. No `pop` first — the router redirect rebuilds
          // this page and there is no sheet standing over it.
          onPressed: () =>
              ref.read(sessionControllerProvider.notifier).logout(),
        ),
      ],
    );
  }
}

/// The frame every state of this route wears.
class MeFrame extends ConsumerWidget {
  const MeFrame({super.key, required this.phase, required this.children});

  final String phase;
  final List<Widget> children;

  /// Nav slot index. Today · My work · Map · **Me**.
  static const int navIndex = TodayFrame.meSlot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final skin = context.skin;
    final wash = ref.watch(agentWashDirectionProvider);

    return TorchScope(
      skin: skin,
      phase: phase,
      navRenders: TorchShell.navWillRender(context, hasNav: true),
      tabbedRoute: true,
      // Empty, and deliberately. Reading your own record is not a move, and
      // the one object the design was tempted to light here — the reward bar's
      // target tick — is ink-1 in every skin (unify §1.1).
      claims: const <TorchClaim>[],
      child: TorchShell(
        profile: TorchShellProfile.agent,
        // THE BACK SHADE. Top-anchored — see `agent_wash.dart`.
        backdrop: agentWashFor(skin, wash),
        backdropClearsScrim: agentWashClearsScrim(wash),
        header: TorchAppHeader(
          title: l10n.meTitle,
          // "All time", and not the month it used to print. `/gamification/me`
          // is read with no window, so every figure below is the agent's whole
          // record; a header reading "September" over a career total is the
          // exact failure — a number labelled as something it is not — that
          // this screen exists to end. See `DioMyRecordRepository.myEarnings`
          // for why the window is absent rather than added.
          facts: <String>[l10n.meAllTime],
          // NO TRAILING ICON BUTTON — 4 October 2026. The skin cycle stood
          // here, and on the other three tab rows, and it is now a row in this
          // screen's own `THIS APP` block ([_ThisApp]). A screen that is the
          // agent's record is also the screen their settings belong on, which
          // is the arrangement the manager's menu has had since it was written.
          status: const TorchSyncChip(),
        ),
        navPill: TorchNavPill(
          slots: TodayFrame.slotsIn(
            l10n,
            runningContests: ref.watch(runningContestsCountProvider).value ?? 0,
          ),
          activeIndex: navIndex,
          onSelect: (i) => TodayFrame.go(context, i),
        ),
        // Whether the agent is being located has an answer on every agent
        // screen (#153, POPIA) — see AgentLocationBanners.
        children: <Widget>[const AgentLocationBanners(), ...children],
      ),
    );
  }
}

/// A localised inline load failure.
///
/// `TorchErrorMessage.sanitise` deliberately throws the exception away — the
/// only thing that crosses that boundary is a kind and a code, because a
/// message that is sometimes an exception is a message that one day carries a
/// host name into a screenshot in a WhatsApp group. What it cannot do is
/// translate, so the two strings are supplied here and the body names the
/// work's safety first, which is the sentence an agent needs before any other.
TorchErrorMessage meLoadError(BuildContext context, String headline) =>
    TorchErrorMessage(
      kind: TorchErrorKind.unknown,
      headline: headline,
      body: context.l10n.meLoadErrorDetail,
      // No retry, and therefore no second button competing with the pull to
      // refresh the list already has. One retry per region is the rule and
      // zero is the honest number when the region is a read that re-runs on
      // its own.
      offersRetry: false,
    );

// ── WHAT I'VE EARNED ───────────────────────────────────────────────────────

class _Earned extends StatelessWidget {
  const _Earned({required this.earnings});

  final AsyncValue<MyEarnings> earnings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return earnings.when(
      loading: () => const _EarnedSkeleton(),
      // An inline error, not a whole-screen one: the visit list below is a
      // separate read and a separate region, and losing one must not take the
      // other off the screen.
      error: (error, stack) => ErrorState(
        message: meLoadError(context, l10n.meEarningsLoadError),
        scope: ErrorScope.inline,
      ),
      data: (data) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _IncentiveCard(earnings: data),
          // s4 between two cards, which is The Floor's own number between its
          // plate and its lead card, with The Floor's own reason: a card has
          // an edge, so the air between two of them reads as more than the
          // same gap between two bare columns did. The s7 that used to stand
          // here was holding two unframed blocks apart by distance alone.
          SizedBox(height: context.skin.space.intraBlock),
          _StandingCard(earnings: data),
          SizedBox(height: context.skin.space.blockGap),
          SectionRule(
            l10n.meLedgerHeading,
            emptyLine: data.ledger.isEmpty ? l10n.meLedgerEmpty : null,
          ),
          if (data.ledger.isNotEmpty) ...<Widget>[
            const SizedBox(height: TiqSpace.s5),
            _Ledger(entries: data.ledger),
          ],
          SizedBox(height: context.skin.space.intraBlock),
          _HonestyLine(text: l10n.mePointsHonesty),
        ],
      ),
    );
  }
}

/// THE WAY TO CONTESTS (#124) — which lived in the nav's fourth slot until
/// Me took it back, and lives here now, beside the points it is part of.
///
/// A move, not a loss: the row opens the same standings the slot did, and it
/// wears the same running count, in words. The Me slot on the bar carries the
/// badge, so Today still says a contest is on. Pushed rather than `go`ne, so
/// back returns here instead of to Today.
class _ContestsRow extends StatelessWidget {
  const _ContestsRow({required this.running});

  final int running;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SoftRow(
      key: const ValueKey<String>('me-contests'),
      form: SoftRowForm.standalone,
      title: l10n.contestsTitle,
      subtitle: running > 0
          ? l10n.contestsRunningHint(running)
          : l10n.meContestsDetail,
      trailing: const SoftRowChevron(),
      separator: SoftRowSeparator.none,
      onTap: () => context.push('/leaderboard/contests'),
    );
  }
}

/// THE PROGRESS-TO-REWARD BAR — the most motivating element an agent sees, and
/// the one the design refuses to light.
///
/// When no scheme is running the bar does not render **at all** and a sentence
/// says so. An empty bar reads as zero progress, which is a different and
/// false statement about a month in which nothing was on offer.
///
/// ## It is in a card now — owner override, 29 September 2026
///
/// > *"lets fix this section to match the style of the app"*
///
/// The bar ran the **full content width with nothing containing it**, which
/// made it the loudest object on the screen and the wrong kind of loud: a
/// bright oatmeal rule spanning gutter to gutter reads as a *divider* rather
/// than as a meter, and it is the last instance of the "lined, rectangular
/// style" the owner had removed from the Tasks lead card on the same day.
/// Nothing else in the product draws an unframed line across the page.
///
/// **The grammar it joins is the hub's progress card** (`_ReadinessBlock` in
/// `audit_shell_screen.dart`, post-#486), which is the manager's Tasks lead
/// card wearing agent data: a `TorchCard` at radius 22, `surface`, no outline,
/// holding a figure block and one supporting sentence. A goal with progress
/// has no exact twin on the manager side, and rather than invent a fourth
/// grammar this takes that one and lets the bar occupy the figure slot — the
/// bar already draws its own label, its own fraction and the reward at the end
/// of the track, so it *is* the block, and the card is the only thing it was
/// missing.
///
/// **Nothing inside the bar changed.** It keeps its key, its milestone, its
/// `doneWord` and its one-node semantics; what it gains is the card's s4
/// padding, which is where the bleed goes. The reach-the-reward state, the
/// hatched state and the amber ledger (unify §1.1 puts the target tick in
/// ink-1, so this screen is 0) are all untouched.
class _IncentiveCard extends StatelessWidget {
  const _IncentiveCard({required this.earnings});

  final MyEarnings earnings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final scheme = earnings.focusScheme;

    if (scheme == null) {
      // THE ABSENCE GETS THE CARD TOO. The sentence is the whole content of
      // the incentive slot when nothing is running, and a sentence lying on
      // the ground between two cards is the same complaint one object down.
      // It stays prose and stays at body weight: it is an explanation, not a
      // figure that has gone missing.
      return TorchCard(
        key: const ValueKey<String>('me-incentive'),
        child: Text(
          l10n.meNoScheme,
          style: skin.text.body.style(color: skin.palette.ink2),
        ),
      );
    }

    final progress = earnings.progressFor(scheme) ?? 0;
    final reward = scheme.rewardDetail?.trim().isNotEmpty == true
        ? scheme.rewardDetail!.trim()
        : l10n.meRewardPoints(scheme.rewardPoints);
    final number = TiqNumber.of(context);
    final valueText = number.format(progress, decimals: 0);
    final totalText = number.format(scheme.threshold, decimals: 0);
    final reached = progress >= scheme.threshold;
    final remaining = (scheme.threshold - progress).clamp(0, double.infinity);
    final line = reached
        ? l10n.meRewardReached(reward)
        : l10n.meRewardToGo(number.format(remaining, decimals: 0), reward);

    return TorchCard(
      key: const ValueKey<String>('me-incentive'),
      child: Semantics(
        container: true,
        label: l10n.meRewardSemantics(valueText, totalText, line),
        excludeSemantics: true,
        child: TorchProgressBar(
          key: const ValueKey<String>('reward-bar'),
          label: scheme.name,
          value: progress,
          total: scheme.threshold,
          state: reached ? ProgressState.complete : ProgressState.determinate,
          fractionText: l10n.meRewardProgress(valueText, totalText),
          // The reward is named at the END of the bar, which is the whole
          // point of the component: an agent walking to a taxi wants the
          // thing, not the arithmetic.
          milestones: <ProgressMilestone>[
            ProgressMilestone(at: scheme.threshold, label: line, reward: true),
          ],
          doneWord: reward,
        ),
      ),
    );
  }
}

/// POINTS, with RANK subordinate to it — the manager's lead card, on the
/// agent's own record.
///
/// ## Owner override, 29 September 2026 — this stops being two peers
///
/// > *"lets fix this section to match the style of the app"*
///
/// It was a [StatCluster] of two [StatTile]s **on the bare ground**, above a
/// ledger of cards, with a large empty gap on either side — so the screen read
/// as two designs stacked, unframed figures over framed rows, with the seam
/// halfway down. Two further faults came with the form and are worth naming
/// because neither is visible in a code review:
///
/// * a tile carries its own 20dp field-density inset, so `POINTS ALL TIME`
///   started **20dp to the right of every other left edge on the screen** —
///   the "second, invisible gutter" [StatTile.padding]'s own doc warns about;
/// * a two-tile cluster on a 390dp phone goes to [StatCluster]'s grid, which
///   draws a **1px `edgeStructure` rule** down the gap between the cells. That
///   is precisely the rule the owner had taken off the Tasks lead card the
///   same day — *"let's remove this lined, rectangular style"* — surviving
///   here only because it is invisible on Night.
///
/// ## Why points leads and rank is subordinate, rather than two peers
///
/// The brief asked for a judgement rather than a sweep, so: **one lead card.**
///
/// 1. **The screen already says so in words.** Its own thesis — see the class
///    comment at the top of this file — is "self-scoped, and not a
///    leaderboard": *"comparing an agent to their peers is Contests' job, and
///    it has its own tab."* Points is what this record is a record *of*; rank
///    is the one line of peer context it permits itself. Drawing them as
///    equals states the opposite of what the screen is for.
/// 2. **Rank is legitimately absent for a whole class of caller.** The server
///    answers `rank: null` to anyone not on the board, and `/me` is open to
///    managers on purpose. A peer tile that is an em dash for every manager
///    who opens the screen is not a peer.
/// 3. **It is the frozen reference's shape.** The manager's Tasks lead card
///    (`tasks_screen.dart` `_LeadBlock`) and the visit hub's readiness card
///    (`audit_shell_screen.dart` `_ReadinessBlock`, #486) are both one
///    dominant figure with its subordinates under it, **separated by a gap and
///    never by a rule**.
///
/// The figure therefore steps up from `figure.l` to `heroFigureCompact` down
/// the same measured fit chain the other two use, and rank steps down to
/// `figure.m` — which is what makes the subordination visible rather than
/// merely asserted.
///
/// ## What is deliberately absent: the mark on the eyebrow
///
/// Both reference cards put a small [SeverityMark] on the eyebrow word. This
/// one does not, and that is a decision rather than an omission. The mark is
/// the **severity** channel, and unify §1.1's ruling for this route is that it
/// claims nothing: *"the content claims nothing at all, which is the whole
/// ruling for this screen."* A career points total has no standard to be
/// measured against, so every kind in the set would be a lie — `onTarget`
/// invents a verdict, `critical` and `watch` invent a crimson one, `held`
/// means queued, and `notMeasured` is false of a figure the server measured.
/// A green circle beside POINTS ALL TIME would be this screen grading its
/// reader, which is the one thing it exists not to do.
class _StandingCard extends StatelessWidget {
  const _StandingCard({required this.earnings});

  final MyEarnings earnings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final entry = earnings.entry;
    // A measured zero is a zero: an agent who has earned nothing has earned 0,
    // and "0" is the true and useful thing to print. Null is reserved for a
    // figure nobody measured.
    final points = entry.points;
    // Null, not a sentinel. The server answers `rank: null` for a caller who
    // is not on the board — which is every caller who is not a field agent,
    // and `/me` is open to managers on purpose. It used to answer
    // `leaderboard.length + 1` and this line used to read `entry.rank > 0`
    // against a zero the server never sent, so the em-dash path was
    // unreachable and a manager was shown a fabricated place instead.
    final rank = earnings.rank;

    return TorchCard(
      key: const ValueKey<String>('me-standing'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 1. THE LABEL. Announced with the figure as one node, which is what
          //    `StatTile` did for it — an eyebrow and a numeral read out as
          //    two separate things is a screen reader listing nouns.
          Semantics(
            container: true,
            label: l10n.mePointsEyebrow,
            value: TiqNumber.of(context).format(points, decimals: 0),
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Eyebrow(l10n.mePointsEyebrow),
                const SizedBox(height: TiqSpace.s2),

                // 2. THE FIGURE. Measured down the fit chain rather than
                //    guessed at: a four-digit total gets the presence the head
                //    of the screen needs and a seven-digit one steps down on
                //    its own. `Align` bounds the slot's `LayoutBuilder` — the
                //    chain only means anything against a real width, and a
                //    stretched child would hand it the whole card.
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FigureSlot(
                    key: const ValueKey<String>('me-points-figure'),
                    value: points,
                    role: skin.text.heroFigureCompact,
                    fit: <TiqTypeToken>[
                      skin.text.heroFigureCompact,
                      skin.text.figureL,
                      skin.text.figureM,
                    ],
                    decimals: 0,
                  ),
                ),
              ],
            ),
          ),

          // 3. THE SUPPORTING LINE, where there is one. The reference cards
          //    carry one always; this figure does not need one, because
          //    "POINTS ALL TIME" over a total is the least ambiguous statement
          //    on the agent side and the header already prints "All time".
          //    A sentence written to fill a slot is padding. What survives is
          //    the one state that genuinely needs words.
          if (points == 0) ...<Widget>[
            const SizedBox(height: TiqSpace.s2),
            Text(
              l10n.meNoPointsYet,
              style: skin.text.meta.style(color: skin.palette.ink3),
            ),
          ],

          // 4. THE SUBORDINATE — a gap, not a rule.
          SizedBox(height: skin.space.intraBlock),
          _RankSubordinate(rank: rank),
        ],
      ),
    );
  }
}

/// RANK, under the points it qualifies: the label left, the figure right.
///
/// The manager's `_Subordinate` on Tasks and the hub's `_ReadinessSubordinate`
/// in one arrangement — the label `Expanded`, the figure a bounded box — which
/// is what makes a column of these align on a single right edge. A subordinate
/// never carries a severity ink: it is context for the figure above it.
///
/// **This one can admit it has no figure, and the other two cannot.** That is
/// the whole reason it is written out here rather than borrowed: the manager's
/// pair takes a non-null `int`. `rank: null` is a real and frequent answer
/// from `/gamification/me` — every caller who is not a field agent — and it
/// must still render as an **em dash with its reason beside it, never a zero
/// and never an invented place**. [FigureSlot] is where [StatTile] got that
/// behaviour from, so passing [FigureState.missing] keeps the identical
/// drawing (em dash, ink-3, the figure's own face) and the identical spoken
/// form (the reason, never the word "dash") that the tile produced.
class _RankSubordinate extends StatelessWidget {
  const _RankSubordinate({required this.rank});

  final int? rank;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final missing = rank == null;

    return Semantics(
      container: true,
      label: l10n.meRankEyebrow,
      value: missing
          ? l10n.meNotRanked
          : TiqNumber.of(context).format(rank, decimals: 0),
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Eyebrow(l10n.meRankEyebrow),
                // The words, always, when the figure is absent. An em dash on
                // its own is a puzzle; the sentence is what makes it an
                // answer. No "4 of 22" ever stands here — `GET
                // /gamification/me` returns the caller's own place and not the
                // size of the field, and a denominator this screen cannot see
                // is one it must not invent.
                if (missing)
                  Text(
                    l10n.meNotRanked,
                    style: skin.text.meta.style(color: skin.palette.ink3),
                  ),
              ],
            ),
          ),
          const SizedBox(width: TiqSpace.s3),
          FigureSlot(
            key: const ValueKey<String>('me-rank-figure'),
            value: rank,
            role: skin.text.figureM,
            decimals: 0,
            state: missing ? FigureState.missing : FigureState.measured,
            textAlign: TextAlign.end,
            semanticsLabel: missing ? l10n.meNotRanked : null,
          ),
        ],
      ),
    );
  }
}

/// THE LEDGER — where each point came from.
class _Ledger extends StatelessWidget {
  const _Ledger({required this.entries});

  final List<PointsEntry> entries;

  @override
  Widget build(BuildContext context) {

    return TorchBleed(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final (i, entry) in entries.indexed)
            _LedgerRow(entry: entry, last: i == entries.length - 1),
        ],
      ),
    );
  }
}

/// THE REASON, IN THE AGENT'S LANGUAGE.
///
/// `PointsEntry.reasonLabel` is a Dart switch returning English literals. It
/// is the right thing for the manager console, which is English-only; on this
/// screen it drew "Visit submitted" inside an otherwise Afrikaans page and
/// read it aloud inside an Afrikaans sentence — "Visit submitted, Do. 17 Sep.,
/// plus 5 punte".
///
/// The three reasons the server can write (`pointsLedger.ts`: `PointsReason`)
/// are translated. Anything else — a reason invented by a server newer than
/// this build — keeps `reasonLabel`'s untranslated wire form rather than being
/// guessed at, because a machine word shown as a machine word is honest and a
/// mistranslated one is not.
String meReasonLabel(AppLocalizations l10n, PointsEntry entry) =>
    pointsReasonLabel(l10n, entry);

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry, required this.last});

  final PointsEntry entry;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final day = formatDayShort(context, entry.occurredAt);
    final reason = meReasonLabel(l10n, entry);
    // A SCORECARD CONTRIBUTED A SCORE, NOT POINTS.
    //
    // `PointsEntry.points` is 0 for every `scorecard` row — the board adds the
    // *average* of the scores, not the rows — and roughly half an agent's
    // ledger is scorecard rows. Drawn as a delta they became a rising triangle
    // in the palette's `good` ink beside "0", and spoken as "plus 0 points": a
    // movement that did not happen, in the colour reserved for good news,
    // while the 85 that actually fed the average was thrown away. A delta
    // never stands beside nothing.
    final score = entry.reason == 'scorecard' ? entry.score : null;

    return SoftRow(
      key: ValueKey<String>('ledger-${entry.id}'),
      title: entry.outletName?.trim().isNotEmpty == true
          ? entry.outletName!
          : reason,
      titleTruncation: SoftRowTruncation.middle,
      subtitle: reason,
      leading: const RowMarkTile(mark: RowMark.disc),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (score != null)
            _LedgerScore(score: score)
          else
            _LedgerDelta(points: entry.points),
          Text(day, style: skin.text.meta.style(color: skin.palette.ink3)),
        ],
      ),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: score != null
          ? l10n.meLedgerScoreRowSemantics(
              reason,
              day,
              TiqNumber.of(context).format(score, decimals: 0),
            )
          : l10n.meLedgerRowSemantics(
              reason,
              day,
              _pointWords(l10n, entry.points),
            ),
    );
  }
}

/// "plus 5 points" / "minus 5 points". The sign in words, for the reader the
/// triangle does not reach.
String _pointWords(AppLocalizations l10n, int points) =>
    points < 0 ? l10n.mePointsMinus(points.abs()) : l10n.mePointsPlus(points);

/// The score a scorecard row fed into the average — a level, so no triangle
/// and no sentiment. `FigureSlot`, like every other figure on this screen, and
/// whole points, like every other score on it.
class _LedgerScore extends StatelessWidget {
  const _LedgerScore({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return FigureSlot(
      value: score,
      role: skin.text.figureS,
      decimals: 0,
      semanticsLabel: context.l10n.meScoredSemantics(
        TiqNumber.of(context).format(score, decimals: 0),
      ),
    );
  }
}

/// Points granted or taken back. Server sentiment, drawn: a reversal is a fall
/// and a grant is a rise, and the word in the semantics carries it for anyone
/// the triangle does not reach.
class _LedgerDelta extends StatelessWidget {
  const _LedgerDelta({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    final reversal = points < 0;
    return Delta(
      data: DeltaData(
        direction: reversal ? DeltaDirection.down : DeltaDirection.up,
        // The server's own sign, not a guess from the direction: points going
        // up is good and a reversal is bad, and this is the one place in the
        // product where those two happen to agree.
        sentiment: reversal ? TiqSentiment.bad : TiqSentiment.good,
        magnitude: points.abs(),
        decimals: 0,
      ),
      semanticsLabel: _pointWords(context.l10n, points),
    );
  }
}

/// The 44dp line under the ledger. Read, never skipped.
class _HonestyLine extends StatelessWidget {
  const _HonestyLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TiqMark(
              shape: MarkShape.heldSquare,
              color: skin.palette.ink3,
              size: MarkScale.glyph(context, 8),
            ),
          ),
          const SizedBox(width: TiqSpace.s2),
          Expanded(
            child: Text(
              text,
              style: skin.text.meta.style(color: skin.palette.ink2),
            ),
          ),
        ],
      ),
    );
  }
}

// ── MY VISITS ──────────────────────────────────────────────────────────────

/// THE AGENT'S OWN VISITS — and, since 26 September 2026, all of them.
///
/// `GET /visits/me` is a cursor-paged endpoint, `MyVisitsPage` has carried a
/// `nextCursor` since it was written, and **no widget read it**: the screen
/// rendered page one and stopped, with no footer, no action and no sentence
/// saying the list had been cut. An agent with more than a page of visits
/// simply could not see their older ones, and nothing on the screen admitted
/// it. That is the same class of loss as a filter dropped in a migration, and
/// the repair is the one `my_work_screen.dart` already uses: a
/// [PaginationFooter] that says what is shown and a ghost action that loads
/// the next page.
///
/// The summary never fabricates a total. The server returns a cursor, not a
/// count, so the line is "Showing 20. There are older visits." and not
/// "Showing 20 of 63" — a number nobody sent.
class _Visits extends ConsumerStatefulWidget {
  const _Visits({required this.visits, required this.sync});

  final AsyncValue<MyVisitsPage> visits;
  final SyncStatus sync;

  @override
  ConsumerState<_Visits> createState() => _VisitsState();
}

class _VisitsState extends ConsumerState<_Visits> {
  /// Pages two and on, in order. Page one stays in the provider so a refresh
  /// of the record refreshes the list.
  final List<MyVisit> _older = <MyVisit>[];

  /// The cursor for the page after everything loaded so far. Null once the
  /// server stops sending one, which is how the list says it has reached the
  /// end without counting anything.
  String? _cursor;
  bool _cursorRead = false;
  bool _loading = false;
  bool _failed = false;

  Future<void> _loadOlder(String cursor) async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await ref
          .read(myRecordRepositoryProvider)
          .myVisits(cursor: cursor);
      if (!mounted) return;
      setState(() {
        _older.addAll(page.visits);
        _cursor = page.nextCursor;
        _cursorRead = true;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      // The visits already on screen stay. A failed *next* page is not a
      // failed list, and throwing the loaded ones away to show an error
      // region would be the worse answer.
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visits = widget.visits;
    final sync = widget.sync;
    final l10n = context.l10n;
    final held = sync.pending.length + sync.needsAttention.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionRule(l10n.meVisitsHeading),
        const SizedBox(height: TiqSpace.s5),
        // What is on this phone and not yet on the server, said once at the
        // top rather than as a dash beside every row. Today's captures are
        // genuinely not in the server's answer, and a list that quietly
        // omitted them would be the same lie in a new place.
        if (held > 0) ...<Widget>[
          _OnThisPhone(count: held),
          SizedBox(height: context.skin.space.intraBlock),
        ],
        visits.when(
          loading: () => const SkeletonRows(count: 3),
          error: (error, stack) => ErrorState(
            message: meLoadError(context, l10n.meVisitsLoadError),
            scope: ErrorScope.inline,
          ),
          data: (page) {
            final all = <MyVisit>[...page.visits, ..._older];
            if (all.isEmpty) {
              return EmptyState(
                headline: l10n.meVisitsEmpty,
                scope: EmptyScope.inline,
                body: l10n.meVisitsEmptyDetail,
              );
            }
            // Page one's cursor until something older has been loaded, then
            // the last page's. `_cursorRead` is the difference between "not
            // asked yet" and "the server sent none", which is the same
            // unknown-versus-zero distinction the figures make.
            final next = _cursorRead ? _cursor : page.nextCursor;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _VisitList(visits: all),
                if (next != null || _failed) ...<Widget>[
                  SizedBox(height: context.skin.space.intraBlock),
                  PaginationFooter(
                    summary: l10n.meVisitsShowing(all.length),
                    narrowLine: _failed ? l10n.meVisitsMoreFailed : null,
                    action: next == null
                        ? null
                        : TorchTertiaryButton(
                            key: const ValueKey<String>('me-show-older'),
                            label: l10n.meVisitsShowOlder,
                            busy: _loading,
                            onPressed: _loading ? null : () => _loadOlder(next),
                          ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _OnThisPhone extends StatelessWidget {
  const _OnThisPhone({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SoftRow(
      key: const ValueKey<String>('on-this-phone'),
      form: SoftRowForm.standalone,
      density: SoftRowDensity.tall,
      title: l10n.meOnThisPhone(count),
      subtitle: l10n.meOnThisPhoneDetail,
      // Oatmeal square. Held work is the normal state of South African field
      // connectivity and it is never crimson.
      leading: const RowMarkTile(mark: RowMark.square),
      separator: SoftRowSeparator.none,
    );
  }
}

class _VisitList extends StatelessWidget {
  const _VisitList({required this.visits});

  final List<MyVisit> visits;

  @override
  Widget build(BuildContext context) {
    return TorchBleed(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final (i, visit) in visits.indexed)
            _VisitRow(visit: visit, last: i == visits.length - 1),
        ],
      ),
    );
  }
}

/// ONE VISIT — the proof, and the number.
class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.visit, required this.last});

  final MyVisit visit;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final score = visit.score;
    final day = formatDayShort(context, visit.checkinTs);
    final dwell = visit.dwellMinutes == null
        ? l10n.meDwellUnknown
        : l10n.meDwellMinutes(visit.dwellMinutes!);
    final tasks = l10n.meTasksRaised(visit.tasksRaised);
    final scoreWords = score == null
        ? l10n.meNotScoredYet
        : l10n.meScoredSemantics(
            TiqNumber.of(context).format(score.weightedTotal, decimals: 0),
          );

    final row = SoftRow(
      key: ValueKey<String>('my-visit-${visit.id}'),
      density: SoftRowDensity.tall,
      title: visit.outletName,
      titleTruncation: SoftRowTruncation.middle,
      subtitle: l10n.meVisitMeta(day, dwell, tasks),
      meta: _VisitEvidence(visit: visit),
      // A scored visit gets its band's silhouette; an unscored one gets the
      // barred ring — the fourth silhouette, not a hatch, because a 3dp stripe
      // inside a 28dp tile aliases to a flat grey disc at 40% backlight.
      leading: RowMarkTile(
        mark: score == null ? RowMark.barredRing : RowMark.disc,
        semanticLabel: scoreWords,
      ),
      trailing: _VisitScore(visit: visit),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      // The row excludes its children's semantics, so the evidence line has
      // to be in this sentence or a screen reader never hears it — and the
      // out-of-fence fact is the one this record most owes its agent.
      semanticsLabel: <String>[
        l10n.meVisitSemantics(visit.outletName, day, dwell, tasks, scoreWords),
        ..._VisitEvidence.facts(l10n, visit),
      ].join('. '),
    );

    // The reconciliation line belongs to the visit's record permanently and is
    // never dismissible: it is still there when this visit is read months
    // later. It sits under the row rather than inside it because the sentence
    // is prose and a row's meta slot is a fact line.
    if (score == null || !score.changedSinceSeen) return row;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        row,
        Padding(
          padding: EdgeInsets.fromLTRB(
            skin.space.gutter,
            0,
            skin.space.gutter,
            skin.space.intraBlock,
          ),
          child: ReconciliationLine(
            key: ValueKey<String>('reconciled-${visit.id}'),
            finalValue: score.weightedTotal.round(),
            seenValue: score.seen!.weightedTotal.round(),
            voice: ReconciliationVoice.agent,
            decimals: 0,
            // The same agent string set the visit outcome screen speaks
            // (unify §1.20: one component, two string sets), so a score that
            // moved reads the same on the way out of the shop and a month on.
            reason: l10n.outcomeReconciledReason,
            strings: ReconciliationStrings(
              agentLead: l10n.outcomeReconciledLead,
              agentTail: l10n.outcomeReconciledTail,
            ),
            semanticsLabel: l10n.outcomeReconciledSemantics(
              score.weightedTotal.round(),
              score.seen!.weightedTotal.round(),
            ),
          ),
        ),
      ],
    );
  }
}

/// The evidence line: how far from the door, how much was captured, and any
/// standing fact about the visit.
///
/// A fraud flag is shown to the agent **as a fact**, because a record they
/// cannot read is the thing this screen exists to end. It is never crimson and
/// never a verdict: out of fence is a distance, and reviewed is an event.
class _VisitEvidence extends StatelessWidget {
  const _VisitEvidence({required this.visit});

  final MyVisit visit;

  /// The same facts in words, in the order they are drawn, for the row's one
  /// screen-reader sentence.
  static List<String> facts(AppLocalizations l10n, MyVisit visit) {
    final distance = visit.checkinDistanceM;
    return <String>[
      l10n.meCapturedCount(
        visit.sectionsCaptured,
        visit.sectionsTotal,
        visit.photos,
      ),
      if (!visit.geofencePass)
        '${l10n.meOutOfFence}, ${distance == null ? l10n.meDistanceUnknown : l10n.meDistanceMeters(distance.round())}',
      if (visit.reviewedVerdict != null) l10n.meReviewed,
      if (visit.pinReported) l10n.mePinReported,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final distance = visit.checkinDistanceM;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          l10n.meCapturedCount(
            visit.sectionsCaptured,
            visit.sectionsTotal,
            visit.photos,
          ),
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
        if (!visit.geofencePass || visit.reviewedVerdict != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s2),
          Wrap(
            spacing: TiqSpace.s2,
            runSpacing: TiqSpace.s2,
            children: <Widget>[
              if (!visit.geofencePass)
                FlagChip(
                  kind: FlagKind.outOfFence,
                  label: l10n.meOutOfFence,
                  detail: distance == null
                      ? l10n.meDistanceUnknown
                      : l10n.meDistanceMeters(distance.round()),
                ),
              if (visit.reviewedVerdict != null)
                FlagChip(kind: FlagKind.forReview, label: l10n.meReviewed),
            ],
          ),
        ],
        // Their own claim that the pin was wrong (#386), said as what they
        // did: it is why a visit they were let into still reads out of fence.
        // Prose, not a chip — it is not a flag on them.
        if (visit.pinReported) ...<Widget>[
          const SizedBox(height: TiqSpace.s2),
          Text(
            l10n.mePinReported,
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
        ],
      ],
    );
  }
}

/// The score, or the sentence that stands in for it.
///
/// **Never a bare em dash.** An unscored visit is not a visit that scored
/// nothing, and a dash on its own is a puzzle rather than an answer.
class _VisitScore extends StatelessWidget {
  const _VisitScore({required this.visit});

  final MyVisit visit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final score = visit.score;

    if (score == null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 96),
        child: Text(
          visit.submitted ? l10n.meNotScoredYet : l10n.meVisitOpen,
          textAlign: TextAlign.end,
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
      );
    }

    return FigureSlot(
      value: score.weightedTotal,
      role: skin.text.figureM,
      decimals: 0,
      semanticsLabel: l10n.meScoredSemantics(
        TiqNumber.of(context).format(score.weightedTotal, decimals: 0),
      ),
    );
  }
}

// ── SKELETON ───────────────────────────────────────────────────────────────

/// The real geometry, empty — never a spinner and never a `well` block at
/// 1.12:1 that nobody can see.
///
/// **The heights and the gap are measured off the arriving cards**, not
/// guessed: 88dp for the incentive card and 141dp for the standing one at
/// 390×844 in Night, with the s4 of ground between them that the loaded screen
/// uses. They were 72/96 separated by s7, which described the two unframed
/// blocks this section used to be, so the skeleton was drawing a layout that
/// no longer arrives — the placeholder jumping on load is the one thing §1.11
/// exists to prevent.
///
/// The material does **not** follow the cards. §1.3's 29 September override is
/// explicit that a skeleton keeps radius 14 and a 1px `edgeStructure` outline
/// even where the arriving object is an outline-less card, because a `surface`
/// fill on the Night ground is 1.49:1 — one quantisation level on a 6-bit
/// panel at 40% backlight, which is a placeholder nobody can see.
class _EarnedSkeleton extends StatelessWidget {
  const _EarnedSkeleton();

  @override
  Widget build(BuildContext context) {
    // The skeleton stands at the real geometry, so it takes the real gaps:
    // the two cards are one block apart and the ledger below them is a block
    // away. It loses `const` to read them, which is the cost of the placeholder
    // moving when the rhythm moves instead of drifting away from it.
    final space = context.skin.space;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SkeletonShell(height: 88),
        SizedBox(height: space.intraBlock),
        const SkeletonShell(height: 141),
        SizedBox(height: space.blockGap),
        const SkeletonRows(count: 2),
      ],
    );
  }
}
