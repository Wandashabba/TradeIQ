import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tiq_number.dart';
import '../../../core/design/torch_scope.dart';
import '../../../core/network/human_error.dart';
import '../../../core/theme/torchlight/console_skin.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../../audit/data/photos_repository.dart';
import '../data/outlets_repository.dart';
import 'outlet_coordinates.dart';
import 'outlets_list_screen.dart' show formatDistance;

/// ONE STORE, and the screen where a wrong pin gets fixed (#386).
///
/// ```text
///   ← Stores
///   Kasi Corner Spaza          [ Out of fence ]
///   KCS-001 · spaza
///   ┌──────────────────────────────────────┐
///   │ ▲ Two agents reported this pin wrong │
///   └──────────────────────────────────────┘
///   ── This store ─────────────────────────
///   Store name · Latitude · Longitude · Status
///   ── Rejected check-ins  3 ──────────────
///   ▏ -26,21140, 28,04930        [Use this]
///   ▏ 8,4 km away · Thandi M
///   ── Pin reports  2 ─────────────────────
///   ── Change history ─────────────────────
///   [ ☾ ]  [            Save            ]
/// ```
///
/// Until this existed an outlet's coordinates were write-once, taken from
/// wherever the manager's phone happened to be when they submitted the create
/// form. Forty stores onboarded during a Monday planning session at the depot
/// were forty stores pinned to the depot car park, and the agent standing
/// inside one of them on Tuesday measured 8.4 km with nothing to press but
/// Retry.
///
/// **No map picker, on purpose.** #386's ruling is that manual entry plus the
/// attempt evidence covers it, and the evidence is the better half: a manager
/// guessing at a map tile is guessing, while an agent's recorded position is
/// where somebody actually stood holding the phone.
///
/// ## The amber, counted
///
/// Not a tab root: a manager came here to fix one store. The thumb zone
/// carries the one commit and Night's two content grants go to **one** object,
/// "Save". Day and Veld light the same block. Every other thing on this screen
/// that looks urgent — the reports banner, the severity on a rejected
/// check-in, the refusal on a mocked position — is crimson plus a silhouette
/// plus a word, because a count of problems is never light.
class OutletDetailScreen extends ConsumerWidget {
  const OutletDetailScreen({super.key, required this.outletId});

  /// "Save". Rung 1, and the only claim this route makes.
  static const String saveClaimId = 'outlet-detail-save';

  final String outletId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConsoleTorchlightRoute(child: _OutletDetail(outletId: outletId));
  }
}

class _OutletDetail extends ConsumerWidget {
  const _OutletDetail({required this.outletId});

  final String outletId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final detail = ref.watch(outletDetailProvider(outletId));

    return detail.when(
      loading: () => _OutletFrame(
        phase: 'loading',
        title: l10n.outletDetailTitle,
        children: <Widget>[
          Skeleton(
            label: l10n.outletDetailTitle,
            child: const SkeletonRows(count: 4, rowHeight: 72),
          ),
        ],
      ),
      error: (error, stack) => _OutletFrame(
        phase: 'error',
        title: l10n.outletDetailTitle,
        children: <Widget>[
          TorchErrorRegion(
            name: 'outlet-detail',
            child: ErrorState(
              message: TorchErrorMessage(
                kind: TorchErrorKind.unknown,
                headline: l10n.outletDetailLoadErrorHeadline,
                body: humanErrorMessage(error, l10n),
                offersRetry: true,
              ),
              drawing: EmptyDrawing.pin,
              action: TorchSecondaryButton(
                key: const ValueKey<String>('outlet-detail-retry'),
                label: l10n.outletsRetry,
                onPressed: () => ref.invalidate(outletDetailProvider(outletId)),
              ),
            ),
          ),
        ],
      ),
      data: (data) => _OutletDetailBody(detail: data),
    );
  }
}

/// The frame every state of this route wears.
class _OutletFrame extends StatelessWidget {
  const _OutletFrame({
    required this.phase,
    required this.title,
    required this.children,
    this.facts = const <String>[],
    this.flagChips = const <Widget>[],
    this.primary,
  });

