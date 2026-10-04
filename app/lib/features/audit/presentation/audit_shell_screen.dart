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
import '../../../core/format/relative_time.dart';
import '../../../core/widgets/agent_motion.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/card.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/check_in_radar.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/sync_status.dart';
import '../../../l10n/l10n.dart';
import '../../beatplans/presentation/today_screen.dart' show displayFor;
import '../../outlets/data/outlets_repository.dart';
import '../data/photos_repository.dart';
import '../data/template_section_repository.dart';
import '../data/visit_progress.dart';
import '../data/visits_repository.dart';
import 'pin_dispute_view.dart';
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
///   │ ▲ SECTIONS CAPTURED                       │
///   │ 5 /8                                      │
///   │ 3 still required                          │
///   │ CAN’T CONFIRM                          1  │
///   └───────────────────────────────────────────┘
///   Do them in any order. Everything saves as you go.
///   THE AUDIT
///   ┌───────────────────────────────────────────┐
///   │ ◉  Outlet info      Confirmed at check-in │
///   └───────────────────────────────────────────┘
///   ┌───────────────────────────────────────────┐
///   │ ● ◑  Stock & availability                 │
///   │      7 of 12                              │
///   │      ▲ Required to submit                 │
///   └───────────────────────────────────────────┘
///   ┌───────────────────────────────────────────┐
///   │ ⊘  Score            Worked out on send  — │
///   └───────────────────────────────────────────┘
///   Stock and Pricing still need finishing.
///   [ ☾ ] [        Submit this visit        ]
/// ```
///
/// ## The composition, amended 29 September 2026
///
/// The owner, a third time: *"Match the manager side please"*, and — resending
/// the approved mockup — *"Look at this and please focus"*. The two previous
/// rounds changed the chips and then the glyph tiles, one shared widget at a
/// time, and the verdict was *"Literally you didnt change anything"*. The
/// remaining difference was never the corner radius; it was the arrangement.
///
/// Three things in the diagram above are new, and each one is the manager's
/// Tasks page rather than an invention:
///
/// * **the lead card leads** — a mark on the eyebrow, one very large figure,
///   one supporting sentence, then label-left / figure-right subordinates,
///   with no meter and no rules. See `_ReadinessBlock`;
/// * **a row's severity is a small dot plus a word**, not a full-size crimson
///   chip carrying `REQUIRED TO SUBMIT` on a line of its own;
/// * **no chevrons**. Eight of them down a ladder read as a settings list.
///
/// ## Amber
///
/// An untabbed route, so the content has two grants in Night — and the hub
/// spends at most one of them, deliberately: it is a reading screen. **A
/// blocked submit emits nothing.** It does not declare a claim at all, so the
/// screen paints zero amber objects while it is blocked and exactly one when
/// it is armed — the armed `Submit visit`, which is the only object here a
/// thumb commits with. The state glyphs, the severity marks, the section
/// marker and every figure are labels, and the law bans amber from all of
/// them by name.
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

  /// "Start the visit, flagged" on the wrong-pin report (#386).
  static const String pinDisputeClaimId = 'pin-dispute-file';

  /// The storefront photo a wrong-pin report carries rides the ordinary photo
  /// pipeline under this section — the backend's `PIN_DISPUTE_PHOTO_SECTION`.
  static const String pinDisputePhotoSection = 'pin_dispute';

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

  /// The failed check-in the agent is reporting a wrong pin against (#386),
  /// while the report screen is up. Null everywhere else.
  CheckInGeofenceFailed? _disputing;

  /// Why the last attempt to start a flagged visit failed, in words.
  String? _disputeError;

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
      debugPrint(
        'Check-in threw for outlet ${widget.outletId}: $error\n$stack',
      );
      result = CheckInFailed(HumanError.of(error));
    }
    if (!mounted) return;
    _land(result);
  }

  /// Everything that follows a check-in result, whichever way it was reached.
  void _land(CheckInResult result) {
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

  void _openDispute(CheckInGeofenceFailed failure) => setState(() {
    _disputing = failure;
    _disputeError = null;
  });

  void _cancelDispute() => setState(() {
    _disputing = null;
    _disputeError = null;
  });

  /// "The pin is wrong" — start the visit outside the fence, flagged, with the
  /// failed check-in's own position as the evidence (#386).
  ///
  /// The photo is queued only once the visit exists, against its local id, so
  /// it waits in the outbox behind the check-in exactly as a section photo
  /// does. A photo that fails to queue does not un-start the visit: the
  /// position and the distance are the evidence, the photo is the extra.
  Future<void> _fileDispute(PinDisputeFiling filing) async {
    final failure = _disputing;
    final lat = failure?.lat;
    final lng = failure?.lng;
    if (failure == null || lat == null || lng == null) return;
    final l10n = context.l10n;

    CheckInResult result;
    try {
      result = await ref
          .read(visitsRepositoryProvider)
          .checkInDisputingPin(
            outletId: widget.outletId,
            lat: lat,
            lng: lng,
            distanceMeters: failure.distanceMeters,
            note: filing.note,
            // The fix's own quality travels with the claim: a manager may end
            // up moving the outlet's pin onto this coordinate (#386).
            accuracyM: failure.accuracyM,
            isMocked: failure.isMocked,
          );
    } catch (error) {
      result = CheckInFailed(HumanError.of(error));
    }
    if (!mounted) return;

    if (result is! CheckInSucceeded) {
      setState(
        () => _disputeError = switch (result) {
          CheckInFailed(:final reason) => reason.message(l10n),
          _ => l10n.visitCheckInFailedTitle,
        },
      );
      return;
    }

    final photo = filing.photo;
    if (photo != null) {
      try {
        await ref
            .read(queuedPhotosRepositoryProvider)
            .queuePhoto(
              visitDraftId: result.visitId,
              section: AuditShellScreen.pinDisputePhotoSection,
              dataUrl: photo.dataUrl,
              gpsTag: photo.gpsTag,
              capturedAt: photo.capturedAt,
              source: photo.source.name,
            );
      } catch (error) {
        debugPrint('Storefront photo not queued for ${result.visitId}: $error');
      }
      if (!mounted) return;
    }

    _disputing = null;
    _disputeError = null;
    _land(result);
  }

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
  ///
  /// The section owns its own frame now. Every capture screen is a
  /// [SectionForm], which carries the header, the thumb zone, the skin cycle
  /// and its own `TorchScope` — so the hub hands it the route and nothing
  /// else, and there is no wrapper left to disagree with it about a title or a
  /// bottom region.
  void _openSection(AuditSection section, String visitDraftId) {
    Navigator.of(
      context,
    ).push(agentSectionRoute<void>(_sectionBody(section, visitDraftId)));
  }

  void _openTemplateSection(ClientTemplate template, String visitDraftId) {
    Navigator.of(context).push(
      agentSectionRoute<void>(
        ClientQuestionsScreen(visitDraftId: visitDraftId, template: template),
      ),
    );
  }

  /// Everything still blocking the submit, **by name**: the fixed sections,
  /// then the client's questions.
  List<String> _blockingNames(AppLocalizations l10n, VisitProgress progress) =>
      [
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

        // Each screen of the check-in gets its own subtree. They all wear a
        // VisitFrame, so without a key Flutter reuses one shell's state across
        // them — and its scroll offset with it: the report, opened from a
        // too-far screen scrolled down to its third action, arrived scrolled,
        // and the hub after it opened with its flags above the fold (#386).
        final disputing = _disputing;
        if (disputing != null && _checkInResult is CheckInGeofenceFailed) {
          return KeyedSubtree(
            key: const ValueKey<String>('visit-screen-pin-dispute'),
            child: PinDisputeView(
              outlet: outlet,
              failure: disputing,
              error: _disputeError,
              onFile: _fileDispute,
              onCancel: _cancelDispute,
            ),
          );
        }

        final result = _checkInResult;
        return KeyedSubtree(
          key: ValueKey<String>(switch (result) {
            null => 'visit-screen-locating',
            CheckInOverridden() => 'visit-screen-hub-flagged',
            CheckInSucceeded() => 'visit-screen-hub',
            CheckInGeofenceFailed() => 'visit-screen-too-far',
            CheckInLocationUnavailable() => 'visit-screen-no-gps',
            CheckInFailed() => 'visit-screen-failed',
          }),
          child: switch (result) {
            null => _CheckingIn(outlet: outlet),
            CheckInSucceeded() => _hub(outlet),
            final CheckInGeofenceFailed failure => _TooFar(
              outlet: outlet,
              failure: failure,
              attempts: _attempts,
              onRetry: _retry,
              onDisputePin: () => _openDispute(failure),
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
          },
        );
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
    // A visit started over a wrong pin says so on every hub frame, loading and
    // failed included. The flags are facts about the visit, not about how well
    // the hub is reading right now.
    final result = _checkInResult;
    final flags = result is CheckInOverridden
        ? overrideFlagChips(context, result)
        : const <Widget>[];
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
        flags: flags,
        facts: <String>[?_inStore(l10n, _checkinTs)],
        children: const <Widget>[_HubSkeleton()],
      ),
      // The chrome renders, the ladder becomes an error line with a retry, and
      // the submit stays disabled naming why. A hub that cannot read its own
      // progress must never offer to send it.
      error: (err, _) => VisitFrame(
        phase: 'hub-error',
        title: outlet.name,
        flags: flags,
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
          flags: flags,
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
            SizedBox(height: skin.space.blockGap),
            // Promoted from meta at the bottom: the agent needs to know this
            // before they start choosing, not after they have finished.
            Text(
              l10n.visitAnyOrderHint,
              style: skin.text.label.style(color: skin.palette.ink2),
            ),
            SizedBox(height: skin.space.blockGap),
            SectionRule(l10n.visitAuditHeading),
            const SizedBox(height: TiqSpace.s5),
            TorchBleed(
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
    this.flags = const <Widget>[],
  });

  final String phase;
  final String title;
  final List<String> facts;

  /// Flag chips about this visit — out of fence, pin reported (#386) — in the
  /// header's capped wrap, after the sync chip.
  final List<Widget> flags;
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
          // The sync chip is pinned to the title row, not dropped into the
          // flag wrap: it is a fact about the phone rather than about this
          // visit, and in the wrap it took a 48dp row of its own under the
          // outlet's subtitle on every screen of a visit.
          status: showSyncChip ? const TorchSyncChip() : null,
          flagChips: flags,
        ),
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
///
/// ## It leads now — 29 September 2026
///
/// The owner, for the third time, on the agent side: *"Match the manager side
/// please"*, and — sending the approved mockup again — *"Look at this and
/// please focus"*. The verdict on the two previous rounds, which fixed the
/// chips and then the glyph tiles, was *"Literally you didnt change
/// anything"*, and it was fair: both rounds changed what the objects were made
/// of and neither changed how they were arranged.
///
/// This block is arranged the way the manager's Tasks lead card is arranged,
/// because that card is the frozen reference and this is its closest
/// analogue — a worklist with a figure at the head of it:
///
/// 1. an **eyebrow with a small mark on the word**, never a mark in a gutter
///    of its own;
/// 2. one **very large luminous figure**, `heroFigureCompact` measured down a
///    fit chain, in `ink1` — the denominator stays `figureM` in `ink3`, which
///    is the mockup's `5` at 26 over `/9` at 15 in `#A79E8C`;
/// 3. **one supporting sentence at meta weight**;
/// 4. **subordinate figures as label-left / figure-right pairs**, separated by
///    a gap and never by a rule.
///
/// ## What came off, and where each fact went
///
/// **The chip beside the figure.** A `StatusChip` at full size, bottom-aligned
/// against the numeral, was the loudest object in the card and the first thing
/// the eye landed on — a red rectangle winning against the number it was
/// supposed to qualify. Its exact words are the supporting line now
/// ([AppLocalizations.visitStillRequired], [AppLocalizations.visitReadyToSubmit]
/// — the same two strings, not a rewrite), and its standing is the
/// [SeverityMark] on the eyebrow. Three channels become two smaller ones that
/// sit where the manager's do.
///
/// **The meter.** A track under the figure is a fourth drawing of `4 / 7`,
/// and it is a horizontal line across a card in the exact place the owner had
/// the Tasks card's rules removed from (*"let's remove this lined, rectangular
/// style"*). The fraction is the progress. The spoken value is unchanged:
/// `visitReadinessSemantics` is on the container, not on the track.
///
/// **The can't-confirm sentence** becomes a subordinate pair, which is the
/// manager's form for a figure that qualifies the lead one. The count and the
/// words both survive.
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
      // The can't-confirm count is spoken here or nowhere: the container
      // excludes its children, so the pair beneath the figure is drawn and not
      // announced. It used to be drawn as a sentence and not announced either
      // — this is the fact arriving in the spoken label rather than leaving it.
      label: <String>[
        l10n.visitReadinessSemantics(done, total, blocking),
        if (unconfirmed > 0) l10n.visitCantConfirmCount(unconfirmed),
      ].join('. '),
      excludeSemantics: true,
      // A CARD, since 29 September 2026. It lost its shadow on 26 September
      // and kept the standalone row's material — radius 14, `surface`, a 1px
      // `edgeStructure` rim — directly above a list of radius-22 section cards
      // with no outline. It is the figure block at the top of an agent screen,
      // which is the same job The Floor's lead card does, and The Floor's is a
      // `TorchCard`.
      child: TorchCard(
        key: const ValueKey<String>('visit-progress'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // 1. THE LABEL, with the silhouette on the word rather than in a
            //    gutter of its own beside the figure.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SeverityMark(
                  kind: ready
                      ? SeverityMarkKind.onTarget
                      : SeverityMarkKind.critical,
                ),
                const SizedBox(width: 6),
                Flexible(child: Eyebrow(l10n.visitSectionsCaptured)),
              ],
            ),
            const SizedBox(height: TiqSpace.s2),

            // 2. THE FIGURE, and the denominator it is read against. The
            //    numerator is `Flexible`, which is what bounds the slot's
            //    `LayoutBuilder` — the fit chain only means anything against a
            //    real width, and an unbounded one always picks the largest.
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Flexible(
                  child: FigureSlot(
                    key: const ValueKey<String>('visit-progress-figure'),
                    value: done,
                    role: skin.text.heroFigureCompact,
                    fit: <TiqTypeToken>[
                      skin.text.heroFigureCompact,
                      skin.text.figureL,
                      skin.text.figureM,
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: TiqSpace.s2),
                  child: Text(
                    '/$total',
                    style: skin.text.figureM.style(color: skin.palette.ink3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: TiqSpace.s2),

            // 3. THE SUPPORTING LINE — the chip's own two strings, at the
            //    weight the manager's "Past the deadline and still open."
            //    carries.
            Text(
              ready ? l10n.visitReadyToSubmit : l10n.visitStillRequired(blocking),
              key: const ValueKey<String>('visit-progress-standing'),
              style: skin.text.meta.style(color: skin.palette.ink3),
            ),

            // 4. THE SUBORDINATE. Two facts, not one figure: a section nobody
            //    could measure is not a section somebody skipped.
            if (unconfirmed > 0) ...<Widget>[
              SizedBox(height: skin.space.intraBlock),
              _ReadinessSubordinate(
                key: const ValueKey<String>('visit-progress-cant-confirm'),
                label: l10n.visitCantConfirmLabel,
                value: unconfirmed,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One subordinate figure under the lead one: the label left, the figure
/// right, on one row.
///
/// The manager's `_Subordinate` on Tasks, in the one arrangement that makes a
/// column of these align on a single right edge — the label is `Expanded` and
/// the figure is a bounded box. A subordinate never carries a severity ink: it
/// is context for the figure above it, and a second coloured number in one
/// card makes the reader hunt for which one the card is about.
class _ReadinessSubordinate extends StatelessWidget {
  const _ReadinessSubordinate({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(child: Eyebrow(label)),
        const SizedBox(width: TiqSpace.s3),
        FigureSlot(
          value: value,
          role: skin.text.figureM,
          textAlign: TextAlign.end,
        ),
      ],
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
      leading: SectionStateGlyph(state: state),
      // THE SEVERITY IS A SMALL DOT PLUS A WORD — 29 September 2026, matching
      // the manager's rows. `watch` puts an outlined crimson dot in the lane
      // the whole ladder already reserves, so no row shifts and the column
      // stays a column.
      severity: showRequired ? SoftRowSeverity.watch : SoftRowSeverity.none,
      severityLabel: showRequired ? l10n.visitRequiredToSubmit : null,
      // The detail sits at META, not at body. The surface says "name at
      // title.m wrapping to 2, detail at meta 12 with figures in mono" — it
      // was a `body` 15 subtitle, a second prose voice under every rung of an
      // eight-rung ladder, which is 15dp a row an agent scrolls past nine
      // times a store.
      //
      // THE REQUIRED CHIP IS GONE. It was a `StatusChip(watch)` carrying five
      // words — `REQUIRED TO SUBMIT` — on its own line under every unfinished
      // row, and on a blocked hub that is four of them stacked down a phone.
      // The fact was already being made three times: in that chip, in the
      // count at the head of the screen, and in the blocking sentence under
      // the primary that names every waiting section **by name**. The Tasks
      // work deleted a section header for exactly this (a marker repeating the
      // chip above it), and the approved mockup draws this marker as a tiny
      // outlined mono pill rather than a full-size chip.
      //
      // What survives is the manager's own channel set, at the manager's
      // scale: the dot in the lane, a small [SeverityMark] on the line, and
      // the word in crimson beside the state. Three channels, none of them a
      // rectangle, and the sentence under the primary is untouched.
      //
      // The standing takes a line of its own beneath the detail rather than
      // riding the end of it. A can't-confirm section's detail is a whole
      // sentence — "The product list did not load — this section can't be
      // confirmed." — and appending to it cost the end of that sentence to an
      // ellipsis. Stacked meta lines are also what the manager's task rows do
      // with the SLA phrase, the priority and the owner.
      meta: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(detail),
          if (showRequired)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: SeverityMark(kind: SeverityMarkKind.watch),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.visitRequiredToSubmit,
                    style: skin.text.meta.style(color: skin.palette.bad),
                  ),
                ),
              ],
            ),
        ],
      ),
      // NO CHEVRON. The manager side dropped them from every row that is not
      // a page in a stack of pages, and the argument the Ask work made is the
      // one that applies hardest here: four stacked chevrons read as a
      // settings list, and this ladder shows eight. The whole card is the
      // target, it presses, and the state tile already says there is something
      // to open.
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: l10n.visitSectionSemantics(
        entry.label,
        SectionStateToken.of(skin, state).word,
        showRequired ? '$detail. ${l10n.visitRequiredToSubmit}' : detail,
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
        SizedBox(height: skin.space.blockGap),
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
        SizedBox(height: skin.space.intraBlock),
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
class _TooFar extends StatelessWidget {
  const _TooFar({
    required this.outlet,
    required this.failure,
    required this.attempts,
    required this.onRetry,
    required this.onDisputePin,
  });

  final Outlet outlet;
  final CheckInGeofenceFailed failure;
  final int attempts;
  final VoidCallback onRetry;

  /// Opens the wrong-pin report (#386).
  final VoidCallback onDisputePin;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final metres = failure.distanceMeters.round();

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
        SizedBox(height: skin.space.intraBlock),
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
        SizedBox(height: skin.space.blockGap),

        // THE MEASURED DISTANCE as the hero.
        _DistanceHero(metres: metres),

        SizedBox(height: skin.space.blockGap),
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
        SizedBox(height: skin.space.blockGap),

        // THE THIRD, QUIETER ACTION (#386). An agent standing at the front
        // door of a shop the app says is 180 m away is telling us something
        // true. It opens the report, which starts the visit OUTSIDE the fence,
        // flagged, with this failure's position and distance as the evidence
        // — never a pass. Tertiary on purpose: it must not compete with
        // walking closer, which is still the right answer most of the time.
        //
        // Beyond the distance the server accepts a report at, the action is
        // replaced by the sentence that says who can fix it. Offering a claim
        // that will be refused would queue a visit that can never sync.
        if (failure.canDisputePin)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TorchTertiaryButton(
              key: const ValueKey<String>('pin-is-wrong'),
              label: l10n.visitPinIsWrong,
              onPressed: onDisputePin,
            ),
          )
        else if (failure.lat != null)
          Text(
            l10n.visitPinTooFarToReport,
            key: const ValueKey<String>('pin-too-far-to-report'),
            style: skin.text.body.style(color: skin.palette.ink2),
          ),
      ],
    );
  }
}

