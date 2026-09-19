import 'dart:async' show unawaited;

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/torch_scope.dart';
import '../../../core/network/human_error.dart';
import '../../../core/theme/torchlight/agent_skin.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/agent_location_banners.dart';
import '../../../core/widgets/agent_kit.dart';
import '../../../core/widgets/agent_motion.dart';
import '../../../core/widgets/agent_scaffold.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/check_in_radar.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/skin_controls.dart';
import '../../../core/widgets/torchlight/sync_status.dart';
import '../../../l10n/l10n.dart';
import '../../beatplans/presentation/today_screen.dart' show displayFor;
import '../../outlets/data/outlets_repository.dart';
import '../data/pin_report.dart';
import '../data/template_section_repository.dart';
import '../data/visit_progress.dart';
import '../data/visits_repository.dart';
import 'sections/client_questions_screen.dart';
import 'sections/s10_scorecard_screen.dart';
import 'sections/s1_outlet_info_screen.dart';
import 'sections/s2_stock_screen.dart';
import 'sections/s3_4_visibility_display_screen.dart';
import 'sections/s5_pricing_promotions_screen.dart';
import 'sections/s6_competitive_screen.dart';
import 'sections/s7_capability_screen.dart';
import 'sections/s8_risks_screen.dart';
import 'sections/s9_action_plan_screen.dart';
import 'submit_gate_screen.dart';

/// THE VISIT — check-in, and then the hub.
///
/// ## No tabs, one primary
///
/// The owner's decision, and the reason this screen is not a tab root:
/// mid-visit navigation loses captured work. From the moment the agent is
/// inside the fence there is one way forward — finish the sections — and one
/// commit, in the thumb zone where a hand holding a crate can reach it.
///
/// ```text
///   Kasi Corner Spaza            [ 12 held on this phone ]
///   In store 12 min
///   ┌───────────────────────────────────────────┐
///   │ CAPTURED                                  │
///   │ 5 /8        ( 3 sections still needed )   │
///   │ ▬▬▬▬▬▬▬▬▬▬▬▬▬░░░░░░░░░░░░░                │
///   └───────────────────────────────────────────┘
///   Do them in any order. Everything saves as you go.
///   ── Sections ────────────────────────────────
///   ◉ Outlet info           Confirmed at check-in
///   ◑ Stock & availability  7 of 12    [Required]
///   ⊘ Pricing               The product list did not load
///   ⊘ Score                 Worked out when the visit sends   —
///   ─────────────────────────────────────────────
///   Stock and Pricing still need finishing.
///   [ ☾ ] [        Submit this visit        ]
/// ```
///
/// ## Amber
///
/// An untabbed route, so the content has two grants in Night — and the hub
/// spends at most one of them, deliberately: it is a reading screen. **A
/// blocked submit emits nothing.** It does not declare a claim at all, so the
/// screen paints zero amber objects while it is blocked and exactly one when
/// it is armed. The readiness chip, the state glyphs, the REQUIRED badges, the
/// section rule and the meter's fill are all labels, and the law bans amber
/// from every one of them by name.
///
/// ## Can't confirm (#389)
///
/// A section the app could not establish shows the fourth silhouette — a
/// barred ring, not a hatch — names the reason in words, and **blocks the
/// submit**. Before this, a stock section with the product list missing
/// reported *done* on zero captures, and a visit with nothing in it went
/// through the gate printing "This store is clean".
class AuditShellScreen extends ConsumerStatefulWidget {
  const AuditShellScreen({super.key, required this.outletId});

  final String outletId;

  /// The submit's claim id. Declared only when the visit can actually be sent.
  static const String submitClaimId = 'visit-submit';

  /// The check-in screens' primary. One id across the three failures: only
  /// one of them is ever on screen, and a census failure names the phase.
  static const String retryClaimId = 'check-in-retry';

  /// The locating radar's live pulse — rung 6, presence and never progress.
  static const String locatingClaimId = 'check-in-locating';

  @override
  ConsumerState<AuditShellScreen> createState() => _AuditShellScreenState();
}

class _AuditShellScreenState extends ConsumerState<AuditShellScreen> {
  bool _checkInStarted = false;
  CheckInResult? _checkInResult;
  DateTime? _checkinTs;
  String? _visitDraftId;

  /// How many times this agent has asked for a fix at this outlet in this
  /// session. The too-far screen's note changes on the third attempt — the
  /// moment the penalty actually starts, and not before.
  int _attempts = 0;

  /// When the last failure happened, for the error-code line.
  DateTime? _failedAt;

