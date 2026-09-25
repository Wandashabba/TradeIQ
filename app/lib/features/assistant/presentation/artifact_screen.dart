import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/console_skin.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../../clients/data/clients_repository.dart';
import '../data/artifact_repository.dart';
import '../export/artifact_exporter.dart';
import '../view_specs/artifact_table.dart';
import '../view_specs/expanded_views.dart';
import 'artifact_filters.dart';

/// Expanded mode, on its own route.
///
/// **A real route, `/artifact/:id`, not a bespoke overlay.** The browser back
/// button, deep links and sharing then work because go_router already makes
/// them work — the alternative is state machinery that reimplements history
/// badly and still breaks on refresh.
///
/// Nothing about the artifact is cached client-side. The row stores what to
/// re-run, so opening this screen re-invokes the tool through a roster built
/// for whoever is asking now: a link shared with a colleague who lacks the
/// tool shows a refusal, not someone else's figures.
///
/// ```text
///   ←  Sales performance
///      Month to date · daily buckets.
///   ── Filters ──────────────────── Undo ──
///   PERIOD   (Today)(Yesterday)(Month to date✓)
///   ── Rate of sale ───────────────────────
///   (Chart✓)(Table)
///   ┌─────────────────────────────────────┐
///   │        ╭──────╮                     │
///   └─────────────────────────────────────┘
///   [ ☾ ] [        Export as a PDF        ]
/// ```
///
/// ## The amber, counted
///
/// A pushed route with no nav, so Night's budget is two. **This screen spends
/// exactly one, on the export** — the only thing on it that commits anything.
/// Day and Veld allow one, the primary commit block, and it is the same
/// object. While the artifact is loading or has failed there is nothing to
/// export, no primary is built, and every skin paints **zero**.
///
/// The chart declines the focus rung for the reason the chart kit declines it
/// everywhere; the selected filter chip is `lifted` like every other selected
/// chip in the product; and a refusal is crimson at two commitment levels with
/// its own words, never amber.
class ArtifactScreen extends ConsumerStatefulWidget {
  const ArtifactScreen({super.key, required this.artifactId});

  final String artifactId;

  /// The id the export's [TorchClaim] is declared under.
  static const String exportClaimId = 'artifact-export';

  @override
  ConsumerState<ArtifactScreen> createState() => _ArtifactScreenState();
}

class _ArtifactScreenState extends ConsumerState<ArtifactScreen> {
  ArtifactDetail? _detail;

  /// Params a control has just moved to, not yet accepted by the server.
  ///
  /// Held apart from [_detail] so the control answers the touch immediately and
  /// a refusal rolls back to something real rather than to a guess. A filter
  /// change costs a query and no model call, so this is usually invisible —
  /// but "usually" is not "always", and a control left sitting on a value the
  /// server rejected is a lie about what the figures below it mean.
  Map<String, dynamic>? _pending;
  String? _error;
  bool _loading = true;

  /// True while a PDF is being built. Shown even on platforms where the work
  /// really is off the UI thread: a share sheet that appears a second after the
  /// tap, with no acknowledgement in between, reads as a dead button.
  bool _exporting = false;

