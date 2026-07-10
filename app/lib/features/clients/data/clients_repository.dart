import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// The scoring configuration for the current client returned by GET /clients/me.
class ClientConfig {
  const ClientConfig({
    required this.name,
    required this.scorecardWeights,
    required this.kpiThresholds,
  });
  final String name;
  final Map<String, double> scorecardWeights;
  final Map<String, double> kpiThresholds;

  factory ClientConfig.fromJson(Map<String, dynamic> json) => ClientConfig(
        name: json['name'] as String,
        scorecardWeights:
            (json['scorecardWeights'] as Map<String, dynamic>? ?? {})
                .map((k, v) => MapEntry(k, (v as num).toDouble())),
        kpiThresholds: (json['kpiThresholds'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
      );
}

abstract class ClientsRepository {
  Future<ClientConfig> getConfig();
  Future<ClientConfig> updateWeights(Map<String, double> weights);
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
}

final clientsRepositoryProvider =
    Provider<ClientsRepository>((ref) => DioClientsRepository());

final clientConfigProvider = FutureProvider<ClientConfig>((ref) {
  return ref.read(clientsRepositoryProvider).getConfig();
});
