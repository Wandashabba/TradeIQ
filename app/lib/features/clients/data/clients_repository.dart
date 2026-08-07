import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// The scoring configuration for the current client returned by GET /clients/me.
class ClientConfig {
  const ClientConfig({
    required this.name,
    required this.scorecardWeights,
    required this.kpiThresholds,
    this.assistantEnabled = false,
  });
  final String name;
  final Map<String, double> scorecardWeights;
  final Map<String, double> kpiThresholds;

  /// Whether the conversational assistant is switched on for this tenant.
  ///
  /// **Read-only, and defaults to `false`.** It is a rollout lever rather than
  /// a customer preference, so `PATCH /clients/me` deliberately does not accept
  /// it — a client admin switching on an unproven, metered AI feature for their
  /// own tenant is the thing the flag exists to prevent.
  ///
  /// Defaulting to `false` also matters for the *older-server* case: an app
  /// built against a backend that predates the field gets no key back, and
  /// hiding the entry point is the safe way to be wrong. The route is gated
  /// server-side regardless — this only decides whether we offer it.
  final bool assistantEnabled;

  factory ClientConfig.fromJson(Map<String, dynamic> json) => ClientConfig(
        name: json['name'] as String,
        scorecardWeights:
            (json['scorecardWeights'] as Map<String, dynamic>? ?? {})
                .map((k, v) => MapEntry(k, (v as num).toDouble())),
        kpiThresholds: (json['kpiThresholds'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
        assistantEnabled: json['assistantEnabled'] as bool? ?? false,
      );
}

/// The KPI thresholds the backend actually reads.
///
/// These four keys are the whole contract — anything else stored under
/// `kpiThresholds` is inert. (The seed used to write `excellent`/`good`/
/// `needsImprovement`, which no code path reads, so the RAG bands silently fell
/// back to their defaults; see #46.)
enum KpiThreshold {
  green(
    key: 'green',
    label: 'Green band',
    help: 'A scorecard at or above this scores green.',
    fallback: 80,
    suffix: '',
  ),
  amber(
    key: 'amber',
    label: 'Amber band',
    help: 'At or above this is amber; below it is red.',
    fallback: 60,
    suffix: '',
  ),
  stockoutUnits(
    key: 'stockoutUnits',
    label: 'Stockout at or below',
    help: 'Units on shelf at or below this open a stockout task automatically.',
    fallback: 0,
    suffix: ' units',
  ),
  priceDeviationPct(
    key: 'priceDeviationPct',
    label: 'Price deviation over',
    help: 'A shelf price deviating from RRP by more than this opens a task.',
    fallback: 10,
    suffix: '%',
  );

  const KpiThreshold({
    required this.key,
    required this.label,
    required this.help,
    required this.fallback,
    required this.suffix,
  });

  final String key;
  final String label;
  final String help;

  /// What the engine uses when the key is absent — shown so an empty field is
  /// never mistaken for "no rule".
  final double fallback;
  final String suffix;
}

abstract class ClientsRepository {
  Future<ClientConfig> getConfig();
  Future<ClientConfig> updateWeights(Map<String, double> weights);
  Future<ClientConfig> updateThresholds(Map<String, double> thresholds);
}

class DioClientsRepository implements ClientsRepository {
  @override
  Future<ClientConfig> getConfig() async {
    final response = await dio.get('/clients/me');
    return ClientConfig.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ClientConfig> updateWeights(Map<String, double> weights) async {
    final response = await dio.patch('/clients/me', data: {
      'scorecardWeights': weights,
    });
    return ClientConfig.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ClientConfig> updateThresholds(Map<String, double> thresholds) async {
    final response = await dio.patch('/clients/me', data: {
      'kpiThresholds': thresholds,
    });
    return ClientConfig.fromJson(response.data as Map<String, dynamic>);
  }
}

final clientsRepositoryProvider =
    Provider<ClientsRepository>((ref) => DioClientsRepository());

final clientConfigProvider = FutureProvider<ClientConfig>((ref) {
  return ref.read(clientsRepositoryProvider).getConfig();
});