  Future<void> _startCheckIn(double outletLat, double outletLng) async {
    // The repository is written not to throw, but this is the one place where
    // a throw is invisible: it happens inside a post-frame callback, so it
    // goes to the console and the screen simply stays on the locating radar —
    // "still looking for you" long after the app has stopped looking. The
    // catch is what guarantees this screen always leaves the loading state.
    CheckInResult result;
    try {
      result = await ref
          .read(visitsRepositoryProvider)
          .checkIn(
            outletId: widget.outletId,
            outletLat: outletLat,
            outletLng: outletLng,
          );
    } catch (error, stack) {
      debugPrint('Check-in threw for outlet ${widget.outletId}: $error\n$stack');
      result = CheckInFailed(HumanError.of(error));
    }
    if (!mounted) return;
    if (result case CheckInSucceeded(:final visitId)) {
      // Pin the client's audit template to this visit (#122), once, so its
      // questions cannot change mid-visit and reopen without signal.
      //
      // #389: the failure is no longer swallowed. A pin that throws sets a
      // flag the hub reads, and the client-questions row renders
      // **can't confirm** and blocks the submit — rather than vanishing and
      // taking the client's questions silently with it.
      unawaited(
        ref
            .read(templateSectionRepositoryProvider)
            .pinForVisit(visitId)
            .catchError((Object e) {
              debugPrint('Template pin failed for $visitId: $e');
              if (!mounted) return;
              ref.read(templatePinFailedProvider.notifier).failed(visitId);
            }),
      );
    }
    setState(() {
      _checkInResult = result;
      if (result is CheckInSucceeded) {
        _checkinTs = DateTime.now();
        _visitDraftId = result.visitId;
      } else {
        _failedAt = DateTime.now();
      }
    });
  }

  /// Retry resets the whole state machine **including the started flag**, so
  /// the post-frame call actually fires again.
  void _retry() => setState(() {
    _checkInStarted = false;
    _checkInResult = null;
    _attempts += 1;
  });

  Outlet? _findOutlet(List<Outlet> outlets) {
    for (final outlet in outlets) {
      if (outlet.id == widget.outletId) return outlet;
    }
    return null;
  }

  Widget _sectionBody(AuditSection section, String visitDraftId) {
    return switch (section) {
      AuditSection.outletInfo => S1OutletInfoScreen(checkinTs: _checkinTs),
      AuditSection.stock => S2StockScreen(
        visitDraftId: visitDraftId,
        outletId: widget.outletId,
      ),
      AuditSection.visibility => S3S4VisibilityDisplayScreen(
        visitDraftId: visitDraftId,
      ),
      AuditSection.pricing => S5PricingPromotionsScreen(
        visitDraftId: visitDraftId,
        outletId: widget.outletId,
      ),
      AuditSection.competitive => S6CompetitiveScreen(
        visitDraftId: visitDraftId,
      ),
      AuditSection.capability => S7CapabilityScreen(visitDraftId: visitDraftId),
      AuditSection.risks => S8RisksScreen(visitDraftId: visitDraftId),
      AuditSection.actionPlan => S9ActionPlanScreen(
        visitDraftId: visitDraftId,
        outletId: widget.outletId,
      ),
      AuditSection.score => S10ScorecardScreen(visitDraftId: visitDraftId),
    };
  }

  /// One section, full screen. It slides in from the right, which says "you
  /// have gone *into* something and can come back out" — exactly the
  /// hub/section relationship. No stagger behind it: the section arrives
  /// whole.
  void _openSection(AuditSection section, String visitDraftId) {
    Navigator.of(context).push(
      agentSectionRoute<void>(
        _SectionScreen(
          title: sectionLabel(context.l10n, section),
          child: _sectionBody(section, visitDraftId),
        ),
      ),
    );
  }

  void _openTemplateSection(ClientTemplate template, String visitDraftId) {
    Navigator.of(context).push(
      agentSectionRoute<void>(
        _SectionScreen(
          title: template.name,
          child: ClientQuestionsScreen(
            visitDraftId: visitDraftId,
            template: template,
          ),
        ),
      ),
    );
  }

  /// Everything still blocking the submit, **by name**: the fixed sections,
  /// then the client's questions.
  List<String> _blockingNames(AppLocalizations l10n, VisitProgress progress) => [
    for (final s in progress.blocking) sectionLabel(l10n, s),
    if (progress.templateBlocking)
      progress.template?.template.name ?? l10n.visitClientQuestions,
  ];