/// The distance, as the one thing this screen is about.
///
/// The FIGURE is ink-1. A severity-coded figure at 56px is a hue doing a
/// number's job — the severity is the mark, the filled triangle and the
/// sentence, all three of which survive greyscale.
///
/// ## A card and a dot, since 29 September 2026
///
/// It was a radius-14 `surface` block with a 1px `edgeStructure` rim **and** a
/// 3px crimson bar running down its leading edge, and it is the exact object
/// unify §1.17 struck on the manager's Execution overview two days earlier:
/// *"a crimson rectangle among radius-22 cards"*. The same ruling gives the
/// replacement, and it is the one `SoftRowSpec` already resolves for every
/// card in the app — **the standing is the 8dp dot** (§1.3's 25 September
/// override), at the same lane, inside a card with no outline.
///
/// Nothing is lost by the trade. The bar carried crimson and a straight edge;
/// the dot carries the same crimson at the same commitment level, and the
/// triangle beside the eyebrow and the sentence under the figure were already
/// the two channels that survive greyscale, deuteranopia and a 6-bit panel.
/// What goes is a silhouette that only reads as severity on a *flush* row —
/// inside a radius-22 card it reads, as §1.3 puts it, as a scratch on the fill.
class _DistanceHero extends StatelessWidget {
  const _DistanceHero({required this.metres});