  /// Wraps the rendered view so the chart can be captured as pixels. The PDF is
  /// hybrid — vector text and table, rasterised chart — and this is the raster
  /// half's only source: the alternative is a second chart engine drawing the
  /// same CustomPainter shapes against a PDF canvas.
  final GlobalKey _captureKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await ref
          .read(artifactRepositoryProvider)
          .fetch(widget.artifactId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } on ArtifactRequestException catch (err) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = err.message;
      });
    }
  }

  Future<void> _apply(Map<String, dynamic> params) => _send(
    (repository) => repository.refine(widget.artifactId, params),
    optimistic: params,
  );

  Future<void> _undo() =>
      _send((repository) => repository.undo(widget.artifactId));

  Future<void> _send(
    Future<ArtifactDetail> Function(ArtifactRepository repository) call, {
    Map<String, dynamic>? optimistic,
  }) async {
    final current = _detail;
    // A second change queued behind the first would let two answers race to be
    // last, and the loser is what the user ends up looking at.
    if (current == null || _pending != null) return;

    setState(() {
      _pending = optimistic ?? current.params;
      _error = null;
    });

    try {
      final detail = await call(ref.read(artifactRepositoryProvider));
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _pending = null;
      });
    } on ArtifactRequestException catch (err) {
      if (!mounted) return;
      setState(() {
        _pending = null;
        _error = err.message;
      });
    }
  }

  Future<void> _exportPdf() async {
    final detail = _detail;
    if (detail == null || _exporting) return;

    setState(() {
      _exporting = true;
      _error = null;
    });

    try {
      await ref
          .read(artifactExporterProvider)
          .export(
            ArtifactExportRequest(
              title: expandedArtifactTitle(context, detail),
              subtitle: expandedArtifactSubtitle(context, detail),
              // The same sentence the screen shows, so the report and the view
              // it came from cannot describe different filters — and the params
              // it describes are the ones on screen, not the ones the artifact
              // happened to be created with.
              filters: describeParamsInWords(
                context.l10n,
                _pending ?? detail.params,
              ),
              tenant: ref.read(clientConfigProvider).value?.name ?? 'TradeIQ',
              table: artifactTableFor(detail),
              captureKey: _captureKey,
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            ),
            filename: '${_filenameFor(context, detail)}.pdf',
          );
    } catch (err) {
      if (!mounted) return;
      // Reported in the same place a refused filter is: this screen already has
      // one honest place for "that did not work", and a second style of failure
      // message would be a second thing to learn.
      setState(() => _error = _exportFailureMessage(context.l10n, err));
      debugPrint('[assistant] pdf export failed: $err');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Why the export failed, in words that lead somewhere.
  ///
  /// "Please try again" is right for a share sheet the user dismissed or a
  /// platform that refused once. It is **actively wrong** when nothing is
  /// wired up to receive the document, because that fails identically on every
  /// retry — so the message sends the user round a loop and whoever supports
  /// them into an investigation.
  ///
  /// This is not hypothetical. It is the shape the bug actually took: a web
  /// build whose generated plugin registrant predated `printing` being added
  /// registered every other plugin, so `sharePdf` reached a method channel
  /// with nothing behind it and threw [MissingPluginException]. The export
  /// path was fine; the build was stale. An error message that says so is the
  /// difference between a reload and an afternoon.
  static String _exportFailureMessage(AppLocalizations l10n, Object err) {
    if (err is MissingPluginException || err is UnimplementedError) {
      return l10n.artifactExportUnavailable;
    }
    return l10n.artifactExportFailed;
  }

  static String _filenameFor(BuildContext context, ArtifactDetail detail) {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final slug = expandedArtifactTitle(context, detail)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    // Dated, because these land in a downloads folder beside last month's.
    return 'tradeiq-$slug-${now.year}${two(now.month)}${two(now.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final detail = _detail;

    if (_loading) {
      return _ArtifactFrame(
        phase: 'loading',
        title: l10n.artifactTitleView,
        children: <Widget>[
          Skeleton(
            label: l10n.artifactTitleView,
            slowLine: l10n.torchStillFetching,
            child: const SkeletonShell(height: 260),
          ),
        ],
      );
    }

    if (detail == null) {
      return _ArtifactFrame(
        phase: 'unopenable',
        title: l10n.artifactTitleView,
        children: <Widget>[
          TorchErrorRegion(
            name: 'artifact',
            child: ErrorState(
              // The server's own words where it gave any: it writes them to be
              // read by a user, and replacing them with "something went wrong"
              // hides which view it refused.
              message: TorchErrorMessage(
                kind: TorchErrorKind.unknown,
                headline: l10n.artifactCouldNotOpenHeadline,
                body: _error ?? l10n.artifactCouldNotOpenBody,
                offersRetry: true,
              ),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('artifact-retry'),
                label: l10n.torchTryAgain,
                onPressed: _load,
              ),
            ),
          ),
        ],
      );
    }

    final params = _pending ?? detail.params;
    final busy = _pending != null;

    return _ArtifactFrame(
      phase: busy ? 'refining' : 'loaded',
      title: artifactTitle(l10n, detail),
      facts: <String>[describeParamsInWords(l10n, params)],
      // The route's one commit, and its one light. Disabled mid-refine on
      // purpose: exporting what is on screen while the figures underneath are
      // being replaced would produce a report of neither state.
      primary: TorchPrimaryButton(
        key: const ValueKey<String>('artifact-export-pdf'),
        claimId: ArtifactScreen.exportClaimId,
        label: _exporting ? l10n.artifactPreparing : l10n.artifactExportPdf,
        icon: Icons.picture_as_pdf_outlined,
        busy: _exporting,
        blockedReason: busy ? l10n.artifactExportBlocked : null,
        onPressed: _exporting || busy ? null : _exportPdf,
      ),
      children: <Widget>[
        if (_error != null) ...<Widget>[
          _RefusalNote(message: _error!),
          SizedBox(height: context.skin.space.blockGap),
        ],
        _Body(
          detail: detail,
          params: params,
          busy: busy,
          captureKey: _captureKey,
          onApply: _apply,
          onUndo: _undo,
        ),
        SizedBox(height: context.skin.space.blockGap),
        Text(
          l10n.artifactExportNote,
          style: context.skin.text.meta.style(
            color: context.skin.palette.ink3,
          ),
        ),
      ],
    );
  }
}