  /// Submitting is irreversible and it raises tasks against a real shop. It
  /// does not happen on one tap of a hub button — the agent gets to see what
  /// they are about to say about this store, and confirm it.
  Future<void> _openSubmitGate(Outlet outlet) async {
    final id = _visitDraftId;
    if (id == null) return;

    final confirmed = await Navigator.of(context).push<bool>(
      agentSectionRoute<bool>(
        SubmitGateScreen(
          visitDraftId: id,
          outletId: outlet.id,
          outletName: outlet.name,
          checkinTs: _checkinTs,
          onConfirm: () => Navigator.of(context).pop(true),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(visitsRepositoryProvider).submitVisit(id);
    if (!mounted) return;

    // The visit is done. Let them feel it — they are about to walk out of the
    // shop and will not be looking at the screen.
    TorchBuzz.success();
    context.go(
      '/audit/${outlet.id}/done?draft=$id&name=${Uri.encodeComponent(outlet.name)}',
    );
  }

  @override
  Widget build(BuildContext context) => TorchlightRoute(child: _body());

  Widget _body() {
    final outletsAsync = ref.watch(outletsListProvider);
    final l10n = context.l10n;

    return outletsAsync.when(
      loading: () => VisitFrame(
        phase: 'outlet-loading',
        title: l10n.visitStartingTitle,
        showSyncChip: false,
        children: const <Widget>[_HubSkeleton()],
      ),
      error: (err, _) => VisitFrame(
        phase: 'outlet-error',
        title: l10n.visitTitle,
        showSyncChip: false,
        children: <Widget>[
          _Statement(
            glyph: Icons.link_off,
            headline: l10n.visitCheckInFailedTitle,
            body: l10n.visitOutletLoadFailed('$err'),
            actionLabel: l10n.visitBackToRoute,
            onAction: () => context.go('/today'),
          ),
        ],
      ),
      data: (outlets) {
        final outlet = _findOutlet(outlets);
        if (outlet == null) {
          return VisitFrame(
            phase: 'outlet-missing',
            title: l10n.visitTitle,
            showSyncChip: false,
            children: <Widget>[
              _Statement(
                glyph: Icons.link_off,
                headline: l10n.visitOutletNotFound,
                body: l10n.todayPickStore,
                actionLabel: l10n.visitBackToRoute,
                onAction: () => context.go('/today'),
              ),
            ],
          );
        }

        if (!_checkInStarted) {
          _checkInStarted = true;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _startCheckIn(outlet.lat, outlet.lng),
          );
        }

        return switch (_checkInResult) {
          null => _CheckingIn(outlet: outlet),
          CheckInSucceeded() => _hub(outlet),
          CheckInGeofenceFailed(:final distanceMeters) => _TooFar(
            outlet: outlet,
            distanceMeters: distanceMeters,
            attempts: _attempts,
            onRetry: _retry,
          ),
          final CheckInLocationUnavailable unavailable => _NoGps(
            outlet: outlet,
            message: unavailable.messageIn(l10n),
            problem: unavailable.problem,
            onRetry: _retry,
          ),
          CheckInFailed(:final reason) => _SomethingElse(
            outlet: outlet,
            reason: reason,
            failedAt: _failedAt,
            onRetry: _retry,
          ),
        };
      },
    );
  }

  /// The hub's rows, in order: S1–S9, then the client's questions when the
  /// visit has a template (#122), then the score — the RESULT of the
  /// captures, so it stays last and is not a form.
  List<_HubEntry> _entries(VisitProgress progress, String visitDraftId) {
    final l10n = context.l10n;
    _HubEntry fixed(AuditSection section) {
      final state = progress.stateOf(section);
      final reason = progress.cantConfirm[section];
      return _HubEntry(
        tileKey: 'section-${section.name}',
        label: sectionLabel(l10n, section),
        state: state,
        detail: reason != null
            ? cantConfirmText(l10n, reason)
            : progress.detailIn(section, l10n),
        required: section.required,
        isScore: section == AuditSection.score,
        onTap: section == AuditSection.score
            ? null
            : () => _openSection(section, visitDraftId),
      );
    }

    final template = progress.template;
    return <_HubEntry>[
      for (final section in AuditSection.values)
        if (section != AuditSection.score) fixed(section),
      if (template != null)
        _HubEntry(
          tileKey: 'section-clientQuestions',
          label: template.template.name,
          state: template.state,
          detail: template.detailIn(l10n),
          required: template.isRequired,
          isScore: false,
          onTap: () => _openTemplateSection(template.template, visitDraftId),
        )
      else if (progress.templateCantConfirm != null)
        _HubEntry(
          tileKey: 'section-clientQuestions',
          label: l10n.visitClientQuestions,
          state: CaptureState.cantConfirm,
          detail: cantConfirmText(l10n, progress.templateCantConfirm!),
          required: true,
          isScore: false,
          // Nothing to open: the questions are what could not be loaded.
          onTap: null,
        ),
      fixed(AuditSection.score),
    ];
  }

  Widget _hub(Outlet outlet) {
    final visitDraftId = _visitDraftId!;
    final l10n = context.l10n;
    final progressAsync = ref.watch(
      visitProgressProvider((
        visitDraftId: visitDraftId,
        outletId: widget.outletId,
      )),
    );

    return progressAsync.when(
      loading: () => VisitFrame(
        phase: 'hub-loading',
        title: outlet.name,
        facts: <String>[?_inStore(l10n, _checkinTs)],
        children: const <Widget>[_HubSkeleton()],
      ),
      // The chrome renders, the ladder becomes an error line with a retry, and
      // the submit stays disabled naming why. A hub that cannot read its own
      // progress must never offer to send it.
      error: (err, _) => VisitFrame(
        phase: 'hub-error',
        title: outlet.name,
        facts: <String>[?_inStore(l10n, _checkinTs)],
        submit: TorchPrimaryButton(
          claimId: AuditShellScreen.submitClaimId,
          label: l10n.visitSubmitButton,
          onPressed: null,
          blockedReason: l10n.visitReadFailedBlock,
        ),
        children: <Widget>[
          _Statement(
            glyph: Icons.link_off,
            headline: l10n.visitReadFailedTitle,
            body: l10n.visitReadFailed('$err'),
            actionLabel: l10n.visitRetry,
            onAction: () => ref.invalidate(
              visitProgressProvider((
                visitDraftId: visitDraftId,
                outletId: widget.outletId,
              )),
            ),
          ),
        ],
      ),
      data: (progress) {
        final blocking = _blockingNames(l10n, progress);
        final entries = _entries(progress, visitDraftId);
        final ready = progress.canSubmit;
        final skin = context.skin;

        return VisitFrame(
          phase: ready ? 'ready' : 'blocked',
          title: outlet.name,
          facts: <String>[?_inStore(l10n, _checkinTs)],
          // ARMED or nothing. A disabled primary declares no claim, so a
          // blocked hub paints zero amber objects — and the census is what
          // proves that rather than this comment.
          claimSubmit: ready,
          submit: TorchPrimaryButton(
            key: const ValueKey<String>('submit-visit'),
            claimId: AuditShellScreen.submitClaimId,
            label: l10n.visitSubmitButton,
            onPressed: ready ? () => _openSubmitGate(outlet) : null,
            // The BarNote names every blocker by name, wrapping, never
            // truncated. A dead end in a shop is a phone call to the office.
            blockedReason: ready
                ? null
                : l10n.visitFinishToSubmit(
                    blocking.reduce((a, b) => l10n.visitSectionsAnd(a, b)),
                  ),
          ),
          children: <Widget>[
            _ReadinessBlock(progress: progress),
            const SizedBox(height: TiqSpace.s7),
            // Promoted from meta at the bottom: the agent needs to know this
            // before they start choosing, not after they have finished.
            Text(
              l10n.visitAnyOrderHint,
              style: skin.text.label.style(color: skin.palette.ink2),
            ),
            const SizedBox(height: TiqSpace.s5),
            SectionRule(l10n.visitAuditHeading),
            const SizedBox(height: TiqSpace.s5),
            TorchBleed(
              extra: skin.space.gutter * 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final (i, entry) in entries.indexed)
                    _SectionRow(entry: entry, last: i == entries.length - 1),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The frame every untabbed visit screen wears.
///
/// One shell, one bottom region: the thumb zone, with the skin cycle at the
/// leading gutter and at most one primary beside it. There is no nav here by
/// the owner's decision, so `tabbedRoute` is false and the content has two
/// grants in Night — which every screen in this file spends at most one of.
class VisitFrame extends StatelessWidget {
  const VisitFrame({
    super.key,
    required this.phase,
    required this.title,
    required this.children,
    this.facts = const <String>[],
    this.submit,
    this.secondary,
    this.claimSubmit = false,
    this.claimId = AuditShellScreen.submitClaimId,
    this.pulseId,
    this.showSyncChip = true,
  });

  final String phase;
  final String title;
  final List<String> facts;
  final List<Widget> children;

  /// The thumb zone's primary, or null on a screen that has none.
  final Widget? submit;

  /// The ghost above it. It sits above rather than below because the thumb
  /// rests at the bottom of the screen and a control that leaves the visit
  /// must never be the bottom-most thing under it.
  final Widget? secondary;

  /// Whether the primary is armed. A primary that is disabled declares
  /// nothing — that is the whole of "a disabled submit emits nothing".
  final bool claimSubmit;

  final String claimId;

  /// The live pulse, when this screen has one (the locating radar).
  final String? pulseId;

  /// Suppressed on the check-in screens: nothing has been captured yet, so
  /// "12 held on this phone" is true but is not about this moment.
  final bool showSyncChip;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return TorchScope(
      skin: skin,
      phase: phase,
      navRenders: false,
      tabbedRoute: false,
      claims: <TorchClaim>[
        if (claimSubmit) TorchClaim.primaryCommit(claimId),
        if (pulseId != null) TorchClaim.livePulse(pulseId!),
      ],
      child: TorchShell(
        profile: TorchShellProfile.agent,
        header: TorchAppHeader(
          title: title,
          facts: facts,
          flagChips: showSyncChip
              ? const <Widget>[TorchSyncChip()]
              : const <Widget>[],
        ),
        // Not a tab root, so the cycle sits at the leading end of the thumb
        // zone — on every screen here including the ones with no primary.
        // Never a screen without the skin cycle.
        skinCycle: const AgentSkinCycle(),
        primary: submit,
        secondary: secondary,
        // Whether the agent is being located has an answer on every agent
        // screen (#153, POPIA) — see AgentLocationBanners.
        children: <Widget>[const AgentLocationBanners(), ...children],
      ),
    );
  }
}

/// THE READINESS BLOCK — "5 / 8", and what is still needed, in words.
class _ReadinessBlock extends StatelessWidget {
  const _ReadinessBlock({required this.progress});

  final VisitProgress progress;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final done = progress.doneCount;
    final total = progress.captureCount;
    final blocking = progress.blockingCount;
    final unconfirmed = progress.cantConfirmCount;
    final ready = blocking == 0;

    return Semantics(
      container: true,
      label: l10n.visitReadinessSemantics(done, total, blocking),
      excludeSemantics: true,
      child: Container(
        key: const ValueKey<String>('visit-progress'),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Eyebrow(l10n.visitSectionsCaptured),
            const SizedBox(height: TiqSpace.s3),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: TiqSpace.s3,
              runSpacing: TiqSpace.s2,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    FigureSlot(value: done, role: skin.text.figureL),
                    Padding(
                      padding: const EdgeInsets.only(bottom: TiqSpace.s1),
                      child: Text(
                        '/$total',
                        style: skin.text.figureM.style(color: skin.palette.ink3),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: TiqSpace.s1),
                  child: StatusChip(
                    level: ready ? StatusLevel.onTarget : StatusLevel.watch,
                    label: ready
                        ? l10n.visitReadyToSubmit
                        : l10n.visitStillRequired(blocking),
                  ),
                ),
              ],
            ),
            if (unconfirmed > 0) ...<Widget>[
              const SizedBox(height: TiqSpace.s2),
              Text(
                // Two facts, not one figure. A section nobody could measure is
                // not a section somebody skipped.
                l10n.visitCantConfirmCount(unconfirmed),
                style: skin.text.meta.style(color: skin.palette.ink2),
              ),
            ],
            const SizedBox(height: TiqSpace.s4),
            Meter(
              value: total == 0 ? 0 : done / total * 100,
              semanticsValue: l10n.visitReadinessSemantics(
                done,
                total,
                blocking,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One entry on the hub — a fixed section, the client's questions (#122), or
/// the score.
class _HubEntry {
  const _HubEntry({
    required this.tileKey,
    required this.label,
    required this.state,
    required this.detail,
    required this.required,
    required this.isScore,
    required this.onTap,
  });

  final String tileKey;
  final String label;
  final CaptureState state;
  final String? detail;

  /// Whether the submit waits on it.
  final bool required;
  final bool isScore;
  final VoidCallback? onTap;
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.entry, required this.last});

  final _HubEntry entry;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;

    // THE SCORE ROW. A result, not a form: a barred-ring tile, an em dash, no
    // chevron, no tap — and NOT at reduced opacity, because opacity is banned
    // as a state channel and a dimmed row reads as a disabled one.
    if (entry.isScore) {
      return SoftRow(
        key: ValueKey<String>(entry.tileKey),
        title: entry.label,
        subtitle: l10n.visitScoreCalculatedOnSubmit,
        leading: const RowMarkTile(mark: RowMark.barredRing),
        trailing: Text(
          emDash,
          style: skin.text.figureM.style(color: skin.palette.ink3),
        ),
        separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
        semanticsLabel: l10n.visitScoreSemantics(entry.label),
      );
    }

    final state = torchStateOf(entry.state);
    final showRequired = entry.required && entry.state != CaptureState.done;
    // The fallback is the STATE's word, not "Not started": a done section
    // with no captured count used to read "Stock & availability / Not
    // started" beside a green tick, which is the row disagreeing with itself.
    // Only a section that genuinely has not been opened gets the
    // not-started / optional pair.
    final detail =
        entry.detail ??
        (entry.state == CaptureState.notStarted
            ? (entry.required
                  ? l10n.visitSectionNotStarted
                  : l10n.visitSectionOptional)
            : SectionStateToken.of(skin, state).word);

    return SoftRow(
      key: ValueKey<String>(entry.tileKey),
      title: entry.label,
      subtitle: detail,
      leading: SectionStateGlyph(state: state, required_: showRequired),
      // The REQUIRED badge sits under the name. Crimson at the outlined
      // commitment level plus a silhouette plus the word — a standing fact
      // about the row, and never carried by the hue alone.
      meta: showRequired
          ? Align(
              alignment: AlignmentDirectional.centerStart,
              child: StatusChip(
                level: StatusLevel.watch,
                label: l10n.visitRequiredToSubmitBadge,
              ),
            )
          : null,
      trailing: entry.onTap == null ? null : const SoftRowChevron(),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: l10n.visitSectionSemantics(
        entry.label,
        SectionStateToken.of(skin, state).word,
        detail,
      ),
      onTap: entry.onTap,
    );
  }
}

/// The data layer's [CaptureState] as the design system's four silhouettes.
SectionState torchStateOf(CaptureState state) => switch (state) {
  CaptureState.notStarted => SectionState.notStarted,
  CaptureState.partial => SectionState.inProgress,
  CaptureState.done => SectionState.done,
  CaptureState.cantConfirm => SectionState.cantConfirm,
};

/// Why a section could not be confirmed, in the agent's language.
String cantConfirmText(AppLocalizations l10n, CantConfirmReason reason) =>
    switch (reason) {
      CantConfirmReason.productListUnavailable => l10n.visitCantConfirmProducts,
      CantConfirmReason.clientTemplateUnavailable =>
        l10n.visitCantConfirmTemplate,
    };

/// A section, full screen, with its own way back to the hub.
///
/// Still [AgentScaffold], deliberately: the section forms are the stock
/// counter, the photo capture and the trough inputs, and all three are Phase 2
/// components another workstream owns. A Torchlight frame around a Lumen form
/// is worse than either, so the frame moves when the fields do.
class _SectionScreen extends StatelessWidget {
  const _SectionScreen({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AgentScaffold(
      title: title,
      subtitle: l10n.visitSectionSavesAsYouGo,
      onBack: () => Navigator.of(context).pop(),
      bottomAction: AgentButton(
        label: l10n.visitSectionDoneBack,
        onPressed: () => Navigator.of(context).pop(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: child,
      ),
    );
  }
}

// ── Check-in states ────────────────────────────────────────────────────────

/// LOCATING. Waiting for a fix in a way that says *we are looking for you*,
/// not *something is happening*.
///
/// There is no primary action while waiting and the zone does not pretend
/// there is: the skin cycle and a real escape, and nothing else. With no
/// primary, a screen-reader user's last stop is a way out.
class _CheckingIn extends StatelessWidget {
  const _CheckingIn({required this.outlet});

  final Outlet outlet;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;

    return VisitFrame(
      phase: 'locating',
      title: outlet.name,
      facts: <String>[outlet.code],
      showSyncChip: false,
      pulseId: AuditShellScreen.locatingClaimId,
      secondary: TorchSecondaryButton(
        label: l10n.visitBackToRoute,
        onPressed: () => context.go('/today'),
      ),
      children: <Widget>[
        Semantics(
          liveRegion: true,
          label: l10n.visitCheckInFinding,
          child: const SizedBox(width: double.infinity, height: 0),
        ),
        const CheckInRadar(
          claimId: AuditShellScreen.locatingClaimId,
          stalled: false,
        ),
        const SizedBox(height: TiqSpace.s6),
        Semantics(
          header: true,
          child: Text(
            l10n.visitCheckInFinding,
            style: displayFor(
              context,
              l10n.visitCheckInFinding,
            ).style(color: skin.palette.ink1),
          ),
        ),
        const SizedBox(height: TiqSpace.s3),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            l10n.visitCheckInWithinHint,
            style: skin.text.body.style(color: skin.palette.ink2),
          ),
        ),
      ],
    );
  }
}

/// TOO FAR. How far away the agent actually is, and what retrying from the car
/// park actually costs.
class _TooFar extends ConsumerWidget {
  const _TooFar({
    required this.outlet,
    required this.distanceMeters,
    required this.attempts,
    required this.onRetry,
  });

  final Outlet outlet;
  final double distanceMeters;
  final int attempts;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final skin = context.skin;
    final metres = distanceMeters.round();
    final reported =
        ref.watch(pinReportsProvider).contains(outlet.id);

    return VisitFrame(
      phase: 'too-far',
      title: outlet.name,
      facts: <String>[outlet.code],
      showSyncChip: false,
      claimSubmit: true,
      claimId: AuditShellScreen.retryClaimId,
      submit: TorchPrimaryButton(
        key: const ValueKey<String>('checkin-retry'),
        claimId: AuditShellScreen.retryClaimId,
        label: l10n.visitRetry,
        onPressed: onRetry,
      ),
      secondary: TorchSecondaryButton(
        label: l10n.visitBackToRoute,
        onPressed: () => context.go('/today'),
      ),
      children: <Widget>[
        Eyebrow(l10n.visitCheckInEyebrow),
        const SizedBox(height: TiqSpace.s3),
        Semantics(
          header: true,
          child: Text(
            l10n.visitTooFarTitle,
            style: displayFor(
              context,
              l10n.visitTooFarTitle,
            ).style(color: skin.palette.ink1),
          ),
        ),
        const SizedBox(height: TiqSpace.s6),

        // THE MEASURED DISTANCE as the hero.
        _DistanceHero(metres: metres),

        const SizedBox(height: TiqSpace.s6),
        Text(
          // First and second attempt: the fact, with no threat attached. The
          // penalty sentence arrives on the third, which is where the penalty
          // actually starts — the app stops encouraging the behaviour at the
          // same moment it starts charging for it.
          attempts >= 2
              ? l10n.visitTooFarFraudNote
              : l10n.visitTooFarAttemptsRecorded,
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
        const SizedBox(height: TiqSpace.s6),

        // THE THIRD, QUIETER ACTION (#386). An agent standing at the front
        // door of a shop the app says is 180 m away is telling us something
        // true. There is nowhere to send it yet, so it is recorded on the
        // phone and the screen says exactly that — never "we'll look into it".
        if (reported)
          Row(
            key: const ValueKey<String>('pin-reported'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const RowMarkTile(mark: RowMark.square),
              const SizedBox(width: TiqSpace.s3),
              Expanded(
                child: Text(
                  l10n.visitPinReportedHeld,
                  style: skin.text.body.style(color: skin.palette.ink2),
                ),
              ),
            ],
          )
        else
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TorchTertiaryButton(
              key: const ValueKey<String>('pin-is-wrong'),
              label: l10n.visitPinIsWrong,
              onPressed: () =>
                  ref.read(pinReportsProvider.notifier).report(outlet.id),
            ),
          ),
      ],
    );
  }
}

/// The distance, as the one thing this screen is about.
///
/// The FIGURE is ink-1. A severity-coded figure at 56px is a hue doing a
/// number's job — the severity is the 3px bar, the filled triangle and the
/// sentence, all three of which survive greyscale.
class _DistanceHero extends StatelessWidget {
  const _DistanceHero({required this.metres});

  final int metres;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    // Veld's hairline is 2px everywhere else, and its severity bar is 4.
    final barWidth = skin.mode == SkinMode.veld ? 4.0 : 3.0;

    return Semantics(
      container: true,
      label: l10n.visitTooFarSemantics(metres),
      excludeSemantics: true,
      child: Container(
        key: const ValueKey<String>('checkin-distance'),
        decoration: BoxDecoration(
          color: skin.palette.surface,
          borderRadius: BorderRadius.circular(skin.radii.panel),
          border: Border.all(
            color: skin.palette.edgeStructure,
            width: skin.depth.borderWidth,
          ),
          boxShadow: skin.depth.shadows,
        ),
        // The severity bar is an OVERLAY, not a stretch child of a Row inside
        // an `IntrinsicHeight` — the same reason `StatCluster`'s rule is one.
        // A `FigureSlot` measures itself with a `LayoutBuilder`, a
        // `LayoutBuilder` cannot answer an intrinsic query, and
        // `IntrinsicHeight` over one throws at layout: *"LayoutBuilder does
        // not support returning intrinsic dimensions"*. The whole too-far
        // screen went down with it, which is how this was found.
        child: Stack(
          children: <Widget>[
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                barWidth + TiqSpace.s4,
                TiqSpace.s4,
                TiqSpace.s4,
                TiqSpace.s4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TiqMark(
                        shape: MarkShape.criticalTriangle,
                        color: skin.palette.bad,
                        size: MarkScale.glyph(context, 12),
                      ),
                      const SizedBox(width: TiqSpace.s2),
                      Eyebrow(l10n.visitCheckInEyebrow),
                    ],
                  ),
                  const SizedBox(height: TiqSpace.s3),
                  FigureSlot(
                    value: metres,
                    role: skin.text.heroFigureCompact,
                    fit: <TiqTypeToken>[
                      skin.text.heroFigureCompact,
                      skin.text.display,
                      skin.text.figureL,
                    ],
                    unit: TiqUnit.worded(l10n.unitMetres),
                    semanticsLabel: l10n.visitTooFarSemantics(metres),
                  ),
                  const SizedBox(height: TiqSpace.s3),
                  Text(
                    metres < 80
                        ? l10n.visitTooFarClose
                        : metres > 2000
                        ? l10n.visitTooFarWrongStore
                        : l10n.visitTooFarNeedWithin(metres),
                    style: skin.text.body.style(color: skin.palette.ink2),
                  ),
                ],
              ),
            ),
            PositionedDirectional(
              top: 0,
              bottom: 0,
              start: 0,
              width: barWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: skin.palette.bad,
                  borderRadius: BorderRadiusDirectional.horizontal(
                    start: Radius.circular(skin.radii.panel),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// NO GPS. "Your phone cannot see the sky" is not "you are in the wrong
/// place", and the fix is different.
class _NoGps extends StatelessWidget {
  const _NoGps({
    required this.outlet,
    required this.message,
    required this.problem,
    required this.onRetry,
  });

  final Outlet outlet;
  final String message;
  final CheckInLocationProblem? problem;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    // The fix, as its own paragraph, per cause. "Open settings" as a real deep
    // link is a follow-up — there is no settings channel on this codebase
    // today, and "go to settings" with no link is an instruction, not a fix —
    // so the primary is the retry the app can actually perform. See the PR.
    final fix = switch (problem) {
      CheckInLocationProblem.permissionDenied => l10n.visitNoGpsFixPermission,
      CheckInLocationProblem.servicesDisabled => l10n.visitNoGpsFixServices,
      CheckInLocationProblem.timedOut => l10n.visitNoGpsFixTimedOut,
      CheckInLocationProblem.failed || null => l10n.visitNoGpsFixGeneric,
    };

    return VisitFrame(
      phase: 'no-gps',
      title: outlet.name,
      facts: <String>[outlet.code],
      showSyncChip: false,
      claimSubmit: true,
      claimId: AuditShellScreen.retryClaimId,
      submit: TorchPrimaryButton(
        key: const ValueKey<String>('checkin-retry'),
        claimId: AuditShellScreen.retryClaimId,
        label: l10n.visitRetry,
        onPressed: onRetry,
      ),
      secondary: TorchSecondaryButton(
        label: l10n.visitBackToRoute,
        onPressed: () => context.go('/today'),
      ),
      children: <Widget>[
        // A line drawing, never a warning triangle: this is a missing
        // capability, not a severity, and it is never red.
        ExcludeSemantics(
          child: Icon(
            Icons.satellite_alt_outlined,
            size: 64,
            color: skin.palette.edgeControl,
          ),
        ),
        const SizedBox(height: TiqSpace.s6),
        Semantics(
          header: true,
          child: Text(
            l10n.visitNoLocationTitle,
            style: displayFor(
              context,
              l10n.visitNoLocationTitle,
            ).style(color: skin.palette.ink1),
          ),
        ),
        const SizedBox(height: TiqSpace.s3),
        // Reason and fix are separate paragraphs, so a reader can get the fix
        // without re-hearing the diagnosis.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            message,
            style: skin.text.body.style(color: skin.palette.ink2),
          ),
        ),
        const SizedBox(height: TiqSpace.s3),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            fix,
            style: skin.text.body.style(color: skin.palette.ink2),
          ),
        ),
        const SizedBox(height: TiqSpace.s6),
        Text(
          l10n.visitCheckInFailedNothingLost,
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
      ],
    );
  }
}

/// SOMETHING ELSE. The app failed, not the agent — and the failure is
/// reportable.
class _SomethingElse extends StatelessWidget {
  const _SomethingElse({
    required this.outlet,
    required this.reason,
    required this.failedAt,
    required this.onRetry,
  });

  final Outlet outlet;
  final HumanError reason;
  final DateTime? failedAt;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final at = failedAt;
    final code = 'checkin/${reason.name}${at == null ? '' : ' · ${_hhmm(at)}'}';

    return VisitFrame(
      phase: 'check-in-failed',
      title: outlet.name,
      facts: <String>[outlet.code],
      showSyncChip: false,
      claimSubmit: true,
      claimId: AuditShellScreen.retryClaimId,
      submit: TorchPrimaryButton(
        key: const ValueKey<String>('checkin-retry'),
        claimId: AuditShellScreen.retryClaimId,
        label: l10n.visitRetry,
        onPressed: onRetry,
      ),
      secondary: TorchSecondaryButton(
        label: l10n.visitBackToRoute,
        onPressed: () => context.go('/today'),
      ),
      children: <Widget>[
        ExcludeSemantics(
          child: Icon(Icons.link_off, size: 64, color: skin.palette.edgeControl),
        ),
        const SizedBox(height: TiqSpace.s6),
        Semantics(
          header: true,
          child: Text(
            l10n.visitCheckInFailedTitle,
            style: displayFor(
              context,
              l10n.visitCheckInFailedTitle,
            ).style(color: skin.palette.ink1),
          ),
        ),
        const SizedBox(height: TiqSpace.s3),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            // The humanised message, never a stack trace.
            reason.message(l10n),
            style: skin.text.body.style(color: skin.palette.ink2),
          ),
        ),
        const SizedBox(height: TiqSpace.s4),
        // The one thing an agent can do for a failure they cannot fix is tell
        // someone precisely.
        _CodeBlock(code: code),
        const SizedBox(height: TiqSpace.s6),
        Text(
          // The difference between retrying and giving up on the shop.
          l10n.visitCheckInFailedNothingLost,
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
      ],
    );
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    return Container(
      key: const ValueKey<String>('checkin-error-code'),
      padding: const EdgeInsets.symmetric(
        horizontal: TiqSpace.s3,
        vertical: TiqSpace.s2,
      ),
      decoration: BoxDecoration(
        // Veld's `well` is white and its border is 2px #1B2632, so the block
        // loses its fill and gains an edge without a branch here.
        color: skin.palette.well,
        borderRadius: BorderRadius.circular(skin.radii.control),
        border: Border.all(
          color: skin.palette.edgeStructure,
          width: skin.depth.borderWidth,
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              // Spelled character by character: a machine code read as a word
              // is a code nobody can repeat down a phone.
              label: l10n.visitErrorCodeSemantics(code.split('').join(' ')),
              excludeSemantics: true,
              child: Text(
                code,
                style: skin.text.monoIdent.style(color: skin.palette.ink2),
              ),
            ),
          ),
          const SizedBox(width: TiqSpace.s2),
          TorchTertiaryButton(
            label: l10n.visitCopyCode,
            semanticLabel: l10n.visitCopyCodeSemantics,
            onPressed: () => Clipboard.setData(ClipboardData(text: code)),
          ),
        ],
      ),
    );
  }
}

