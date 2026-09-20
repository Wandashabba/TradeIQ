import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/person_label.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../outlets/data/outlets_repository.dart';
import '../../users/data/users_repository.dart';
import 'fraud_repository.dart';

/// THE RISK BAND, declared once.
///
/// The bands are the ones the backend flags on. They live in the data layer
/// and not on a screen because two screens read them — the review queue and
/// the visit detail — and a band that each screen decides is a band that says
/// "High risk" in one place and "Elevated" in the other for the same number.
enum FraudRiskBand {
  high('High risk'),
  elevated('Elevated'),
  low('Low risk');

  const FraudRiskBand(this.word);

  /// The word. Severity is never carried by a hue alone, and this is the
  /// channel that survives greyscale, deuteranopia, glare and a reader.
  final String word;

  static FraudRiskBand of(double score) => score >= 70
      ? FraudRiskBand.high
      : score >= 50
          ? FraudRiskBand.elevated
          : FraudRiskBand.low;

  /// How hard a row commits to the accusation: solid for high, outlined for
  /// elevated, no bar at all below the review threshold.
  SoftRowSeverity? get severity => switch (this) {
        FraudRiskBand.high => SoftRowSeverity.critical,
        FraudRiskBand.elevated => SoftRowSeverity.watch,
        FraudRiskBand.low => null,
      };
}

/// One flagged visit, ready to render.
class FraudRow {
  const FraudRow({
    required this.visitId,
    required this.agentId,
    required this.agentName,
    required this.outletName,
    required this.riskScore,
    required this.band,
    required this.signals,
    this.verdict,
    this.scoredAt,
  });

  final String visitId;
  final String agentId;

  /// Who is being accused, by name. Null where the roster does not carry them
  /// — and then the row says "Unknown agent" in words and puts the id on its
  /// own third line, which is the one place a raw id is legitimate because it
  /// is then the only fact.
  final String? agentName;

  /// Where, resolved against the outlet list. [FraudView.unnamedOutlet] when
  /// the id is not on a list this manager can see — never the id itself.
  final String outletName;

  final double riskScore;
  final FraudRiskBand band;
  final List<FraudSignal> signals;

  /// The standing ruling, or null for a visit nobody has looked at.
  final FraudVerdict? verdict;

  final DateTime? scoredAt;

  /// The rule codes that fired, machine-facing, for quoting back.
  String get codes => signals.map((s) => s.code).join(', ');

  /// What the rules actually found, in their own words.
  String get evidence => signals.map((s) => s.detail).join(' · ');
}

/// The whole review queue.
class FraudView {
  const FraudView({
    required this.rows,
    required this.unscored,
    this.nextCursor,
  });

  /// What a row says when its outlet id is not on the outlet list — still
  /// loading, or outside this manager's list. Words, never the UUID.
  static const String unnamedOutlet = 'Outlet name unavailable';

  /// What a row says when the roster does not carry the agent.
  static const String unknownAgent = 'Unknown agent';

  /// Riskiest first: the list reads top-down as the review order.
  final List<FraudRow> rows;

  /// Submitted visits in the window with no stored score yet. They can be
  /// neither listed nor ruled out, so they are counted (#236) — a short list
  /// of the riskiest twenty must never read as "nothing suspicious".
  final int unscored;

  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  /// The unscored sentence, or null when there are none. Not optional where
  /// it is true: an unscored visit is not a clean one.
  String? unscoredNote(String Function(int) figure) {
    if (unscored <= 0) return null;
    final count = figure(unscored);
    return unscored == 1
        ? '$count submitted visit has not been scored yet and is not listed '
              'here.'
        : '$count submitted visits have not been scored yet and are not '
              'listed here.';
  }
}

/// The flagged page, merged with the names it needs to be readable.
///
/// Two base layers, neither a blocker: the roster names the agent and the
/// outlet list names the shop. A slow or failed lookup leaves a row saying so
/// in words and never takes the queue down with it — a review queue that
/// will not load because a name will not resolve is a queue nobody reviews.
final fraudViewProvider =
    FutureProvider.family<FraudView, FlaggedReviewFilter>((ref, filter) async {
  final page = await ref.read(fraudRepositoryProvider).flagged(
        reviewed: filter,
      );

  final outlets = ref
      .watch(outletsListProvider)
      .maybeWhen(data: (list) => list, orElse: () => const <Outlet>[]);
  final outletNames = <String, String>{for (final o in outlets) o.id: o.name};

  final users = ref
      .watch(usersListProvider)
      .maybeWhen(data: (list) => list, orElse: () => const <AppUser>[]);
  final people = <String, AppUser>{for (final u in users) u.id: u};

  final sorted = <FlaggedVisit>[...page.data]
    ..sort((a, b) => b.riskScore.compareTo(a.riskScore));

  return FraudView(
    unscored: page.unscored,
    nextCursor: page.nextCursor,
    rows: <FraudRow>[
      for (final v in sorted)
        FraudRow(
          visitId: v.visitId,
          agentId: v.agentId,
          // The one fallback every screen that shows a person uses: the
          // display name when there is one, otherwise the address. Null only
          // where the roster does not carry this agent at all, and the row
          // then says so in words.
          agentName: _nameOf(people[v.agentId]),
          outletName: outletNames[v.outletId] ?? FraudView.unnamedOutlet,
          riskScore: v.riskScore,
          band: FraudRiskBand.of(v.riskScore),
          signals: v.signals,
          verdict: v.verdict,
          scoredAt: v.scoredAt,
        ),
    ],
  );
});

String? _nameOf(AppUser? user) =>
    user == null ? null : personLabel(user.displayName, user.email);
