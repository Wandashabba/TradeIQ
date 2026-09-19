import 'package:flutter/widgets.dart';

import '../../../core/design/torch_scope.dart';
import '../answer/ask_light.dart';
import '../data/chat_controller.dart';
import 'instrument_panel.dart';
import 'rich_figures.dart';
import 'view_spec_registry.dart';

/// THE ONE OBJECT ON THE ROUTE THAT MAY TAKE THE ANSWER'S LIGHT.
///
/// [TorchScope] grants the route a `chartFocus` claim; it cannot know which
/// of the transcript's bars and series that claim is for. Left to every card
/// to decide for itself, three landed answers with three rankings each light
/// their own bar — three amber objects under a single grant, which is the
/// failure the counted budget exists to prevent.
///
/// So the target is resolved **once per turn, from the server's word**:
///
/// 1. The first `ranked_bars` block in panel order that the server named a
///    focus for — through the `focus{artifactId,index}` event, or the same
///    index written into the run as `focusIndex` — and that has at least two
///    rows (one bar cannot be ranked).
/// 2. Otherwise, only if the turn has **no** ranked block at all, the first
///    trend chart: its primary series is the answer's subject by definition,
///    and the ledger lights it "only when the answer has no ranked bars".
/// 3. Otherwise nothing. Tiles are never a target — four numbers together are
///    the reading, and lighting one would misdirect.
///
/// Only the **latest** turn has a target. An earlier answer keeps its focus
/// bar's marker and weight, in ink; its light went out when the next question
/// was asked.
@immutable
class AnswerFocusTarget {
  const AnswerFocusTarget({required this.artifactId, this.index});

  final String artifactId;

  /// The bar's index for a ranking; null for a trend chart's primary series.
  final int? index;

  static AnswerFocusTarget? resolve(ChatMessage message) {
    final figures = AnswerFigures.of(message);
    if (figures.suppressed && figures.internal.isEmpty) return null;
    final ordered = arrangeAnswerArtifacts(figures.internal);

    for (final artifact in ordered) {
      if (artifact.type != 'ranked_bars') continue;
      final index = focusIndexOf(artifact, message.focus);
      if (index != null) {
        return AnswerFocusTarget(artifactId: artifact.id, index: index);
      }
    }
    if (ordered.any((a) => a.type == 'ranked_bars')) return null;
    for (final artifact in ordered) {
      if (artifact.type == 'trend_chart' && _plottable(artifact.data)) {
        return AnswerFocusTarget(artifactId: artifact.id);
      }
    }
    return null;
  }

  /// The server's focus for a ranking, or null.
  ///
  /// The `focus` event wins; the run's own `focusIndex` is the same server
  /// decision written into the data, and it is what a patched or replayed
  /// artifact still carries. Out of range, or a list of one, is no focus.
  static int? focusIndexOf(ChatArtifact artifact, Map<String, int> focus) {
    final data = RankedBarsData.from(artifact.data);
    final index = focus[artifact.id] ?? data.provenance.focusIndex;
    if (index == null || data.items.length < 2 || index >= data.items.length) {
      return null;
    }
    return index;
  }

  static bool _plottable(dynamic data) {
    if (data is! Map) return false;
    final points = data['points'];
    if (points is! List) return false;
    var readable = 0;
    for (final row in points) {
      if (row is Map && row['value'] is num && (row['value'] as num).isFinite) {
        readable++;
      }
    }
    return readable >= 2;
  }
}

/// Carries a turn's focus map and, on the latest turn, its one target down to
/// the cards.
///
/// Outside this scope — the full-view artifact screen, an export — a card
/// falls back to the run's own `focusIndex` for its marker and is never lit:
/// no route there has claimed the answer's light.
class AnswerFocusScope extends InheritedWidget {
  const AnswerFocusScope({
    super.key,
    required this.focus,
    required this.target,
    required super.child,
  });

  /// The turn's `focus` events.
  final Map<String, int> focus;

  /// The route's one lit object, or null on every turn but the latest.
  final AnswerFocusTarget? target;

  static AnswerFocusScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AnswerFocusScope>();

  /// The index of the bar the sentence is about in [artifact], lit or not.
  static int? focusIndexFor(BuildContext context, ChatArtifact artifact) =>
      AnswerFocusTarget.focusIndexOf(
        artifact,
        maybeOf(context)?.focus ?? const <String, int>{},
      );

  /// Whether [artifact] holds the route's one lit object right now: the route
  /// granted the claim, and this is the object it was granted for.
  static bool isLit(BuildContext context, ChatArtifact artifact) {
    final target = maybeOf(context)?.target;
    if (target == null || target.artifactId != artifact.id) return false;
    return TorchScope.lit(context, AskLight.focusClaimId);
  }

  @override
  bool updateShouldNotify(AnswerFocusScope old) =>
      old.target?.artifactId != target?.artifactId ||
      old.target?.index != target?.index ||
      old.focus != focus;
}