/// A drawing, a headline, a sentence and a way on. The whole-screen statement
/// grammar: left-aligned to the gutter, never centred, and no animation.
class _Statement extends StatelessWidget {
  const _Statement({
    required this.glyph,
    required this.headline,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData glyph;
  final String headline;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ExcludeSemantics(
          child: Icon(glyph, size: 64, color: skin.palette.edgeControl),
        ),
        const SizedBox(height: TiqSpace.s6),
        Semantics(
          header: true,
          child: Text(
            headline,
            style: displayFor(context, headline).style(color: skin.palette.ink1),
          ),
        ),
        const SizedBox(height: TiqSpace.s3),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            body,
            style: skin.text.body.style(color: skin.palette.ink2),
          ),
        ),
        if (actionLabel != null && onAction != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s6),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TorchSecondaryButton(
              label: actionLabel!,
              onPressed: onAction,
            ),
          ),
        ],
      ],
    );
  }
}

/// The skeleton: the real geometry, empty. Not a spinner.
class _HubSkeleton extends StatelessWidget {
  const _HubSkeleton();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(skin.radii.panel),
            border: Border.all(
              color: skin.palette.edgeStructure,
              width: skin.depth.borderWidth,
            ),
          ),
        ),
        const SizedBox(height: TiqSpace.s7),
        for (var i = 0; i < 5; i++) ...<Widget>[
          SizedBox(
            height: TiqSpace.s5,
            child: ColoredBox(color: skin.palette.edgeStructure),
          ),
          const SizedBox(height: TiqSpace.s6),
        ],
      ],
    );
  }
}