  final String phase;
  final String title;
  final List<String> facts;
  final List<Widget> flagChips;
  final Widget? primary;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;

    return TorchScope(
      skin: skin,
      phase: phase,
      navRenders: false,
      tabbedRoute: false,
      claims: <TorchClaim>[
        if (primary != null)
          TorchPrimaryButton.claim(OutletDetailScreen.saveClaimId),
      ],
      child: TorchShell(
        profile: TorchShellProfile.console,
        header: TorchAppHeader(
          title: title,
          facts: facts,
          flagChips: flagChips,
          back: TorchIconButton(
            icon: Icons.arrow_back,
            semanticLabel: l10n.outletDetailBack,
            onPressed: () => context.pop(),
          ),
        ),
        skinCycle: const ConsoleSkinCycle(),
        primary: primary,
        children: children,
      ),
    );
  }
}

class _OutletDetailBody extends ConsumerStatefulWidget {
  const _OutletDetailBody({required this.detail});

  final OutletDetail detail;

  @override
  ConsumerState<_OutletDetailBody> createState() => _OutletDetailBodyState();
}

class _OutletDetailBodyState extends ConsumerState<_OutletDetailBody> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  late String _status;

  /// The check-in attempt whose position the manager chose to adopt, or null
  /// when they are typing coordinates in themselves.
  ///
  /// The two are exclusive because the backend makes them exclusive: a PATCH
  /// carrying both a typed pair and an attempt id is a 400, so that the audit
  /// trail cannot say "moved to the agent's recorded position" beside numbers
  /// that were never any agent's position.
  String? _fromAttemptId;

  /// The claim this edit answers, when the manager came here to answer one.
  String? _disputeId;

  bool _saving = false;
  final Map<String, String> _errors = <String, String>{};

  @override
  void initState() {
    super.initState();
    final outlet = widget.detail.outlet;
    _nameCtrl = TextEditingController(text: outlet.name)..addListener(_onTyped);
    _latCtrl = TextEditingController(text: outlet.lat.toString());
    _lngCtrl = TextEditingController(text: outlet.lng.toString());
    _status = outlet.status;
    // Typing over an adopted position makes it a manual correction again: the
    // server would otherwise record "moved to the agent's recorded position"
    // beside numbers nobody stood on.
    _latCtrl.addListener(_onCoordinateTyped);
    _lngCtrl.addListener(_onCoordinateTyped);
  }

  void _onTyped() => setState(() {});

  void _onCoordinateTyped() => setState(() => _fromAttemptId = null);

  @override
  void dispose() {
    _nameCtrl
      ..removeListener(_onTyped)
      ..dispose();
    _latCtrl
      ..removeListener(_onCoordinateTyped)
      ..dispose();
    _lngCtrl
      ..removeListener(_onCoordinateTyped)
      ..dispose();
    super.dispose();
  }

  /// Adopt an agent's recorded position as the new pin.
  ///
  /// The coordinates are shown so the manager can see what they are about to
  /// agree to, but they are NOT what gets sent: the request carries the
  /// attempt id and the server reads the numbers out of that row itself.
  void _useAttempt(CheckInAttemptEvidence attempt, {String? disputeId}) {
    // The listeners clear `_fromAttemptId` on every programmatic write too, so
    // the id is set after the text rather than before it.
    _latCtrl.text = attempt.lat.toString();
    _lngCtrl.text = attempt.lng.toString();
    setState(() {
      _fromAttemptId = attempt.id;
      _disputeId = disputeId ?? _disputeId;
    });
  }

  bool get _complete =>
      _nameCtrl.text.trim().isNotEmpty &&
      double.tryParse(_latCtrl.text.trim()) != null &&
      double.tryParse(_lngCtrl.text.trim()) != null;

  Future<void> _save() async {
    final l10n = context.l10n;
    final errors = <String, String>{};
    if (_nameCtrl.text.trim().isEmpty) errors['name'] = l10n.outletRequired;
    final lat = validateCoordinate(l10n, _latCtrl.text, latitude: true);
    final lng = validateCoordinate(l10n, _lngCtrl.text, latitude: false);
    if (lat != null) errors['lat'] = lat;
    if (lng != null) errors['lng'] = lng;
    if (errors.isNotEmpty) {
      setState(
        () => _errors
          ..clear()
          ..addAll(errors),
      );
      return;
    }
    setState(_errors.clear);

    final outlet = widget.detail.outlet;
    final typedLat = double.parse(_latCtrl.text.trim());
    final typedLng = double.parse(_lngCtrl.text.trim());
    final pinMoved = typedLat != outlet.lat || typedLng != outlet.lng;

    setState(() => _saving = true);
    try {
      await ref
          .read(outletAdminRepositoryProvider)
          .updateOutlet(
            id: outlet.id,
            name: _nameCtrl.text.trim() == outlet.name
                ? null
                : _nameCtrl.text.trim(),
            status: _status == outlet.status ? null : _status,
            // Either the attempt id or the typed numbers reach the wire, never
            // both — see _fromAttemptId.
            fromAttemptId: _fromAttemptId,
            lat: _fromAttemptId == null && pinMoved ? typedLat : null,
            lng: _fromAttemptId == null && pinMoved ? typedLng : null,
            disputeId: _disputeId,
          );
      ref.invalidate(outletDetailProvider(outlet.id));
      ref.invalidate(outletsListProvider);
      ref.invalidate(openPinDisputesProvider);
      if (!mounted) return;
      setState(() {
        _fromAttemptId = null;
        _disputeId = null;
        _saving = false;
      });
      showTorchToast(
        context,
        message: l10n.outletSaved,
        kind: ToastKind.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showTorchToast(
        context,
        message: l10n.outletSaveFailed,
        kind: ToastKind.failure,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final detail = widget.detail;
    final outlet = detail.outlet;
    final openDisputes = detail.disputes.where((d) => d.isOpen).toList();

    return _OutletFrame(
      phase: _saving ? 'saving' : 'loaded',
      title: outlet.name,
      facts: <String>[
        outlet.channelType.isEmpty
            ? outlet.code
            : '${outlet.code} · ${outlet.channelType}',
      ],
      flagChips: <Widget>[
        if (openDisputes.isNotEmpty)
          FlagChip(
            key: const ValueKey<String>('outlet-disputes-flag'),
            kind: FlagKind.forReview,
            label: l10n.outletsPinReported,
          ),
      ],
      primary: TorchPrimaryButton(
        key: const ValueKey<String>('save-outlet'),
        label: l10n.outletSave,
        claimId: OutletDetailScreen.saveClaimId,
        busy: _saving,
        blockedReason: _complete ? null : l10n.outletSaveBlocked,
        onPressed: _complete && !_saving ? _save : null,
      ),
      children: <Widget>[
        if (openDisputes.isNotEmpty) ...<Widget>[
          _DisputeBanner(count: openDisputes.length),
          const SizedBox(height: TiqSpace.s7),
        ],

        SectionRule(l10n.outletDetailFormHeading),
        const SizedBox(height: TiqSpace.s4),
        TorchTextField(
          key: const ValueKey<String>('outlet-name'),
          label: l10n.outletFieldName,
          controller: _nameCtrl,
          error: _errors['name'],
        ),
        const SizedBox(height: TiqSpace.s5),
        TorchTextField(
          key: const ValueKey<String>('outlet-lat'),
          label: l10n.outletFieldLatitude,
          controller: _latCtrl,
          help: l10n.outletFieldLatitudeHelp,
          error: _errors['lat'],
          keyboardType: coordinateKeyboard,
          autocorrect: false,
          identifier: true,
        ),
        const SizedBox(height: TiqSpace.s5),
        TorchTextField(
          key: const ValueKey<String>('outlet-lng'),
          label: l10n.outletFieldLongitude,
          controller: _lngCtrl,
          help: l10n.outletFieldLongitudeHelp,
          error: _errors['lng'],
          keyboardType: coordinateKeyboard,
          autocorrect: false,
          identifier: true,
        ),
        if (_fromAttemptId != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s3),
          Text(
            key: const ValueKey<String>('outlet-using-attempt'),
            l10n.outletUsingAttempt,
            style: context.skin.text.meta.style(
              color: context.skin.palette.ink3,
            ),
          ),
        ],
        const SizedBox(height: TiqSpace.s5),
        // Two options with a consequence each: a choice row, not a dropdown.
        // "Closed" has a real consequence and the row says it, because a
        // manager closing a store must not discover from an agent that it
        // also blocked their check-in — it does not.
        ChoiceRow<String>(
          key: const ValueKey<String>('outlet-status'),
          label: l10n.outletFieldStatus,
          value: _status,
          notAnsweredLine: l10n.outletRequired,
          options: <ChoiceOption<String>>[
            ChoiceOption<String>(
              value: 'active',
              label: l10n.outletStatusActive,
              consequence: l10n.outletStatusActiveConsequence,
            ),
            ChoiceOption<String>(
              value: 'closed',
              label: l10n.outletStatusClosed,
              consequence: l10n.outletStatusClosedConsequence,
            ),
          ],
          onChanged: (value) => setState(() => _status = value),
        ),
        const SizedBox(height: TiqSpace.s7),

        _FailedAttempts(attempts: detail.failedAttempts, onUse: _useAttempt),
        const SizedBox(height: TiqSpace.s7),
        _Disputes(
          disputes: detail.disputes,
          attempts: detail.failedAttempts,
          onUse: _useAttempt,
          onAnswer: (id) => setState(() => _disputeId = id),
          answering: _disputeId,
        ),
        _ChangeLedger(changes: detail.changes),
      ],
    );
  }
}

/// How many agents said the pin is wrong, and what saving does about it.
///
/// Crimson at the watch level plus the triangle plus the sentence — three
/// channels, never amber. A count of problems is the least lit thing on a
/// screen whose one light is the commit.
class _DisputeBanner extends StatelessWidget {
  const _DisputeBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;

    return SoftRow(
      key: const ValueKey<String>('outlet-disputes-banner'),
      form: SoftRowForm.standalone,
      density: SoftRowDensity.tall,
      title: l10n.outletDetailDisputesHeadline(count),
      leading: SeverityMark(
        kind: SeverityMarkKind.watch,
        semanticsLabel: l10n.outletsPinReported,
      ),
      meta: Text(
        l10n.outletDetailDisputesBody,
        style: skin.text.meta.style(color: skin.palette.ink2),
      ),
    );
  }
}

