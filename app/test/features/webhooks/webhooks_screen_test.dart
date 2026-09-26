import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/webhooks/data/webhooks_repository.dart';
import 'package:tradeiq_app/features/webhooks/presentation/webhooks_screen.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

import '../../core/design/amber_golden.dart';
import '../worklist_harness.dart';

/// An `Error` rather than an `Exception`: Riverpod 3 retries an Exception and
/// the screen then never leaves its loading phase.
StateError get _networkFailure =>
    StateError('SocketException: Failed host lookup: api.tradeiq.co.za');

final _healthy = Webhook(
  id: 'w-first',
  url: 'https://example.com/first',
  event: 'visit.submitted',
  active: true,
  health: WebhookHealth.healthy,
  hasSecret: true,
  lastDeliveryStatus: DeliveryStatus.succeeded,
  lastDeliveryAt: DateTime.now().subtract(const Duration(minutes: 5)),
);

final _failing = Webhook(
  id: 'w-second',
  url: 'https://example.com/second',
  event: 'order.created',
  active: true,
  health: WebhookHealth.failing,
  lastDeliveryStatus: DeliveryStatus.failedRetrying,
  lastDeliveryAt: DateTime.now().subtract(const Duration(hours: 2)),
);

const _unhealthy = Webhook(
  id: 'w-third',
  url: 'https://example.com/third',
  event: 'alert.raised',
  active: true,
  health: WebhookHealth.unhealthy,
  consecutiveFailures: 1,
);

List<WebhookDelivery> _deliveries() {
  final now = DateTime.now();
  return <WebhookDelivery>[
    WebhookDelivery(
      id: 'd-ok',
      event: 'visit.submitted',
      status: DeliveryStatus.succeeded,
      attempts: 1,
      lastStatusCode: 200,
      createdAt: now.subtract(const Duration(minutes: 5)),
      deliveredAt: now.subtract(const Duration(minutes: 5)),
    ),
    WebhookDelivery(
      id: 'd-retry',
      event: 'visit.submitted',
      status: DeliveryStatus.failedRetrying,
      attempts: 2,
      lastStatusCode: 503,
      lastError: 'HTTP 503',
      createdAt: now.subtract(const Duration(minutes: 10)),
      nextAttemptAt: now.add(const Duration(minutes: 25, seconds: 30)),
    ),
    WebhookDelivery(
      id: 'd-dead',
      event: 'visit.submitted',
      status: DeliveryStatus.gaveUp,
      attempts: 6,
      lastError: 'connect ECONNREFUSED',
      createdAt: now.subtract(const Duration(days: 1)),
    ),
  ];
}

class _FakeWebhooksRepository implements WebhooksRepository {
  _FakeWebhooksRepository({
    List<Webhook>? webhooks,
    this.listFailure,
    this.setActiveFailure,
  }) : webhooks = webhooks ?? <Webhook>[_healthy, _failing, _unhealthy];

  final List<Webhook> webhooks;
  final Object? listFailure;
  final Object? setActiveFailure;

  String? deletedId;
  String? createdUrl;
  String? createdEvent;
  String? createdSecret;
  String? deliveriesFor;
  String? redeliveredId;
  String? toggledId;
  bool? toggledValue;

  @override
  Future<PaginatedResponse<Webhook>> listWebhooks() async {
    if (listFailure != null) throw listFailure!;
    return PaginatedResponse<Webhook>(data: webhooks, nextCursor: null);
  }

  @override
  Future<Webhook> createWebhook({
    required String url,
    required String event,
    String? secret,
  }) async {
    createdUrl = url;
    createdEvent = event;
    createdSecret = secret;
    return Webhook(id: 'w-new', url: url, event: event, active: true);
  }

  @override
  Future<void> deleteWebhook(String id) async => deletedId = id;

  @override
  Future<Webhook> setActive(String id, bool active) async {
    toggledId = id;
    toggledValue = active;
    if (setActiveFailure != null) throw setActiveFailure!;
    return _healthy;
  }

  @override
  /// The cursor the delivery log hands back. A fake that never sets one
  /// cannot tell a whole log from a log cut at ten.
  String? deliveriesCursor;

  @override
  Future<PaginatedResponse<WebhookDelivery>> listDeliveries(
    String webhookId, {
    int limit = 10,
  }) async {
    deliveriesFor = webhookId;
    return PaginatedResponse<WebhookDelivery>(
      data: _deliveries(),
      nextCursor: deliveriesCursor,
    );
  }

