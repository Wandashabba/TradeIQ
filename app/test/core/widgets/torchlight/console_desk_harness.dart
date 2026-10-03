import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/audit/data/photos_repository.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/users/data/users_repository.dart';
import 'package:tradeiq_app/features/fraud/data/fraud_repository.dart';
import 'package:tradeiq_app/features/visits/data/visit_detail_repository.dart';
import 'package:tradeiq_app/features/webhooks/data/webhooks_repository.dart';

import '../../../features/worklist_harness.dart';

/// Everything the desk's tests need to stand a console screen up at desktop
/// width without a server.
///
/// It is [pumpWorklist] with the size unpinned and **a real `GoRouter` at the
/// route under test**, which the rail needs and nothing else did: the rail
/// asks `currentMenuLocation` which destination it is standing on, and a
/// harness with no router would render every row unselected and photograph a
/// rail that can never exist. `path: '/alerts'` is therefore load-bearing in
/// every call, not decoration.
///
/// The fakes override **repositories**, never the view providers above them,
/// which is `worklist_harness.dart`'s own rule: a test that overrode
/// `alertsViewProvider` would prove only that a pane can render a record.
Future<void> pumpDesk(
  WidgetTester tester,
  Widget screen, {
  required Size size,
  required String path,
  TiqSkin? skin,
  double textScale = 1.0,
  List<Override> overrides = const <Override>[],
  List<AppUser> users = const <AppUser>[],
  bool settle = true,
}) => pumpWorklist(
  tester,
  screen,
  skin: skin,
  size: size,
  textScale: textScale,
  overrides: overrides,
  users: users,
  path: path,
  settle: settle,
  // No debug banner: these frames are looked at to decide whether a screen is
  // finished, and a red barber-pole across the top-right corner of the detail
  // pane is noise in that judgement. `floor_look_test.dart`'s reason.
  banner: false,
);

/// Three exceptions, two severities, one acknowledged — enough for the lead
/// indicator to have something to say, both filter rails to have counts, and
/// the detail pane to have a record whose evidence is not empty.
List<Override> deskAlertOverrides({CountingAlerts? alerts}) => <Override>[
  alertsRepositoryProvider.overrideWithValue(alerts ?? CountingAlerts()),
  outletsRepositoryProvider.overrideWithValue(
    FakeOutletsRepository(<Outlet>[
      outlet('o1', 'SaveMor Glenwood'),
      outlet('o2', 'Shoprite Klipspruit Mall'),
      outlet('o3', 'Kasi Corner Spaza'),
    ]),
  ),
  photosRepositoryProvider.overrideWithValue(
    FakePhotosRepository(bytes: pngBytes),
  ),
  visitDetailRepositoryProvider.overrideWithValue(_FakeVisits()),
];

/// The roster. `pumpWorklist` installs `usersRepositoryProvider` itself —
/// overriding a provider twice in one container is an assert, not a
/// last-wins — so the names go in through its own `users:` parameter.
List<AppUser> deskPeople() => <AppUser>[
  person('u1', 'thandi@acme.test', name: 'Thandi Mokoena'),
];

/// Three webhooks, which is a list of records whose rows expand **in place**
/// and have no detail destination at all — the one-column case, rendered.
List<Override> deskWebhookOverrides() => <Override>[
  webhooksRepositoryProvider.overrideWithValue(_FakeWebhooks()),
];

/// The fake, and the instrument for one of the two seamlessness claims:
/// **selecting a record must not refetch**, which is only a measurement if
/// something counts the calls.
class CountingAlerts implements AlertsRepository {
  CountingAlerts([List<AlertItem>? alerts]) : alerts = alerts ?? deskAlerts();

  final List<AlertItem> alerts;

  /// How many times the list has been asked for.
  int listCalls = 0;

  @override
  Future<PaginatedResponse<AlertItem>> listAlerts({
    bool? acknowledged,
    String? severity,
    int? limit,
    String? cursor,
  }) async {
    listCalls++;
    return PaginatedResponse<AlertItem>(data: alerts, nextCursor: null);
  }

  @override
  Future<AlertItem> acknowledge(String id) async =>
      alerts.firstWhere((a) => a.id == id);
}