/// A section's name in the active language. [AuditSection.label] stays the
/// data layer's English identifier.
String sectionLabel(AppLocalizations l10n, AuditSection section) =>
    switch (section) {
      AuditSection.outletInfo => l10n.visitSectionOutletInfo,
      AuditSection.stock => l10n.visitSectionStock,
      AuditSection.visibility => l10n.visitSectionVisibility,
      AuditSection.pricing => l10n.visitSectionPricing,
      AuditSection.competitive => l10n.visitSectionCompetitive,
      AuditSection.capability => l10n.visitSectionCapability,
      AuditSection.risks => l10n.visitSectionRisks,
      AuditSection.actionPlan => l10n.visitSectionActionPlan,
      AuditSection.score => l10n.visitSectionScore,
    };

/// "In store 12 min" — how long since check-in, on the same scale as
/// [formatAgo] (just now / min / h / d).
String? _inStore(AppLocalizations l10n, DateTime? checkinTs) {
  if (checkinTs == null) return null;
  final d = DateTime.now().difference(checkinTs);
  if (d.inSeconds < 60) return l10n.visitInStoreJustNow;
  if (d.inMinutes < 60) return l10n.visitInStoreMinutes(d.inMinutes);
  if (d.inHours < 24) return l10n.visitInStoreHours(d.inHours);
  return l10n.visitInStoreDays(d.inDays);
}