  @override
  Future<WebhookDelivery> redeliver(String deliveryId) async {
    redeliveredId = deliveryId;
    return _deliveries().firstWhere((d) => d.id == deliveryId);
  }
}

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required _FakeWebhooksRepository repo,
    TiqSkin? skin,
    double textScale = 1.0,
  }) => pumpWorklist(
    tester,
    const WebhooksScreen(),
    skin: skin,
    textScale: textScale,
    overrides: <Override>[
      webhooksRepositoryProvider.overrideWithValue(repo),
    ],
  );

  group('relativeTime', () {
    final now = DateTime(2026, 9, 20, 12);
    test('says just now, minutes, hours and days', () {
      expect(relativeTime(now, englishLocalizations, now: now), 'just now');
      expect(
        relativeTime(now.subtract(const Duration(minutes: 5)), englishLocalizations, now: now),
        '5m ago',
      );
      expect(
        relativeTime(now.subtract(const Duration(hours: 3)), englishLocalizations, now: now),
        '3h ago',
      );
      expect(
        relativeTime(now.subtract(const Duration(days: 2)), englishLocalizations, now: now),
        '2d ago',
      );
    });

    test('a future time reads forwards', () {
      expect(
        relativeTime(now.add(const Duration(minutes: 25)), englishLocalizations, now: now),
        'in 25m',
      );
      expect(
        relativeTime(now.add(const Duration(seconds: 20)), englishLocalizations, now: now),
        'in under a minute',
      );
    });
  });

  group('the list', () {
    testWidgets('each endpoint names its event, address and health', (
      tester,
    ) async {
      await pump(tester, repo: _FakeWebhooksRepository());

      // MOVED 26 September 2026: a row is named by its event **in words**.
      //
      // The headline was the wire's dotted slug, so a manager picked a
      // webhook by wire token. The token is not hidden — it is on the
      // identifier line with the URL, which is where a thing you paste into a
      // config file belongs — and this asserts both halves.
      expect(find.text('Visit submitted'), findsOneWidget);
      expect(
        find.text('visit.submitted · https://example.com/first'),
        findsOneWidget,
      );
      expect(find.text('Healthy'), findsOneWidget);
      expect(find.text('Failing'), findsOneWidget);
    });

    testWidgets('an endpoint that is not receiving is said once at the top, '
        'and carried on the row', (tester) async {
      await pump(tester, repo: _FakeWebhooksRepository());

      expect(
        find.byKey(const ValueKey<String>('webhooks-unhealthy')),
        findsOneWidget,
      );
      expect(
        find.textContaining('1 endpoint is not receiving'),
        findsOneWidget,
      );
    });

    testWidgets('an empty list is a stated result', (tester) async {
      await pump(
        tester,
        repo: _FakeWebhooksRepository(webhooks: <Webhook>[]),
      );

      expect(find.text('No endpoints registered.'), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets('a failure is sanitised and offers one retry', (tester) async {
      await pump(
        tester,
        repo: _FakeWebhooksRepository(listFailure: _networkFailure),
      );

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('webhooks-retry')),
        findsOneWidget,
      );
    });
  });

  group('a secret is never rendered', () {
    testWidgets('a signed endpoint says Signed, and nothing else', (
      tester,
    ) async {
      await pump(tester, repo: _FakeWebhooksRepository());

      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey<String>('signing-w-first')),
            )
            .data,
        'Signed — deliveries carry an HMAC signature.',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey<String>('signing-w-second')),
            )
            .data,
        'Not signed — deliveries carry no signature.',
      );
    });

    testWidgets('the model does not even carry one', (tester) async {
      // The repository parses `hasSecret` and there is no `secret` field to
      // read — the value stops at the server. A screen cannot render what the
      // client never holds.
      final parsed = Webhook.fromJson(const <String, dynamic>{
        'id': 'w',
        'url': 'https://example.com/x',
        'event': 'visit.submitted',
        'active': true,
        'hasSecret': true,
        // A server that regressed and sent one: it is dropped in the parse.
        'secret': 'whsec_do_not_render_me',
      });
      expect(parsed.hasSecret, isTrue);
      expect(parsed.toString(), isNot(contains('whsec_')));
    });

    testWidgets('the create sheet takes one and never shows it back', (
      tester,
    ) async {
      final repo = _FakeWebhooksRepository();
      await pump(tester, repo: repo);

      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('webhook-create')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('webhook-create')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('new-url')),
        'https://example.com/new',
      );
      await tester.pumpAndSettle();
      await scrollSheetTo(
        tester,
        find.byKey(const ValueKey<String>('new-secret')),
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('new-secret')),
        'whsec_abc123',
      );
      await tester.pumpAndSettle();

      final field = tester.widget<TorchTextField>(
        find.byKey(const ValueKey<String>('new-secret')),
      );
      expect(
        field.obscureText,
        isTrue,
        reason: 'A secret is never on screen, even while it is being typed.',
      );

      await scrollSheetTo(
        tester,
        find.byKey(const ValueKey<String>('create-webhook')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('create-webhook')));
      await tester.pumpAndSettle();

      expect(repo.createdUrl, 'https://example.com/new');
      expect(repo.createdEvent, 'visit.submitted');
      expect(repo.createdSecret, 'whsec_abc123');
      // Back on the list, and the value is nowhere.
      expect(find.textContaining('whsec_'), findsNothing);
    });
  });

  group('the create sheet', () {
    testWidgets('says why it cannot save until the address is a web address', (
      tester,
    ) async {
      await pump(tester, repo: _FakeWebhooksRepository());

      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('webhook-create')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('webhook-create')));
      await tester.pumpAndSettle();

      expect(
        find.text('Give the endpoint a web address.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('new-url')),
        'ftp://example.com/x',
      );
      await tester.pumpAndSettle();
      expect(
        find.text('The address has to start with http:// or https://.'),
        findsWidgets,
      );
    });
  });

  group('the toggle', () {
    testWidgets('pauses and resumes, and tells the server', (tester) async {
      final repo = _FakeWebhooksRepository();
      await pump(tester, repo: repo);

      final toggle = find.byKey(const ValueKey<String>('toggle-w-first'));
      await scrollWorklistTo(tester, toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(repo.toggledId, 'w-first');
      expect(repo.toggledValue, isFalse);
    });

    testWidgets('a refused toggle goes back and says so', (tester) async {
      final repo = _FakeWebhooksRepository(setActiveFailure: _networkFailure);
      await pump(tester, repo: repo);

      final toggle = find.byKey(const ValueKey<String>('toggle-w-first'));
      await scrollWorklistTo(tester, toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(tester.widget<TorchToggle>(toggle).value, isTrue);
      expect(find.byType(TorchToast), findsOneWidget);
      await settleToasts(tester);
    });
  });

  group('deliveries', () {
    testWidgets('open on the row, and each says what happened', (
      tester,
    ) async {
      final repo = _FakeWebhooksRepository();
      await pump(tester, repo: repo);

      final expander = find.byKey(
        const ValueKey<String>('deliveries-toggle-w-first'),
      );
      await scrollWorklistTo(tester, expander);
      await tester.tap(expander);
      await tester.pumpAndSettle();

      expect(repo.deliveriesFor, 'w-first');
      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('delivery-d-dead')),
      );
      expect(find.text('Gave up'), findsOneWidget);
      expect(find.text('connect ECONNREFUSED'), findsOneWidget);
    });

    testWidgets('a log that was cut says where it stops', (tester) async {
      // `listDeliveries` defaulted to ten that nobody asked for and the
      // provider threw the cursor away, so a manager debugging a failing
      // endpoint saw ten deliveries and no sign there were more. A log that
      // silently stops is a log you draw the wrong conclusion from.
      final repo = _FakeWebhooksRepository()..deliveriesCursor = 'page-2';
      await pump(tester, repo: repo);

      final expander = find.byKey(
        const ValueKey<String>('deliveries-toggle-w-first'),
      );
      await scrollWorklistTo(tester, expander);
      await tester.tap(expander);
      await tester.pumpAndSettle();

      await scrollWorklistTo(tester, find.textContaining('most recent'));
      expect(find.textContaining('most recent'), findsOneWidget);
      // Never a total: the server sends a cursor, not a count.
      expect(find.textContaining(' of '), findsNothing);
    });

    testWidgets('a whole log owns up to nothing', (tester) async {
      await pump(tester, repo: _FakeWebhooksRepository());

      final expander = find.byKey(
        const ValueKey<String>('deliveries-toggle-w-first'),
      );
      await scrollWorklistTo(tester, expander);
      await tester.tap(expander);
      await tester.pumpAndSettle();

      expect(find.textContaining('most recent'), findsNothing);
    });

    testWidgets('a failed delivery can be re-queued', (tester) async {
      final repo = _FakeWebhooksRepository();
      await pump(tester, repo: repo);

      final expander = find.byKey(
        const ValueKey<String>('deliveries-toggle-w-first'),
      );
      await scrollWorklistTo(tester, expander);
      await tester.tap(expander);
      await tester.pumpAndSettle();

      final redeliver = find.byKey(
        const ValueKey<String>('redeliver-d-dead'),
      );
      await scrollWorklistTo(tester, redeliver);
      await tester.tap(redeliver);
      await tester.pumpAndSettle();

      expect(repo.redeliveredId, 'd-dead');
      await settleToasts(tester);
    });

    testWidgets('a delivered one offers no re-queue', (tester) async {
      await pump(tester, repo: _FakeWebhooksRepository());

      final expander = find.byKey(
        const ValueKey<String>('deliveries-toggle-w-first'),
      );
      await scrollWorklistTo(tester, expander);
      await tester.tap(expander);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('redeliver-d-ok')),
        findsNothing,
      );
    });
  });

  group('delete', () {
    testWidgets('asks first and names the endpoint', (tester) async {
      final repo = _FakeWebhooksRepository();
      await pump(tester, repo: repo);

      final delete = find.byKey(const ValueKey<String>('delete-w-first'));
      await scrollWorklistTo(tester, delete);
      await tester.tap(delete);
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmSheet), findsOneWidget);
      expect(find.text('https://example.com/first'), findsWidgets);

      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();
      expect(repo.deletedId, isNull);
    });

    testWidgets('confirming deletes', (tester) async {
      final repo = _FakeWebhooksRepository();
      await pump(tester, repo: repo);

      final delete = find.byKey(const ValueKey<String>('delete-w-first'));
      await scrollWorklistTo(tester, delete);
      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete this endpoint'));
      await tester.pumpAndSettle();

      expect(repo.deletedId, 'w-first');
    });
  });

  group('the amber census', () {
    testWidgets('Night paints exactly one lit object: the nav tab', (
      tester,
    ) async {
      await pump(tester, repo: _FakeWebhooksRepository());

      final census = await amberCensus(tester);
      expectWithinAmberBudget(
        census,
        TiqSkin.night(),
        route: 'webhooks',
        phase: 'loaded',
      );
      expect(census.objectCount, 1, reason: census.describe());
    });

    testWidgets('Night, empty, still exactly the nav tab', (tester) async {
      await pump(
        tester,
        repo: _FakeWebhooksRepository(webhooks: <Webhook>[]),
      );
      final census = await amberCensus(tester);
      expect(census.objectCount, 1, reason: census.describe());
    });

    testWidgets('Night, error, still exactly the nav tab', (tester) async {
      await pump(
        tester,
        repo: _FakeWebhooksRepository(listFailure: _networkFailure),
      );
      final census = await amberCensus(tester);
      expect(census.objectCount, 1, reason: census.describe());
    });

    testWidgets('Night, the create sheet armed: one, and the nav is out', (
      tester,
    ) async {
      await pump(tester, repo: _FakeWebhooksRepository());
      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('webhook-create')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('webhook-create')));
      await tester.pumpAndSettle();

      var census = await amberCensus(tester);
      expect(
        census.objectCount,
        0,
        reason:
            'Nothing typed yet, so the commit is not armed and declares no '
            'claim; the nav beneath the sheet has gone out.\n'
            '${census.describe()}',
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('new-url')),
        'https://example.com/new',
      );
      await tester.pumpAndSettle();
      // The commit is past the fold inside the sheet, and the census counts
      // pixels: a button nobody has scrolled to has not been painted.
      await scrollSheetTo(
        tester,
        find.byKey(const ValueKey<String>('create-webhook')),
      );

      census = await amberCensus(tester);
      expectWithinAmberBudget(
        census,
        TiqSkin.night(),
        route: 'webhooks/new',
        phase: 'sheet',
      );
      expect(census.objectCount, 1, reason: census.describe());
    });

    for (final skin in <TiqSkin>[TiqSkin.day(), TiqSkin.veld()]) {
      for (final phase in const <String>['loaded', 'empty', 'error']) {
        testWidgets('${skin.mode.name}, $phase, paints no amber at all', (
          tester,
        ) async {
          await pump(
            tester,
            skin: skin,
            repo: _FakeWebhooksRepository(
              webhooks: phase == 'empty' ? <Webhook>[] : null,
              listFailure: phase == 'error' ? _networkFailure : null,
            ),
          );

          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            skin,
            route: 'webhooks',
            phase: phase,
          );
          expect(census.objectCount, 0, reason: census.describe());
        });
      }
    }
  });

  testWidgets('2.0x: the endpoints survive and nothing overflows', (
    tester,
  ) async {
    await pump(tester, repo: _FakeWebhooksRepository(), textScale: 2.0);

    await scrollWorklistTo(tester, find.text('Visit submitted'));
    expect(find.text('Visit submitted'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Veld builds the list', (tester) async {
    await pump(
      tester,
      repo: _FakeWebhooksRepository(),
      skin: TiqSkin.veld(),
    );

    expect(find.text('Visit submitted'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an event this build has never heard of keeps its token', (
    tester,
  ) async {
    // A fifth event the server starts emitting must be visibly a fifth
    // event, not a name this client invented for it.
    await pump(
      tester,
      repo: _FakeWebhooksRepository(
        webhooks: <Webhook>[
          Webhook(
            id: 'w-unknown',
            url: 'https://example.com/unknown',
            event: 'invoice.settled',
            active: true,
            health: WebhookHealth.healthy,
            hasSecret: true,
          ),
        ],
      ),
    );
    expect(find.text('invoice.settled'), findsOneWidget);
  });
}