/// Three exceptions, two severities, one acknowledged.
List<AlertItem> deskAlerts() => <AlertItem>[
  AlertItem(
    id: 'a1',
    metric: 'out_of_stock',
    message: 'Kalahari Cola 2L out of stock at SaveMor Glenwood (6 days)',
    severity: 'critical',
    acknowledged: false,
    outletId: 'o1',
    visitId: 'v1',
    evidencePhotoId: 'p1',
    createdAt: DateTime.utc(2026, 9, 16, 9, 6),
  ),
  AlertItem(
    id: 'a2',
    metric: 'price_deviation',
    message: 'Price above the published band for the third week running',
    severity: 'warning',
    acknowledged: false,
    outletId: 'o2',
    visitId: 'v2',
    createdAt: DateTime.utc(2026, 9, 16, 12),
  ),
  AlertItem(
    id: 'a3',
    metric: 'planogram',
    message: 'Planogram compliance under 50 percent on the main aisle',
    severity: 'critical',
    acknowledged: true,
    outletId: 'o3',
    createdAt: DateTime.utc(2026, 9, 17, 6),
  ),
];

class _FakeVisits implements VisitDetailRepository {
  @override
  Future<VisitDetail> fetch(String visitId) async => VisitDetail(
    id: visitId,
    status: 'submitted',
    outlet: const VisitOutletRef(
      id: 'o1',
      name: 'SaveMor Glenwood',
      code: 'SMG-001',
      channelType: 'supermarket',
    ),
    agent: const VisitAgentRef(id: 'u1', email: 'thandi@acme.test'),
    checkinTs: DateTime.utc(2026, 9, 16, 8),
    submittedAtClient: DateTime.utc(2026, 9, 16, 9),
    geofencePass: true,
    distanceM: 12,
    score: null,
    sections: const <VisitSectionSummary>[],
    photoTotal: 1,
    photos: <VisitPhotoRef>[
      VisitPhotoRef(
        id: 'p1',
        section: 'shelf',
        timestamp: DateTime.utc(2026, 9, 16, 8, 42),
      ),
    ],
    riskScore: 0,
    signals: const <FraudSignal>[],
  );
}

class _FakeWebhooks implements WebhooksRepository {
  @override
  Future<PaginatedResponse<Webhook>> listWebhooks() async =>
      PaginatedResponse<Webhook>(
        data: const <Webhook>[
          Webhook(
            id: 'w1',
            url: 'https://acme.test/hooks/visit-submitted',
            event: 'visit.submitted',
            active: true,
          ),
          Webhook(
            id: 'w2',
            url: 'https://acme.test/hooks/alert-raised',
            event: 'alert.raised',
            active: true,
          ),
          Webhook(
            id: 'w3',
            url: 'https://acme.test/hooks/task-closed',
            event: 'task.closed',
            active: false,
          ),
        ],
        nextCursor: null,
      );

  @override
  Future<Webhook> createWebhook({
    required String url,
    required String event,
    String? secret,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteWebhook(String id) async => throw UnimplementedError();

  @override
  Future<Webhook> setActive(String id, bool active) async =>
      throw UnimplementedError();

  @override
  Future<PaginatedResponse<WebhookDelivery>> listDeliveries(
    String webhookId, {
    int limit = 10,
  }) async => const PaginatedResponse<WebhookDelivery>(
    data: <WebhookDelivery>[],
    nextCursor: null,
  );

  @override
  Future<WebhookDelivery> redeliver(String deliveryId) async =>
      throw UnimplementedError();
}

/// Schibsted Grotesk and JetBrains Mono, the same two
/// `test/features/agent_harness.dart` loads. Re-declared here rather than
/// imported so this group does not depend on the agent surface's harness for
/// a font.
Future<void> loadDeskFonts() async {
  for (final (family, assets) in <(String, List<String>)>[
    (
      'Schibsted Grotesk',
      <String>['assets/fonts/SchibstedGrotesk-Variable.ttf'],
    ),
    (
      'JetBrains Mono',
      <String>[
        'assets/fonts/JetBrainsMono-Regular.ttf',
        'assets/fonts/JetBrainsMono-Medium.ttf',
        'assets/fonts/JetBrainsMono-SemiBold.ttf',
        'assets/fonts/JetBrainsMono-Bold.ttf',
      ],
    ),
  ]) {
    final loader = FontLoader(family);
    for (final asset in assets) {
      loader.addFont(
        File(asset).readAsBytes().then((b) => ByteData.view(b.buffer)),
      );
    }
    await loader.load();
  }
}

/// The Material icon font, so the refresh control, the chevrons and the ask
/// bar's grid and Send keys are glyphs rather than tofu boxes. Returns
/// quietly where the cache is not on disk, exactly as
/// `floor_look_test.dart`'s does.
Future<void> loadDeskIcons() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  final cache = root != null
      ? Directory('$root/bin/cache')
      : File(Platform.resolvedExecutable).parent.parent.parent;
  final font = File(
    '${cache.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!font.existsSync()) return;
  await (FontLoader(
    'MaterialIcons',
  )..addFont(font.readAsBytes().then((b) => ByteData.view(b.buffer)))).load();
}