  final int metres;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    // The card's own severity geometry, resolved from the same spec every
    // list row reads — so this dot is the dot, at the lane the rows use, and
    // it grows with the text at the rate they grow at.
    final spec = SoftRowSpec.resolve(
      skin: skin,
      severity: SoftRowSeverity.critical,
      textScale: MediaQuery.textScalerOf(context).scale(1),
    );

    return Semantics(
      container: true,
      label: l10n.visitTooFarSemantics(metres),
      excludeSemantics: true,
      child: TorchCard(
        key: const ValueKey<String>('checkin-distance'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // THE STANDING, as the dot §1.3 declares — solid, because a
                // failed fence is critical and not a watch.
                Container(
                  width: spec.barWidth,
                  height: spec.barHeight,
                  decoration: BoxDecoration(
                    color: spec.barFill,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: spec.severityLane - spec.barWidth),
                TiqMark(
                  shape: MarkShape.criticalTriangle,
                  color: skin.palette.bad,
                  size: MarkScale.glyph(context, 12),
                ),
                const SizedBox(width: TiqSpace.s2),
                Eyebrow(l10n.visitCheckInEyebrow),
              ],
            ),
            SizedBox(height: skin.space.intraBlock),
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
            SizedBox(height: skin.space.intraBlock),
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
        SizedBox(height: skin.space.blockGap),
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
        SizedBox(height: skin.space.intraBlock),
        // Reason and fix are separate paragraphs, so a reader can get the fix
        // without re-hearing the diagnosis.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            message,
            style: skin.text.body.style(color: skin.palette.ink2),
          ),
        ),
        SizedBox(height: skin.space.intraBlock),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            fix,
            style: skin.text.body.style(color: skin.palette.ink2),
          ),
        ),
        SizedBox(height: skin.space.blockGap),
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
          child: Icon(
            Icons.link_off,
            size: 64,
            color: skin.palette.edgeControl,
          ),
        ),
        SizedBox(height: skin.space.blockGap),
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
        SizedBox(height: skin.space.intraBlock),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            // The humanised message, never a stack trace.
            reason.message(l10n),
            style: skin.text.body.style(color: skin.palette.ink2),
          ),
        ),
        SizedBox(height: skin.space.intraBlock),
        // The one thing an agent can do for a failure they cannot fix is tell
        // someone precisely.
        _CodeBlock(code: code),
        SizedBox(height: skin.space.blockGap),
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
        SizedBox(height: skin.space.blockGap),
        Semantics(
          header: true,
          child: Text(
            headline,
            style: displayFor(
              context,
              headline,
            ).style(color: skin.palette.ink1),
          ),
        ),
        SizedBox(height: skin.space.intraBlock),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            body,
            style: skin.text.body.style(color: skin.palette.ink2),
          ),
        ),
        if (actionLabel != null && onAction != null) ...<Widget>[
          SizedBox(height: skin.space.blockGap),
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
        // THE SKELETON KEEPS THE OUTLINE — unify §1.11, and the device floor
        // behind it: a `surface` block on the Night ground is 1.49:1 and a
        // skeleton nobody can see is worse than no skeleton.
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
        SizedBox(height: skin.space.blockGap),
        for (var i = 0; i < 5; i++) ...<Widget>[
          SizedBox(
            height: TiqSpace.s5,
            child: ColoredBox(color: skin.palette.edgeStructure),
          ),
          SizedBox(height: skin.space.blockGap),
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