/// What this artifact is, in the manager's words.
///
/// Derived from the TOOL, not from the params: the row stores tool arguments,
/// and `pillar_metrics` in particular carries its pillar only in the view spec
/// the chat stream sent — which this screen never sees, because it loads from
/// the server by id.
String artifactTitle(AppLocalizations l10n, ArtifactDetail detail) =>
    switch (detail.toolName) {
      'getRateOfSale' => l10n.artifactToolSalesPerformance,
      'getSkuMovement' => l10n.artifactToolSkuMovement,
      'getStockLevels' => l10n.artifactToolStockLevels,
      'getShareOfShelf' => l10n.artifactToolShareOfShelf,
      'getVisibilityCompliance' => l10n.artifactToolVisibility,
      'getCompetitorActivity' => l10n.artifactToolCompetitor,
      'getVisitHistory' => l10n.artifactToolVisits,
      'getFraudFlags' => l10n.artifactToolFlaggedVisits,
      'getAgentScorecard' => l10n.artifactToolAgentScorecard,
      'getMetricTrend' => l10n.artifactToolTrend,
      // A tool this build has not heard of is a server that shipped ahead of
      // the app, which is normal — not an error state.
      _ => l10n.artifactTitleView,
    };

/// The frame every state of this route wears.
class _ArtifactFrame extends StatelessWidget {
  const _ArtifactFrame({
    required this.phase,
    required this.title,
    required this.children,
    this.facts = const <String>[],
    this.primary,
  });

  final String phase;
  final String title;
  final List<String> facts;
  final Widget? primary;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canPop = Navigator.of(context).canPop();

    return TorchScope(
      skin: context.skin,
      phase: phase,
      navRenders: false,
      tabbedRoute: false,
      claims: <TorchClaim>[
        // Declared only when there is something to export. The allocator is
        // told the truth about the frame rather than handed a claim the widget
        // will then decline to spend.
        if (primary != null)
          TorchPrimaryButton.claim(ArtifactScreen.exportClaimId),
      ],
      child: TorchShell(
        profile: TorchShellProfile.console,
        header: TorchAppHeader(
          title: title,
          // The applied filters, spelled out. A chart with no visible date
          // range is a support ticket waiting to happen — and this route is
          // reachable by a link from someone else's conversation, where the
          // reader has none of the context the chat gave.
          facts: facts,
          back: TorchIconButton(
            key: const ValueKey<String>('artifact-back'),
            icon: Icons.arrow_back,
            semanticLabel: canPop ? l10n.artifactBackToAsk : l10n.artifactBackToFloor,
            onPressed: () => canPop ? context.pop() : context.go('/dashboard'),
          ),
        ),
        skinCycle: const ConsoleSkinCycle(),
        primary: primary,
        children: children,
      ),
    );
  }
}

/// The controls and the view, side by side once there is room for both.
class _Body extends StatelessWidget {
  const _Body({
    required this.detail,
    required this.params,
    required this.busy,
    required this.captureKey,
    required this.onApply,
    required this.onUndo,
  });

  final ArtifactDetail detail;
  final Map<String, dynamic> params;
  final bool busy;
  final GlobalKey captureKey;
  final ValueChanged<Map<String, dynamic>> onApply;
  final VoidCallback onUndo;

  /// Side by side above this; stacked below it, which is the phone's
  /// full-screen sheet in all but name. The console's usual tablet line.
  static const double wideAt = 880;

  @override
  Widget build(BuildContext context) {
    final gap = context.skin.space.blockGap;
    final controls = ArtifactFilters(
      detail: detail,
      params: params,
      busy: busy,
      onApply: onApply,
      onUndo: onUndo,
    );
    // RepaintBoundary, not a screenshot of the page: it captures exactly the
    // view — chart, legend and all — at whatever pixel ratio is asked for, and
    // nothing of the controls beside it. Print mode is the view with the
    // controls stripped, and this is what strips them.
    final view = RepaintBoundary(
      key: captureKey,
      child: expandedArtifactView(context, detail),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Dimmed, not removed, while a change is in flight: the figures are
        // still the last true ones, and blanking them makes a 200ms query look
        // like a page load. The whole region is also announced as busy, so the
        // dimming is not the only channel.
        final dimmed = Semantics(
          liveRegion: busy,
          label: busy ? context.l10n.artifactRefining : null,
          child: Opacity(opacity: busy ? 0.55 : 1, child: view),
        );

        if (constraints.maxWidth < wideAt) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[controls, SizedBox(height: gap), dimmed],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: dimmed),
            SizedBox(width: gap),
            SizedBox(width: 300, child: controls),
          ],
        );
      },
    );
  }
}

/// A change the server refused, in its own words.
///
/// Crimson at the watch commitment level, with the mark and the words — never
/// a hue on its own, and never amber: there is no amber warning in this system
/// and a refusal is the most tempting place to invent one.
class _RefusalNote extends StatelessWidget {
  const _RefusalNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: SeverityMark(kind: SeverityMarkKind.watch),
          ),
          const SizedBox(width: TiqSpace.s3),
          Expanded(
            child: Text(
              message,
              key: const ValueKey<String>('artifact-refusal'),
              style: skin.text.body.style(color: skin.palette.bad),
            ),
          ),
        ],
      ),
    );
  }
}