/// The evidence. Each row is an agent who stood somewhere and was told they
/// were not at the shop, with where they actually were — several of them
/// clustered on one spot hundreds of metres from the pin is what a wrong pin
/// looks like in data.
class _FailedAttempts extends StatelessWidget {
  const _FailedAttempts({required this.attempts, required this.onUse});

  final List<CheckInAttemptEvidence> attempts;
  final void Function(CheckInAttemptEvidence attempt) onUse;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final gutter = skin.space.gutterFor(MediaQuery.sizeOf(context).width);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionRule(
          l10n.outletAttemptsHeading,
          count: attempts.isEmpty ? null : attempts.length,
        ),
        const SizedBox(height: TiqSpace.s3),
        Text(
          l10n.outletAttemptsNote,
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
        const SizedBox(height: TiqSpace.s4),
        if (attempts.isEmpty)
          EmptyState(
            scope: EmptyScope.inPanel,
            headline: l10n.outletAttemptsEmptyHeadline,
            body: l10n.outletAttemptsEmptyBody,
          )
        else
          TorchBleed(
            extra: gutter.left * 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < attempts.length; i++)
                  _AttemptRow(
                    attempt: attempts[i],
                    last: i == attempts.length - 1,
                    onUse: () => onUse(attempts[i]),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AttemptRow extends StatelessWidget {
  const _AttemptRow({
    required this.attempt,
    required this.last,
    required this.onUse,
  });

  final CheckInAttemptEvidence attempt;
  final bool last;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final position = formatPosition(context, attempt.lat, attempt.lng);
    final quality = fixQuality(
      l10n,
      context,
      attempt.accuracyM,
      attempt.isMocked,
    );

    return SoftRow(
      key: ValueKey<String>('attempt-${attempt.id}'),
      density: SoftRowDensity.tall,
      title: position,
      subtitle: l10n.outletAttemptSubtitle(
        formatDistance(context, attempt.distanceM),
        attempt.agentLabel,
      ),
      meta: Text(
        <String>[
          '${formatDayShort(context, attempt.createdAt.toLocal())} · '
              '${formatClock(context, attempt.createdAt.toLocal())}',
          quality,
        ].join(' · '),
        style: skin.text.meta.style(color: skin.palette.ink3),
      ),
      // A position the platform called fake, or one only good to hundreds of
      // metres, cannot become the place a shop is: the pin decides who may
      // check in there. The server refuses it too (outlets.service) — this is
      // the same rule where the manager can see it before they press.
      //
      // The button **stays on screen** and goes dead, rather than vanishing: a
      // manager who has been told this evidence is unusable still needs to see
      // where the usable ones would have been offered, and the reason is
      // already in the meta line above it. The verb lives in `actions`, never
      // in `meta` — `meta` is inside the row's excluded label, so a button
      // there is painted and announced nowhere.
      actions: Align(
        alignment: AlignmentDirectional.centerStart,
        child: TorchTertiaryButton(
          key: ValueKey<String>('use-attempt-${attempt.id}'),
          label: l10n.outletUseThisPosition,
          onPressed: attempt.isAdoptable ? onUse : null,
        ),
      ),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: <String>[
        position,
        l10n.outletAttemptSubtitle(
          formatDistance(context, attempt.distanceM),
          attempt.agentLabel,
        ),
        quality,
      ].join('. '),
    );
  }
}

class _Disputes extends StatelessWidget {
  const _Disputes({
    required this.disputes,
    required this.attempts,
    required this.onUse,
    required this.onAnswer,
    required this.answering,
  });

  final List<PinDispute> disputes;
  final List<CheckInAttemptEvidence> attempts;
  final void Function(CheckInAttemptEvidence attempt, {String? disputeId})
  onUse;
  final void Function(String disputeId) onAnswer;
  final String? answering;

  @override
  Widget build(BuildContext context) {
    if (disputes.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionRule(l10n.outletDisputesHeading, count: disputes.length),
        const SizedBox(height: TiqSpace.s4),
        for (final dispute in disputes) ...<Widget>[
          _DisputeBlock(
            dispute: dispute,
            attempt: _attemptFor(dispute),
            onUse: onUse,
            onAnswer: onAnswer,
            answering: answering,
          ),
          const SizedBox(height: TiqSpace.s6),
        ],
        const SizedBox(height: TiqSpace.s3),
      ],
    );
  }

  /// The rejected check-in that matches this report's position, if it is still
  /// in the evidence window. Matched on coordinates because the dispute and
  /// the attempt are two records of one moment.
  CheckInAttemptEvidence? _attemptFor(PinDispute dispute) {
    for (final attempt in attempts) {
      if (attempt.lat == dispute.lat && attempt.lng == dispute.lng) {
        return attempt;
      }
    }
    return null;
  }
}

class _DisputeBlock extends StatelessWidget {
  const _DisputeBlock({
    required this.dispute,
    required this.attempt,
    required this.onUse,
    required this.onAnswer,
    required this.answering,
  });

