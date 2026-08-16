import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../data/artifact_repository.dart';
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
class ArtifactScreen extends ConsumerStatefulWidget {
  const ArtifactScreen({super.key, required this.artifactId});

  final String artifactId;

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

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    return ManagerScaffold(
      title: detail == null ? 'View' : artifactTitle(detail),
      body: _loading
          ? const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : detail == null
          ? _LoadFailure(
              message: _error ?? 'That view could not be opened.',
              onRetry: _load,
            )
          : _Loaded(
              detail: detail,
              params: _pending ?? detail.params,
              busy: _pending != null,
              error: _error,
              onApply: _apply,
              onUndo: _undo,
            ),
    );
  }
}

/// What this artifact is, in the manager's words.
///
/// Derived from the TOOL, not from the params: the row stores tool arguments,
/// and `pillar_metrics` in particular carries its pillar only in the view spec
/// the chat stream sent — which this screen never sees, because it loads from
/// the server by id.
String artifactTitle(ArtifactDetail detail) => switch (detail.toolName) {
  'getRateOfSale' => 'Sales performance',
  'getSkuMovement' => 'SKU movement',
  'getStockLevels' => 'Stock levels',
  'getShareOfShelf' => 'Share of shelf',
  'getVisibilityCompliance' => 'Visibility compliance',
  'getCompetitorActivity' => 'Competitor activity',
  'getVisitHistory' => 'Visits',
  'getFraudFlags' => 'Flagged visits',
  'getAgentScorecard' => 'Agent scorecard',
  'getMetricTrend' => 'Trend',
  // A tool this build has not heard of is a server that shipped ahead of
  // the app, which is normal — not an error state.
  _ => 'View',
};

class _Loaded extends StatelessWidget {
  const _Loaded({
    required this.detail,
    required this.params,
    required this.busy,
    required this.error,
    required this.onApply,
    required this.onUndo,
  });

  final ArtifactDetail detail;
  final Map<String, dynamic> params;
  final bool busy;
  final String? error;
  final ValueChanged<Map<String, dynamic>> onApply;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final controls = ArtifactFilters(
      detail: detail,
      params: params,
      busy: busy,
      onApply: onApply,
      onUndo: onUndo,
    );
    final view = expandedArtifactView(context, detail);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Side by side once there is room for both; stacked below that, which
        // is the phone's full-screen sheet in all but name. The breakpoint is
        // the console's usual tablet line.
        final wide = constraints.maxWidth >= 880;

        final body = <Widget>[
          if (error != null) ...[
            _RefusalNote(message: error!),
            const SizedBox(height: 12),
          ],
          _AppliedFilters(detail: detail, params: params),
          const SizedBox(height: 12),
          // Dimmed, not removed, while a change is in flight: the figures are
          // still the last true ones, and blanking them makes a 200ms query
          // look like a page load.
          Opacity(opacity: busy ? 0.55 : 1, child: view),
        ];

        if (!wide) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [controls, const SizedBox(height: 12), ...body],
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView(padding: EdgeInsets.zero, children: body),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 300,
                child: ListView(padding: EdgeInsets.zero, children: [controls]),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The applied filters, spelled out.
///
/// A chart with no visible date range is a support ticket waiting to happen —
/// and this screen is reachable by a link from someone else's conversation,
/// where the user has none of the context the chat gave.
class _AppliedFilters extends StatelessWidget {
  const _AppliedFilters({required this.detail, required this.params});

  final ArtifactDetail detail;
  final Map<String, dynamic> params;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Text(
      describeParamsInWords(params),
      style: TextStyle(fontSize: 12, height: 1.4, color: colors.ink3),
    );
  }
}

class _RefusalNote extends StatelessWidget {
  const _RefusalNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, size: 15, color: colors.critText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            // The server's own words. It writes them to be read by a user, and
            // replacing them with "something went wrong" hides which filter it
            // refused.
            message,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: colors.critText,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_outlined, size: 26, color: colors.ink4),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.5, color: colors.ink2),
            ),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

/// A PanelCard-friendly wrapper used by the filter panel.
class FilterSection extends StatelessWidget {
  const FilterSection({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [SectionLabel(label), const SizedBox(height: 6), child],
      ),
    );
  }
}
