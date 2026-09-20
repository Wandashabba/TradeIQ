import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'territories_repository.dart';

/// Coverage for one territory, kept per-id and cached by Riverpod so a row
/// that rebuilds does not re-fetch.
///
/// It stays a family rather than becoming one list-wide request: a territory
/// whose coverage query is slow must not hold up the fourteen above it, and a
/// coverage block that fails must fail in its own row rather than taking the
/// list with it. That was the shape before this migration and it is the right
/// one.
final territoryCoverageProvider =
    FutureProvider.family<TerritoryCoverage, String>((ref, id) {
  return ref.read(territoriesRepositoryProvider).getCoverage(id);
});

/// Which of the three things a territory row's coverage figure is.
///
/// A row is the place the unknown-versus-zero law is easiest to break: three
/// different absences (not loaded, did not load, nothing to measure) all look
/// like "no number" and all used to print `0% covered`.
enum TerritoryCoverageState {
  /// Still in flight. A skeleton, never a nought.
  loading,

  /// The request failed. An em dash and the reason — not a retry per row,
  /// because a list of fifteen rows with fifteen Retry buttons is fifteen
  /// regions and `TorchErrorRegion` allows one.
  failed,

  /// The server answered and there is nothing to take a percentage of: a
  /// territory with no outlets in it. The wire sends `0` here and the wire is
  /// wrong — a rate over an empty denominator is not a nought.
  noOutlets,

  /// A real rate, including a real `0`.
  measured,
}

/// One territory as the list shows it.
class TerritoryRow {
  const TerritoryRow({
    required this.territory,
    required this.state,
    this.coverage,
  });

  final Territory territory;
  final TerritoryCoverageState state;

  /// Null in every state but [TerritoryCoverageState.measured].
  final TerritoryCoverage? coverage;

  String get id => territory.id;

  /// A territory nobody is assigned to is the one state worth flagging; the
  /// rest is a count. It is a fact about the roster, so it is only knowable
  /// once the coverage block has arrived.
  bool? get unassigned {
    final value = coverage;
    if (value == null) return null;
    return value.agentCount == 0;
  }

  /// The rate, or null. Never a defaulted zero.
  double? get coverageRate => coverage?.measuredCoverageRate;

  static TerritoryRow from(Territory territory, AsyncValue<TerritoryCoverage> async) {
    return switch (async) {
      AsyncData(:final value) when !value.coverageMeasured => TerritoryRow(
        territory: territory,
        state: TerritoryCoverageState.noOutlets,
        coverage: value,
      ),
      AsyncData(:final value) => TerritoryRow(
        territory: territory,
        state: TerritoryCoverageState.measured,
        coverage: value,
      ),
      AsyncError() => TerritoryRow(
        territory: territory,
        state: TerritoryCoverageState.failed,
      ),
      _ => TerritoryRow(
        territory: territory,
        state: TerritoryCoverageState.loading,
      ),
    };
  }
}