  final PinDispute dispute;
  final CheckInAttemptEvidence? attempt;
  final void Function(CheckInAttemptEvidence attempt, {String? disputeId})
  onUse;
  final void Function(String disputeId) onAnswer;
  final String? answering;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final meta = skin.text.meta.style(color: skin.palette.ink3);
    final body = skin.text.body.style(color: skin.palette.ink2);
    final adoptable = attempt;

    final verbs = <Widget>[
      if (dispute.isOpen)
        TorchTertiaryButton(
          key: ValueKey<String>('answer-${dispute.id}'),
          label: l10n.outletDisputeAnswer,
          onPressed: () => onAnswer(dispute.id),
        ),
      // Adopting the reporting agent's own position is the common repair, so
      // it is one tap from the report rather than a hunt through the attempt
      // list. It goes dead rather than disappearing when the fix is one the
      // pin may not be moved onto — the sentence above it says which.
      if (dispute.isOpen && adoptable != null)
        TorchTertiaryButton(
          key: ValueKey<String>('adopt-${dispute.id}'),
          label: l10n.outletUseTheirPosition,
          onPressed: adoptable.isAdoptable
              ? () => onUse(adoptable, disputeId: dispute.id)
              : null,
        ),
    ];

    return SoftRow(
      key: ValueKey<String>('dispute-${dispute.id}'),
      form: SoftRowForm.standalone,
      density: SoftRowDensity.tall,
      title: dispute.agentLabel,
      subtitle:
          '${formatDayShort(context, dispute.createdAt.toLocal())} · '
          '${formatClock(context, dispute.createdAt.toLocal())}',
      leading: dispute.isOpen
          ? SeverityMark(
              kind: SeverityMarkKind.watch,
              semanticsLabel: l10n.outletDisputeOpen,
            )
          : null,
      meta: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l10n.outletDisputeStood(
              formatPosition(context, dispute.lat, dispute.lng),
              formatDistance(context, dispute.distanceM),
              formatPosition(context, dispute.outletLat, dispute.outletLng),
            ),
            style: body,
          ),
          const SizedBox(height: TiqSpace.s2),
          Text(
            key: ValueKey<String>('dispute-fix-${dispute.id}'),
            fixQuality(l10n, context, dispute.accuracyM, dispute.isMocked),
            style: meta,
          ),
          if (dispute.agentIsOnlyVisitor) ...<Widget>[
            const SizedBox(height: TiqSpace.s2),
            Text(
              key: ValueKey<String>('dispute-sole-${dispute.id}'),
              // Not a refusal. A store visited once by one agent is also a
              // store visited once by one agent.
              l10n.outletDisputeSoleVisitor,
              style: meta,
            ),
          ],
          if (dispute.note != null && dispute.note!.isNotEmpty) ...<Widget>[
            const SizedBox(height: TiqSpace.s2),
            Text('“${dispute.note}”', style: body),
          ],
          if (dispute.photos.isNotEmpty) ...<Widget>[
            const SizedBox(height: TiqSpace.s4),
            // The photo itself, not a count of photos. A manager deciding
            // where a shop is from "1 storefront photo attached." is deciding
            // from nothing.
            for (final photo in dispute.photos) _DisputePhoto(photo: photo),
          ],
          const SizedBox(height: TiqSpace.s3),
          Text(
            dispute.isOpen
                ? (answering == dispute.id
                      ? l10n.outletDisputeAnswering
                      : l10n.outletDisputeOpen)
                : dispute.status == 'applied'
                ? l10n.outletDisputeApplied(
                    dispute.resolvedByLabel ??
                        l10n.outletDisputeResolvedByManager,
                  )
                : l10n.outletDisputeRejected(
                    dispute.resolvedByLabel ??
                        l10n.outletDisputeResolvedByManager,
                  ),
            style: meta,
          ),
        ],
      ),
      actions: verbs.isEmpty
          ? null
          : Wrap(spacing: TiqSpace.s4, children: verbs),
    );
  }
}

