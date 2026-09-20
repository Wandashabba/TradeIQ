import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// The zone every client starts in, and the one assumed when a server that
/// predates `Client.timezone` (#309) sends none.
const defaultClientTimeZone = 'Africa/Johannesburg';

/// The field day every client starts on, and what is assumed of a server that
/// predates the working-hours columns (#153 T2).
const defaultWorkHoursStart = '07:00';
const defaultWorkHoursEnd = '17:00';
const defaultWorkDays = <int>[1, 2, 3, 4, 5];

/// The names of the ISO weekdays, indexable by weekday number (1 = Monday), so
/// index 0 is unused.
const weekdayNames = <String>[
  '',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// The scoring configuration for the current client returned by GET /clients/me.
class ClientConfig {
  const ClientConfig({
    required this.name,
    required this.scorecardWeights,
    required this.kpiThresholds,
    this.assistantEnabled = false,
    this.timezone = defaultClientTimeZone,
    this.workHoursStart = defaultWorkHoursStart,
    this.workHoursEnd = defaultWorkHoursEnd,
    this.workDays = defaultWorkDays,
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

  /// The IANA zone this client's calendar days are counted in (#309): which
  /// day's route a check-in ticks, and where trend days and weeks begin.
  ///
  /// Unlike the scoring config, managers may change it as well as admins — it
  /// is a fact about where the team works, not a scoring policy.
  final String timezone;

  /// When the field team's working day starts and ends, `HH:MM` on the wall
  /// clock of [timezone] (#153 T2), and the ISO weekdays it applies to
  /// (1 = Monday … 7 = Sunday).
  ///
  /// This is read by exactly one thing: the window background location tracking
  /// is allowed to run in. It is not a shift model and it is not attendance —
  /// nothing is scored against it and no agent is measured by it. Managers may
  /// change it as well as admins, like [timezone], because when the team works
  /// is a fact about the team rather than a scoring policy.
  final String workHoursStart;
  final String workHoursEnd;
  final List<int> workDays;

  factory ClientConfig.fromJson(Map<String, dynamic> json) => ClientConfig(
    name: json['name'] as String,
    scorecardWeights: (json['scorecardWeights'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, (v as num).toDouble())),
    kpiThresholds: (json['kpiThresholds'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    ),
    assistantEnabled: json['assistantEnabled'] as bool? ?? false,
    timezone: json['timezone'] as String? ?? defaultClientTimeZone,
    workHoursStart: json['workHoursStart'] as String? ?? defaultWorkHoursStart,
    workHoursEnd: json['workHoursEnd'] as String? ?? defaultWorkHoursEnd,
    // A server that predates the column sends nothing, and Monday-to-Friday
    // is the safe way to be wrong: it narrows tracking rather than widening
    // it, which is the direction a privacy control should fail in.
    workDays:
        (json['workDays'] as List<dynamic>?)
            ?.map((d) => (d as num).toInt())
            .toList() ??
        defaultWorkDays,
  );
}

/// The KPI thresholds the backend actually reads.
///
/// These four keys are the whole contract — anything else stored under
/// `kpiThresholds` is inert. (The seed used to write `excellent`/`good`/
/// `needsImprovement`, which no code path reads, so the RAG bands silently fell
/// back to their defaults; see #46.)
enum KpiThreshold {
  // The keys are wire values and stay `green` / `amber` / `red`; the labels
  // are the display names the rest of the app shows (core/rating_band.dart).
  green(
    key: 'green',
    label: 'Healthy band',
    help: 'A scorecard at or above this is Healthy.',
    fallback: 80,
    suffix: '',
  ),
  amber(
    key: 'amber',
    label: 'Watch band',
    help: 'At or above this is Watch; below it is Gap.',
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

  /// Sets the client's IANA timezone. Manager or admin; the server rejects a
  /// name it does not recognise with a 400.
  Future<ClientConfig> updateTimezone(String timezone);

  /// Sets the working-hours window background location tracking runs in
  /// (#153 T2). Manager or admin.
  ///
  /// All three go together because the server validates them together: a start
  /// at or after the end is a 400, and so is an empty or out-of-range day list.
  Future<ClientConfig> updateWorkingHours({
    required String start,
    required String end,
    required List<int> days,
  });
}

class DioClientsRepository implements ClientsRepository {
  @override
  Future<ClientConfig> getConfig() async {
    final response = await dio.get('/clients/me');
    return ClientConfig.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ClientConfig> updateWeights(Map<String, double> weights) async {
    final response = await dio.patch(
      '/clients/me',
      data: {'scorecardWeights': weights},
    );
    return ClientConfig.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ClientConfig> updateThresholds(Map<String, double> thresholds) async {
    final response = await dio.patch(
      '/clients/me',
      data: {'kpiThresholds': thresholds},
    );
    return ClientConfig.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ClientConfig> updateTimezone(String timezone) async {
    final response = await dio.patch(
      '/clients/me',
      data: {'timezone': timezone},
    );
    return ClientConfig.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ClientConfig> updateWorkingHours({
    required String start,
    required String end,
    required List<int> days,
  }) async {
    final response = await dio.patch(
      '/clients/me',
      data: {'workHoursStart': start, 'workHoursEnd': end, 'workDays': days},
    );
    return ClientConfig.fromJson(response.data as Map<String, dynamic>);
  }
}

final clientsRepositoryProvider = Provider<ClientsRepository>(
  (ref) => DioClientsRepository(),
);

final clientConfigProvider = FutureProvider<ClientConfig>((ref) {
  return ref.read(clientsRepositoryProvider).getConfig();
});