/// Who has changed this store, and what it was before. A store's coordinates
/// decide who can check in where, so moving one is a change to an access
/// boundary and is recorded as such.
class _ChangeLedger extends StatelessWidget {
  const _ChangeLedger({required this.changes});

  final List<OutletChange> changes;

  @override
  Widget build(BuildContext context) {
    if (changes.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final gutter = context.skin.space.gutterFor(
      MediaQuery.sizeOf(context).width,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionRule(l10n.outletChangesHeading, count: changes.length),
        const SizedBox(height: TiqSpace.s4),
        TorchBleed(
          extra: gutter.left * 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var i = 0; i < changes.length; i++)
                SoftRow(
                  key: ValueKey<String>('change-${changes[i].id}'),
                  density: SoftRowDensity.tall,
                  title: _describe(context, changes[i]),
                  subtitle:
                      '${changes[i].userLabel} · '
                      '${formatDayShort(context, changes[i].createdAt.toLocal())} · '
                      '${formatClock(context, changes[i].createdAt.toLocal())}',
                  separator: i == changes.length - 1
                      ? SoftRowSeparator.none
                      : SoftRowSeparator.auto,
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _describe(BuildContext context, OutletChange change) {
    final l10n = context.l10n;
    final parts = <String>[];
    if (change.after.containsKey('lat')) {
      final moved = l10n.outletChangePinMoved(
        '${formatLedgerCoordinate(context, change.before['lat'])}, '
            '${formatLedgerCoordinate(context, change.before['lng'])}',
        '${formatLedgerCoordinate(context, change.after['lat'])}, '
            '${formatLedgerCoordinate(context, change.after['lng'])}',
      );
      parts.add(
        change.pinSource == 'agent_position'
            ? '$moved (${l10n.outletChangePinFromAgent})'
            : moved,
      );
    }
    if (change.after.containsKey('name')) {
      parts.add(
        l10n.outletChangeRenamed(
          '${change.before['name']}',
          '${change.after['name']}',
        ),
      );
    }
    if (change.after.containsKey('status')) {
      parts.add(
        l10n.outletChangeStatus(
          _statusWord(l10n, change.before['status']),
          _statusWord(l10n, change.after['status']),
        ),
      );
    }
    return parts.isEmpty ? l10n.outletChangeOther : parts.join('. ');
  }

  String _statusWord(AppLocalizations l10n, Object? value) => switch (value) {
    'active' => l10n.outletStatusActive,
    'closed' => l10n.outletStatusClosed,
    _ => '$value',
  };
}

/// One storefront photo, with both accounts of it side by side.
///
/// The device's timestamp is what the agent's phone said; "Received" is when
/// this server took delivery, and the source is how the image was obtained. A
/// picture chosen from the gallery is stamped with the moment it was PICKED,
/// so a screenshot taken at home arrives with a fresh time and a home position
/// that agree with the claim perfectly. The server refuses a gallery image for
/// this section; older evidence may say nothing, and unknown is shown as
/// unknown.
class _DisputePhoto extends ConsumerWidget {
  const _DisputePhoto({required this.photo});

  final PinDisputePhoto photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final skin = context.skin;
    final bytes = ref.watch(thumbnailBytesProvider(photo.id));
    final meta = skin.text.meta.style(color: skin.palette.ink3);

    return Padding(
      key: ValueKey<String>('dispute-photo-${photo.id}'),
      padding: const EdgeInsets.only(bottom: TiqSpace.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 72,
            height: 72,
            child: bytes.when(
              data: (data) => Semantics(
                image: true,
                label: l10n.outletPhotoAlt,
                excludeSemantics: true,
                child: Image.memory(data, fit: BoxFit.cover),
              ),
              loading: () => const SkeletonShell(height: 72, outlined: true),
              error: (_, _) => Text(l10n.outletPhotoMissing, style: meta),
            ),
          ),
          const SizedBox(width: TiqSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(switch (photo.source) {
                  'camera' => l10n.outletPhotoCamera,
                  'gallery' => l10n.outletPhotoGallery,
                  _ => l10n.outletPhotoUnknownSource,
                }, style: skin.text.body.style(color: skin.palette.ink2)),
                Text(
                  l10n.outletPhotoPhoneSaid(
                    '${formatDayShort(context, photo.timestamp.toLocal())} · '
                    '${formatClock(context, photo.timestamp.toLocal())}',
                  ),
                  style: meta,
                ),
                Text(
                  l10n.outletPhotoReceived(
                    '${formatDayShort(context, photo.receivedAt.toLocal())} · '
                    '${formatClock(context, photo.receivedAt.toLocal())}',
                  ),
                  style: meta,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What the device said about a fix, in words — including when it said
/// nothing.
String fixQuality(
  AppLocalizations l10n,
  BuildContext context,
  double? accuracyM,
  bool? isMocked,
) {
  if (isMocked == true) return l10n.outletFixMocked;
  if (accuracyM == null) return l10n.outletFixUnknown;
  final metres = TiqNumber.of(context).format(accuracyM.round());
  return accuracyM > 100
      ? l10n.outletFixCoarse(metres)
      : l10n.outletFixGood(metres);
}
